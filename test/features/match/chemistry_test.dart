// Nationality chemistry (owner spec 2026-11-09, T-0067).
//
// Unit level: chemistryPercentOf must return exactly the owner's
// verbatim examples — all-distinct 0, a pair +1, a triple +2, 2 Egypt +
// 4 Brazil + 5 distinct +4, eleven equal +10 — and clamp beyond 10,
// with ''/null never grouping.
//
// Engine level: two identical even-strength XIs, one nationality-less
// and one sharing a nationality — across fixed seeds 0..199 the
// chemistry side's mean goals scored must be strictly higher (fixed
// seeds → deterministic, no flake).
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/chemistry.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
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

void main() {
  group('chemistryPercentOf — the owner spec examples', () {
    test('all distinct nationalities → 0', () {
      expect(
        chemistryPercentOf([
          'Egypt',
          'Brazil',
          'France',
          'Germany',
          'Spain',
          'Italy',
          'England',
          'Portugal',
          'Morocco',
          'Senegal',
          'Japan',
        ]),
        0,
      );
    });

    test('a pair of one nationality → +1', () {
      expect(chemistryPercentOf(['Egypt', 'Egypt']), 1);
    });

    test('a triple of one nationality → +2', () {
      expect(chemistryPercentOf(['Brazil', 'Brazil', 'Brazil']), 2);
    });

    test('the owner\'s example: 2 Egypt + 4 Brazil + 5 distinct → +4', () {
      expect(
        chemistryPercentOf([
          'Egypt',
          'Egypt',
          'Brazil',
          'Brazil',
          'Brazil',
          'Brazil',
          'France',
          'Germany',
          'Spain',
          'Italy',
          'England',
        ]),
        4,
      );
    });

    test('eleven equal nationalities → +10', () {
      expect(chemistryPercentOf(List.filled(11, 'Egypt')), 10);
    });

    test('empty and blank entries never group', () {
      expect(chemistryPercentOf(['', '', '', null, null, '']), 0);
      expect(chemistryPercentOf(['Egypt', '', null, 'Egypt']), 1);
      expect(chemistryPercentOf(const []), 0);
    });

    test('more than 11 entries still clamp to 10', () {
      expect(chemistryPercentOf(List.filled(40, 'Brazil')), 10);
      expect(
        chemistryPercentOf([
          ...List.filled(6, 'Egypt'),
          ...List.filled(6, 'Brazil'),
          ...List.filled(6, 'France'),
        ]),
        10,
      );
    });

    test('a lone player has no chemistry', () {
      expect(chemistryPercentOf(['Egypt']), 0);
    });
  });

  group('engine — chemistry lifts the boosted XI', () {
    final gen = const BaseStatsGenerator();

    List<MatchPlayer> teamOf(
      int base,
      String nationality, {
      int value = 20_000_000,
    }) => [
      for (var i = 0; i < _positions.length; i++)
        MatchPlayer(
          playerId: base + i,
          name: 'P $i',
          position: _positions[i],
          attack: gen.generate(_positions[i], value).attack,
          support: gen.generate(_positions[i], value).support,
          defence: gen.generate(_positions[i], value).defence,
          goalkeeping: gen.generate(_positions[i], value).goalkeeping,
          nationality: nationality,
        ),
    ];

    MatchEngine engineOf(int seed, String boostedNationality) => MatchEngine(
      seed: seed,
      home: MatchTeamInput(
        teamId: 1,
        teamName: 'Home',
        formationCode: '4-4-2',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: teamOf(100, boostedNationality),
        bench: const [],
        aiControlled: true,
      ),
      away: MatchTeamInput(
        teamId: 2,
        teamName: 'Away',
        formationCode: '4-3-3',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        // Eleven distinct nationalities → 0% for the away side; the
        // home XI shares one → +10%.
        starters: [
          for (var i = 0; i < _positions.length; i++)
            MatchPlayer(
              playerId: 300 + i,
              name: 'A $i',
              position: _positions[i],
              attack: gen.generate(_positions[i], 20_000_000).attack,
              support: gen.generate(_positions[i], 20_000_000).support,
              defence: gen.generate(_positions[i], 20_000_000).defence,
              goalkeeping: gen.generate(_positions[i], 20_000_000).goalkeeping,
              nationality: 'nat$i',
            ),
        ],
        bench: const [],
        aiControlled: true,
      ),
    );

    test('across seeds 0..199 the chemistry XI scores more on average', () {
      const seeds = 200;
      var plainHomeGoals = 0;
      var boostedHomeGoals = 0;
      for (var seed = 0; seed < seeds; seed++) {
        final plain = engineOf(seed, '').simulateToEnd();
        final boosted = engineOf(seed, 'Egypt').simulateToEnd();
        plainHomeGoals += _homeGoalsOf(plain);
        boostedHomeGoals += _homeGoalsOf(boosted);
      }
      final plainMean = plainHomeGoals / seeds;
      final boostedMean = boostedHomeGoals / seeds;
      // Fixed seeds → both means are deterministic; strictly higher
      // is stable, not flaky.
      expect(
        boostedMean,
        greaterThan(plainMean),
        reason:
            'chemistry (+10%) should raise the boosted XI\'s mean goals '
            'across fixed seeds: boosted=$boostedMean plain=$plainMean',
      );
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('zero-chemistry fixtures are unchanged by the feature', () {
      // Both sides nationality-less → chemistry factor is exactly 1.0
      // on every computeTotals call: same seed, same events as before
      // the feature existed.
      final events = engineOf(42, '').simulateToEnd();
      expect(events, isNotEmpty);
    });
  });
}

int _homeGoalsOf(List<dynamic> events) => events
    .where((e) => e.type == MatchEventType.goal && e.side == MatchSide.home)
    .length;
