import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/season/season_engine.dart';

/// A realistic pool for real-player generation tests: every position
/// stocked across the overall ladder (mirrors the shipped dataset's
/// shape — thousands of players from ~40 OVR to ~94).
List<AiPoolPlayer> buildPool() {
  final pool = <AiPoolPlayer>[];
  var id = 1;
  for (final position in Position.values) {
    for (var overall = 36; overall <= 94; overall++) {
      for (var copy = 0; copy < 6; copy++) {
        pool.add(
          AiPoolPlayer(
            playerId: id,
            name:
                '${position.code.toUpperCase()} ${overall.toString().padLeft(2, '0')} $copy',
            position: position,
            overall: overall,
            attack: overall,
            support: overall,
            defence: overall,
            goalkeeping: overall,
          ),
        );
        id++;
      }
    }
  }
  return pool;
}

math.Random _rand(int seed) => math.Random(seed);

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
        homes['$a-$b-${p.homeIndex}'] =
            (homes['$a-$b-${p.homeIndex}'] ?? 0) + 1;
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
        expect(
          byRound[p.round]!.add(p.homeIndex),
          isTrue,
          reason: 'round ${p.round} home dup',
        );
        expect(
          byRound[p.round]!.add(p.awayIndex),
          isTrue,
          reason: 'round ${p.round} away dup',
        );
      }
    });

    test('the anchor team has a reasonable home/away balance', () {
      const engine = SeasonEngine();
      final pairings = engine.generateFixtures(20, anchorIndex: 0);
      final homeGames = pairings.where((p) => p.homeIndex == 0).length;
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
        standings.fold<int>(0, (a, e) => a + e.goalsAgainst),
      );
      // every team's played matches sum consistently.
      expect(
        standings.every((e) => e.played == e.won + e.drawn + e.lost),
        isTrue,
      );
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
        expect(
          engine.outcomeForPosition(pos),
          SeasonOutcome.stayed,
          reason: 'position $pos',
        );
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
        final clubs = engine.generateAiClubs(
          division,
          random: _rand(7 + division),
        );
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
        expect(
          (mean - target).abs(),
          lessThan(6),
          reason: 'division $division mean $mean vs target $target',
        );
      }
    });

    test('difficulty scales between divisions (GDD 9.6)', () {
      expect(
        engine.config.targetAverageOverall(5),
        greaterThan(engine.config.targetAverageOverall(1)),
      );
      expect(
        engine.config.targetAverageOverall(10),
        greaterThan(engine.config.targetAverageOverall(5)),
      );
      expect(
        engine.config.targetAverageOverall(2) -
            engine.config.targetAverageOverall(1),
        engine.config.overallPerDivision,
      );
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

  group('Real-player AI squads (GDD 9.4/9.6)', () {
    const engine = SeasonEngine();

    test('squads draw REAL players from the provided pool', () {
      final pool = buildPool();
      final clubs = engine.generateAiClubs(2, random: _rand(21), pool: pool);
      final poolById = {for (final p in pool) p.playerId: p};
      for (final club in clubs) {
        for (final p in club.players) {
          expect(
            p.realPlayerId,
            isNotNull,
            reason: '${club.name} has a synthetic player',
          );
          final real = poolById[p.realPlayerId]!;
          expect(p.name, real.name);
          expect(p.position, real.position);
        }
      }
    });

    test('a real player joins at most ONE club per division', () {
      final pool = buildPool();
      final clubs = engine.generateAiClubs(1, random: _rand(5), pool: pool);
      final seen = <int>{};
      for (final club in clubs) {
        for (final p in club.players) {
          expect(
            seen.contains(p.realPlayerId),
            isFalse,
            reason: 'player ${p.realPlayerId} signed twice',
          );
          seen.add(p.realPlayerId!);
        }
      }
    });

    test('players the user owns are never signed', () {
      final pool = buildPool();
      final owned = {for (final p in pool.take(50)) p.playerId};
      final clubs = engine.generateAiClubs(
        3,
        random: _rand(9),
        pool: pool,
        excludePlayerIds: owned,
      );
      for (final club in clubs) {
        for (final p in club.players) {
          expect(owned.contains(p.realPlayerId), isFalse);
        }
      }
    });

    test(
      'Division 1 is the easiest, later divisions field stronger squads',
      () {
        final pool = buildPool();
        double meanOverall(int division) {
          final clubs = engine.generateAiClubs(
            division,
            random: _rand(31),
            pool: pool,
          );
          final ratings = [
            for (final c in clubs)
              for (final p in c.players) (p.attack + p.support + p.defence) / 3,
          ];
          return ratings.reduce((a, b) => a + b) / ratings.length;
        }

        final d1 = meanOverall(1);
        final d3 = meanOverall(3);
        final d5 = meanOverall(5);
        // Division 1 sits near the new-user difficulty (~54), not the old 66.
        expect(d1, inInclusiveRange(50, 58));
        expect(d3, greaterThan(d1 + 3));
        expect(d5, greaterThan(d3 + 3));
      },
    );

    test('thin pools fall back to synthetic squads (graceful degradation)', () {
      // A pool with only a handful of players cannot fill 19×18 squads:
      // clubs must still be produced, with synthetic players.
      final tinyPool = buildPool().take(30).toList();
      final clubs = engine.generateAiClubs(1, random: _rand(3), pool: tinyPool);
      expect(clubs.length, 19);
      for (final c in clubs) {
        expect(c.players.length, 18);
      }
      final synthetic = [
        for (final c in clubs)
          for (final p in c.players)
            if (p.realPlayerId == null) p,
      ];
      expect(synthetic, isNotEmpty);
    });
  });

  group('AI squad lift past the dataset ceiling (GDD 9.6, 2026-11-09)', () {
    const engine = SeasonEngine();

    /// Average effective overall of a club's 18 players, computed the
    /// same way the lift does: mean of per-player outfield averages
    /// (ATT/SUP/DEF — the generation tests' basis; GK would read 0 for
    /// every outfield player).
    double avgEffectiveOverall(AiClubDefinition club) {
      final ratings = [
        for (final p in club.players)
          (p.attack + p.support + p.defence) / 3,
      ];
      return ratings.reduce((a, b) => a + b) / ratings.length;
    }

    test('division 1 squads are unchanged (zero drift, level 0)', () {
      final clubs = engine.generateAiClubs(1, random: _rand(5));
      for (final club in clubs) {
        for (final p in club.players) {
          expect(p.upgradeLevel, 0, reason: '${club.name} lifted at div 1');
        }
      }
      // And the near-target band still holds (GDD 9.6).
      final target = engine.config.targetAverageOverall(1);
      final means = clubs.map(avgEffectiveOverall).toList();
      final mean = means.reduce((a, b) => a + b) / means.length;
      expect((mean - target).abs(), lessThan(6));
    });

    test(
      'pool-path divisions the pool supplies never lift (review attempt 1)',
      () {
        // The reviewer's counterexample seeds: 42 lifted 3 div-1 clubs
        // under the dead-zone gate; 77 lifted 2. The structural gate
        // (pristine pool capacity) must keep every one of them at level
        // 0 — a variance shortfall is not a ceiling.
        for (final seed in [5, 42, 77, 1234]) {
          for (final division in [1, 2, 8, 12, 13, 14]) {
            final clubs = engine.generateAiClubs(
              division,
              random: _rand(seed),
              pool: buildPool(),
            );
            for (final club in clubs) {
              for (final p in club.players) {
                expect(
                  p.upgradeLevel,
                  0,
                  reason: 'div $division seed $seed lifted ${club.name}',
                );
              }
            }
          }
        }
      },
    );

    test(
      'synthetic divisions under the 94 clamp never lift (review attempt 1)',
      () {
        // Same invariant on the no-pool path, divisions 1..14 (targets
        // 54..93): the RNG-order fix keeps generation byte-identical and
        // the ceiling gate keeps the lift off.
        for (final seed in [5, 42, 77, 1234]) {
          for (final division in [1, 7, 14]) {
            final clubs = engine.generateAiClubs(division, random: _rand(seed));
            for (final club in clubs) {
              for (final p in club.players) {
                expect(p.upgradeLevel, 0);
              }
            }
          }
        }
      },
    );

    test('division 20 (target 111): every club meets the target ±1', () {
      final clubs = engine.generateAiClubs(20, random: _rand(77));
      final target = engine.config.targetAverageOverall(20);
      expect(target, 111);
      var above99 = 0;
      for (final club in clubs) {
        // ≥ target − 1: per-attr rounding on the lifted values costs at
        // most a fraction of a point, and division 20's gap (94-capped
        // generation vs 111) is far past the ceiling gate.
        expect(
          avgEffectiveOverall(club),
          greaterThan(target - 1),
          reason: '${club.name} missed the target',
        );
        for (final p in club.players) {
          if (p.attack > 99 || p.defence > 99 || p.support > 99) above99++;
          expect(p.upgradeLevel, greaterThan(0));
        }
      }
      // Lifted attributes flow past the 99 cap into matches.
      expect(above99, greaterThan(0));
    });

    test('real-pool path also lifts at division 20', () {
      // buildPool caps at 94: past that only the lift can reach 111.
      final pool = buildPool();
      final clubs = engine.generateAiClubs(20, random: _rand(21), pool: pool);
      final target = engine.config.targetAverageOverall(20);
      for (final club in clubs) {
        expect(avgEffectiveOverall(club), greaterThan(target - 1));
      }
    });

    test('same seed twice → identical squads and lifts', () {
      final a = engine.generateAiClubs(20, random: _rand(1234));
      final b = engine.generateAiClubs(20, random: _rand(1234));
      for (var i = 0; i < a.length; i++) {
        expect(a[i].name, b[i].name);
        for (var j = 0; j < a[i].players.length; j++) {
          final pa = a[i].players[j];
          final pb = b[i].players[j];
          expect(pa.name, pb.name);
          expect(pa.attack, pb.attack);
          expect(pa.support, pb.support);
          expect(pa.defence, pb.defence);
          expect(pa.goalkeeping, pb.goalkeeping);
          expect(pa.upgradeLevel, pb.upgradeLevel);
        }
      }
    });

    test('thin/no pool at a high target still produces a full legal XI', () {
      // No dataset loaded at all (synthetic path), division 25 (target
      // 126): every club must still field 18 players at the target.
      final clubs = engine.generateAiClubs(25, random: _rand(99));
      final target = engine.config.targetAverageOverall(25);
      expect(clubs.length, 19);
      for (final club in clubs) {
        expect(club.players.length, 18);
        expect(avgEffectiveOverall(club), greaterThan(target - 1));
      }
      // And a degenerate tiny pool mid-division also survives.
      final tiny = engine.generateAiClubs(
        20,
        random: _rand(3),
        pool: buildPool().take(30).toList(),
      );
      final target20 = engine.config.targetAverageOverall(20);
      for (final club in tiny) {
        expect(club.players.length, 18);
        expect(avgEffectiveOverall(club), greaterThan(target20 - 1));
      }
    });
  });

  group('AI lineup rotation (GDD 11)', () {
    const engine = SeasonEngine();

    AiSquadPlayer mk(
      Position position,
      int rating,
      double stamina, {
      String name = 'P',
    }) => AiSquadPlayer(
      realPlayerId: position.index * 100 + rating,
      name: '$name $rating ${position.code}',
      position: position,
      attack: position == Position.gk ? 20 : rating,
      support: rating,
      defence: position == Position.gk ? 20 : rating,
      goalkeeping: position == Position.gk ? rating : 20,
      stamina: stamina,
    );

    test('fresh starters keep their place at full stamina', () {
      final squad = [
        mk(Position.gk, 70, 100),
        for (final p in [Position.cb, Position.cb, Position.lb, Position.rb])
          mk(p, 70, 100),
        for (final p in [Position.cdm, Position.cm, Position.cam])
          mk(p, 70, 100),
        for (final p in [Position.lw, Position.rw, Position.st]) mk(p, 70, 100),
        for (var i = 0; i < 7; i++) mk(Position.cb, 40, 100, name: 'B$i'),
      ];
      final lineup = engine.pickAiLineup(squad, '4-3-3');
      expect(lineup.starters.length, 11);
      expect(lineup.bench.length, 7);
      // Every full-fitness first-teamer starts over the 40-rated bench.
      for (final s in lineup.starters) {
        expect(s.support, greaterThan(50));
      }
    });

    test('a genuinely tired starter is rested for a close backup', () {
      final squad = [
        mk(Position.gk, 70, 100),
        mk(Position.cb, 70, 30), // exhausted starter
        mk(Position.cb, 70, 100),
        mk(Position.lb, 70, 100),
        mk(Position.rb, 70, 100),
        for (final p in [Position.cdm, Position.cm, Position.cam])
          mk(p, 70, 100),
        for (final p in [Position.lw, Position.rw, Position.st]) mk(p, 70, 100),
        mk(Position.cb, 68, 100, name: 'Backup'), // near-quality cover
        for (var i = 0; i < 6; i++) mk(Position.cm, 40, 100, name: 'B$i'),
      ];
      final lineup = engine.pickAiLineup(squad, '4-3-3');
      final tired = squad[1];
      expect(
        lineup.starters.contains(tired),
        isFalse,
        reason: '30-stamina starter must be rotated out',
      );
      expect(lineup.bench.contains(tired), isTrue);
    });

    test('a tired STAR still starts over a weak backup (quality wins)', () {
      final squad = [
        mk(Position.gk, 70, 100),
        mk(Position.st, 85, 35), // tired but a superstar
        for (final p in [Position.cb, Position.cb, Position.lb, Position.rb])
          mk(p, 70, 100),
        for (final p in [Position.cdm, Position.cm, Position.cam])
          mk(p, 70, 100),
        mk(Position.lw, 70, 100),
        mk(Position.rw, 70, 100),
        mk(Position.st, 50, 100, name: 'Backup'), // weak cover
        for (var i = 0; i < 6; i++) mk(Position.cm, 40, 100, name: 'B$i'),
      ];
      final lineup = engine.pickAiLineup(squad, '4-3-3');
      final star = squad[1];
      expect(
        lineup.starters.contains(star),
        isTrue,
        reason: '85-rated at 35 stamina beats a 50-rated fresh backup',
      );
    });

    test('lineup returns XI in formation slot order and a bench', () {
      final squad = [
        mk(Position.gk, 70, 100),
        for (final p in [
          Position.lb,
          Position.cb,
          Position.cb,
          Position.rb,
          Position.cam,
          Position.cm,
          Position.cm,
          Position.lw,
          Position.st,
          Position.rw,
        ])
          mk(p, 70, 100),
        for (var i = 0; i < 7; i++) mk(Position.cm, 50, 100, name: 'B$i'),
      ];
      final lineup = engine.pickAiLineup(squad, '4-3-3');
      expect(lineup.starters.first.position, Position.gk);
      expect(lineup.starters.length + lineup.bench.length, squad.length);
    });
  });
}
