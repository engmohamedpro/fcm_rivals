// The v13 → v14 schema migration (T-0106): the achievements claims
// table + the equipped-title column land as PURE ADDITIONS — every
// pre-existing row survives byte-for-byte, a fresh install creates
// v14 cleanly. Pattern: the schema_v12 migration test (hand-crafted
// prior-version database on raw sqlite3, open with the current
// AppDatabase, snapshot before/after).
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The UserSettings shape through schema v13 (before equippedTitle):
/// id, match_speed, locale — the v14 step ALTERs it.
const String _userSettingsV13Ddl =
    'CREATE TABLE IF NOT EXISTS "user_settings" ('
    '"id" INTEGER NOT NULL, '
    '"match_speed" INTEGER NOT NULL DEFAULT 1, '
    '"locale" TEXT NULL, '
    'PRIMARY KEY ("id"))';

const List<String> _userSettingsV13Columns = [
  'id',
  'match_speed',
  'locale',
];

/// The Clubs shape at v13 (crest present — T-0097 landed in v13).
const String _clubsV13Ddl =
    'CREATE TABLE IF NOT EXISTS "clubs" ('
    '"id" INTEGER PRIMARY KEY AUTOINCREMENT, '
    '"name" TEXT NOT NULL, "manager_name" TEXT NOT NULL, '
    '"crest_index" INTEGER NOT NULL DEFAULT 0, '
    '"crest" TEXT NULL, '
    '"formation_code" TEXT NOT NULL DEFAULT \'4-3-3\', '
    '"tactics" TEXT NOT NULL DEFAULT \'{}\', '
    '"mentality" TEXT NOT NULL DEFAULT \'balanced\', '
    '"coins" INTEGER NOT NULL, "is_user" INTEGER NOT NULL DEFAULT 1, '
    '"created_at" INTEGER NOT NULL)';

void main() {
  test('fresh install creates schema v14 with the claims table and '
      'the equipped-title column', () async {
    final database = AppDatabase(NativeDatabase.memory());
    expect(database.schemaVersion, 14);

    // The claims table exists and enforces its UNIQUE key.
    await database.into(database.achievementClaims).insert(
          AchievementClaimsCompanion.insert(
            clubId: 1,
            achievementId: 'career_wins',
            tierKey: '16',
            rewardCoins: 20,
            claimedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          ),
        );
    expect(
      () => database.into(database.achievementClaims).insert(
            AchievementClaimsCompanion.insert(
              clubId: 1,
              achievementId: 'career_wins',
              tierKey: '16',
              rewardCoins: 20,
              claimedAt: DateTime.fromMillisecondsSinceEpoch(1700000000001),
            ),
          ),
      throwsA(isA<Exception>()),
      reason: 'fresh installs get the idempotency lock from minute one',
    );

    // The settings row accepts a title.
    await database.into(database.userSettings).insert(
          UserSettingsCompanion.insert(
            id: 1,
            equippedTitle: const Value('career_wins-title1'),
          ),
        );
    final row = await (database.select(database.userSettings)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    expect(row.equippedTitle, 'career_wins-title1');
    expect(row.matchSpeed, 1);
    await database.close();
  });

  test('v13→v14 upgrade preserves every existing row byte-for-byte',
      () async {
    final file = File(
      '${Directory.systemTemp.createTempSync('fcm_v14').path}/db.sqlite',
    );

    // 1. Hand-craft a v13 database with pre-existing data: a club, a
    // settings row (speed 3, locale 'ar') and a coin ledger row —
    // the tables the v14 step touches plus one bystander.
    final raw = sqlite3.sqlite3.open(file.path);
    raw.execute('PRAGMA user_version = 13');
    raw.execute(_clubsV13Ddl);
    raw.execute(_userSettingsV13Ddl);
    raw.execute(
      'CREATE TABLE IF NOT EXISTS "coin_transactions" ('
      '"id" INTEGER PRIMARY KEY AUTOINCREMENT, '
      '"club_id" INTEGER NOT NULL, '
      '"amount" INTEGER NOT NULL, '
      '"balance_after" INTEGER NOT NULL, '
      '"reason" TEXT NOT NULL, '
      '"detail" TEXT NULL, '
      '"created_at" INTEGER NOT NULL)',
    );
    raw.execute(
      "INSERT INTO clubs VALUES (1, 'Pyramid United', 'Mohamed', 0, NULL, "
      "'4-3-3', '{}', 'balanced', 25000, 1, 1700000000)",
    );
    raw.execute("INSERT INTO user_settings VALUES (1, 3, 'ar')");
    raw.execute(
      "INSERT INTO coin_transactions VALUES (1, 1, 1500, 26500, "
      "'match_reward', 'round 1', 1700000001)",
    );

    String settingsSnapshot(sqlite3.Database db) => {
      for (final row in db.select('SELECT * FROM user_settings'))
        _userSettingsV13Columns.map((c) => row[c]).join('|'),
    }.single;
    final settingsBefore = settingsSnapshot(raw);
    final ledgerBefore = {
      for (final row in raw.select('SELECT * FROM coin_transactions'))
        '${row['id']}: ${row['club_id']}|${row['amount']}|'
            '${row['balance_after']}|${row['reason']}',
    }.single;
    final coinsBefore =
        raw.select('SELECT coins FROM clubs').first['coins'] as int;
    raw.dispose();

    // 2. Open with the current database: the 13→14 migration runs.
    final database = AppDatabase(NativeDatabase(file));
    expect(database.schemaVersion, 14);

    // The pre-existing settings row kept its values and gained null
    // title (the new column's additive default).
    final settings = await database.select(database.userSettings).get();
    expect(settings.single.matchSpeed, 3);
    expect(settings.single.locale, 'ar');
    expect(settings.single.equippedTitle, isNull);

    // The ledger row survived.
    final ledger = await database.select(database.coinTransactions).get();
    expect(ledger.single.amount, 1500);
    expect(ledger.single.reason, 'match_reward');

    // 3. Post-migration the new surface works: claim + title write.
    await database.into(database.achievementClaims).insert(
          AchievementClaimsCompanion.insert(
            clubId: 1,
            achievementId: 'career_matches',
            tierKey: '128',
            rewardCoins: 20,
            claimedAt: DateTime.fromMillisecondsSinceEpoch(1700000000002),
          ),
        );
    await (database.update(database.userSettings)
          ..where((t) => t.id.equals(1)))
        .write(const UserSettingsCompanion(
      equippedTitle: Value('career_wins-title2'),
    ));
    await database.close();

    // 4. Every pre-existing row survived byte-for-byte on disk (the
    // v13 columns only), and the new writes landed beside them.
    final reopened = sqlite3.sqlite3.open(file.path);
    expect(settingsSnapshot(reopened), settingsBefore,
        reason: 'match speed and locale untouched');
    expect(
      reopened.select('SELECT equipped_title FROM user_settings').first
          ['equipped_title'],
      'career_wins-title2',
    );
    expect(
      reopened
          .select('SELECT reward_coins FROM achievement_claims')
          .first['reward_coins'],
      20,
    );
    expect(
      reopened.select('SELECT coins FROM clubs').first['coins'] as int,
      coinsBefore,
    );
    expect(
      {
        for (final row
            in reopened.select('SELECT * FROM coin_transactions'))
          '${row['id']}: ${row['club_id']}|${row['amount']}|'
              '${row['balance_after']}|${row['reason']}',
      }.single,
      ledgerBefore,
    );
    reopened.dispose();
  });
}
