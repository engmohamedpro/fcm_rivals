/// Schema v8 → v9 (AiPlayers.realPlayerId): an existing v8 database with
/// AI squads upgrades in place — rows survive, the new column reads as
/// null for the pre-existing synthetic players, and new seasons sign
/// real dataset players into it.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a v8 database upgrades to v9, keeping its AI squads', () async {
    final file = File(
      '${Directory.systemTemp.path}/v8_upgrade_${DateTime.now().millisecondsSinceEpoch}.sqlite',
    );

    // Phase 1: create the database with the CURRENT code, then rewind it
    // to a v8 shape (drop the v9 column by rebuilding the table without
    // it) and set user_version = 8 — exactly what a shipped v8 install
    // looks like to the new code.
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
        'CREATE TABLE ai_players_v8 (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'club_id INTEGER NOT NULL, player_name TEXT NOT NULL, '
        'position TEXT NOT NULL, attack INTEGER NOT NULL, '
        'support INTEGER NOT NULL, defence INTEGER NOT NULL, '
        'goalkeeping INTEGER NOT NULL, stamina_percent INTEGER NOT NULL '
        'DEFAULT 100)',
      );
      await db.customStatement(
        "INSERT INTO ai_players_v8 (club_id, player_name, position, attack, "
        "support, defence, goalkeeping, stamina_percent) VALUES "
        "(1, 'Legacy Star', 'ST', 70, 70, 70, 20, 88)",
      );
      await db.customStatement('DROP TABLE ai_players');
      await db.customStatement(
        'ALTER TABLE ai_players_v8 RENAME TO ai_players',
      );
      await db.customStatement('PRAGMA user_version = 8');
      await db.close();
    }

    // Phase 2: reopen with the current (v9) code — the migration runs.
    {
      final db = AppDatabase(NativeDatabase(file));
      final version = await db.customSelect('PRAGMA user_version').get();
      expect(
        version.first.read<int>('user_version'),
        9,
        reason: 'opening a v8 database migrates it to v9',
      );

      // The v8 row survived and reads through the drift API with a null
      // realPlayerId (synthetic legacy player).
      final rows = await db.select(db.aiPlayers).get();
      expect(rows.length, 1);
      expect(rows.single.playerName, 'Legacy Star');
      expect(rows.single.staminaPercent, 88);
      expect(rows.single.realPlayerId, isNull);

      // And the column accepts a real id for newly signed players.
      await db.customStatement(
        "INSERT INTO ai_players (club_id, player_name, position, attack, "
        "support, defence, goalkeeping, stamina_percent, real_player_id) "
        "VALUES (1, 'New Real', 'CB', 60, 60, 60, 20, 100, 4242)",
      );
      final after = await db.select(db.aiPlayers).get();
      expect(after.length, 2);
      expect(after.last.realPlayerId, 4242);
      await db.close();
    }

    await file.delete();
  });

  test('the fresh schema carries the real_player_id column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    expect(db.schemaVersion, 9);
    final cols = await db.customSelect("PRAGMA table_info('ai_players')").get();
    final names = cols.map((row) => row.read<String>('name')).toSet();
    expect(names.contains('real_player_id'), isTrue);
    await db.close();
  });
}
