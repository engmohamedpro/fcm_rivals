// Fatigue decoupling (owner decision 2026-11-07, task T-0052):
// stamina never affects match performance — it stays the rotation
// currency, the substitute-management resource and, from the injury
// tasks, the injury-risk input. Nothing else.
//
// Locks the three guarantees the decoupling rests on:
//   1. computeTotals stamina invariance — two identical squads differing
//      only in starting stamina return identical team totals, at minute
//      0 and after a full match of drain.
//   2. lateGameOpenFactor — the pure time escalation that replaced the
//      removed `(1 - avgStamina)` term: identity below minute 60,
//      strictly increasing after, pure (no RNG) and bounded at
//      1 + slope at full time.
//   3. Determinism — same seed, different starting stamina, AI
//      substitutions disabled (empty bench): byte-identical event
//      streams. Only stamina LEVELS differ, and nothing reads them on
//      the performance path any more.
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import 'package:fcm_rivals/core/domain/players.dart';
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

List<MatchPlayer> _team(int base, String name, int value, double stamina) {
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
        stamina: stamina,
      ),
  ];
}

MatchEngine _engine(
  int seed, {
  required double homeStamina,
  required double awayStamina,
}) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _team(100, 'Home', 20_000_000, homeStamina),
    bench: const [],
    aiControlled: true,
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-3-3',
    tactics: const TeamTactics(),
    mentality: Mentality.balanced,
    starters: _team(300, 'Away', 20_000_000, awayStamina),
    bench: const [],
    aiControlled: true,
  ),
);

/// Canonical one-line record of an event for byte-identical stream
/// comparison: every field the engine derives, in stable order.
String _dump(MatchEvent e) =>
    '${e.eventId}|${e.minute}|${e.second}|${e.type}|${e.side}|'
    '${e.teamId}|${e.primaryPlayerId}|${e.secondaryPlayerId}|'
    '${e.shotOutcome}|${e.quality}|${e.xg}|${e.metadata}';

void main() {
  group('computeTotals stamina invariance (T-0052)', () {
    test('stamina 100 vs 40: identical totals at minute 0', () {
      final fresh = _engine(7, homeStamina: 100, awayStamina: 100);
      final tired = _engine(7, homeStamina: 40, awayStamina: 40);
      for (final side in MatchSide.values) {
        final a = fresh.totalsOf(side);
        final b = tired.totalsOf(side);
        expect(b.attack, a.attack, reason: 'attack $side');
        expect(b.support, a.support, reason: 'support $side');
        expect(b.defence, a.defence, reason: 'defence $side');
        expect(b.goalkeeping, a.goalkeeping, reason: 'goalkeeping $side');
      }
    });

    test('invariance survives a full match of drain', () {
      final fresh = _engine(11, homeStamina: 100, awayStamina: 100);
      final tired = _engine(11, homeStamina: 40, awayStamina: 40);
      fresh.simulateToEnd();
      tired.simulateToEnd();
      // Sanity: the tired squad really did drain to a different level.
      final freshAvg =
          fresh.playersOf(MatchSide.home).fold<double>(0, (a, p) => a + p.stamina) /
          11;
      final tiredAvg =
          tired.playersOf(MatchSide.home).fold<double>(0, (a, p) => a + p.stamina) /
          11;
      expect(tiredAvg, lessThan(freshAvg));
      for (final side in MatchSide.values) {
        final a = fresh.totalsOf(side);
        final b = tired.totalsOf(side);
        expect(b.attack, a.attack, reason: 'attack $side');
        expect(b.support, a.support, reason: 'support $side');
        expect(b.defence, a.defence, reason: 'defence $side');
        expect(b.goalkeeping, a.goalkeeping, reason: 'goalkeeping $side');
      }
    });
  });

  group('lateGameOpenFactor (pure time escalation, T-0052)', () {
    const config = LateGameOpenConfig();
    test('identity below the open minute (60)', () {
      for (var m = 0; m < config.openStartMinute; m++) {
        expect(
          lateGameOpenFactor(m, 94, config),
          1.0,
          reason: 'minute $m must be identity',
        );
      }
    });

    test('strictly increasing after the open minute to full time', () {
      const fullTime = 94;
      // At the open minute itself the factor is still the identity;
      // every minute AFTER it strictly raises the factor.
      var prev = lateGameOpenFactor(config.openStartMinute, fullTime, config);
      expect(prev, 1.0);
      for (var m = config.openStartMinute + 1; m <= fullTime; m++) {
        final f = lateGameOpenFactor(m, fullTime, config);
        expect(f, greaterThan(prev), reason: 'minute $m not increasing');
        prev = f;
      }
    });

    test('pure: same inputs return the same value, no RNG', () {
      for (var m = 0; m <= 120; m++) {
        expect(
          lateGameOpenFactor(m, 94, config),
          lateGameOpenFactor(m, 94, config),
        );
      }
    });

    test('bounded: exactly 1 + slope at full time and clamped beyond', () {
      expect(
        lateGameOpenFactor(94, 94, config),
        closeTo(1 + config.slope, 1e-9),
      );
      expect(
        lateGameOpenFactor(120, 94, config),
        closeTo(1 + config.slope, 1e-9),
      );
      // Degenerate span (full time == open minute) must not divide by 0.
      expect(
        lateGameOpenFactor(90, config.openStartMinute, config),
        closeTo(1 + config.slope, 1e-9),
      );
    });

    test('knob moves the escalation (sweep seam)', () {
      const steep = LateGameOpenConfig(slope: 0.90);
      expect(
        lateGameOpenFactor(90, 94, steep),
        greaterThan(lateGameOpenFactor(90, 94, config)),
      );
    });
  });

  group('determinism under different starting stamina (T-0052)', () {
    test('same seed, stamina 100 vs 40, empty bench: byte-identical streams', () {
      final fresh = _engine(2026, homeStamina: 100, awayStamina: 100);
      final tired = _engine(2026, homeStamina: 40, awayStamina: 40);
      final a = fresh.simulateToEnd().map(_dump).toList();
      final b = tired.simulateToEnd().map(_dump).toList();
      expect(a, isNotEmpty);
      expect(b, a, reason: 'event streams must be byte-identical');
      expect(fresh.state.scoreHome, tired.state.scoreHome);
      expect(fresh.state.scoreAway, tired.state.scoreAway);
    });
  });
}
