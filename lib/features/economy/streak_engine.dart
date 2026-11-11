/// FCM Rivals — the daily rewards streak engine.
///
/// Pure decision logic, no UI and no database (GDD development rule 4,
/// same split as the ad engine): given the club's claim history and a
/// moment in time it decides whether today's reward may be claimed,
/// which streak day it would land on, and what it pays.
///
/// The streak rules:
///  - a reward is claimable ONCE per local calendar day;
///  - consecutive days keep the run alive — day N pays the ladder's
///    Nth reward, and the ladder NEVER ends (it scales forever);
///  - a missed day resets the run: the next claim lands on day 1
///    again, restarting the whole climb.
///
/// The idempotency itself is owned by the database (the UNIQUE
/// (club, day) key on daily_streak_claims) — the engine only computes;
/// the store transaction makes the row insert and the coin credit
/// all-or-nothing, the same guarantee achievement claims carry.
library;

import 'dart:math' as math;

/// Tunable streak economics — pre-balance placeholders (GDD rule 14).
class StreakConfig {
  const StreakConfig({
    this.dayOneReward = 500,
    this.daySevenBonus = 2_500,
    this.baseGrowth = 100,
    // A gentle compounding curve: day N pays roughly
    // dayOneReward + baseGrowth * N^exponent — 750 by day 2, ~2.6k by
    // day 10, ~8k by day 30 — against a par match reward of ~1.9k that
    // reads as a real but never dominant income stream, and every
    // 7th day pays its own bonus ON TOP of the curve (day 7 itself
    // pays ~2.1k + 2.5k).
    this.exponent = 1.4,
    this.rewardCap = 20_000,
  });

  /// What the very first day of every run pays (and what a reset
  /// restarts at).
  final int dayOneReward;

  /// Flat bonus paid on every 7th consecutive day (day 7, 14, 21, …)
  /// on top of that day's curve reward — the weekly jackpot moment.
  final int daySevenBonus;

  /// The ladder's linear growth term.
  final int baseGrowth;

  /// The curve's exponent (see the config docs).
  final double exponent;

  /// The single-day ceiling: the ladder grows forever but no single
  /// day's payout may out-earn a Legendary pack.
  final int rewardCap;
}

const StreakConfig defaultStreakConfig = StreakConfig();

/// The immutable claim history the engine decides over: the streak
/// ordinal of the most recent claim and which local day it landed on.
class StreakState {
  const StreakState({required this.lastStreakDay, required this.lastDayKey});

  /// No claims ever — the run has not started.
  static const empty = StreakState(lastStreakDay: 0, lastDayKey: '');

  /// The streak ordinal of the most recent claim (1, 2, 3, …).
  final int lastStreakDay;

  /// The local day key ('YYYY-MM-DD') that claim landed on ('' when
  /// there is no claim yet).
  final String lastDayKey;

  bool get isEmpty => lastStreakDay == 0 || lastDayKey.isEmpty;
}

/// What a claim attempt resolved to.
sealed class StreakClaimResult {
  const StreakClaimResult();
}

/// Today's reward is claimable NOW — [streakDay] is the ordinal this
/// claim advances the run to, [rewardCoins] what it pays.
class StreakClaimable extends StreakClaimResult {
  const StreakClaimable({required this.streakDay, required this.rewardCoins});

  final int streakDay;
  final int rewardCoins;
}

/// Today was already claimed (double tap, retry after a kill, …).
class StreakAlreadyClaimed extends StreakClaimResult {
  const StreakAlreadyClaimed();
}

/// The streak engine: pure functions over the claim history.
class StreakEngine {
  const StreakEngine({this.config = defaultStreakConfig});

  final StreakConfig config;

  /// Canonical local day key of [now] — 'YYYY-MM-DD'. Local, not UTC:
  /// the streak follows the player's day, the same convention the ad
  /// engine's daily limits use.
  static String dayKeyOf(DateTime now) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${now.year}-${two(now.month)}-${two(now.day)}';
  }

  /// The reward the ladder pays on streak day [day] (1-based). The
  /// ladder is ENDLESS: any day has a defined reward, the weekly bonus
  /// lands on every multiple of 7, and [StreakConfig.rewardCap]
  /// ceilings each single day's payout.
  int rewardForDay(int day) {
    if (day <= 0) return 0;
    final grown =
        config.dayOneReward +
        (config.baseGrowth * math.pow(day, config.exponent)).round();
    var reward = grown.clamp(0, config.rewardCap);
    if (day % 7 == 0) {
      reward = (reward + config.daySevenBonus).clamp(
        0,
        config.rewardCap + config.daySevenBonus,
      );
    }
    return reward;
  }

  /// Resolves a claim attempt at [now] over the [state] history.
  StreakClaimResult evaluate(StreakState state, DateTime now) {
    final today = dayKeyOf(now);
    if (state.lastDayKey == today) {
      return const StreakAlreadyClaimed();
    }
    // Consecutive: the last claim was exactly yesterday → the run
    // continues; anything older (a missed day or more) restarts at 1.
    final consecutive = _isYesterday(state.lastDayKey, today);
    final streakDay = consecutive ? state.lastStreakDay + 1 : 1;
    return StreakClaimable(
      streakDay: streakDay,
      rewardCoins: rewardForDay(streakDay),
    );
  }

  /// Whether [dayKey] is exactly the day before [todayKey].
  static bool _isYesterday(String dayKey, String todayKey) {
    if (dayKey.isEmpty || todayKey.isEmpty) return false;
    final a = DateTime.parse('${dayKey}T00:00:00');
    final b = DateTime.parse('${todayKey}T00:00:00');
    final diff = b.difference(a);
    return diff.inDays == 1 && diff < const Duration(days: 2);
  }
}
