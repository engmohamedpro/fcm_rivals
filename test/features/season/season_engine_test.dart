import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/season/season_engine.dart';

void main() {
  group('Round-robin fixtures (FR-036, GDD 9.2)', () {
    test('20 teams produce 38 rounds of 10 matches = 380 fixtures', () {
      const engine = SeasonEngine();
      final pairings = engine.generateFixtures(20);
      expect(pairings.length, 380);
      // 10 matches per round, rounds 0..37.
      final byRound = <int, int>{};
      for (final p in pairings) {
        byRound[p.round] = (byRound[p.round] ?? 0) + 1;
      }
      expect(byRound.length, 38);
      expect(byRound.values.every((c) => c == 10), isTrue);
    });

    test('every pair meets exactly twice, once home and once away', () {
      const engine = SeasonEngine();
      final pairings = engine.generateFixtures(20);
      final seen = <int, int>{};
      final homes = <String, int>{};
      for (final p in pairings) {
        expect(p.homeIndex, isNot(p.awayIndex));
        final a = p.homeIndex < p.awayIndex ? p.homeIndex : p.awayIndex;
        final b = p.homeIndex < p.awayIndex ? p.awayIndex : p.homeIndex;
        final key = a * 100 + b;
        seen[key] = (seen[key] ?? 0) + 1;
        homes['$a-$b-${p.homeIndex}'] = (homes['$a-$b-${p.homeIndex}'] ?? 0) + 1;
      }
      // 190 distinct pairs, each twice.
      expect(seen.length, 190);
      expect(seen.values.every((c) => c == 2), isTrue);
      // Each pair hosts exactly once.
      for (final e in seen.entries) {
        final a = e.key ~/ 100;
        final b = e.key % 100;
        expect(homes['$a-$b-$a'], 1, reason: 'pair $a-$b hosting count');
        expect(homes['$a-$b-$b'], 1, reason: 'pair $a-$b away count');
      }
    });

    test('no team plays twice in the same round', () {
      const engine = SeasonEngine();
      final pairings = engine.generateFixtures(20);
      final byRound = <int, Set<int>>{};
      for (final p in pairings) {
        byRound.putIfAbsent(p.round, () => <int>{});
        expect(byRound[p.round]!.add(p.homeIndex), isTrue,
            reason: 'round ${p.round} home dup');
        expect(byRound[p.round]!.add(p.awayIndex), isTrue,
            reason: 'round ${p.round} away dup');
      }
    });

    test('the anchor team has a reasonable home/away balance', () {
      const engine = SeasonEngine();
      final pairings = engine.generateFixtures(20, anchorIndex: 0);
      final homeGames =
          pairings.where((p) => p.homeIndex == 0).length;
      expect(homeGames, 19); // half of 38
    });

    test('works for small even counts too', () {
      const engine = SeasonEngine();
      final pairings = engine.generateFixtures(4);
      expect(pairings.length, 12); // 2*(4-1) rounds × 2 matches
      final seen = <int, int>{};
      for (final p in pairings) {
        final a = p.homeIndex < p.awayIndex ? p.homeIndex : p.awayIndex;
        final b = p.homeIndex < p.awayIndex ? p.awayIndex : p.homeIndex;
        final key = a * 100 + b;
        seen[key] = (seen[key] ?? 0) + 1;
      }
      expect(seen.length, 6);
      expect(seen.values.every((c) => c == 2), isTrue);
    });
  });

  group('Standings (GDD 9.3)', () {
    const engine = SeasonEngine();

    test('points, wins/draws/losses and goal difference add up', () {
      final standings = engine.computeStandings(
        clubIds: [1, 2, 3, 4],
        names: ['A', 'B', 'C', 'D'],
        results: const [
          (round: 1, homeIndex: 0, awayIndex: 1, homeGoals: 2, awayGoals: 0),
          (round: 1, homeIndex: 2, awayIndex: 3, homeGoals: 1, awayGoals: 1),
          (round: 2, homeIndex: 1, awayIndex: 2, homeGoals: 0, awayGoals: 3),
          (round: 2, homeIndex: 3, awayIndex: 0, homeGoals: 0, awayGoals: 1),
        ],
      );
      // A: W2 (6 pts, 3-0 GD); C: W1 D1 (4 pts); D: D1 L1 (1 pt, -1 GD);
      // B: L2 (0 pts, -4 GD).
      final byName = {for (final e in standings) e.name: e};
      expect(byName['A']!.points, 6);
      expect(byName['A']!.won, 2);
      expect(byName['A']!.goalDifference, 3);
      expect(byName['C']!.points, 4);
      expect(byName['D']!.points, 1);
      expect(byName['B']!.points, 0);
      expect(byName['B']!.lost, 2);
      // positions ordered by points.
      expect(standings.first.name, 'A');
      expect(standings.map((e) => e.position).toList(), [1, 2, 3, 4]);
      // total goals for == total goals against.
      expect(
          standings.fold<int>(0, (a, e) => a + e.goalsFor),
          standings.fold<int>(0, (a, e) => a + e.goalsAgainst));
      // every team's played matches sum consistently.
      expect(standings.every((e) => e.played == e.won + e.drawn + e.lost),
          isTrue);
    });

    test('tiebreak: goal difference then goals for', () {
      final standings = engine.computeStandings(
        clubIds: [1, 2, 3],
        names: ['A', 'B', 'C'],
        results: const [
          (round: 1, homeIndex: 0, awayIndex: 1, homeGoals: 3, awayGoals: 0),
          (round: 1, homeIndex: 2, awayIndex: 1, homeGoals: 2, awayGoals: 1),
        ],
      );
      // A: 3 pts +3; C: 3 pts +1; B: 0 pts. Same points → GD decides.
      expect(standings.first.name, 'A');
      expect(standings[1].name, 'C');
      expect(standings.first.goalDifference, 3);
      expect(standings[1].goalDifference, 1);
    });
  });

  group('Promotion/relegation (GDD 9.3)', () {
    const engine = SeasonEngine();

    test('positions 1-3 promote, 4-17 stay, 18-20 relegate', () {
      expect(engine.outcomeForPosition(1), SeasonOutcome.promoted);
      expect(engine.outcomeForPosition(2), SeasonOutcome.promoted);
      expect(engine.outcomeForPosition(3), SeasonOutcome.promoted);
      for (var pos = 4; pos <= 17; pos++) {
        expect(engine.outcomeForPosition(pos), SeasonOutcome.stayed,
            reason: 'position $pos');
      }
      expect(engine.outcomeForPosition(18), SeasonOutcome.relegated);
      expect(engine.outcomeForPosition(19), SeasonOutcome.relegated);
      expect(engine.outcomeForPosition(20), SeasonOutcome.relegated);
    });

    test('next division climbs on promotion, floors at 1 on relegation', () {
      expect(engine.nextDivisionFor(3, SeasonOutcome.promoted), 4);
      expect(engine.nextDivisionFor(3, SeasonOutcome.stayed), 3);
      expect(engine.nextDivisionFor(3, SeasonOutcome.relegated), 2);
      expect(engine.nextDivisionFor(1, SeasonOutcome.relegated), 1);
    });
  });

  group('Rewards (GDD 18)', () {
    const engine = SeasonEngine();

    test('champion earns the most, relegated the least', () {
      final first = engine.seasonRewardCoins(division: 1, position: 1);
      final third = engine.seasonRewardCoins(division: 1, position: 3);
      final mid = engine.seasonRewardCoins(division: 1, position: 10);
      final relegated = engine.seasonRewardCoins(division: 1, position: 19);
      expect(first, greaterThan(third));
      expect(third, greaterThan(mid));
      expect(mid, greaterThan(relegated));
      expect(relegated, greaterThan(0)); // participation reward
    });

    test('higher divisions pay more but sub-linearly', () {
      final d1 = engine.seasonRewardCoins(division: 1, position: 1);
      final d5 = engine.seasonRewardCoins(division: 5, position: 1);
      final d9 = engine.seasonRewardCoins(division: 9, position: 1);
      expect(d5, greaterThan(d1));
      expect(d9, greaterThan(d5));
      // Sub-linear: 8 divisions up pays less than 8× the base growth step
      // would suggest linearly (i.e. growth < ×2 per division).
      expect(d9 / d5, lessThan(2.0));
    });
  });

  group('AI club generation (GDD 9.4/9.6, FR-039)', () {
    const engine = SeasonEngine();

    test('generates 19 unique clubs with full 18-player squads', () {
      final random = DateTime.now().millisecondsSinceEpoch;
      final clubs = engine.generateAiClubs(1, random: _rand(random));
      expect(clubs.length, 19);
      final names = clubs.map((c) => c.name).toSet();
      expect(names.length, 19);
      for (final c in clubs) {
        expect(c.players.length, 18);
        expect(c.managerName, isNotEmpty);
        expect(c.formationCode, isNotEmpty);
      }
    });

    test('squads sit near the division target overall (GDD 9.6)', () {
      // Regenerate stats through the same curve the generator uses: the
      // definition's attributes derive from BaseStatsGenerator, so the
      // weighted average of generated overall ratings should be close to
      // the target.
      for (final division in [1, 5, 10]) {
        final target = engine.config.targetAverageOverall(division);
        final clubs =
            engine.generateAiClubs(division, random: _rand(7 + division));
        final ratings = <int>[];
        for (final club in clubs) {
          for (final p in club.players) {
            // Invert: what market value would produce these attributes?
            // Instead check directly: attack/support/defence around target.
            final avg = (p.attack + p.support + p.defence) / 3;
            ratings.add(avg.round());
          }
        }
        final mean = ratings.reduce((a, b) => a + b) / ratings.length;
        // The ±3 spread and position weighting keep the mean within a few
        // points of the division target.
        expect((mean - target).abs(), lessThan(6),
            reason: 'division $division mean $mean vs target $target');
      }
    });

    test('difficulty scales between divisions (GDD 9.6)', () {
      expect(
          engine.config.targetAverageOverall(5),
          greaterThan(engine.config.targetAverageOverall(1)));
      expect(
          engine.config.targetAverageOverall(10),
          greaterThan(engine.config.targetAverageOverall(5)));
      expect(
          engine.config.targetAverageOverall(2) -
              engine.config.targetAverageOverall(1),
          engine.config.overallPerDivision);
    });

    test('AI squads mirror real-player attribute structure', () {
      // A generated CB must be defence-heavy, an ST attack-heavy — the
      // same shape the BaseStatsGenerator produces for real players.
      final clubs = engine.generateAiClubs(3, random: _rand(11));
      final all = clubs.expand((c) => c.players).toList();
      final cb = all.firstWhere((p) => p.position == Position.cb);
      final st = all.firstWhere((p) => p.position == Position.st);
      final gk = all.firstWhere((p) => p.position == Position.gk);
      expect(cb.defence, greaterThan(cb.attack));
      expect(st.attack, greaterThan(st.defence));
      expect(gk.goalkeeping, greaterThan(gk.defence));
    });
  });
}

/// Deterministic random for stable generation tests.
math.Random _rand(int seed) => math.Random(seed);
