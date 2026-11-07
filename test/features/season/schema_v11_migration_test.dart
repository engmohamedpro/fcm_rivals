/// Schema migration into the CURRENT version: a shipped v10 install
/// (playing_style text column, no tactics JSON column) upgrades in
/// place — rows survive, the new column exists, and every legacy
/// playing-style value loads as default tactics with no exceptions.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Rewinds the current on-disk schema to hand-built v10-shaped
  /// `clubs`, `owned_players` and `ai_players` tables (a real v10
  /// install predates the tactics column AND the v12 injury columns),
  /// then reopens through the real upgrade path.
  Future<File> rewindToV10(String playingStyle) async {
    final file = File(
      '${Directory.systemTemp.path}/v10_${playingStyle}_'
      '${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    final db = AppDatabase(NativeDatabase(file));
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
      "created_at) VALUES ('Legacy FC', 'Old Manager', '$playingStyle', "
      "500, 1700000000000)",
    );
    await db.customStatement('DROP TABLE clubs');
    await db.customStatement('ALTER TABLE clubs_v10 RENAME TO clubs');
    // The v12 migration (T-0053) adds the injury columns to these two
    // tables — the fixture must present them at their pre-v12 shape or
    // the ADD COLUMNs would hit duplicate columns on current-shape
    // tables that a real v10 install never had.
    await db.customStatement(
      'CREATE TABLE owned_players_v11 (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'club_id INTEGER NOT NULL, player_id INTEGER NOT NULL, '
      'upgrade_level INTEGER NOT NULL DEFAULT 0, '
      'upgraded_attack INTEGER NOT NULL DEFAULT 0, '
      'upgraded_support INTEGER NOT NULL DEFAULT 0, '
      'upgraded_defence INTEGER NOT NULL DEFAULT 0, '
      'upgraded_goalkeeping INTEGER NOT NULL DEFAULT 0, '
      'stamina_percent INTEGER NOT NULL DEFAULT 100, '
      'squad_slot INTEGER NULL, status TEXT NOT NULL DEFAULT \'owned\', '
      'acquisition_source TEXT NOT NULL DEFAULT \'pack\', '
      'acquired_at INTEGER NOT NULL)',
    );
    await db.customStatement('DROP TABLE owned_players');
    await db.customStatement(
      'ALTER TABLE owned_players_v11 RENAME TO owned_players',
    );
    await db.customStatement(
      'CREATE TABLE ai_players_v11 (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'club_id INTEGER NOT NULL, player_name TEXT NOT NULL, '
      'position TEXT NOT NULL, attack INTEGER NOT NULL, '
      'support INTEGER NOT NULL, defence INTEGER NOT NULL, '
      'goalkeeping INTEGER NOT NULL, '
      'stamina_percent INTEGER NOT NULL DEFAULT 100, '
      'real_player_id INTEGER NULL)',
    );
    await db.customStatement('DROP TABLE ai_players');
    await db.customStatement('ALTER TABLE ai_players_v11 RENAME TO ai_players');
    await db.customStatement('PRAGMA user_version = 10');
    await db.close();
    return file;
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  test('a v10 database upgrades: tactics column added, rows survive', () async {
    final file = await rewindToV10('gegenpressing');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final columns = await columnsOf(db, 'clubs');
    expect(columns, contains('tactics'));
    expect(columns, isNot(contains('playing_style')));

    final clubs = await db.select(db.clubs).get();
    expect(clubs, hasLength(1));
    expect(clubs.first.name, 'Legacy FC');
  });

  test('every legacy style name loads as default tactics, no exceptions',
      () async {
    const legacyStyles = [
      'possession',
      'tikiTaka',
      'directPlay',
      'counterAttack',
      'gegenpressing',
      'highPress',
      'wingPlay',
      'longBall',
      'lowBlock',
      'balanced',
    ];
    for (final style in legacyStyles) {
      final file = await rewindToV10(style);
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final clubs = await db.select(db.clubs).get();
      expect(clubs, hasLength(1), reason: style);
      // The migrated column's default: no payload yet.
      expect(clubs.first.tactics, anyOf(isEmpty, '{}'), reason: style);
      // The loader maps any legacy value to the default setup: an
      // identity modifier bundle, exactly the old Balanced behaviour.
      final tactics = tacticsFromDbPayload(clubs.first.tactics);
      expect(tactics, const TeamTactics(), reason: style);
      expect(tactics.modifiers.attack, 1.0);
      expect(tactics.modifiers.possession, 1.0);
      // The legacy-style factory agrees (documentation-only mapping).
      expect(TeamTactics.fromLegacyStyle(style), const TeamTactics());
    }
  });

  test('a legacy value sitting in the tactics column also loads safely',
      () async {
    // A v10 row whose style text was carried over into the new column
    // (defensive double-check for hand-migrated installs).
    expect(tacticsFromDbPayload('counterAttack'), const TeamTactics());
    expect(tacticsFromDbPayload(''), const TeamTactics());
    expect(tacticsFromDbPayload(null), const TeamTactics());
    expect(tacticsFromDbPayload('not json'), const TeamTactics());
    expect(tacticsFromDbPayload('[1,2,3]'), const TeamTactics());
  });

  test('a round-tripped tactics payload loads back', () async {
    final tactics = const TeamTactics();
    final payload = tactics.toJson();
    expect(TeamTactics.fromJson(payload), tactics);
  });
}
