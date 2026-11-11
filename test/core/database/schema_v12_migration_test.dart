import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The OwnedPlayers shape as it existed through schema v11 (before the
/// v12 injury columns). Column names and types must match what drift
/// generated for v11 — the ALTER TABLE ADD COLUMN migration appends to
/// exactly this table.
const String _ownedPlayersV11Ddl =
    'CREATE TABLE IF NOT EXISTS "owned_players" ('
    '"id" INTEGER PRIMARY KEY AUTOINCREMENT, '
    '"club_id" INTEGER NOT NULL, '
    '"player_id" INTEGER NOT NULL, '
    '"upgrade_level" INTEGER NOT NULL DEFAULT 0, '
    '"upgraded_attack" INTEGER NOT NULL DEFAULT 0, '
    '"upgraded_support" INTEGER NOT NULL DEFAULT 0, '
    '"upgraded_defence" INTEGER NOT NULL DEFAULT 0, '
    '"upgraded_goalkeeping" INTEGER NOT NULL DEFAULT 0, '
    '"stamina_percent" INTEGER NOT NULL DEFAULT 100, '
    '"squad_slot" INTEGER NULL, '
    '"status" TEXT NOT NULL DEFAULT \'owned\', '
    '"acquisition_source" TEXT NOT NULL DEFAULT \'pack\', '
    '"acquired_at" INTEGER NOT NULL)';

/// The AiPlayers shape through schema v11.
const String _aiPlayersV11Ddl =
    'CREATE TABLE IF NOT EXISTS "ai_players" ('
    '"id" INTEGER PRIMARY KEY AUTOINCREMENT, '
    '"club_id" INTEGER NOT NULL, '
    '"player_name" TEXT NOT NULL, '
    '"position" TEXT NOT NULL, '
    '"attack" INTEGER NOT NULL, '
    '"support" INTEGER NOT NULL, '
    '"defence" INTEGER NOT NULL, '
    '"goalkeeping" INTEGER NOT NULL, '
    '"stamina_percent" INTEGER NOT NULL DEFAULT 100, '
    '"real_player_id" INTEGER NULL)';

const List<String> _ownedPlayersV11Columns = [
  'id', 'club_id', 'player_id', 'upgrade_level', 'upgraded_attack',
  'upgraded_support', 'upgraded_defence', 'upgraded_goalkeeping',
  'stamina_percent', 'squad_slot', 'status', 'acquisition_source',
  'acquired_at',
];

const List<String> _aiPlayersV11Columns = [
  'id', 'club_id', 'player_name', 'position', 'attack', 'support',
  'defence', 'goalkeeping', 'stamina_percent', 'real_player_id',
];

void main() {
  test('fresh install creates schema v12 with the injury columns', () async {
    final database = AppDatabase(NativeDatabase.memory());
    // Add a player with an active injury and read it back.
    final id = await database.into(database.ownedPlayers).insert(
          OwnedPlayersCompanion.insert(
            clubId: 1,
            playerId: 42,
            acquiredAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            injuryMatchesRemaining: const Value(3),
            injuryKind: const Value('muscle'),
          ),
        );
    final row =
        await (database.select(database.ownedPlayers)
              ..where((t) => t.id.equals(id)))
            .getSingle();
    expect(row.injuryMatchesRemaining, 3);
    expect(row.injuryKind, 'muscle');
    // A healthy default row reads as fit.
    await database.into(database.ownedPlayers).insert(
          OwnedPlayersCompanion.insert(
            clubId: 1,
            playerId: 43,
            acquiredAt: DateTime.fromMillisecondsSinceEpoch(1700000000001),
          ),
        );
    final healthy = await (database.select(database.ownedPlayers)
          ..where((t) => t.playerId.equals(43)))
        .getSingle();
    expect(healthy.injuryMatchesRemaining, 0);
    expect(healthy.injuryKind, isNull);
    // T-0097 bumped the schema to 13 (clubs.crest); T-0106 to
    // 14 (achievement_claims + equipped_title); the daily rewards
    // streak bumped it to 15 (daily_streak_claims); dataset v3's
    // presentation columns to 16 — the injury columns this fixture
    // exercises are untouched by all four.
    expect(database.schemaVersion, 16);
    await database.close();
  });

  test('v11→v12 upgrade preserves every existing row byte-for-byte',
      () async {
    final file = File(
      '${Directory.systemTemp.createTempSync('fcm_v12').path}/db.sqlite',
    );
    // 1. Hand-craft a v11 database with one row per table.
    final raw = sqlite3.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 11');
    // The v11 fixture's clubs table (T-0097): pre-crest shape — the
    // v13 step ALTERs it, so it must exist like a real v11 install's.
    raw.execute(
      "CREATE TABLE IF NOT EXISTS \"clubs\" ("
      "\"id\" INTEGER PRIMARY KEY AUTOINCREMENT, "
      "\"name\" TEXT NOT NULL, \"manager_name\" TEXT NOT NULL, "
      "\"crest_index\" INTEGER NOT NULL DEFAULT 0, "
      "\"formation_code\" TEXT NOT NULL DEFAULT '4-3-3', "
      "\"tactics\" TEXT NOT NULL DEFAULT '{}', "
      "\"mentality\" TEXT NOT NULL DEFAULT 'balanced', "
      "\"coins\" INTEGER NOT NULL, \"is_user\" INTEGER NOT NULL DEFAULT 1, "
      "\"created_at\" INTEGER NOT NULL)",
    );
    raw.execute(_ownedPlayersV11Ddl);
    raw.execute(_aiPlayersV11Ddl);
    // A real v11 database also carries the v8 settings table and the
    // coin ledger — the v14 step ALTERs user_settings, so the fixture
    // must be a faithful v11 (T-0106 found this gap when v14's ALTER
    // hit a settings table the old fixture never created).
    raw.execute(
      'CREATE TABLE IF NOT EXISTS "user_settings" ('
      '"id" INTEGER NOT NULL, '
      '"match_speed" INTEGER NOT NULL DEFAULT 1, '
      '"locale" TEXT NULL, '
      'PRIMARY KEY ("id"))',
    );
    raw.execute("INSERT INTO user_settings VALUES (1, 2, NULL)");
    raw.execute(
      "INSERT INTO owned_players VALUES (1, 1, 42, 2, 1, 0, 3, 0, 73, 5, "
      "'owned', 'pack', 1700000000)",
    );
    raw.execute(
      "INSERT INTO owned_players VALUES (2, 1, 77, 0, 0, 0, 0, 0, 100, "
      "NULL, 'owned', 'starting', 1700000001)",
    );
    raw.execute(
      "INSERT INTO ai_players VALUES (1, 2, 'AI Keeper', 'GK', 40, 35, 38, "
      "78, 91, NULL)",
    );
    Set<String> snapshot(
      sqlite3.Database db,
      String table,
      List<String> columns,
    ) => {
      for (final row in db.select('SELECT * FROM $table'))
        '${row['id']}: ${columns.map((c) => row[c]).join('|')}',
    };

    final ownedBefore = snapshot(raw, 'owned_players', _ownedPlayersV11Columns);
    final aiBefore = snapshot(raw, 'ai_players', _aiPlayersV11Columns);
    raw.dispose();

    // 2. Open with the current database: the 11→12 migration runs.
    final database = AppDatabase(NativeDatabase(file));
    final ownedRows = await database.select(database.ownedPlayers).get();
    expect(ownedRows, hasLength(2));
    expect(ownedRows.first.injuryMatchesRemaining, 0);
    expect(ownedRows.first.injuryKind, isNull);
    final aiRows = await database.select(database.aiPlayers).get();
    expect(aiRows.single.injuryMatchesRemaining, 0);
    expect(aiRows.single.injuryKind, isNull);

    // 3. The AI row can carry an injury through the same columns.
    await (database.update(database.aiPlayers)
          ..where((t) => t.id.equals(1)))
        .write(
      const AiPlayersCompanion(
        injuryMatchesRemaining: Value(2),
        injuryKind: Value('knock'),
      ),
    );
    final aiRow =
        await (database.select(database.aiPlayers)
              ..where((t) => t.id.equals(1)))
            .getSingle();
    expect(aiRow.injuryMatchesRemaining, 2);
    expect(aiRow.injuryKind, 'knock');
    await database.close();

    // 4. Every v11 column of every pre-existing row survived untouched —
    // the snapshot covers only v11 columns, so the post-migration injury
    // write to the AI row does not affect it.
    final reopened = sqlite3.sqlite3.open(file.path);
    expect(
      snapshot(reopened, 'owned_players', _ownedPlayersV11Columns),
      ownedBefore,
    );
    expect(
      snapshot(reopened, 'ai_players', _aiPlayersV11Columns),
      aiBefore,
    );
    expect(
      reopened.select("SELECT injury_matches_remaining FROM ai_players "
              "WHERE id = 1")
          .first['injury_matches_remaining'],
      2,
    );
    expect(reopened.select('PRAGMA user_version').first['user_version'], 15);
    reopened.dispose();
  });
}
