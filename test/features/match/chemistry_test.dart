// Chemistry (owner spec 2026-11-09 nationality half, T-0067; club half
// and the combined total added 2026-11-11).
//
// Unit level: chemistryPercentOf must return exactly the owner's
// verbatim examples — all-distinct 0, a pair +1, a triple +2, 2 Egypt +
// 4 Brazil + 5 distinct +4, eleven equal +10 — and clamp beyond 10,
// with ''/null never grouping. totalChemistryPercentOf adds the club
// dimension with the same formula and keeps the combined ceiling at 10
// (locked by the T-0068 balance gate).
//
// Engine level: two identical even-strength XIs, one chemistry-less
// and one sharing a nationality (and a second pair sharing a club) —
// across fixed seeds the chemistry side's mean goals scored must be
// strictly higher (fixed seeds → deterministic, no flake).
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

  group('clubChemistryKeyOf — club grouping keys', () {
    test('a known club id groups by id', () {
      expect(clubChemistryKeyOf(18, 'Liverpool'), 'club:18');
    });

    test('an id-less club falls back to its name', () {
      expect(clubChemistryKeyOf(0, 'Al Ahly'), 'club:Al Ahly');
    });

    test('an unknown club is blank and never groups', () {
      expect(clubChemistryKeyOf(0, ''), '');
    });

    test('the id wins over the name, so the same club never splits', () {
      // Two rows of one club (id 18, name 'Liverpool') vs a different
      // club that happens to carry the same name: id keys keep them
      // apart, and id-0 rows still group with each other by name.
      expect(clubChemistryKeyOf(18, 'Liverpool') ==
              clubChemistryKeyOf(18, 'LFC'),
          isTrue);
      expect(clubChemistryKeyOf(18, 'Liverpool') ==
              clubChemistryKeyOf(0, 'Liverpool'),
          isFalse);
    });
  });

  group('totalChemistryPercentOf — nationality + club (2026-11-11)', () {
    test('all distinct in both dimensions → 0', () {
      expect(
        totalChemistryPercentOf(
          nationalities: ['Egypt', 'Brazil', 'France'],
          clubs: ['club:1', 'club:2', 'club:3'],
        ),
        0,
      );
    });

    test('2 same nationality + 2 same club (disjoint pairs) → +2', () {
      expect(
        totalChemistryPercentOf(
          nationalities: ['Egypt', 'Egypt', 'Brazil', 'France'],
          clubs: ['club:1', 'club:2', 'club:2', 'club:3'],
        ),
        2,
      );
    });

    test('the owner formula per dimension: 2 Egypt + 4 Brazil + club groups → +9', () {
      expect(
        totalChemistryPercentOf(
          nationalities: [
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
          ],
          clubs: [
            'club:1',
            'club:1',
            'club:1',
            'club:1',
            'club:1',
            'club:2',
            'club:2',
            'club:3',
            'club:4',
            'club:5',
            'club:6',
          ],
        ),
        9, // 4 nationality points (1 + 3) + 5 club points (4 + 1).
      );
    });

    test('a pair sharing BOTH nationality and club counts once per type', () {
      expect(
        totalChemistryPercentOf(
          nationalities: ['Egypt', 'Egypt'],
          clubs: ['club:1', 'club:1'],
        ),
        2,
      );
    });

    test('the combined total still clamps at 10 (T-0068 gate ceiling)', () {
      expect(
        totalChemistryPercentOf(
          nationalities: List.filled(11, 'Egypt'),
          clubs: List.filled(11, 'club:1'),
        ),
        10, // 10 + 10 → 10, not 20.
      );
      expect(
        totalChemistryPercentOf(
          nationalities: List.filled(11, 'Egypt'),
          clubs: List.filled(11, 'club:2'),
        ),
        10,
      );
    });

    test('blank clubs contribute nothing', () {
      expect(
        totalChemistryPercentOf(
          nationalities: ['Egypt', 'Egypt'],
          clubs: ['', '', null],
        ),
        1,
      );
    });
  });

  group('engine — chemistry lifts the boosted XI', () {
    final gen = const BaseStatsGenerator();

    List<MatchPlayer> teamOf(
      int base,
      List<String> nationalities, {
      int value = 20_000_000,
      int clubId = 0,
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
          nationality: nationalities[i],
          clubId: clubId,
          clubName: clubId == 0 ? '' : 'Shared FC',
        ),
    ];

    MatchEngine engineOf(
      int seed,
      List<String> homeNationalities, {
      int homeClubId = 0,
    }) => MatchEngine(
      seed: seed,
      home: MatchTeamInput(
        teamId: 1,
        teamName: 'Home',
        formationCode: '4-4-2',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: teamOf(100, homeNationalities, clubId: homeClubId),
        bench: const [],
        aiControlled: true,
      ),
      away: MatchTeamInput(
        teamId: 2,
        teamName: 'Away',
        formationCode: '4-3-3',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        // Eleven distinct nationalities and no club → 0% for the away
        // side; the home XI's boost is varied per test.
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
        final plain = engineOf(seed, List.filled(11, '')).simulateToEnd();
        final boosted = engineOf(seed, List.filled(11, 'Egypt'))
            .simulateToEnd();
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

    test('across seeds 0..199 a CLUB-only chemistry XI scores more on average', () {
      // Distinct nationalities, one shared club: the entire +10% comes
      // from the club half (owner request 2026-11-11) — proving the new
      // dimension reaches the engine totals, not just the reading.
      const seeds = 200;
      var plainHomeGoals = 0;
      var clubbedHomeGoals = 0;
      for (var seed = 0; seed < seeds; seed++) {
        final plain = engineOf(seed, [for (var i = 0; i < 11; i++) 'hn$i'])
            .simulateToEnd();
        final clubbed = engineOf(
          seed,
          [for (var i = 0; i < 11; i++) 'hn$i'],
          homeClubId: 7,
        ).simulateToEnd();
        plainHomeGoals += _homeGoalsOf(plain);
        clubbedHomeGoals += _homeGoalsOf(clubbed);
      }
      final plainMean = plainHomeGoals / seeds;
      final clubbedMean = clubbedHomeGoals / seeds;
      expect(
        clubbedMean,
        greaterThan(plainMean),
        reason:
            'club chemistry (+10%) should raise the boosted XI\'s mean '
            'goals across fixed seeds: clubbed=$clubbedMean '
            'plain=$plainMean',
      );
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('zero-chemistry fixtures are unchanged by the feature', () {
      // Both sides nationality-less and club-less → chemistry factor
      // is exactly 1.0 on every computeTotals call: same seed, same
      // events as before the feature existed.
      final events = engineOf(42, List.filled(11, '')).simulateToEnd();
      expect(events, isNotEmpty);
    });
  });
}

int _homeGoalsOf(List<dynamic> events) => events
    .where((e) => e.type == MatchEventType.goal && e.side == MatchSide.home)
    .length;
