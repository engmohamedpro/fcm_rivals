// The daily rewards streak contracts: the endless ladder, the
// once-per-day claim, the missed-day reset, the atomic claim +
// credit transaction, the UNIQUE-guarded idempotency, the ledger
// convention — pure engine tests plus store tests on an in-memory
// database with a real club and a real balance.
library;

import 'dart:math' as math;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart' as db;
import 'package:fcm_rivals/features/economy/streak_engine.dart';
import 'package:fcm_rivals/features/economy/streak_store.dart';

void main() {
  // ------------------------------------------------------------------
  // The engine — pure functions, no database.
  // ------------------------------------------------------------------
  group('StreakEngine', () {
    const engine = StreakEngine();

    test('day keys are canonical local YYYY-MM-DD', () {
      expect(
        StreakEngine.dayKeyOf(DateTime(2026, 11, 5, 23, 59)),
        '2026-11-05',
      );
      expect(
        StreakEngine.dayKeyOf(DateTime(2026, 1, 2, 0, 0)),
        '2026-01-02',
      );
    });

    test('the ladder is endless: every day pays, weekly bonus on '
        'multiples of 7, cap holds', () {
      // Day 1 pays the configured first reward.
      expect(engine.rewardForDay(1), 600);
      // The BASE ladder never regresses across a long climb — no
      // exhaustion point. The weekly bonus sits ON TOP of it, so a
      // bonus day may pay more than the day after it; the curve
      // itself never dips (it grows until the cap, then holds the
      // ceiling forever — an endless climb that stops getting richer
      // but never gets poorer).
      var lastCurve = engine.rewardForDay(1);
      for (var d = 2; d <= 400; d++) {
        final r = engine.rewardForDay(d);
        expect(r, greaterThan(0), reason: 'day $d must pay something');
        final isBonusDay = d % 7 == 0;
        if (!isBonusDay) {
          expect(r, greaterThanOrEqualTo(lastCurve),
              reason: 'day $d must not pay less than day ${d - 1} on the '
                  'base curve');
          lastCurve = r;
        } else {
          // The bonus day: its own curve rung + the flat bonus.
          expect(
            r,
            greaterThan(engine.rewardForDay(d - 1)),
            reason: 'bonus day $d pays more than the day before',
          );
        }
      }
      // The cap: no single day out-earns the ceiling (+ the bonus
      // allowance on a bonus day).
      expect(engine.rewardForDay(400),
          lessThanOrEqualTo(defaultStreakConfig.rewardCap));
      // Day 7 pays its curve reward PLUS the bonus.
      final curve7 = defaultStreakConfig.dayOneReward +
          _curveTerm(7);
      expect(engine.rewardForDay(7), curve7 + defaultStreakConfig.daySevenBonus);
      // A non-multiple pays the bare curve.
      final curve6 = defaultStreakConfig.dayOneReward +
          _curveTerm(6);
      expect(engine.rewardForDay(6), curve6);
      // Day 0 / negative: nothing.
      expect(engine.rewardForDay(0), 0);
      expect(engine.rewardForDay(-3), 0);
    });

    test('first claim ever lands on day 1', () {
      final r = engine.evaluate(
        StreakState.empty,
        DateTime(2026, 11, 5, 10),
      );
      expect(r, isA<StreakClaimable>());
      expect((r as StreakClaimable).streakDay, 1);
      expect(r.rewardCoins, engine.rewardForDay(1));
    });

    test('consecutive days climb: yesterday → day N+1', () {
      final r = engine.evaluate(
        const StreakState(lastStreakDay: 4, lastDayKey: '2026-11-04'),
        DateTime(2026, 11, 5, 10),
      );
      final c = r as StreakClaimable;
      expect(c.streakDay, 5);
      expect(c.rewardCoins, engine.rewardForDay(5));
    });

    test('a missed day resets the run to day 1', () {
      // Last claim two days ago — the run is broken.
      final r = engine.evaluate(
        const StreakState(lastStreakDay: 9, lastDayKey: '2026-11-03'),
        DateTime(2026, 11, 5, 10),
      );
      final c = r as StreakClaimable;
      expect(c.streakDay, 1, reason: 'a missed day restarts the climb');
      expect(c.rewardCoins, engine.rewardForDay(1));
      // A week-long gap is the same reset.
      final r2 = engine.evaluate(
        const StreakState(lastStreakDay: 30, lastDayKey: '2026-10-29'),
        DateTime(2026, 11, 5, 10),
      );
      expect((r2 as StreakClaimable).streakDay, 1);
    });

    test('today already claimed → AlreadyClaimed, whatever the run', () {
      final r = engine.evaluate(
        const StreakState(lastStreakDay: 12, lastDayKey: '2026-11-05'),
        DateTime(2026, 11, 5, 22),
      );
      expect(r, isA<StreakAlreadyClaimed>());
    });

    test('month and year boundaries: yesterday is yesterday', () {
      // Crossing a month end (Oct 31 → Nov 1).
      final r = engine.evaluate(
        const StreakState(lastStreakDay: 3, lastDayKey: '2026-10-31'),
        DateTime(2026, 11, 1, 9),
      );
      expect((r as StreakClaimable).streakDay, 4);
      // Crossing a year end (Dec 31 2026 → Jan 1 2027).
      final r2 = engine.evaluate(
        const StreakState(lastStreakDay: 7, lastDayKey: '2026-12-31'),
        DateTime(2027, 1, 1, 9),
      );
      expect((r2 as StreakClaimable).streakDay, 8);
    });
  });

  // ------------------------------------------------------------------
  // The store — a real database, a real club, a real balance.
  // ------------------------------------------------------------------
  group('StreakStore', () {
    late db.AppDatabase database;
    late StreakStore store;
    const clubId = 1;

    setUp(() async {
      database = db.AppDatabase(NativeDatabase.memory());
      await database
          .into(database.clubs)
          .insert(
            db.ClubsCompanion.insert(
              name: 'Pyramid United',
              managerName: 'Mohamed',
              coins: 10_000,
              createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
            ),
          );
      store = StreakStore(database);
    });

    tearDown(() => database.close());

    Future<int> balance() async =>
        (await (database.select(database.clubs)
                ..where((c) => c.id.equals(clubId)))
            .getSingle())
            .coins;

    test('happy path: granted, ledger row exact, balance moved', () async {
      final before = await balance();
      final outcome = await store.claim(
        clubId: clubId,
        now: DateTime(2026, 11, 5, 15),
      );
      expect(outcome, isA<StreakClaimGranted>());
      final g = outcome as StreakClaimGranted;
      expect(g.streakDay, 1);
      expect(g.rewardCoins, store.engine.rewardForDay(1));
      expect(g.balanceAfter, before + g.rewardCoins);
      expect(await balance(), before + g.rewardCoins);

      final ledger = await (database.select(database.coinTransactions)
            ..where((t) => t.reason.equals('streak_reward')))
          .get();
      expect(ledger, hasLength(1));
      expect(ledger.single.detail, '2026-11-05:1');
      expect(ledger.single.amount, g.rewardCoins);
    });

    test('once per day: a second claim the SAME day is denied, no '
        'coins, still ONE ledger row', () async {
      await store.claim(clubId: clubId, now: DateTime(2026, 11, 5, 8));
      final afterFirst = await balance();

      // The double tap — later the same day.
      final second = await store.claim(
        clubId: clubId,
        now: DateTime(2026, 11, 5, 21),
      );
      expect(second, isA<StreakClaimDenied>());
      expect((second as StreakClaimDenied).reason, 'already_claimed');
      expect(await balance(), afterFirst);

      final ledger = await (database.select(database.coinTransactions)
            ..where((t) => t.reason.equals('streak_reward')))
          .get();
      expect(ledger, hasLength(1));
    });

    test('consecutive days climb the ladder — day 7 pays the weekly '
        'bonus', () async {
      // Six consecutive claims: days 1..6, none a bonus day.
      for (var d = 1; d <= 6; d++) {
        final o = await store.claim(
          clubId: clubId,
          now: DateTime(2026, 11, d, 12),
        );
        expect(o, isA<StreakClaimGranted>());
        expect((o as StreakClaimGranted).streakDay, d);
      }
      final bonus = await store.claim(
        clubId: clubId,
        now: DateTime(2026, 11, 7, 12),
      );
      expect((bonus as StreakClaimGranted).streakDay, 7);
      expect(bonus.rewardCoins,
          store.engine.rewardForDay(7), reason: 'day 7 carries the bonus');
      expect(bonus.rewardCoins, greaterThan(store.engine.rewardForDay(6)));
    });

    test('a missed day restarts the climb at day 1', () async {
      // Build a run: 3 consecutive days.
      for (var d = 1; d <= 3; d++) {
        await store.claim(clubId: clubId, now: DateTime(2026, 11, d, 12));
      }
      // Skip Nov 4 entirely — the run is dead.
      final after = await store.claim(
        clubId: clubId,
        now: DateTime(2026, 11, 5, 12),
      );
      expect((after as StreakClaimGranted).streakDay, 1,
          reason: 'the missed day resets the streak');
      expect(after.rewardCoins, store.engine.rewardForDay(1));
      expect(await balance(), 10_000 + _sumLadder(store, 3) + after.rewardCoins);
    });

    test('snapshot: the card view carries the run, the rewards and '
        'the broken flag', () async {
      await store.claim(clubId: clubId, now: DateTime(2026, 11, 5, 12));
      final snap = await store.snapshot(
        clubId,
        now: DateTime(2026, 11, 5, 18),
      );
      expect(snap.claimedToday, true);
      expect(snap.state.lastStreakDay, 1);
      expect(snap.tomorrowRewardCoins, store.engine.rewardForDay(2));
      expect(snap.missedDay, false);

      // The next morning, unclaimed: claimable at day 2.
      final morning = await store.snapshot(
        clubId,
        now: DateTime(2026, 11, 6, 9),
      );
      expect(morning.claimedToday, false);
      expect(morning.nextStreakDay, 2);
      expect(morning.nextRewardCoins, store.engine.rewardForDay(2));
      expect(morning.missedDay, false);

      // Two mornings later: broken.
      final broken = await store.snapshot(
        clubId,
        now: DateTime(2026, 11, 8, 9),
      );
      expect(broken.missedDay, true);
      expect(broken.nextStreakDay, 1);
      expect(broken.tomorrowRewardCoins, store.engine.rewardForDay(1));
    });

    test('no club: denied with reason no_club, nothing written', () async {
      final outcome = await store.claim(
        clubId: 99,
        now: DateTime(2026, 11, 5, 12),
      );
      expect(outcome, isA<StreakClaimDenied>());
      expect((outcome as StreakClaimDenied).reason, 'no_club');
      final rows = await database.select(database.dailyStreakClaims).get();
      expect(rows, isEmpty);
    });
  });
}

int _curveTerm(int day) {
  // The engine's exact curve term: round(growth * day^exponent) —
  // the ROUNDING ORDER matters (round the product, not the power).
  return (defaultStreakConfig.baseGrowth *
          math.pow(day.toDouble(), defaultStreakConfig.exponent))
      .round();
}

int _sumLadder(StreakStore store, int days) {
  var sum = 0;
  for (var d = 1; d <= days; d++) {
    sum += store.engine.rewardForDay(d);
  }
  return sum;
}
