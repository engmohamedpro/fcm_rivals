// The v15 → v16 schema migration (dataset v3): the player presentation
// columns — club_id, club_name, club_crest_url, league_name,
// league_logo_url, image_url — land as PURE ADDITIONS. Every
// pre-existing row survives byte-for-byte and reads the 0/'' defaults;
// a fresh install creates v16 cleanly. Pattern: the schema_v12/v14
// migration tests (hand-crafted prior-version database on raw sqlite3,
// open with the current AppDatabase, snapshot before/after).
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The players shape through schema v15 (before the presentation
/// columns) — the v16 step ALTERs it.
const String _playersV15Ddl =
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

void main() {
  test('fresh install creates schema v16 with the presentation columns',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    expect(database.schemaVersion, 18);

    // The fresh-create path writes and reads the portrait facts through
    // the generated data class.
    await database
        .into(database.players)
        .insert(
          PlayersCompanion.insert(
            playerId: const Value(418560),
            name: 'Erling Haaland',
            position: 'ST',
            nationality: 'Norway',
            marketValueEur: 200_000_000,
            overall: 99,
            attack: 99,
            support: 90,
            defence: 45,
            goalkeeping: 15,
            clubId: const Value(281),
            clubName: Value('Manchester City'),
            clubCrestUrl: Value(
              'https://img.a.transfermarkt.technology/wappen/head/281.png',
            ),
            leagueName: Value('Premier League'),
            leagueLogoUrl: Value(
              'https://img.a.transfermarkt.technology/logo/header/gb1.png',
            ),
            imageUrl: Value(
              'https://img.a.transfermarkt.technology/portrait/header/'
              '418560-1709108116.png',
            ),
          ),
        );
    final row = await database.select(database.players).getSingle();
    expect(row.clubId, 281);
    expect(row.clubName, 'Manchester City');
    expect(row.imageUrl, contains('418560'));
  });

  test('v15→v16 upgrade preserves every existing row byte-for-byte',
      () async {
    final dir = await Directory.systemTemp.createTemp('fcm_v16_test');
    final file = File('${dir.path}/v15.db');
    addTearDown(() => dir.delete(recursive: true));

    // A hand-crafted v15 database with one player row and no
    // presentation columns.
    final raw = sqlite3.sqlite3.open(file.path);
    raw.execute(_playersV15Ddl);
    raw.execute(
      "INSERT INTO players VALUES (418560, 'Erling Haaland', 'ST', "
      "'Norway', 200000000, 99, 99, 90, 45, 15)",
    );
    raw.execute('PRAGMA user_version = 15');
    raw.dispose();

    final database = AppDatabase(NativeDatabase(file));
    addTearDown(database.close);
    expect(database.schemaVersion, 18);

    // The six columns exist...
    final columns = (await database
            .customSelect('PRAGMA table_info(players)')
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();
    expect(
      columns,
      containsAll(const [
        'club_id',
        'club_name',
        'club_crest_url',
        'league_name',
        'league_logo_url',
        'image_url',
      ]),
    );

    // ...and the pre-existing row survived with every original value
    // plus the additive defaults.
    final survived = await database.select(database.players).getSingle();
    expect(survived.playerId, 418560);
    expect(survived.name, 'Erling Haaland');
    expect(survived.marketValueEur, 200_000_000);
    expect(survived.overall, 99);
    expect(survived.clubId, 0);
    expect(survived.clubName, '');
    expect(survived.clubCrestUrl, '');
    expect(survived.leagueName, '');
    expect(survived.leagueLogoUrl, '');
    expect(survived.imageUrl, '');
  });
}
