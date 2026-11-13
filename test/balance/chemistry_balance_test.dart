/// FCM Rivals — chemistry impact gate (T-0068, GDD 12 chemistry).
///
/// Measurement-only lock (no production code changes): two identical
/// even-strength teams — same XIs, same tactics, same mentality, same
/// formation — varying ONLY the home side's nationalities so its
/// chemistry level is 0% / 3% / 5% / 10%. Seeds 0..999 per level,
/// following the balance suite's batch pattern.
///
/// Bands locked by this gate:
///  (a) both sides' avg goals stay inside the engine's 1.4–5.2 band at
///      every level — chemistry never breaks the goals economy;
///  (b) the chemistry side's win rate rises monotonically with the
///      level (0% < 3% < 5% < 10%) — the bonus is real;
///  (c) at 10% the win rate stays below 0.62 — a full-chemistry edge
///      remains weaker than a 4-rating-point squad gap;
///  (d) the 0% level reproduces the even-strength band (0.42–0.52).
library;

import 'dart:math' as math;

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

/// Value that generates overall 70 under the default curve — both sides
/// are even strength by construction (same helper math as the balance
/// suite's ladder).
int get _evenValue => (50_000_000 * math.pow(2, (70 - 84) / 4)).round();

/// One even-strength XI; nationalities are injected per level. The
/// generator is deterministic on position+value, so home and away XIs
/// are statistically identical before chemistry.
List<MatchPlayer> _squad(int base, String prefix, List<String> nations) {
  final gen = const BaseStatsGenerator();
  final value = _evenValue;
  return [
    for (var i = 0; i < _positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$prefix $i',
        position: _positions[i],
        attack: gen.generate(_positions[i], value).attack,
        support: gen.generate(_positions[i], value).support,
        defence: gen.generate(_positions[i], value).defence,
        goalkeeping: gen.generate(_positions[i], value).goalkeeping,
        nationality: nations[i],
      ),
  ];
}

/// Nationality list for a level: [groupSize] players share 'Egypt'
/// (worth groupSize − 1 chemistry points) and the rest stay distinct.
List<String> _nations(int groupSize) => [
  for (var i = 0; i < groupSize; i++) 'Egypt',
  for (var i = groupSize; i < _positions.length; i++) 'hn$i',
];

/// The away side is always all-distinct: 0% chemistry at every level.
const _awayNations = [
  'an0',
  'an1',
  'an2',
  'an3',
  'an4',
  'an5',
  'an6',
  'an7',
  'an8',
  'an9',
  'an10',
];

MatchEngine _engine(int seed, List<String> homeNations) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _squad(100, 'H', homeNations),
    bench: const [],
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _squad(300, 'A', _awayNations),
    bench: const [],
  ),
);

class ChemBatch {
  ChemBatch(
    this.matches,
    this.homeWins,
    this.draws,
    this.awayWins,
    this.homeGoals,
    this.awayGoals,
    this.homeShots,
    this.awayShots,
  );

  final int matches;
  final int homeWins;
  final int draws;
  final int awayWins;
  final int homeGoals;
  final int awayGoals;
  final int homeShots;
  final int awayShots;

  double get homeWinRate => homeWins / matches;
  double get drawRate => draws / matches;
  double get awayWinRate => awayWins / matches;
  double get avgHomeGoals => homeGoals / matches;
  double get avgAwayGoals => awayGoals / matches;
  double get avgHomeShots => homeShots / matches;
  double get avgAwayShots => awayShots / matches;
}

/// Sweep seeds 0..[matches] − 1 with the home side at the given
/// chemistry nationalities.
ChemBatch runChemBatch(int matches, List<String> homeNations) {
  var hw = 0, d = 0, aw = 0, hg = 0, ag = 0, hs = 0, as_ = 0;
  for (var m = 0; m < matches; m++) {
    final engine = _engine(m, homeNations);
    engine.simulateToEnd();
    final s = engine.state;
    if (s.scoreHome > s.scoreAway) {
      hw++;
    } else if (s.scoreAway > s.scoreHome) {
      aw++;
    } else {
      d++;
    }
    hg += s.scoreHome;
    ag += s.scoreAway;
    final stats = computeStats(engine.events, homeTeamId: 1, awayTeamId: 2);
    hs += stats.home.shots;
    as_ += stats.away.shots;
  }
  return ChemBatch(matches, hw, d, aw, hg, ag, hs, as_);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chemistry impact ladder (T-0068 gate)', () {
    const n = 1000;
    final levels = <int, ChemBatch>{};
    setUpAll(() {
      // groupSize n → chemistry (n − 1)%: 0% distinct, 3% one group of
      // 4, 5% one group of 6, 10% all 11 equal.
      for (final groupSize in [1, 4, 6, 11]) {
        final b = runChemBatch(n, _nations(groupSize));
        levels[groupSize] = b;
        // Measured profile, printed for the Developer Notes record.
        // ignore: avoid_print
        print(
          'chemistry ${(groupSize - 1).toString().padLeft(2)}%: '
          'win ${b.homeWinRate.toStringAsFixed(3)} '
          'draw ${b.drawRate.toStringAsFixed(3)} '
          'homeGoals ${b.avgHomeGoals.toStringAsFixed(2)} '
          'awayGoals ${b.avgAwayGoals.toStringAsFixed(2)} '
          'homeShots ${b.avgHomeShots.toStringAsFixed(1)} '
          'awayShots ${b.avgAwayShots.toStringAsFixed(1)}',
        );
      }
    });

    test('(a) total avg goals per match stay inside the engine band 1.4–5.2', () {
      // The engine band is per-MATCH total goals (the suite's avgGoals =
      // (home + away) / matches), not per side — a per-side reading
      // would fail the suite's own gap ladder too (the +20 underdog
      // averages ~1.1). Chemistry must not break the goals economy.
      for (final e in levels.entries) {
        final avgGoals = e.value.avgHomeGoals + e.value.avgAwayGoals;
        expect(
          avgGoals,
          inInclusiveRange(1.4, 5.2),
          reason: 'chemistry ${(e.key - 1)}% total goals '
              '${avgGoals.toStringAsFixed(2)}',
        );
      }
    });

    test('(b) win rate rises monotonically 0% < 3% < 5% < 10%', () {
      expect(levels[4]!.homeWinRate, greaterThan(levels[1]!.homeWinRate));
      expect(levels[6]!.homeWinRate, greaterThan(levels[4]!.homeWinRate));
      expect(levels[11]!.homeWinRate, greaterThan(levels[6]!.homeWinRate));
    });

    test('(c) full chemistry stays weaker than a 4-point squad gap', () {
      expect(
        levels[11]!.homeWinRate,
        lessThan(0.62),
        reason: '10% chemistry win rate '
            '${levels[11]!.homeWinRate.toStringAsFixed(3)}',
      );
    });

    test('(d) the 0% level reproduces the even-strength band 0.42–0.52', () {
      expect(
        levels[1]!.homeWinRate,
        inInclusiveRange(0.42, 0.52),
        reason: '0% chemistry win rate '
            '${levels[1]!.homeWinRate.toStringAsFixed(3)}',
      );
    });
  });
}
