import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/simulation/match_simulator.dart';

void main() {
  final simulator = MatchSimulator();

  group('MatchSimulator determinism (GDD 31)', () {
    test('same seed + same command sequence replays identically', () {
      for (final seed in [1, 42, 999, 20261101]) {
        expect(
          simulator.replaysDeterministically(
            seed: seed,
            commandFactories: const [],
          ),
          isTrue,
          reason: 'seed $seed should replay deterministically',
        );
      }
    });

    test('determinism holds with a command sequence (substitution at 60)', () {
      expect(
        simulator.replaysDeterministically(
          seed: 4242,
          commandFactories: [
            () => const ChangeMentalityCommand(
              atMinute: 60,
              side: MatchSide.home,
              mentality: Mentality.attacking,
            ),
          ],
        ),
        isTrue,
      );
    });

    test('summarize() is stable for the same seed', () {
      final a = simulator.summarize(123);
      final b = simulator.summarize(123);
      expect(a, equals(b));
      expect(a.eventCount, greaterThan(0));
    });

    test('minute-60 tactic change affects future events only', () {
      final result = simulator.minute60ChangeAffectsFutureOnly(
        seed: 700,
        sampleMatches: 48,
      );
      // null = no divergence anywhere (change did nothing); the invariant
      // itself (identical prefix) is checked inside and returns false on
      // violation. true = at least one diverging match, prefix intact.
      expect(
        result,
        anyOf(isTrue, isNull),
        reason: 'prefix must stay identical; divergence allowed only later',
      );
    });
  });

  group('MatchSimulator balance metrics (GDD 31)', () {
    test('equal-strength batch produces sane aggregate rates', () {
      final report = simulator.runBatch(
        label: 'equal',
        matches: 120,
        homeValueEur: MatchSimulator.mediumValueEur,
      );
      expect(report.matches, 120);
      // Sanity ranges for a football sim: total goals per match.
      expect(report.avgGoals, inInclusiveRange(1.0, 6.0));
      // Home advantage exists but is not overwhelming.
      expect(report.homeWinRate, inInclusiveRange(0.20, 0.60));
      expect(report.drawRate, inInclusiveRange(0.10, 0.40));
      expect(
        report.homeWinRate + report.awayWinRate + report.drawRate,
        closeTo(1.0, 0.0001),
      );
      // Shots on target can't exceed shots; both positive.
      expect(report.avgShots, greaterThan(0));
      expect(report.avgShotsOnTarget, lessThanOrEqualTo(report.avgShots));
      // Goal conversion on target typically 10-60%.
      expect(report.goalConversion, inInclusiveRange(0.05, 0.80));
      // Cards exist but are not constant.
      expect(report.avgYellowCards, inInclusiveRange(0.0, 8.0));
      // Stamina depletes over 90 minutes but never to nothing on average.
      expect(report.staminaDepletion, greaterThan(0));
      expect(report.avgHomeStaminaEnd, inInclusiveRange(10, 95));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('stronger home team wins more often (tactical/quality effect)', () {
      final even = simulator.runBatch(
        label: 'even',
        matches: 150,
        homeValueEur: MatchSimulator.mediumValueEur,
      );
      final stacked = simulator.runBatch(
        label: 'stacked',
        matches: 150,
        homeValueEur: MatchSimulator.highValueEur,
        awayValueEur: MatchSimulator.lowValueEur,
      );
      expect(stacked.homeWinRate, greaterThan(even.homeWinRate));
      expect(stacked.avgHomeGoals, greaterThan(stacked.avgAwayGoals));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('higher divisions are harder for the same squad (GDD 9.6/31)', () {
      final d1 = simulator.runBatch(
        label: 'd1',
        matches: 120,
        homeValueEur: MatchSimulator.mediumValueEur,
      );
      final d4 = simulator.runBatch(
        label: 'd4',
        matches: 120,
        homeValueEur: MatchSimulator.mediumValueEur,
        homeDivision: 4,
      );
      // Division difficulty scales the away side up: the home side must
      // score/win less at higher divisions.
      expect(d1.homeWinRate, greaterThan(d4.homeWinRate));
      expect(d1.avgHomeGoals, greaterThan(d4.avgHomeGoals));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('value bands measure differently (GDD 30 low vs high squads)', () {
      final low = simulator.runBatch(
        label: 'low-vs-low',
        matches: 60,
        homeValueEur: MatchSimulator.lowValueEur,
      );
      final high = simulator.runBatch(
        label: 'high-vs-high',
        matches: 60,
        homeValueEur: MatchSimulator.highValueEur,
      );
      // Both are even matchups; metrics exist and differ in detail.
      expect(low.avgGoals, greaterThan(0));
      expect(high.avgGoals, greaterThan(0));
      // Higher-quality football creates and scores more (T-0048
      // re-anchor: the widened elite ladder trades per-chance purity for
      // chance volume — elite attacks (99) now face wider-but-lower
      // elite defences, so the conversion-per-shot ratio is no longer
      // monotonic in squad value; the volume metrics are the stable
      // band separators: ~24.8 shots / 9.6 SoT / 3.1 goals vs ~22.7 /
      // 7.9 / 2.8).
      expect(high.avgShotsOnTarget, greaterThan(low.avgShotsOnTarget));
      expect(high.avgGoals, greaterThan(low.avgGoals));
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
