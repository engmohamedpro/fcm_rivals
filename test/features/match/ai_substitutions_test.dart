// AI substitutions (review 2026-11-04_match-engine_ai-substitutions).
//
// The old 40/30 stamina gates never intersected the real drain curve
// (starters finish near 70), so AI subs were dead code — 0.0/match.
// The gates now sit at 76 (from 65') and 70 (from 80'), spaced ≥ 12
// minutes apart, plus a chasing-game attacker swap after 70'. These
// tests lock the measured behaviour so the code cannot die silently
// again: average volume, the hard cap, report reflection, minute
// accounting for subbed-off players, the empty-bench guard and seed
// determinism.
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

// A realistic 5-man bench: cover keeper, full-back, centre-back, holder
// and an attacker — the chasing swap needs someone to throw on.
const _benchPositions = [
  Position.gk,
  Position.rb,
  Position.cb,
  Position.cdm,
  Position.st,
];

List<MatchPlayer> makeTeam(
  int base,
  String name, {
  required int value,
  required List<Position> positions,
}) {
  final gen = const BaseStatsGenerator();
  return [
    for (var i = 0; i < positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$name $i',
        position: positions[i],
        attack: gen.generate(positions[i], value).attack,
        support: gen.generate(positions[i], value).support,
        defence: gen.generate(positions[i], value).defence,
        goalkeeping: gen.generate(positions[i], value).goalkeeping,
      ),
  ];
}

MatchEngine engineWithBench(int seed) => MatchEngine(
  seed: seed,
  home: MatchTeamInput(
    teamId: 1,
    teamName: 'Home',
    formationCode: '4-4-2',
    style: PlayingStyle.balanced,
    mentality: Mentality.balanced,
    starters: makeTeam(100, 'Home', value: 20_000_000, positions: _positions),
    bench: makeTeam(
      200,
      'HomeBench',
      value: 20_000_000,
      positions: _benchPositions,
    ),
    aiControlled: true,
  ),
  away: MatchTeamInput(
    teamId: 2,
    teamName: 'Away',
    formationCode: '4-3-3',
    style: PlayingStyle.balanced,
    mentality: Mentality.balanced,
    starters: makeTeam(300, 'Away', value: 20_000_000, positions: _positions),
    bench: makeTeam(
      400,
      'AwayBench',
      value: 20_000_000,
      positions: _benchPositions,
    ),
    aiControlled: true,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AI substitutions fire at a realistic volume and never exceed the cap',
    () {
      const matches = 500;
      var totalSubs = 0;
      var maxOneTeam = 0;
      var chaseSubs = 0;
      for (var m = 0; m < matches; m++) {
        final eng = engineWithBench(m);
        eng.simulateToEnd();
        for (final side in MatchSide.values) {
          final used = eng.substitutionsUsedOf(side);
          totalSubs += used;
          if (used > maxOneTeam) maxOneTeam = used;
        }
        chaseSubs += eng.events
            .where(
              (e) =>
                  e.type == MatchEventType.substitution &&
                  e.metadata['reason'] == 'chasing',
            )
            .length;
      }
      final perTeam = totalSubs / (matches * 2);
      expect(perTeam, greaterThan(2.0), reason: 'AI subs must actually fire');
      expect(perTeam, lessThan(4.0), reason: 'AI must not sub like basketball');
      expect(maxOneTeam, lessThanOrEqualTo(5), reason: '5-sub cap (FR-023)');
      expect(chaseSubs, greaterThan(0), reason: 'chasing swap must be live');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'substitutions are reflected in the report and minute accounting stops '
    'for subbed-off players',
    () {
      // Scan seeds until a match with at least two subs (the volume test
      // shows nearly every match qualifies).
      late MatchEngine eng;
      for (var seed = 0;; seed++) {
        eng = engineWithBench(seed);
        eng.simulateToEnd();
        if (eng.substitutionsUsedOf(MatchSide.home) +
                eng.substitutionsUsedOf(MatchSide.away) >=
            2) {
          break;
        }
      }

      final subEvents = eng.events
          .where((e) => e.type == MatchEventType.substitution)
          .toList();
      expect(subEvents, isNotEmpty);

      // Every subbed-on player appears in the final squad the report is
      // built from (playersOf covers on-pitch, bench and off-pitch).
      final squadBySide = {
        for (final side in MatchSide.values)
          side: eng.playersOf(side).map((p) => p.playerId).toSet(),
      };
      for (final e in subEvents) {
        expect(e.secondaryPlayerId, isNotNull);
        expect(
          squadBySide[e.side]!.contains(e.secondaryPlayerId),
          isTrue,
          reason: 'subbed-on player must be in the final squad list',
        );
      }

      // Subbed-off players stop accruing minutes the moment they leave:
      // anyone who never appeared in a substitution event (never on the
      // "out" side AND never on the "in" side) and stayed on the pitch
      // played the full match; the men who came off must have fewer
      // minutes than that.
      final subbedOff = {
        for (final e in subEvents) e.primaryPlayerId!,
      };
      final subbedOn = {
        for (final e in subEvents)
          if (e.secondaryPlayerId != null) e.secondaryPlayerId!,
      };
      final allPlayers = [
        ...eng.playersOf(MatchSide.home),
        ...eng.playersOf(MatchSide.away),
      ];
      final untouchedStarters = allPlayers
          .where(
            (p) =>
                !subbedOff.contains(p.playerId) &&
                !subbedOn.contains(p.playerId) &&
                p.position != Position.gk &&
                p.minutesPlayed > 60,
          )
          .map((p) => p.minutesPlayed)
          .toList();
      expect(untouchedStarters, isNotEmpty);
      final fullMatchMinutes = untouchedStarters.reduce(
        (a, b) => a > b ? a : b,
      );
      for (final p in allPlayers) {
        if (!subbedOff.contains(p.playerId)) continue;
        expect(
          p.minutesPlayed,
          lessThan(fullMatchMinutes),
          reason: '${p.name} came off and must stop accruing minutes',
        );
      }

      // The commentary (the match report's narrative) carries the swaps.
      final names = {
        for (final p in allPlayers) p.playerId: p.name,
      };
      final lines = generateCommentary(
        eng.events,
        playerNames: names,
        homeTeamName: 'Home',
        awayTeamName: 'Away',
      );
      expect(
        lines.where((l) => l.text.contains('Substitution for')).length,
        subEvents.length,
        reason: 'every substitution must produce a commentary line',
      );
    },
  );

  test('an empty bench is safe: no substitutions, match completes', () {
    final eng = MatchEngine(
      seed: 42,
      home: MatchTeamInput(
        teamId: 1,
        teamName: 'Home',
        formationCode: '4-4-2',
        style: PlayingStyle.balanced,
        mentality: Mentality.balanced,
        starters: makeTeam(100, 'Home', value: 20_000_000, positions: _positions),
        bench: const [],
        aiControlled: true,
      ),
      away: MatchTeamInput(
        teamId: 2,
        teamName: 'Away',
        formationCode: '4-3-3',
        style: PlayingStyle.balanced,
        mentality: Mentality.balanced,
        starters: makeTeam(300, 'Away', value: 20_000_000, positions: _positions),
        bench: const [],
        aiControlled: true,
      ),
    );
    eng.simulateToEnd();
    expect(eng.isFinished, isTrue);
    expect(eng.substitutionsUsedOf(MatchSide.home), 0);
    expect(eng.substitutionsUsedOf(MatchSide.away), 0);
    expect(
      eng.events.where((e) => e.type == MatchEventType.substitution),
      isEmpty,
    );
  });

  test('substitution behaviour is deterministic for a given seed', () {
    int subsOf(int seed) {
      final eng = engineWithBench(seed);
      eng.simulateToEnd();
      return eng.substitutionsUsedOf(MatchSide.home) +
          eng.substitutionsUsedOf(MatchSide.away);
    }

    for (final seed in [7, 123, 2024]) {
      expect(subsOf(seed), subsOf(seed), reason: 'seed $seed must repeat');
    }
  });
}
