// Pass-completion stats (review 2026-11-04_match-report_pass-completion-stats).
//
// Reported pass completion was 15.6% vs real 75-85%: possession-kept
// pockets counted attempts with zero completions. Now every counted
// attempt carries its completions (kept pockets at the team's
// support-driven accuracy, lost pockets at a reduced volume), and
// keepers register involvement through saves and corner claims. These
// tests lock the measured bands so the stat cannot rot silently again.
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

MatchEngine engine(int seed, {required int homeValue, required int awayValue}) =>
    MatchEngine(
      seed: seed,
      home: MatchTeamInput(
        teamId: 1,
        teamName: 'Home',
        formationCode: '4-4-2',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: makeTeam(100, 'Home', value: homeValue),
        bench: const [],
        aiControlled: true,
      ),
      away: MatchTeamInput(
        teamId: 2,
        teamName: 'Away',
        formationCode: '4-3-3',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: makeTeam(300, 'Away', value: awayValue),
        bench: const [],
        aiControlled: true,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'pass completion lands in the real band 70-88% at even strength',
    () {
      const matches = 2000;
      var attempted = 0, completed = 0;
      for (var m = 0; m < matches; m++) {
        final eng = engine(m, homeValue: 20_000_000, awayValue: 20_000_000);
        final events = eng.simulateToEnd();
        final stats = computeStats(events, homeTeamId: 1, awayTeamId: 2);
        attempted += stats.home.passesAttempted + stats.away.passesAttempted;
        completed += stats.home.passesCompleted + stats.away.passesCompleted;
      }
      final completion = completed / attempted;
      expect(completion, greaterThan(0.70), reason: 'real teams: 75-85%');
      expect(completion, lessThan(0.88));

      // Volume stays realistic: 300-600 attempts per team per match.
      expect(attempted / (matches * 2), greaterThan(300));
      expect(attempted / (matches * 2), lessThan(600));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a +6-support-point favourite completes >= +4 points over the underdog',
    () {
      const matches = 500;
      // €24M vs €20M ≈ a 7-point support gap after the totals pipeline.
      var favAtt = 0, favComp = 0, dogAtt = 0, dogComp = 0;
      for (var m = 0; m < matches; m++) {
        final eng = engine(m, homeValue: 24_000_000, awayValue: 20_000_000);
        final events = eng.simulateToEnd();
        final stats = computeStats(events, homeTeamId: 1, awayTeamId: 2);
        favAtt += stats.home.passesAttempted;
        favComp += stats.home.passesCompleted;
        dogAtt += stats.away.passesAttempted;
        dogComp += stats.away.passesCompleted;
      }
      final edge = (favComp / favAtt) - (dogComp / dogAtt);
      expect(
        edge,
        greaterThan(0.04),
        reason: 'a real technical gap shows in pass completion',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the goalkeeper has non-zero involvement in >= 90% of matches '
    '(saves and corner claims)',
    () {
      const matches = 500;
      var gkVisibleMatches = 0;
      for (var m = 0; m < matches; m++) {
        final eng = engine(m, homeValue: 20_000_000, awayValue: 20_000_000);
        final events = eng.simulateToEnd();
        final homeGk = eng
            .playersOf(MatchSide.home)
            .firstWhere((p) => p.position == Position.gk);
        final awayGk = eng
            .playersOf(MatchSide.away)
            .firstWhere((p) => p.position == Position.gk);
        var visible = false;
        for (final e in events) {
          if (e.type == MatchEventType.shot &&
              (e.metadata['gkPlayerId'] == homeGk.playerId ||
                  e.metadata['gkPlayerId'] == awayGk.playerId)) {
            visible = true;
            break;
          }
          if (e.type == MatchEventType.corner &&
              e.metadata['gkClaim'] == true) {
            visible = true;
            break;
          }
        }
        if (visible) gkVisibleMatches++;
      }
      expect(
        gkVisibleMatches / matches,
        greaterThan(0.90),
        reason: 'GDD 14: keepers must register in low-scoring matches too',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
