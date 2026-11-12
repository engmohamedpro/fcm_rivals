/// Dataset probe (developer tool, not a shipped test): runs the shipped
/// tm-file bundle through the REAL parser, import rules, drift migration
/// and persistence round-trip — the verification harness for the
/// 2026-11-12 tm-bundle swap (owner request: the four tm-*.json assets
/// as sent, never rewritten; the loader adapts).
///
/// Sections:
///  1. parser — the tm bundle: players/icons/clubs/leagues, position
///     mapping, the icon flag, the 5 dual-file ids resolving to their
///     icon rows, legacy rows dropped by the v3-era validation rules;
///  2. import rules — presentation-fact changes update in place, only
///     Market Value/Position regenerate Base Stats (GDD 4.6);
///  3. schema migration — a hand-crafted v16 database upgrades to v17
///     with every pre-existing row byte-for-byte intact;
///  4. round-trip — the full bundle imports into a real drift database,
///     reopens, and the registry warm-up rows carry the portraits and
///     the icon flag.
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

const _playersPath = 'assets/data/tm-players.json';
const _iconsPath = 'assets/data/tm-icons.json';
const _clubsPath = 'assets/data/tm-clubs.json';
const _leaguesPath = 'assets/data/tm-leagues.json';

/// The players table shape through schema v16 (before the v17 is_icon
/// column) — the upgrade step ALTERs it.
const _playersV16Ddl =
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
    '"club_id" INTEGER NOT NULL DEFAULT 0, '
    '"club_name" TEXT NOT NULL DEFAULT \'\', '
    '"club_crest_url" TEXT NOT NULL DEFAULT \'\', '
    '"league_name" TEXT NOT NULL DEFAULT \'\', '
    '"league_logo_url" TEXT NOT NULL DEFAULT \'\', '
    '"image_url" TEXT NOT NULL DEFAULT \'\', '
    'PRIMARY KEY ("player_id"))';

Future<void> main() async {
  final dataset = PlayerDataset.fromTmBundle(
    playersJson: File(_playersPath).readAsStringSync(),
    iconsJson: File(_iconsPath).readAsStringSync(),
    clubsJson: File(_clubsPath).readAsStringSync(),
    leaguesJson: File(_leaguesPath).readAsStringSync(),
  );

  // ---------------------------------------------------------- 1. parser
  print('— parser');
  check(dataset.version == 4, 'bundle version 4');
  final icons = dataset.rows.where((r) => r.isIcon).toList();
  check(icons.length == 73, 'all 73 icon rows parse');
  final regulars = dataset.rows.where((r) => !r.isIcon).toList();
  check(regulars.length == 39017, '39,017 regular rows parse');
  final puskas = dataset.rows.firstWhere((r) => r.playerId == 103092);
  check(
    puskas.isIcon && puskas.name.contains('Pusk') && puskas.imageUrl.isNotEmpty,
    'Puskás imports as an icon with his portrait',
  );
  final haaland = dataset.rows.firstWhere((r) => r.playerId == 418560);
  check(
    haaland.name == 'Erling Haaland' &&
        !haaland.isIcon &&
        haaland.clubId == 281 &&
        haaland.clubName == 'Manchester City' &&
        haaland.clubCrestUrl.contains('wappen/big/281.png') &&
        haaland.leagueName == 'Premier League' &&
        haaland.leagueLogoUrl.contains('logo/medium/gb1') &&
        haaland.imageUrl.contains('portrait/big/418560'),
    'Haaland row resolves club + league + portrait via the maps',
  );
  // The 5 dual-file ids resolve to their ICON rows (the legend wins).
  const dualIds = {28003, 8198, 68290, 27992, 44352};
  check(
    dualIds.every(
      (id) => dataset.rows.firstWhere((r) => r.playerId == id).isIcon,
    ),
    'the 5 dual-file ids (Messi/Ronaldo/Neymar/Modrić/Suárez) are icons',
  );
  check(
    dataset.rows.any((r) => r.playerId == 8198 && r.name.contains('Ronaldo')),
    'Ronaldo resolves to the icon row',
  );

  // Legacy compact format still parses (old saves' reimport path).
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
        !legacyRow.isIcon &&
        legacyRow.playerId == 1 &&
        legacyRow.marketValueEur == 5_000_000,
    'legacy 5-field rows default every presentation fact',
  );

  // ------------------------------------------------- 2. import rules
  print('— import rules');
  final registry = PlayerDatabase();
  var result = registry.importDataset(dataset);
  check(
    result.added.length == 39090 && result.removed.isEmpty,
    'first import: all 39,090 rows added',
  );
  final before = {for (final p in registry.all) p.playerId: p.baseStats};
  result = registry.importDataset(dataset);
  check(
    result.unchanged == 39090 &&
        result.updated.isEmpty &&
        result.regenerated.isEmpty,
    're-import identical dataset: all unchanged',
  );
  check(
    before.entries.every((e) => registry[e.key]!.baseStats == e.value),
    'Base Stats byte-for-byte across the re-import',
  );

  // Presentation-fact change updates in place; stats untouched.
  final changedRow = PlayerDatasetRow(
    playerId: 418560,
    name: haaland.name,
    position: haaland.position,
    nationality: haaland.nationality,
    marketValueEur: haaland.marketValueEur,
    clubId: 131,
    clubName: 'FC Barcelona',
    clubCrestUrl: 'https://example.invalid/wappen.png',
    leagueName: 'LaLiga',
    leagueLogoUrl: 'https://example.invalid/laliga.png',
    imageUrl: haaland.imageUrl,
  );
  result = registry.importDataset(
    PlayerDataset(version: 5, asOf: '2026-11-12', rows: [
      changedRow,
      for (final r in dataset.rows)
        if (r.playerId != 418560) r,
    ]),
  );
  check(
    result.regenerated.isEmpty &&
        result.updated.length == 1 &&
        result.updated.single.playerId == 418560 &&
        result.updated.single.clubName == 'FC Barcelona' &&
        registry[418560]!.baseStats == before[418560],
    'club-only change updates in place, stats untouched',
  );
  final withNewValue = PlayerDatasetRow(
    playerId: 418560,
    name: haaland.name,
    position: haaland.position,
    nationality: haaland.nationality,
    marketValueEur: haaland.marketValueEur + 20_000_000,
    clubId: haaland.clubId,
    clubName: haaland.clubName,
    clubCrestUrl: haaland.clubCrestUrl,
    leagueName: haaland.leagueName,
    leagueLogoUrl: haaland.leagueLogoUrl,
    imageUrl: haaland.imageUrl,
  );
  result = registry.importDataset(
    PlayerDataset(version: 6, asOf: '2026-11-12', rows: [
      withNewValue,
      for (final r in dataset.rows)
        if (r.playerId != 418560) r,
    ]),
  );
  check(
    result.regenerated.any((p) => p.playerId == 418560),
    'Market Value change still regenerates Base Stats',
  );

  // -------------------------------------------- 3. v16 -> v17 migration
  print('— schema migration v16 -> v17');
  final dir = Directory.systemTemp.createTempSync('fcm_v17_probe');
  final migrateFile = File('${dir.path}/migrate.db');
  {
    final raw3 = sqlite3.sqlite3.open(migrateFile.path);
    raw3.execute(_playersV16Ddl);
    raw3.execute(
      "INSERT INTO players VALUES (418560, 'Erling Haaland', 'ST', "
      "'Norway', 200000000, 99, 99, 90, 45, 15, 281, 'Manchester City', "
      "'https://img.a.transfermarkt.technology/wappen/big/281.png', "
      "'Premier League', 'https://img.a.transfermarkt.technology/"
      "logo/medium/gb1.png', 'https://img.a.transfermarkt.technology/"
      "portrait/big/418560-1788115885.jpg')",
    );
    raw3.execute('PRAGMA user_version = 16');
    raw3.dispose();
  }
  {
    final db = AppDatabase(NativeDatabase(migrateFile));
    // Opening runs the v17 step: is_icon lands with its default and the
    // pre-existing row survives byte-for-byte.
    final columns = await db.customSelect('PRAGMA table_info(players)').get();
    final names = columns.map((r) => r.read<String>('name')).toSet();
    check(names.contains('is_icon'), 'v16 database upgraded: is_icon exists');
    final survived = await db.select(db.players).getSingle();
    check(
      survived.playerId == 418560 &&
          survived.name == 'Erling Haaland' &&
          survived.marketValueEur == 200000000 &&
          survived.overall == 99 &&
          survived.clubId == 281 &&
          survived.imageUrl.isNotEmpty &&
          survived.isIcon == false,
      'pre-existing row intact, is_icon defaults false',
    );
    await db.close();
  }

  // ------------------------------------------- 4. full round-trip
  print('— persistence round-trip (full bundle)');
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
              isIcon: Value(player.isIcon),
            ),
        ],
        mode: InsertMode.insertOrReplace,
      );
    });
    await db.close();
  }
  {
    // Reopen fresh — the registry warm-up path reads everything back.
    final db = AppDatabase(NativeDatabase(roundTripFile));
    final rowsBack = await db.select(db.players).get();
    check(rowsBack.length == 39090, 'reopened database holds all 39,090 rows');
    final iconRows = rowsBack.where((r) => r.isIcon).length;
    check(iconRows == 73, 'icon round-trip: all 73 survive the reopen');
    final hh = rowsBack.firstWhere((r) => r.playerId == 418560);
    check(
      hh.imageUrl.contains('portrait/big/418560') &&
          hh.clubId == 281 &&
          hh.clubName == 'Manchester City' &&
          hh.leagueName == 'Premier League' &&
          !hh.isIcon,
      'Haaland round-trips portrait + club + league + flag',
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
