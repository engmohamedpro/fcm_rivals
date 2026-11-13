// Squad drag-and-drop rules (Team tab): any two players can swap across
// the formation, the bench and the reserves — the ONLY restriction is
// that a player landing in a STARTING slot must have that slot's
// position. Pure Dart, no widgets.
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_swap.dart';

PlayerCard _card(int id, Position position) => PlayerCard(
  ownedId: id,
  upgradeLevel: 0,
  base: BasePlayer(
    playerId: 1000 + id,
    name: 'First Surn$id',
    position: position,
    nationality: 'Egypt',
    marketValueEur: 5_000_000,
    baseStats: const BaseStats(
      overall: 80,
      attack: 82,
      support: 75,
      defence: 40,
      goalkeeping: 0,
    ),
  ),
);

final _f433 = formationByCode('4-3-3');

/// A full 23-man squad for the 4-3-3: the XI in slot order (ids 0..10, each
/// in its own slot's position), bench ids 11..17 (a mix of positions), and
/// reserves ids 18..22.
Map<int, PlayerCard> _squad() {
  final squad = <int, PlayerCard>{};
  for (var i = 0; i < 11; i++) {
    squad[i] = _card(i, _f433.slots[i].position);
  }
  const benchPositions = [
    Position.gk,
    Position.cb,
    Position.lb,
    Position.cm,
    Position.st,
    Position.rw,
    Position.cdm,
  ];
  for (var i = 0; i < 7; i++) {
    squad[11 + i] = _card(11 + i, benchPositions[i]);
  }
  const reservePositions = [
    Position.st,
    Position.cam,
    Position.rb,
    Position.lw,
    Position.cb,
  ];
  for (var i = 0; i < 5; i++) {
    squad[18 + i] = _card(18 + i, reservePositions[i]);
  }
  return squad;
}

void main() {
  group('swapSquadSlots', () {
    test('bench player swaps with a starter of the SAME position', () {
      // Slot 9 is the ST; bench slot 15 (id 15) is a ST.
      final squad = _squad();
      final out = swapSquadSlots(
        formation: _f433,
        squad: squad,
        fromSlot: 15,
        toSlot: 9,
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 15, reason: 'the bench ST starts');
      expect(out.assignment![15], 9, reason: 'the starter takes his place');
      expect(
        out.assignment!.length,
        squad.length,
        reason: 'nobody lost, nobody duplicated',
      );
      expect(out.assignment!.values.toSet().length, squad.length);
    });

    test('dragging a starter onto a bench player works the same way', () {
      final out = swapSquadSlots(
        formation: _f433,
        squad: _squad(),
        fromSlot: 9,
        toSlot: 15,
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 15);
      expect(out.assignment![15], 9);
    });

    test('a bench player of ANOTHER position may take a starting slot '
        '(custom formations: outfield is free)', () {
      // Bench slot 12 is a CB; slot 9 wants a ST. Out-of-position
      // placement is a manager's choice now — only the keeper's slot
      // is protected (owner request 2026-11-12).
      final out = swapSquadSlots(
        formation: _f433,
        squad: _squad(),
        fromSlot: 12,
        toSlot: 9,
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 12, reason: 'the CB stands up front');
      expect(out.assignment![12], 9);
    });

    test('the same freedom applies when dragging the starter out', () {
      // Dragging the XI ST (9) onto the bench CB: the ST takes the
      // bench place, the CB comes in — both out of position, both
      // allowed (the pitch shows the warn marks).
      final out = swapSquadSlots(
        formation: _f433,
        squad: _squad(),
        fromSlot: 9,
        toSlot: 12,
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
    });

    test('bench ↔ reserves swap freely whatever the positions', () {
      final squad = _squad();
      // Bench GK (11) with reserve LW (21).
      final out = swapSquadSlots(
        formation: _f433,
        squad: squad,
        fromSlot: 11,
        toSlot: 21,
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![21], 11);
      expect(out.assignment![11], 21);
    });

    test('two starters swap only when both fit each other\'s slot', () {
      // The two CB slots (2 and 3) are interchangeable…
      final cbs = swapSquadSlots(
        formation: _f433,
        squad: _squad(),
        fromSlot: 2,
        toSlot: 3,
      );
      expect(cbs.isAccepted, isTrue, reason: cbs.rejection);
      expect(cbs.assignment![2], 3);
      expect(cbs.assignment![3], 2);
      // …the two CM slots (6 and 7) too…
      expect(
        swapSquadSlots(
          formation: _f433,
          squad: _squad(),
          fromSlot: 6,
          toSlot: 7,
        ).isAccepted,
        isTrue,
      );
      // …and LB (1) ↔ RB (4) swap too now: out-of-position placement
      // is a manager's choice (custom formations, 2026-11-12) — the
      // pitch shows the warn marks, the engine applies its factor.
      final backs = swapSquadSlots(
        formation: _f433,
        squad: _squad(),
        fromSlot: 1,
        toSlot: 4,
      );
      expect(backs.isAccepted, isTrue, reason: backs.rejection);
    });

    test(
      'a goalkeeper only goes in goal and only a keeper takes his place',
      () {
        final squad = _squad();
        // Bench GK (11) ↔ XI GK (0): fine.
        expect(
          swapSquadSlots(
            formation: _f433,
            squad: squad,
            fromSlot: 11,
            toSlot: 0,
          ).isAccepted,
          isTrue,
        );
        // Bench CM (14) onto the keeper: refused.
        expect(
          swapSquadSlots(
            formation: _f433,
            squad: squad,
            fromSlot: 14,
            toSlot: 0,
          ).isAccepted,
          isFalse,
        );
      },
    );

    test('a starter can be dropped on an empty bench place, leaving his '
        'slot empty', () {
      final squad = _squad()..remove(17); // an empty bench slot
      final out = swapSquadSlots(
        formation: _f433,
        squad: squad,
        fromSlot: 9,
        toSlot: 17,
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![17], squad[9]!.ownedId);
      expect(
        out.assignment!.containsKey(9),
        isFalse,
        reason: 'the XI may have a hole until kick-off',
      );
    });

    test('a bench player moves into an empty reserves place', () {
      final squad = _squad()..remove(22);
      final out = swapSquadSlots(
        formation: _f433,
        squad: squad,
        fromSlot: 13,
        toSlot: 22,
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![22], 13);
      expect(
        out.assignment!.containsKey(13),
        isFalse,
        reason: 'his old place is now empty',
      );
    });

    test('an empty starting slot takes any outfielder (custom rules)', () {
      final squad = _squad()..remove(9); // ST slot empty
      // Bench ST (15) fills it…
      expect(
        swapSquadSlots(
          formation: _f433,
          squad: squad,
          fromSlot: 15,
          toSlot: 9,
        ).isAccepted,
        isTrue,
      );
      // …and a bench CB (12) may too — out-of-position placement is
      // allowed since the custom-formation rules (2026-11-12).
      expect(
        swapSquadSlots(
          formation: _f433,
          squad: squad,
          fromSlot: 12,
          toSlot: 9,
        ).isAccepted,
        isTrue,
      );
    });

    test('nonsense moves are refused', () {
      final squad = _squad();
      expect(
        swapSquadSlots(
          formation: _f433,
          squad: squad,
          fromSlot: 9,
          toSlot: 9,
        ).isAccepted,
        isFalse,
      );
      expect(
        swapSquadSlots(
          formation: _f433,
          squad: squad,
          fromSlot: 9,
          toSlot: 40,
        ).isAccepted,
        isFalse,
      );
      expect(
        swapSquadSlots(
          formation: _f433,
          squad: squad..remove(20),
          fromSlot: 20,
          toSlot: 11,
        ).isAccepted,
        isFalse,
        reason: 'nobody in the source slot',
      );
    });

    test('the input squad is never mutated', () {
      final squad = _squad();
      final before = {for (final e in squad.entries) e.key: e.value.ownedId};
      swapSquadSlots(formation: _f433, squad: squad, fromSlot: 15, toSlot: 9);
      expect({for (final e in squad.entries) e.key: e.value.ownedId}, before);
    });
  });

  group('planSquadDrop', () {
    test('resolves a player target to his slot', () {
      final squad = _squad();
      final out = planSquadDrop(
        formation: _f433,
        squad: squad,
        dragged: squad[15]!,
        target: SquadDropTarget.player(squad[9]!),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 15);
    });

    test('resolves an empty zone to its first free place', () {
      final squad = _squad()
        ..remove(13)
        ..remove(15);
      // A pool player (id 19 sits in a legacy reserve slot) onto the
      // bench zone takes the first free bench place.
      final out = planSquadDrop(
        formation: _f433,
        squad: squad,
        dragged: squad[19]!,
        target: const SquadDropTarget.emptyIn(SquadZone.bench),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![13], 19, reason: 'first free bench place');
    });

    test('an empty xi slot target is used as is', () {
      final squad = _squad()..remove(9);
      final out = planSquadDrop(
        formation: _f433,
        squad: squad,
        dragged: squad[15]!,
        target: const SquadDropTarget.xiSlot(9),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 15);
    });

    test('a full bench has no free place for a pool player', () {
      final squad = _squad();
      final out = planSquadDrop(
        formation: _f433,
        squad: squad,
        dragged: squad[19]!,
        target: const SquadDropTarget.emptyIn(SquadZone.bench),
      );
      expect(out.isAccepted, isFalse);
    });

    group('the all-players pool', () {
      test('a pool player replaces a starter of his position; the starter '
          'goes back to the pool', () {
        final squad = _squad();
        final out = planSquadDrop(
          formation: _f433,
          squad: squad,
          dragged: _card(99, Position.st),
          target: SquadDropTarget.player(squad[9]!),
        );
        expect(out.isAccepted, isTrue, reason: out.rejection);
        expect(out.assignment![9], 99);
        expect(out.assignment!.values, isNot(contains(9)));
      });

      test('a pool player of ANOTHER position may take a starting slot '
          '(outfield is free)', () {
        final squad = _squad();
        final out = planSquadDrop(
          formation: _f433,
          squad: squad,
          dragged: _card(99, Position.cb),
          target: SquadDropTarget.player(squad[9]!),
        );
        expect(out.isAccepted, isTrue, reason: out.rejection);
        expect(out.assignment![9], 99);
      });

      test('a pool player takes a bench place whatever his position', () {
        final squad = _squad();
        final out = planSquadDrop(
          formation: _f433,
          squad: squad,
          dragged: _card(99, Position.cb),
          target: SquadDropTarget.player(squad[15]!),
        );
        expect(out.isAccepted, isTrue, reason: out.rejection);
        expect(out.assignment![15], 99);
      });

      test('dropping a bench player on the pool takes him out of the '
          'squad', () {
        final squad = _squad();
        final out = planSquadDrop(
          formation: _f433,
          squad: squad,
          dragged: squad[15]!,
          target: const SquadDropTarget.emptyIn(SquadZone.reserves),
        );
        expect(out.isAccepted, isTrue, reason: out.rejection);
        expect(out.assignment!.containsKey(15), isFalse);
        expect(out.assignment!.values, isNot(contains(15)));
      });

      test('a starter can be dropped on a pool card of his position', () {
        final squad = _squad();
        final pool = _card(99, Position.st);
        final out = planSquadDrop(
          formation: _f433,
          squad: squad,
          dragged: squad[9]!,
          target: SquadDropTarget.player(pool),
        );
        expect(out.isAccepted, isTrue, reason: out.rejection);
        expect(out.assignment![9], 99);
      });

      test('the legacy reserve slots are dropped from the saved squad', () {
        final squad = _squad();
        final out = planSquadDrop(
          formation: _f433,
          squad: squad,
          dragged: squad[19]!,
          target: SquadDropTarget.player(squad[15]!),
        );
        expect(out.isAccepted, isTrue, reason: out.rejection);
        expect(out.assignment!.keys.every((k) => k < 18), isTrue);
      });

      test('a pool player dropped on a pool card is refused', () {
        final squad = _squad();
        final out = planSquadDrop(
          formation: _f433,
          squad: squad,
          dragged: _card(98, Position.st),
          target: SquadDropTarget.player(_card(99, Position.st)),
        );
        expect(out.isAccepted, isFalse);
      });
    });
  });

  test('zones cover the 23-man squad exactly', () {
    expect(SquadZone.xi.slots.length, Formation.startingXiSize);
    expect(SquadZone.bench.slots.length, Formation.benchSize);
    expect(SquadZone.reserves.slots.length, Formation.reservesSize);
    final all = [
      ...SquadZone.xi.slots,
      ...SquadZone.bench.slots,
      ...SquadZone.reserves.slots,
    ];
    expect(all, List<int>.generate(Formation.squadSize, (i) => i));
    for (final slot in all) {
      expect(SquadZone.ofSlot(slot).slots, contains(slot));
    }
  });
}
