// The claims repository contracts (T-0106): typed round-trips, the
// DB-level idempotency lock, per-club isolation and the equipped
// title's settings upsert. All against an in-memory NativeDatabase —
// the real migration runs in schema_v14_migration_test.dart.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/achievements/achievement_claims_repository.dart';

void main() {
  late AppDatabase database;
  late AchievementClaimsRepository repo;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repo = AchievementClaimsRepository(database);
  });

  tearDown(() => database.close());

  DateTime at(int ms) => DateTime.fromMillisecondsSinceEpoch(ms);

  AchievementClaimsCompanion _claim({
    required int clubId,
    required String achievementId,
    required String tierKey,
    int rewardCoins = 20,
    String? titleGranted,
    int claimedAtMs = 1700000000000,
  }) =>
      AchievementClaimsCompanion.insert(
        clubId: clubId,
        achievementId: achievementId,
        tierKey: tierKey,
        rewardCoins: rewardCoins,
        titleGranted: titleGranted == null
            ? const Value.absent()
            : Value(titleGranted),
        claimedAt: at(claimedAtMs),
      );

  test('insert + read round-trip, newest first', () async {
    await database.into(database.achievementClaims).insert(
          _claim(
            clubId: 1,
            achievementId: 'career_wins',
            tierKey: '4',
            claimedAtMs: 1000,
          ),
        );
    await database.into(database.achievementClaims).insert(
          _claim(
            clubId: 1,
            achievementId: 'attack_goals',
            tierKey: '160',
            rewardCoins: 20,
            titleGranted: 'attack_goals-title2',
            claimedAtMs: 2000,
          ),
        );

    final claims = await repo.claimsForClub(1);
    expect(claims.length, 2);
    // Newest first.
    expect(claims.first.achievementId, 'attack_goals');
    expect(claims.first.tierKey, '160');
    expect(claims.first.rewardCoins, 20);
    expect(claims.first.titleGranted, 'attack_goals-title2');
    expect(claims.first.claimedAt, at(2000));
    expect(claims.last.achievementId, 'career_wins');
    expect(claims.last.titleGranted, isNull);
  });

  test('THE IDEMPOTENCY LOCK: a duplicate (club, achievement, tierKey) '
      'insert is refused by the DB', () async {
    await database.into(database.achievementClaims).insert(
          _claim(clubId: 1, achievementId: 'career_wins', tierKey: '16'),
        );

    // The advisory check sees it.
    expect(
      await repo.hasClaim(clubId: 1, achievementId: 'career_wins', tierKey: '16'),
      isTrue,
    );
    expect(
      await repo.hasClaim(clubId: 1, achievementId: 'career_wins', tierKey: '32'),
      isFalse,
    );

    // The STRUCTURAL refusal: the same triple cannot land again —
    // drift surfaces SQLite's UNIQUE violation as an exception whose
    // message carries the constraint. Exact behaviour pinned so a
    // silent double-claim becomes a test failure.
    expect(
      () => database.into(database.achievementClaims).insert(
            _claim(clubId: 1, achievementId: 'career_wins', tierKey: '16'),
          ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('UNIQUE constraint failed'),
        ),
      ),
      reason: 'double taps, back replays and process-kill retries must '
          'fail at the DB level, not in UI guards',
    );

    // And the table still holds exactly ONE row for the triple.
    final claims = await repo.claimsForClub(1);
    expect(claims.length, 1);
    expect(claims.single.rewardCoins, 20);
  });

  test('different clubs claim the same tier independently', () async {
    await database.into(database.achievementClaims).insert(
          _claim(clubId: 1, achievementId: 'career_wins', tierKey: '16'),
        );
    // Club 2 claims the SAME tier: allowed — the key is club-scoped.
    await database.into(database.achievementClaims).insert(
          _claim(clubId: 2, achievementId: 'career_wins', tierKey: '16'),
        );
    // Same club, same achievement, DIFFERENT tier: allowed.
    await database.into(database.achievementClaims).insert(
          _claim(clubId: 1, achievementId: 'career_wins', tierKey: '32'),
        );

    expect((await repo.claimsForClub(1)).length, 2);
    expect((await repo.claimsForClub(2)).length, 1);
    expect(
      await repo.hasClaim(clubId: 2, achievementId: 'career_wins', tierKey: '16'),
      isTrue,
    );
  });

  test('equipped title: set → get → clear round-trip on the settings '
      'row (insert path)', () async {
    // Fresh database: no settings row exists yet — the set must
    // CREATE it (the upsert's insert path).
    expect(await repo.getEquippedTitle(), isNull);

    await repo.setEquippedTitle('career_wins-title2');
    expect(await repo.getEquippedTitle(), 'career_wins-title2');

    // Overwrite on the existing row (the update path).
    await repo.setEquippedTitle('silverware_titles-title1');
    expect(await repo.getEquippedTitle(), 'silverware_titles-title1');

    // Null clears back to no-title.
    await repo.setEquippedTitle(null);
    expect(await repo.getEquippedTitle(), isNull);

    // Exactly ONE settings row ever existed.
    final rows = await database.select(database.userSettings).get();
    expect(rows.length, 1);
    expect(rows.single.id, 1);
  });

  test('equipped title coexists with the existing settings writes '
      '(match speed survives a title change)', () async {
    // The settings row pre-exists with a match speed (the store's
    // write pattern); the title update must not clobber it.
    await database.into(database.userSettings).insert(
          UserSettingsCompanion.insert(
            id: 1,
            matchSpeed: const Value(3),
          ),
        );
    await repo.setEquippedTitle('loyalty_seasons-title1');

    final row = await (database.select(database.userSettings)
          ..where((t) => t.id.equals(1)))
        .getSingle();
    expect(row.equippedTitle, 'loyalty_seasons-title1');
    expect(row.matchSpeed, 3, reason: 'the column update is surgical');
  });

  test('repository insertClaim round-trips a full row', () async {
    await repo.insertClaim(
      clubId: 7,
      achievementId: 'packs_opened',
      tierKey: '48',
      rewardCoins: 20,
      titleGranted: 'packs_opened-title1',
      claimedAt: at(1700000099 * 1000),
    );
    final claims = await repo.claimsForClub(7);
    expect(claims.single.achievementId, 'packs_opened');
    expect(claims.single.tierKey, '48');
    expect(claims.single.rewardCoins, 20);
    expect(claims.single.titleGranted, 'packs_opened-title1');
    expect(claims.single.claimedAt, at(1700000099 * 1000));
    expect(
      await repo.hasClaim(clubId: 7, achievementId: 'packs_opened', tierKey: '48'),
      isTrue,
    );
  });
}
