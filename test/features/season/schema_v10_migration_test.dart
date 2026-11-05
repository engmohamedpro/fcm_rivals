/// Schema migrations into the CURRENT version: a shipped v8 install (no
/// `ai_players.real_player_id`, no `user_settings.locale`) and a shipped
/// v9 install (real ids but no `locale`) both upgrade in place — rows
/// survive, each step applies exactly once, and the resulting schema
/// matches what fresh code creates.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The v8 shape of the two tables touched since: ai_players without
  /// real_player_id, user_settings without locale.
  const v8Shape = [
    'CREATE TABLE ai_players_v8 (id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'club_id INTEGER NOT NULL, player_name TEXT NOT NULL, '
    'position TEXT NOT NULL, attack INTEGER NOT NULL, '
    'support INTEGER NOT NULL, defence INTEGER NOT NULL, '
    'goalkeeping INTEGER NOT NULL, stamina_percent INTEGER NOT NULL '
    'DEFAULT 100)',
    'CREATE TABLE user_settings_v8 (id INTEGER NOT NULL, '
    'match_speed INTEGER NOT NULL DEFAULT 1)',
  ];

  /// Rewinds the current on-disk schema to an older user_version by
  /// swapping the drifted tables for hand-built old shapes, seeded with
  /// one surviving row each. Reopening then exercises the real upgrade
  /// path over exactly the columns a shipped install would have.
  Future<File> rewindTo(String tag, int version) async {
    final file = File(
      '${Directory.systemTemp.path}/${tag}_${DateTime.now().millisecondsSinceEpoch}.sqlite',
    );
    final db = AppDatabase(NativeDatabase(file));
    for (final statement in v8Shape) {
      await db.customStatement(statement);
    }
    await db.customStatement(
      "INSERT INTO ai_players_v8 (club_id, player_name, position, attack, "
      "support, defence, goalkeeping, stamina_percent) VALUES "
      "(1, 'Legacy Star', 'ST', 70, 70, 70, 20, 88)",
    );
    await db.customStatement(
      "INSERT INTO user_settings_v8 (id, match_speed) VALUES (1, 3)",
    );
    await db.customStatement('DROP TABLE ai_players');
    await db.customStatement('DROP TABLE user_settings');
    await db.customStatement(
      'ALTER TABLE ai_players_v8 RENAME TO ai_players',
    );
    await db.customStatement(
      'ALTER TABLE user_settings_v8 RENAME TO user_settings',
    );
    if (version >= 9) {
      await db.customStatement(
        'ALTER TABLE ai_players ADD COLUMN real_player_id INTEGER NULL',
      );
      await db.customStatement(
        "UPDATE ai_players SET real_player_id = 4242 WHERE player_name = "
        "'Legacy Star'",
      );
    }
    // Clubs back to the pre-v11 shape: playing_style text column, no
    // tactics payload — the v11 step (played_style → tactics JSON)
    // must run against the real legacy column set.
    await db.customStatement(
      'CREATE TABLE clubs_v10 (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, manager_name TEXT NOT NULL, '
      'crest_index INTEGER NOT NULL DEFAULT 0, '
      'formation_code TEXT NOT NULL DEFAULT \'4-3-3\', '
      'playing_style TEXT NOT NULL DEFAULT \'balanced\', '
      'mentality TEXT NOT NULL DEFAULT \'balanced\', '
      'coins INTEGER NOT NULL, is_user INTEGER NOT NULL DEFAULT 1, '
      'created_at INTEGER NOT NULL)',
    );
    await db.customStatement(
      "INSERT INTO clubs_v10 (name, manager_name, playing_style, coins, "
      "created_at) VALUES ('Legacy FC', 'Old Manager', 'lowBlock', 500, "
      "1700000000000)",
    );
    await db.customStatement('DROP TABLE clubs');
    await db.customStatement('ALTER TABLE clubs_v10 RENAME TO clubs');
    await db.customStatement('PRAGMA user_version = $version');
    await db.close();
    return file;
  }

  /// Column names of a table on the reopened (migrated) database.
  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  test('a v8 database upgrades to the current version, keeping its AI '
      'squads and settings', () async {
    final file = await rewindTo('v8_upgrade', 8);

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());

    final version = await db.customSelect('PRAGMA user_version').get();
    expect(version.first.read<int>('user_version'), db.schemaVersion,
        reason: 'opening a v8 database migrates it to the current version');

    // The v8 row survived and reads through the drift API with a null
    // realPlayerId (synthetic legacy player).
    final rows = await db.select(db.aiPlayers).get();
    expect(rows.length, 1);
    expect(rows.single.playerName, 'Legacy Star');
    expect(rows.single.staminaPercent, 88);
    expect(rows.single.realPlayerId, isNull);

    // The persisted match speed survived the v8→v10 walk (v8 created the
    // table, v10 added the locale column beside it).
    final settings = await db.select(db.userSettings).get();
    expect(settings.single.matchSpeed, 3);
    expect(settings.single.locale, isNull);

    // Both post-v8 columns exist — each migration step applied exactly
    // once (a double apply would have thrown "duplicate column name").
    expect((await columnsOf(db, 'ai_players')).contains('real_player_id'),
        isTrue);
    expect((await columnsOf(db, 'user_settings')).contains('locale'), isTrue);
    // The v11 step swapped the clubs style column for the tactics
    // payload — the legacy row survives it.
    final clubColumns = await columnsOf(db, 'clubs');
    expect(clubColumns.contains('tactics'), isTrue);
    expect(clubColumns.contains('playing_style'), isFalse);
    final clubRows = await db.select(db.clubs).get();
    expect(clubRows.single.name, 'Legacy FC');

    // The columns accept values for newly written rows.
    await db.customStatement(
      "INSERT INTO ai_players (club_id, player_name, position, attack, "
      "support, defence, goalkeeping, stamina_percent, real_player_id) "
      "VALUES (1, 'New Real', 'CB', 60, 60, 60, 20, 100, 4242)",
    );
    final after = await db.select(db.aiPlayers).get();
    expect(after.length, 2);
    expect(after.last.realPlayerId, 4242);

    await file.delete();
  });

  test('a v9 database upgrades to the current version, adding locale '
      'beside the existing real ids', () async {
    final file = await rewindTo('v9_upgrade', 9);

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());

    final version = await db.customSelect('PRAGMA user_version').get();
    expect(version.first.read<int>('user_version'), db.schemaVersion,
        reason: 'opening a v9 database migrates it to the current version');

    // The v9 row survived WITH its real id — only the v10 step ran.
    final rows = await db.select(db.aiPlayers).get();
    expect(rows.single.playerName, 'Legacy Star');
    expect(rows.single.realPlayerId, 4242);

    // v10 applied exactly once: the locale column exists and reads null
    // (follow the system locale) for the untouched row.
    expect((await columnsOf(db, 'user_settings')).contains('locale'), isTrue);
    final settings = await db.select(db.userSettings).get();
    expect(settings.single.matchSpeed, 3);
    expect(settings.single.locale, isNull);

    await file.delete();
  });

  test('the fresh schema carries the current migration columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => db.close());

    expect(db.schemaVersion, 11);
    expect((await columnsOf(db, 'ai_players')).contains('real_player_id'),
        isTrue);
    expect((await columnsOf(db, 'user_settings')).contains('locale'), isTrue);
    expect((await columnsOf(db, 'clubs')).contains('tactics'), isTrue);
    expect((await columnsOf(db, 'clubs')).contains('playing_style'), isFalse);
  });
}
