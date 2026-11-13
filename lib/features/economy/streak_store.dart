/// FCM Rivals — the daily rewards streak store.
///
/// One claim per day is enforced by the DATABASE, not by UI
/// discipline: the UNIQUE (club, day) key on daily_streak_claims
/// makes a double claim of any single day structurally impossible,
/// and the claim row + the coin credit land in ONE transaction —
/// all-or-nothing, exactly the guarantee achievement claims carry. A
/// double tap pays once. A process kill mid-claim leaves either both
/// rows or neither. The reward is STATE-DERIVED (the engine recomputes
/// it from the history inside the decision), so no client parameter
/// can mint coins.
///
/// The streak itself is ENDLESS (the ladder never ends and the run
/// never "completes"): consecutive days climb it forever, a missed day
/// resets the climb to day 1 — the engine owns that rule, the store
/// only persists and pays.
///
/// Ledger convention: `reason: LedgerReasons.streakReward` with
/// `detail: '<dayKey>:<streakDay>'` so the economy sweep can
/// attribute streak income precisely.
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart' as db;
import '../../core/database/coin_ops.dart' show CoinOps;
import '../achievements/achievement_progress.dart' show LedgerReasons;
import 'streak_engine.dart';

/// The UI-facing view of the club's streak: what the claim card shows.
class StreakSnapshot {
  const StreakSnapshot({
    required this.state,
    required this.claimedToday,
    required this.nextStreakDay,
    required this.nextRewardCoins,
    required this.tomorrowRewardCoins,
    required this.missedDay,
  });

  /// The claim history (empty = the run never started).
  final StreakState state;

  /// Whether today's reward was already claimed.
  final bool claimedToday;

  /// The streak ordinal a claim RIGHT NOW advances the run to (1 on a
  /// fresh or broken run; the day the card's counter shows).
  final int nextStreakDay;

  /// What a claim RIGHT NOW pays (0 when already claimed today).
  final int nextRewardCoins;

  /// What tomorrow's claim pays if the run stays alive — the visible
  /// "keep going" incentive on the card. 0 when the run is broken
  /// (restarts at day 1's reward).
  final int tomorrowRewardCoins;

  /// Whether the run is broken: the last claim predates yesterday, so
  /// the next claim restarts the whole climb.
  final bool missedDay;
}

/// The claim outcome — sealed, no exceptions across the API boundary.
sealed class StreakClaimOutcome {
  const StreakClaimOutcome();
}

class StreakClaimGranted extends StreakClaimOutcome {
  const StreakClaimGranted({
    required this.streakDay,
    required this.rewardCoins,
    required this.balanceAfter,
  });

  /// The streak ordinal this claim advanced the run to.
  final int streakDay;

  final int rewardCoins;

  /// The club's coin balance after the credit landed.
  final int balanceAfter;
}

class StreakClaimDenied extends StreakClaimOutcome {
  const StreakClaimDenied(this.reason);

  /// 'already_claimed' | 'no_club' — stable strings for the UI.
  final String reason;
}

/// Owns the daily_streak_claims table and the claim pipeline.
class StreakStore {
  StreakStore(this.database, {StreakEngine? engine})
      : engine = engine ?? const StreakEngine();

  final db.AppDatabase database;
  final StreakEngine engine;

  /// The club's current streak state — the most recent claim row,
  /// mapped to the engine's history shape.
  Future<StreakState> _stateOf(int clubId) async {
    final rows = await (database.select(database.dailyStreakClaims)
          ..where((t) => t.clubId.equals(clubId))
          ..orderBy([(t) => OrderingTerm.desc(t.claimedAt)])
          ..limit(1))
        .get();
    if (rows.isEmpty) return StreakState.empty;
    final row = rows.first;
    return StreakState(
      lastStreakDay: row.streakDay,
      lastDayKey: row.dayKey,
    );
  }

  /// What the profile card shows. [now] is injectable for tests.
  Future<StreakSnapshot> snapshot(int clubId, {DateTime? now}) async {
    final timestamp = now ?? DateTime.now();
    final state = await _stateOf(clubId);
    final today = StreakEngine.dayKeyOf(timestamp);
    final claimedToday = state.lastDayKey == today;
    final evaluation = engine.evaluate(state, timestamp);
    final claimable = evaluation is StreakClaimable
        ? evaluation
        : null;
    final nextDay = claimable?.streakDay ?? state.lastStreakDay;
    // A missed day is a last claim that predates yesterday while the
    // run exists at all.
    final missed = !state.isEmpty &&
        !claimedToday &&
        !_withinOneDay(state.lastDayKey, today);
    // Tomorrow pays the ladder's next rung only when the run is alive
    // right now (claimed today, or claimable today).
    final alive = claimedToday || claimable != null;
    final tomorrowDay = claimedToday ? state.lastStreakDay + 1 : nextDay;
    return StreakSnapshot(
      state: state,
      claimedToday: claimedToday,
      nextStreakDay: nextDay,
      nextRewardCoins: claimable?.rewardCoins ?? 0,
      tomorrowRewardCoins:
          alive ? engine.rewardForDay(tomorrowDay) : engine.rewardForDay(1),
      missedDay: missed,
    );
  }

  /// Claims today's reward (the one public write): re-derives the state
  /// inside the transaction, resolves it through the engine, then
  /// inserts the UNIQUE-guarded row and credits the coins — ONE
  /// transaction, all-or-nothing. A lost race (double tap) surfaces
  /// as [StreakClaimDenied] with reason 'already_claimed'.
  Future<StreakClaimOutcome> claim({
    required int clubId,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final club = await (database.select(database.clubs)
          ..where((c) => c.id.equals(clubId)))
        .getSingleOrNull();
    if (club == null) return const StreakClaimDenied('no_club');

    final state = await _stateOf(clubId);
    final evaluation = engine.evaluate(state, timestamp);
    if (evaluation is StreakAlreadyClaimed) {
      return const StreakClaimDenied('already_claimed');
    }
    final claimable = evaluation as StreakClaimable;
    final dayKey = StreakEngine.dayKeyOf(timestamp);

    try {
      return await database.transaction(() async {
        await database
            .into(database.dailyStreakClaims)
            .insert(
              db.DailyStreakClaimsCompanion.insert(
                clubId: clubId,
                dayKey: dayKey,
                streakDay: claimable.streakDay,
                rewardCoins: claimable.rewardCoins,
                claimedAt: timestamp,
              ),
            );
        final balance = await database.creditCoins(
          clubId,
          claimable.rewardCoins,
          reason: LedgerReasons.streakReward,
          detail: '$dayKey:${claimable.streakDay}',
        );
        return StreakClaimGranted(
          streakDay: claimable.streakDay,
          rewardCoins: claimable.rewardCoins,
          balanceAfter: balance,
        );
      });
    } on Exception {
      // The UNIQUE (club, day) refusal — caught broadly (the message
      // is not a stable cross-version API), then verified by the row's
      // actual presence so a genuine failure is not masked as success.
      final already = await (database.select(database.dailyStreakClaims)
            ..where(
              (t) => t.clubId.equals(clubId) & t.dayKey.equals(dayKey),
            )
            ..limit(1))
          .get();
      if (already.isNotEmpty) return const StreakClaimDenied('already_claimed');
      rethrow;
    }
  }

  /// Whether [dayKey] is today or yesterday — the run is alive.
  static bool _withinOneDay(String dayKey, String todayKey) {
    if (dayKey.isEmpty) return false;
    final a = DateTime.parse('${dayKey}T00:00:00');
    final b = DateTime.parse('${todayKey}T00:00:00');
    final diff = b.difference(a);
    return diff >= Duration.zero && diff < const Duration(days: 2);
  }
}
