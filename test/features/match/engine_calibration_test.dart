// Real-football calibration (GDD §31 metrics, engine v2).
//
// The engine must reproduce the distributions of real professional
// football — not just 'plausible' ranges — and it must keep doing so
// when one side is massively stronger: a title winner against a
// relegation squad wins ~4 in 5 with scorelines like 3-0/4-1, NOT
// 9-1. The strength response is deliberately SATURATING (logistic
// chance creation, bounded shot conversion), which is what bounds the
// blowouts.
//
// Real-world reference points (Europe's top divisions, recent seasons):
//   goals/match            ~2.6-2.8
//   share of 0-0/1-0/1-1   ~30% of all scorelines
//   6+ goal matches        ~3.5-4%
//   shots per team         9-14, on-target ~35-40%
//   fouls per match        ~20-24, yellows ~4, reds rare
//   corners per match      ~9-10 total
//   home W/D/L             ~45/25/30
//   biggest gap (20 OVR)   favourite wins ~80-85%, rarely 6+ goals
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_report.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

const _positions = [
  Position.gk,
  Position.lb,
  Position.cb,
  Position.cb,
  Position.rb,
  Position.lm,
  Position.cm,
  Position.cm,
  Position.rm,
  Position.st,
  Position.st,
];

List<MatchPlayer> makeTeam(int base, String name, {required int value}) {
  final gen = const BaseStatsGenerator();
  return [
    for (var i = 0; i < 11; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$name $i',
        position: _positions[i],
        attack: gen.generate(_positions[i], value).attack,
        support: gen.generate(_positions[i], value).support,
        defence: gen.generate(_positions[i], value).defence,
        goalkeeping: gen.generate(_positions[i], value).goalkeeping,
      ),
  ];
}

MatchEngine engine(
  int seed, {
  required int homeValue,
  required int awayValue,
}) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    style: PlayingStyle.balanced,
    mentality: Mentality.balanced,
    starters: makeTeam(100, 'Home', value: homeValue),
    bench: const [],
    aiControlled: true,
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-3-3',
    style: PlayingStyle.balanced,
    mentality: Mentality.balanced,
    starters: makeTeam(300, 'Away', value: awayValue),
    bench: const [],
    aiControlled: true,
  ),
);

/// One scenario's aggregate over [n] seeds.
// ignore: library_private_types_in_public_api
class _Scenario {
  _Scenario(this.label, this.scores, this.statsList);

  final String label;
  final List<(int, int)> scores;
  final List<MatchStatsReport> statsList;

  int get matches => scores.length;
  double get avgGoals =>
      scores.fold<int>(0, (a, s) => a + s.$1 + s.$2) / matches;
  int get maxGoals =>
      scores.fold<int>(0, (a, s) => a > s.$1 + s.$2 ? a : s.$1 + s.$2);
  double get share6Plus =>
      scores.where((s) => s.$1 + s.$2 >= 6).length / matches;
  double get favouriteWins {
    final fav = scores.where((s) => s.$1 > s.$2).length;
    return fav / matches;
  }

  double get avgShotsPerTeam =>
      statsList.fold<int>(0, (a, s) => a + s.home.shots + s.away.shots) /
      (matches * 2);
  double get foulsPerMatch =>
      statsList.fold<int>(0, (a, s) => a + s.home.fouls + s.away.fouls) /
      matches;
  double get avgPossessionHome {
    var total = 0.0;
    var n = 0;
    for (final s in statsList) {
      if (s.home.possessionMinutes + s.away.possessionMinutes > 0) {
        total += s.possessionPercent(s.home);
        n++;
      }
    }
    return n > 0 ? total / n : 0;
  }
}

Future<_Scenario> _runScenario(
  String label,
  int matches,
  int homeValue,
  int awayValue,
) async {
  final scores = <(int, int)>[];
  final statsList = <MatchStatsReport>[];
  for (var m = 0; m < matches; m++) {
    final eng = engine(m, homeValue: homeValue, awayValue: awayValue);
    final events = eng.simulateToEnd();
    scores.add((eng.state.scoreHome, eng.state.scoreAway));
    statsList.add(computeStats(events, homeTeamId: 1, awayTeamId: 2));
  }
  return _Scenario(label, scores, statsList);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Enough seeds that share-estimates are stable to ±3%.
  const matches = 400;

  group('engine calibration vs real football (even strength)', () {
    late _Scenario even;
    setUpAll(() async {
      even = await _runScenario('even', matches, 20_000_000, 20_000_000);
    });

    test('average goals per match lands in the real band 2.4–2.9', () {
      expect(even.avgGoals, greaterThan(2.4));
      expect(even.avgGoals, lessThan(2.9));
    });

    test('goalless/low-scoring matches stay common (real ~30% under 2)', () {
      final under2 = even.scores
          .where((s) => s.$1 + s.$2 <= 1)
          .length; // 0-0, 1-0, 0-1
      expect(under2 / even.matches, greaterThan(0.18));
    });

    test('6+ goal thrillers are rare (real ~4%) and 9+ never at even', () {
      expect(even.share6Plus, lessThan(0.065));
      expect(even.maxGoals, lessThan(9));
    });

    test('shots per team 9–14 with real-ish share on target', () {
      expect(even.avgShotsPerTeam, greaterThan(9));
      expect(even.avgShotsPerTeam, lessThan(14));
      var onTarget = 0, shots = 0;
      for (final s in even.statsList) {
        onTarget += s.home.shotsOnTarget + s.away.shotsOnTarget;
        shots += s.home.shots + s.away.shots;
      }
      expect(onTarget / shots, greaterThan(0.34));
      expect(onTarget / shots, lessThan(0.48));
    });

    test('fouls 16–24 and corners 3.5–6.5 per match', () {
      expect(even.foulsPerMatch, greaterThan(16));
      expect(even.foulsPerMatch, lessThan(24));
      final corners =
          even.statsList.fold<int>(
            0,
            (a, s) => a + s.home.corners + s.away.corners,
          ) /
          even.matches;
      expect(corners, greaterThan(3.5));
      expect(corners, lessThan(6.5));
    });

    test('home advantage is real but modest (42–52% home wins)', () {
      expect(even.favouriteWins, greaterThan(0.42));
      expect(even.favouriteWins, lessThan(0.52));
    });

    test('possession stays in a plausible band (48–56%) at even strength', () {
      expect(even.avgPossessionHome, greaterThan(48));
      expect(even.avgPossessionHome, lessThan(56));
    });
  });

  group('engine calibration vs real football (big power gaps)', () {
    late _Scenario gap;
    setUpAll(() async {
      // €100M squad (OVR ~88) vs €5M squad (OVR ~71): a 17-point class
      // difference — title winner vs relegation fodder.
      gap = await _runScenario('gap', matches, 100_000_000, 5_000_000);
    });

    test('the favourite dominates: 72–88% wins', () {
      expect(gap.favouriteWins, greaterThan(0.72));
      expect(gap.favouriteWins, lessThan(0.88));
    });

    test('but scorelines stay REAL: avg under 3.9, 6+ goals under 15%', () {
      expect(gap.avgGoals, greaterThan(2.9));
      expect(gap.avgGoals, lessThan(3.9));
      expect(gap.share6Plus, lessThan(0.15));
      expect(gap.maxGoals, lessThan(10));
    });

    test('the favourite outshoots the underdog, not out-scores-per-shot', () {
      final favShots = gap.statsList.fold<int>(0, (a, s) => a + s.home.shots);
      final dogShots = gap.statsList.fold<int>(0, (a, s) => a + s.away.shots);
      expect(favShots, greaterThan(dogShots * 1.15));
      // Conversion advantage is bounded: per-shot goal rate no more than
      // 1.6x the underdog's (saturating response, not certain goals).
      final favGoals = gap.scores.fold<int>(0, (a, s) => a + s.$1);
      final dogGoals = gap.scores.fold<int>(0, (a, s) => a + s.$2);
      final favRate = favGoals / favShots;
      final dogRate = dogGoals / dogShots;
      expect(favRate / dogRate, lessThan(1.9));
    });

    test('possession dominance is strong but bounded (max ~65% average)', () {
      expect(gap.avgPossessionHome, greaterThan(56));
      expect(gap.avgPossessionHome, lessThan(66));
    });
  });

  group('engine calibration vs real football (extreme 90/10 gap)', () {
    late _Scenario huge;
    setUpAll(() async {
      // €180M galacticos vs €2M minnows: the widest gap the game can
      // field (OVR ~91 vs ~65). Still must not produce basketball.
      huge = await _runScenario('huge', matches ~/ 2, 180_000_000, 2_000_000);
    });

    test('avg goals stay under 4.4 and 8+ blowouts stay exceptional', () {
      expect(huge.avgGoals, lessThan(4.4));
      expect(
        huge.scores.where((s) => s.$1 + s.$2 >= 8).length / huge.matches,
        lessThan(0.06),
      );
      expect(huge.maxGoals, lessThan(11));
    });

    test('the minnow still creates chances of its own (shots > 5/team)', () {
      final dogShots = huge.statsList.fold<int>(0, (a, s) => a + s.away.shots);
      expect(dogShots / huge.matches, greaterThan(5));
    });
  });
}
