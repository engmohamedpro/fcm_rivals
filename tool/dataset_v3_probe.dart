/// Dataset v3 probe (developer tool, not a shipped test): runs the
/// shipped asset through the REAL parser, import rules, drift migration
/// and persistence round-trip — the verification harness for the
/// portrait/club presentation facts (schema v16).
///
/// Sections:
///  1. parser — 7-field rows + clubs/leagues maps on the shipped asset,
///     legacy 5-field rows keep their defaults;
///  2. import rules — presentation-fact changes update in place, only
///     Market Value/Position regenerate Base Stats (GDD 4.6);
///  3. schema migration — a hand-crafted v15 database upgrades to v16
///     with every pre-existing row byte-for-byte intact;
///  4. round-trip — the full asset imports into a real drift database,
///     reopens, and the registry warm-up rows carry the portraits.
///
/// Run: dart run tool/dataset_v3_probe.dart
library;

// ignore_for_file: avoid_print — CLI report tool.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart' show NativeDatabase;
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

int _checks = 0;
int _failures = 0;

void check(bool condition, String label) {
  _checks++;
  if (condition) {
    print('ok   $label');
  } else {
    _failures++;
    print('FAIL $label');
  }
}

const assetPath = 'assets/data/players_v1.json';

/// The players table shape through schema v15 (before the v16
/// presentation columns) — the upgrade step ALTERs it.
const _playersV15Ddl =
    'CREATE TABLE IF NOT EXISTS "players" ('
    '"player_id" INTEGER NOT NULL, '
    '"name" TEXT NOT NULL, '
    '"position" TEXT NOT NULL, '
    '"nationality" TEXT NOT NULL, '
    '"market_value_eur" INTEGER NOT NULL, '
    '"overall" INTEGER NOT NULL, '
    '"attack" INTEGER NOT NULL, '
    '"support" INTEGER NOT NULL, '
    '"defence" INTEGER NOT NULL, '
    '"goalkeeping" INTEGER NOT NULL, '
    'PRIMARY KEY ("player_id"))';

Future<void> main() async {
  final text = File(assetPath).readAsStringSync();
  final raw = json.decode(text) as Map<String, dynamic>;

  // ---------------------------------------------------------- 1. parser
  print('— parser');
  final dataset = PlayerDataset.fromJson(text);
  check(dataset.count == 20876, 'asset parses, 20,876 rows');
  check(dataset.version == 3 && dataset.asOf.isNotEmpty, 'v3 metadata');

  final haaland = dataset.rows.firstWhere((r) => r.playerId == 418560);
  check(
    haaland.name == 'Erling Haaland' &&
        haaland.clubId == 281 &&
        haaland.clubName == 'Manchester City' &&
        haaland.clubCrestUrl.endsWith('wappen/head/281.png') &&
        haaland.leagueName == 'Premier League' &&
        haaland.leagueLogoUrl.endsWith('logo/header/gb1.png') &&
        haaland.imageUrl.endsWith('418560-1709108116.png'),
    'Haaland row resolves club + league + portrait via the maps',
  );
  final withImage = dataset.rows.where((r) => r.imageUrl.isNotEmpty).length;
  check(withImage == 19476, 'portrait coverage 19,476 (placeholders are \'\')');
  check(
    dataset.clubs['515'] != null && dataset.clubs['515']!.name == 'Free Agent',
    'free-agent convention in the clubs map',
  );

  final legacy = PlayerDataset.fromJson(
    json.encode({
      'format': 'fcm-rivals-players',
      'version': 2,
      'asOf': '2026-11-01',
      'players': [
        [1, 'Legacy Row', 'ST', 'Egypt', 5_000_000],
      ],
    }),
  );
  final legacyRow = legacy.rows.single;
  check(
    legacyRow.clubId == 0 &&
        legacyRow.clubName.isEmpty &&
        legacyRow.imageUrl.isEmpty &&
        legacyRow.playerId == 1 &&
        legacyRow.marketValueEur == 5_000_000,
    'legacy 5-field rows default every presentation fact',
  );

  // ------------------------------------------------- 2. import rules
  print('— import rules');
  final registry = PlayerDatabase();
  var result = registry.importDataset(dataset);
  check(
    result.added.length == 20876 && result.removed.isEmpty,
    'first import: all 20,876 added',
  );
  final before = {for (final p in registry.all) p.playerId: p.baseStats};
  result = registry.importDataset(dataset);
  check(
    result.unchanged == 20876 &&
        result.updated.isEmpty &&
        result.regenerated.isEmpty,
    're-import identical dataset: all unchanged',
  );
  check(
    before.length == 20876 &&
        before.entries.every((e) => registry[e.key]!.baseStats == e.value),
    'Base Stats byte-for-byte across the re-import',
  );

  final rows = [
    for (final r in (raw['players'] as List).take(50))
      PlayerDatasetRow.fromList(r as List, clubs: dataset.clubs, leagues: dataset.leagues),
  ];
  final withNewImage = [
    for (final r in rows)
      r.playerId == 418560
          ? PlayerDatasetRow.fromList(
              [
                r.playerId,
                r.name,
                r.position.code,
                r.nationality,
                r.marketValueEur,
                r.clubId,
                'https://img.a.transfermarkt.technology/portrait/header/'
                    '418560-1788115885.jpg',
              ],
              clubs: dataset.clubs,
              leagues: dataset.leagues,
            )
          : r,
  ];
  final slice = PlayerDataset(
    version: 4,
    asOf: '2026-11-12',
    rows: withNewImage,
    clubs: dataset.clubs,
    leagues: dataset.leagues,
  );
  result = registry.importDataset(slice);
  check(
    result.regenerated.isEmpty &&
        result.updated.length == 1 &&
        result.updated.single.playerId == 418560 &&
        result.updated.single.imageUrl.endsWith('418560-1788115885.jpg') &&
        registry[418560]!.baseStats == before[418560],
    'image-only change updates in place, stats untouched',
  );
  final withNewValue = [
    for (final r in rows)
      r.playerId == 418560
          ? PlayerDatasetRow.fromList(
              [
                r.playerId,
                r.name,
                r.position.code,
                r.nationality,
                r.marketValueEur + 20_000_000,
                r.clubId,
                r.imageUrl,
              ],
              clubs: dataset.clubs,
              leagues: dataset.leagues,
            )
          : r,
  ];
  result = registry.importDataset(
    PlayerDataset(version: 5, asOf: '2026-11-12', rows: withNewValue),
  );
  check(
    result.regenerated.any((p) => p.playerId == 418560),
    'Market Value change still regenerates Base Stats',
  );

  // -------------------------------------------- 3. v15 -> v16 migration
  print('— schema migration v15 -> v16');
  final dir = Directory.systemTemp.createTempSync('fcm_v16_probe');
  final migrateFile = File('${dir.path}/migrate.db');
  {
    final raw3 = sqlite3.sqlite3.open(migrateFile.path);
    raw3.execute(_playersV15Ddl);
    raw3.execute(
      "INSERT INTO players VALUES (418560, 'Erling Haaland', 'ST', "
      "'Norway', 200000000, 99, 99, 90, 45, 15)",
    );
    raw3.execute('PRAGMA user_version = 15');
    raw3.dispose();
  }
  {
    final db = AppDatabase(NativeDatabase(migrateFile));
    // Opening runs the v16 step: the six presentation columns land with
    // their defaults and the pre-existing row survives byte-for-byte.
    final columns = await db.customSelect('PRAGMA table_info(players)').get();
    final names = columns.map((r) => r.read<String>('name')).toSet();
    check(
      names.containsAll(const [
        'club_id',
        'club_name',
        'club_crest_url',
        'league_name',
        'league_logo_url',
        'image_url',
      ]),
      'v15 database upgraded: the six columns exist',
    );
    final survived = await db.select(db.players).getSingle();
    check(
      survived.playerId == 418560 &&
          survived.name == 'Erling Haaland' &&
          survived.marketValueEur == 200000000 &&
          survived.overall == 99 &&
          survived.clubId == 0 &&
          survived.imageUrl.isEmpty,
      'pre-existing row intact with the 0/\'\' defaults',
    );
    await db.close();
  }

  // ------------------------------------------- 4. full round-trip
  print('— persistence round-trip (full asset)');
  final roundTripFile = File('${dir.path}/roundtrip.db');
  {
    final db = AppDatabase(NativeDatabase(roundTripFile));
    final registry2 = PlayerDatabase();
    final imported = registry2.importDataset(dataset);
    // The store's exact upsert pattern (collection_store_dataset.dart).
    await db.batch((batch) {
      batch.insertAll(
        db.players,
        [
          for (final player in [
            ...imported.added,
            ...imported.updated,
            ...imported.regenerated,
          ])
            PlayersCompanion.insert(
              playerId: Value(player.playerId),
              name: player.name,
              position: player.position.code,
              nationality: player.nationality,
              marketValueEur: player.marketValueEur,
              overall: player.baseStats.overall,
              attack: player.baseStats.attack,
              support: player.baseStats.support,
              defence: player.baseStats.defence,
              goalkeeping: player.baseStats.goalkeeping,
              clubId: Value(player.clubId),
              clubName: Value(player.clubName),
              clubCrestUrl: Value(player.clubCrestUrl),
              leagueName: Value(player.leagueName),
              leagueLogoUrl: Value(player.leagueLogoUrl),
              imageUrl: Value(player.imageUrl),
            ),
        ],
        mode: InsertMode.insertOrReplace,
      );
    });
    await db.close();
  }
  {
    // Reopen fresh — the registry warm-up path reads the portraits back.
    final db = AppDatabase(NativeDatabase(roundTripFile));
    final rowsBack = await db.select(db.players).get();
    check(rowsBack.length == 20876, 'reopened database holds all 20,876 rows');
    final images = rowsBack.where((r) => r.imageUrl.isNotEmpty).length;
    check(images == 19476, 'portrait round-trip: 19,476 survive the reopen');
    final hh = rowsBack.firstWhere((r) => r.playerId == 418560);
    check(
      hh.imageUrl.endsWith('418560-1709108116.png') &&
          hh.clubId == 281 &&
          hh.clubName == 'Manchester City' &&
          hh.leagueName == 'Premier League',
      'Haaland round-trips portrait + club + league',
    );
    await db.close();
  }

  print(
    _failures == 0
        ? '\nALL $_checks CHECKS PASSED'
        : '\n$_failures FAILURES OUT OF $_checks CHECKS',
  );
  exit(_failures == 0 ? 0 : 1);
}
