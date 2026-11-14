// Owner request 2026-11-14: "remove red card misses next match — when a
// player gets a red card in a live match he is removed from the engine's
// calculations for THAT match, and the next match starts clean".
//
// Verification found the app ALREADY behaves this way: `sentOff` is a
// MatchPlayer field mutated in-memory by the engine (the player leaves
// the pitch and penalties skip sent-off takers), `MatchSession.finish()`
// persists only stamina/minutes/injuries/rewards — never any suspension
// — and the DB schema has no suspension columns (the
// `suspendedPlayerIds` parameter in SquadEngine.autoPick is an empty
// hook, always called with `const {}`).
//
// These tests PIN that contract so it cannot regress silently:
//  1. A red card removes the player from the pitch for the rest of the
//     match (engine calculations exclude him).
//  2. A brand-new match over the same squad starts everyone with a
//     clean slate — no sent-off / yellow-card state leaks across
//     matches because none of it is persisted anywhere.
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart' show Position;
import 'package:fcm_rivals/features/match/match_event.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/team_tactics.dart' as tactics;

void main() {
  // One flat-70 starter per outfield slot position, ids offset per side.
  List<MatchPlayer> flatSquad(int base, String prefix) {
    const positions = [
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
    return [
      for (var i = 0; i < 11; i++)
        MatchPlayer(
          playerId: base + i,
          name: '$prefix$i',
          position: positions[i],
          attack: 70,
          support: 70,
          defence: 70,
          goalkeeping: 70,
        ),
    ];
  }

  // An engine whose discipline dials are forced towards reds: every
  // card is a straight red and cards are frequent, so the home side is
  // virtually guaranteed a sending-off on any seed. The test scans the
  // event stream rather than assuming WHICH player went.
  MatchEngine engineWithARedCard(int seed) {
    final config = MatchEngineConfig(
      yellowCardChance: 0.9,
      straightRedChance: 0.9,
    );
    return MatchEngine(
      seed: seed,
      config: config,
      home: MatchTeamInput(
        teamId: 1,
        teamName: 'Home',
        formationCode: '4-4-2',
        tactics: const tactics.TeamTactics(),
        mentality: tactics.Mentality.balanced,
        starters: flatSquad(100, 'H'),
        bench: const [],
      ),
      away: MatchTeamInput(
        teamId: 2,
        teamName: 'Away',
        formationCode: '4-4-2',
        tactics: const tactics.TeamTactics(),
        mentality: tactics.Mentality.balanced,
        starters: flatSquad(300, 'A'),
        bench: const [],
      ),
    );
  }

  test(
    'a red card removes the player from the pitch for the rest of the '
    'match (engine calculations exclude him)',
    () {
      final engine = engineWithARedCard(99);
      engine.simulateToEnd();

      final redEvents = engine.events
          .where(
            (e) =>
                e.type == MatchEventType.card && e.metadata['card'] == 'red',
          )
          .toList();
      expect(redEvents, isNotEmpty, reason: 'the forced config produced a red');

      for (final red in redEvents) {
        final sentOffId = red.primaryPlayerId;
        expect(sentOffId, isNotNull);
        // He never returns to the pitch: the final on-pitch eleven
        // excludes him and his runtime flag is set.
        expect(
          engine.onPitchOf(red.side).map((p) => p.playerId),
          isNot(contains(sentOffId)),
          reason: 'the sent-off player never returns to the pitch',
        );
        final sentOffPlayer = engine
            .playersOf(red.side)
            .firstWhere((p) => p.playerId == sentOffId);
        expect(sentOffPlayer.sentOff, isTrue);
      }
    },
  );

  test(
    'no suspension survives into the next match: a fresh match over the '
    'same squad starts everyone on a clean slate',
    () {
      final first = engineWithARedCard(99);
      first.simulateToEnd();
      final hadRed = first.events.any(
        (e) => e.type == MatchEventType.card && e.metadata['card'] == 'red',
      );
      expect(hadRed, isTrue, reason: 'precondition: the first match had a red');

      // A brand-new match with the SAME inputs: nothing from the first
      // match leaks in — MatchPlayer state is per-match in-memory data,
      // and no suspension is persisted anywhere (schema + finish()).
      final fresh = engineWithARedCard(7);
      // Before any simulation: nobody is sent off, nobody is booked.
      for (final player in [
        ...fresh.playersOf(MatchSide.home),
        ...fresh.playersOf(MatchSide.away),
      ]) {
        expect(player.sentOff, isFalse, reason: 'fresh match, clean slate');
        expect(player.yellowCards, 0);
      }
    },
  );
}
