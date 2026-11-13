// Custom formations (owner request 2026-11-12): the drag-built shapes.
//
// The owner's exact ladder is the law (2026-11-13 update):
//   GK exactly 1 (the keeper's slot never changes)
//   ST 0-2, LW 0-1, RW 0-1, CAM 0-2,
//   CM 0-3, CDM 0-3, CB 2-3 (a back line needs its pair), RB 0-1,
//   LB 0-1 (LM/RM 0-1 each — the dataset carries them)
//
// A custom formation serialises as 'C|GK,LB,CB,…'; formationOfCode
// decodes it, so the match engine and every consumer see it as just
// another formation. Pure Dart, no widgets.
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart'
    show PlayerCard, SquadEngine;
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

/// A legal custom XI: 2 ST, 1 LW, 1 RW, 1 CAM, 2 CM, 1 CDM, 2 CB, 1 LB,
/// 1 RB, 1 GK — every cap respected (a 4-1-2-1-2-ish strike-pair shape).
const _legalMix = [
  Position.gk,
  Position.lb, Position.cb, Position.cb, Position.rb,
  Position.cdm, Position.cm, Position.cm,
  Position.lw, Position.cam, Position.rw,
  Position.st, Position.st, // <- 13 entries: caught by the length check
];

void main() {
  group('positionCaps (the owner\'s ladder)', () {
    test('the caps are exactly the owner\'s stated ladder', () {
      expect(positionCaps[Position.gk], (1, 1));
      expect(positionCaps[Position.st], (0, 2));
      expect(positionCaps[Position.lw], (0, 1));
      expect(positionCaps[Position.rw], (0, 1));
      expect(positionCaps[Position.cam], (0, 2));
      expect(positionCaps[Position.cm], (0, 3));
      expect(positionCaps[Position.cdm], (0, 3));
      expect(positionCaps[Position.cb], (2, 3));
      expect(positionCaps[Position.rb], (0, 1));
      expect(positionCaps[Position.lb], (0, 1));
      // LM/RM: 0-1 each (the dataset carries 393 LM / 457 RM).
      expect(positionCaps[Position.lm], (0, 1));
      expect(positionCaps[Position.rm], (0, 1));
    });
  });

  group('customFormation builder', () {
    test('builds a legal custom mix and serialises round-trip', () {
      final f = customFormation(_legalMix.sublist(0, 11));
      expect(f, isNotNull);
      expect(f!.isValid, isTrue, reason: '11 slots, GK first');
      expect(isCustomFormationCode(f.code), isTrue);
      // Round-trip: the code decodes back to the same positions.
      final decoded = formationOfCode(f.code);
      expect(decoded.code, f.code);
      for (var i = 0; i < 11; i++) {
        expect(decoded.slots[i].position, _legalMix[i],
            reason: 'slot $i keeps its position through the round-trip');
      }
    });

    test('a legal mix with zero ST, zero LW, zero RW (0-3-4-3 shape)', () {
      // GK + 3 CB + 1 LB + 1 RB + 3 CM + 1 CDM + 1 CAM + 1 ST — no
      // wingers at all, all caps respected.
      const mix = [
        Position.gk,
        Position.cb, Position.cb, Position.cb,
        Position.lb, Position.rb,
        Position.cm, Position.cm, Position.cm,
        Position.cdm, Position.cam,
        // 11 so far — one more CM would hit the cap; a ST closes it.
        Position.st,
      ];
      // 12 entries — trim to 11 by dropping the spare.
      final f = customFormation(mix.sublist(0, 11));
      expect(f, isNotNull);
      expect(customFormationProblem(mix.sublist(0, 11)), isNull);
    });

    test('refuses a third striker', () {
      // 11 slots: 3 ST (over the cap of 2) and 3 CB (legal — the
      // refusal must name the ST excess, not anything else).
      final threeStrikers = [
        Position.gk,
        Position.cb, Position.cb, Position.cb,
        Position.cm, Position.cm, Position.cm,
        Position.cdm,
        Position.st, Position.st, Position.st,
      ];
      expect(customFormation(threeStrikers), isNull);
      expect(customFormationProblem(threeStrikers), contains('ST'));
    });

    test('a single CB is refused (the back line needs its pair)', () {
      const oneCb = [
        Position.gk,
        Position.cb,
        Position.lb, Position.rb,
        Position.cm, Position.cm, Position.cm, Position.cdm,
        Position.cam, Position.st, Position.st,
      ];
      expect(customFormation(oneCb), isNull);
      expect(customFormationProblem(oneCb), contains('CB'));
    });

    test('a back line with NO centre back is refused (min 2 holds for an '
        'absent position too)', () {
      const noCb = [
        Position.gk,
        Position.lb, Position.rb,
        Position.cm, Position.cm, Position.cm,
        Position.cdm, Position.cdm, Position.cdm,
        Position.st, Position.st,
      ];
      expect(customFormation(noCb), isNull);
      expect(customFormationProblem(noCb), contains('CB'));
    });

    test('refuses 4 CB and 2 LW', () {
      const fourCb = [
        Position.gk,
        Position.cb, Position.cb, Position.cb, Position.cb,
        Position.lb, Position.rb,
        Position.cm, Position.cm, Position.cdm,
        Position.cam,
      ];
      expect(customFormation(fourCb), isNull);
      expect(customFormationProblem(fourCb), contains('CB'));

      const twoLw = [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm, Position.cm,
        Position.lw, Position.lw, Position.st,
      ];
      expect(customFormation(twoLw), isNull);
      expect(customFormationProblem(twoLw), contains('LW'));
    });

    test('refuses a missing keeper and a misplaced keeper', () {
      const noKeeper = [
        Position.cb, Position.cb, Position.cb, Position.cb, Position.cb,
        Position.cm, Position.cm, Position.cdm,
        Position.lw, Position.rw, Position.st,
      ];
      expect(customFormation(noKeeper), isNull);

      const keeperNotFirst = [
        Position.cb, Position.gk, Position.cb, Position.cb,
        Position.lb, Position.rb,
        Position.cm, Position.cm, Position.cdm,
        Position.st, Position.st,
      ];
      expect(customFormation(keeperNotFirst), isNull);
      expect(customFormationProblem(keeperNotFirst), contains('GK'));
    });

    test('three ST exactly is refused (cap is 2)', () {
      const threeSt = [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm, Position.cm, Position.cam,
        Position.st, Position.st, // 11 — but add another: build 12.
      ];
      // Explicit: 11 slots, 3 ST, only 2 CB.
      const actual = [
        Position.gk,
        Position.cb, Position.cb,
        Position.lb, Position.rb,
        Position.cdm, Position.cm, Position.cm,
        Position.st, Position.st, Position.st,
      ];
      expect(customFormation(actual), isNull);
      expect(customFormationProblem(actual), contains('ST'));
      expect(threeSt.length, 11);
    });

    test('three CAM is refused (cap is 2)', () {
      const mix = [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm,
        Position.cam, Position.cam, Position.cam,
        Position.st,
      ];
      expect(customFormation(mix), isNull);
      expect(customFormationProblem(mix), contains('CAM'));
    });

    test('three CDM is legal (cap is 3)', () {
      const mix = [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cdm, Position.cdm,
        Position.lw, Position.cam, Position.st,
      ];
      expect(customFormation(mix), isNotNull);
      expect(customFormationProblem(mix), isNull);
    });

    test('LM and RM may field one each', () {
      const mix = [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm, Position.cm,
        Position.lm, Position.rm, Position.st,
      ];
      expect(customFormation(mix), isNotNull);
      // Two LM would be refused.
      final twoLm = [...mix];
      twoLm[9] = Position.lm; // second LM — now 2 LM
      expect(customFormation(twoLm), isNull);
    });

    test('the anchors spread same-position slots symmetrically', () {
      // Two CBs: first left (28), second right (72) — the pair reads
      // centred, exactly like a preset back-three's outer men.
      final f = customFormation(const [
        Position.gk,
        Position.st, Position.st, // forwards first — slots can be anywhere
        Position.cb, Position.cb, // the CB pair
        Position.lb, Position.rb,
        Position.cdm, Position.cm, Position.cam,
        Position.rw,
      ])!;
      expect(f.slots[3].x, lessThan(f.slots[4].x),
          reason: 'first CB left of second CB');
      expect(50 - f.slots[3].x, closeTo(f.slots[4].x - 50, 0.01),
          reason: 'the pair is symmetric about the centre');
      // The keeper always at home depth.
      expect(f.slots[0].y, 5);
      expect(f.slots[0].x, 50);
    });

    test('a LONE slot of a position centres; a strike pair halves '
        '(owner request 2026-11-13)', () {
      // One striker: dead centre (50). A lone CAM: dead centre too.
      final lone = customFormation(const [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm, Position.cm,
        Position.lw, Position.cam, Position.st,
      ])!;
      final st = lone.slots.last;
      expect(st.x, 50, reason: 'a lone striker stands dead centre');
      expect(lone.slots[9].x, 50, reason: 'a lone CAM stands dead centre');

      // Two strikers: 40 and 60, beside each other, centred as a pair.
      final pair = customFormation(const [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm, Position.cm, Position.cam,
        Position.st, Position.st,
      ])!;
      expect(pair.slots[9].x, 40);
      expect(pair.slots[10].x, 60);

      // Three CMs: 22 / 50 / 78 — a left-centre-right line.
      final trio = customFormation(const [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cm, Position.cm, Position.cm, Position.cdm,
        Position.lw, Position.st,
      ])!;
      expect(trio.slots[5].x, 22);
      expect(trio.slots[6].x, 50);
      expect(trio.slots[7].x, 78);
    });

    test('every custom slot keeps the GK-first, x/y bounds contract', () {
      final f = customFormation(_legalMix.sublist(0, 11))!;
      for (final slot in f.slots) {
        expect(slot.x, inInclusiveRange(0, 100));
        expect(slot.y, inInclusiveRange(0, 100));
      }
    });
  });

  group('formationOfCode', () {
    test('decodes a custom code; presets unchanged; junk falls back', () {
      final custom = customFormation(_legalMix.sublist(0, 11))!;
      expect(formationOfCode(custom.code).code, custom.code);
      expect(formationOfCode('4-3-3').code, '4-3-3');
      // Malformed custom codes fall back to the default shape.
      expect(formationOfCode('C|GK').code, '4-3-3');
      expect(formationOfCode('C|XX,GK,CB,CB,CB,CB,CM,CM,CM,CDM,CAM').code,
          '4-3-3');
    });
  });

  group('planSquadDrop builds custom formations', () {
    test('dropping a pool player on an empty slot redefines it', () {
      // 4-3-3 with the LW slot (8) empty. Dropping a ST there turns
      // the slot into a ST slot: the mix becomes 2 ST, 0 LW — legal.
      final squad = {
        for (var i = 0; i < 11; i++)
          if (i != 8) i: _card(i, _f433Positions[i]),
        11: _card(11, Position.gk),
      };
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: _card(99, Position.st),
        target: const SquadDropTarget.xiSlot(8),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![8], 99);
      expect(out.formation, isNotNull,
          reason: 'the drop carries the new formation');
      expect(out.formation!.slots[8].position, Position.st,
          reason: 'slot 8 now asks for a ST');
      expect(isCustomFormationCode(out.formation!.code), isTrue);
    });

    test('redefining past a cap is refused with the reason', () {
      // 4-3-3: slots 1 (LB), 2 (CB), 3 (CB), 4 (RB) — dropping a third
      // CB on the empty LB slot would make 3 CB + 0 LB: LEGAL. So use
      // a shape already at 3 CB: make slots 1..3 all CB first.
      final custom = customFormation(const [
        Position.gk,
        Position.cb, Position.cb, Position.cb, // back three
        Position.rb,
        Position.cdm, Position.cm, Position.cm,
        Position.lw, Position.cam, Position.rw,
        // 11 — one short: the LW slot stands empty below.
      ])!;
      final squad = {
        for (var i = 0; i < 11; i++)
          if (i != 8) i: _card(i, custom.slots[i].position),
      };
      // Dropping a CB on the empty LW slot (8): 4 CB — over the cap.
      final out = planSquadDrop(
        formation: custom,
        squad: squad,
        dragged: _card(99, Position.cb),
        target: const SquadDropTarget.xiSlot(8),
      );
      expect(out.isAccepted, isFalse);
      expect(out.rejection, contains('CB'));
      expect(out.formation, isNull);
    });

    test('the GK slot can never be redefined', () {
      final squad = {
        for (var i = 1; i < 11; i++) i: _card(i, _f433Positions[i]),
      };
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: _card(99, Position.st),
        target: const SquadDropTarget.xiSlot(0),
      );
      expect(out.isAccepted, isFalse);
      expect(out.rejection, contains('goalkeeper'));
    });

    test('a keeper dropped on an empty outfield slot is refused', () {
      final squad = {
        for (var i = 0; i < 11; i++)
          if (i != 8) i: _card(i, _f433Positions[i]),
      };
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: _card(99, Position.gk),
        target: const SquadDropTarget.xiSlot(8),
      );
      expect(out.isAccepted, isFalse);
      // A keeper in an outfield slot would break the exactly-1-GK law.
      expect(customFormationProblem(const [
        Position.gk, Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm, Position.cm,
        Position.gk, // the redefined slot — a second GK
        Position.st, Position.rw,
      ]), isNotNull);
    });

    test('a bench player dropped on an empty slot redefines it too, and '
        'frees his bench place', () {
      final squad = {
        for (var i = 0; i < 11; i++)
          if (i != 8) i: _card(i, _f433Positions[i]),
        11: _card(11, Position.cm),
        12: _card(12, Position.st),
      };
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[12]!,
        target: const SquadDropTarget.xiSlot(8),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![8], 12, reason: 'the bench ST takes the slot');
      expect(out.assignment!.containsKey(12), isFalse,
          reason: 'his bench place is freed');
      expect(out.formation!.slots[8].position, Position.st);
    });

    test('an injured player cannot be dropped on an empty XI slot', () {
      final squad = {
        for (var i = 0; i < 11; i++)
          if (i != 8) i: _card(i, _f433Positions[i]),
      };
      final injured = PlayerCard(
        ownedId: 99,
        upgradeLevel: 0,
        injuryMatchesRemaining: 2,
        base: _card(99, Position.st).base,
      );
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: injured,
        target: const SquadDropTarget.xiSlot(8),
      );
      expect(out.isAccepted, isFalse);
      expect(out.rejection, contains('injured'));
    });

    test('dropping on an OCCUPIED slot stays a plain swap (no redefinition)',
        () {
      final squad = {
        for (var i = 0; i < 11; i++) i: _card(i, _f433Positions[i]),
        11: _card(11, Position.gk),
      };
      // Bench CB (slot 12) onto the XI ST (slot 9): a swap, out of
      // position — allowed, and the formation does NOT change.
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: _card(12, Position.cb),
        target: SquadDropTarget.player(squad[9]!),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.formation, isNull,
          reason: 'swaps never redefine slots — only empty-slot drops do');
      expect(out.assignment![9], 12);
    });
  });

  group('drops with a position (the pitch always sends one) — no vanishing '
      'players', () {
    Map<int, PlayerCard> natural(List<Position> mix, {Set<int> without = const {}}) => {
      for (var i = 0; i < 11; i++)
        if (!without.contains(i)) i: _card(i, mix[i]),
    };

    test('a bench striker dropped on the empty ST place fills it', () {
      final squad = {
        ...natural(_f442Positions, without: {10}),
        11: _card(11, Position.gk),
        12: _card(12, Position.st),
      };
      final out = planSquadDrop(
        formation: formationByCode('4-4-2'),
        squad: squad,
        dragged: squad[12]!,
        target: const SquadDropTarget.xiSlot(10, position: Position.st),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![10], 12);
      expect(out.assignment!.containsKey(12), isFalse,
          reason: 'his bench place is freed');
      expect(out.assignment!.length, 12,
          reason: '10 starters + the moved striker + the bench keeper: '
              'nobody is lost');
    });

    test('an XI striker dropped on the OTHER empty ST place moves there', () {
      final squad = natural(_f442Positions, without: {10});
      final out = planSquadDrop(
        formation: formationByCode('4-4-2'),
        squad: squad,
        dragged: squad[9]!,
        target: const SquadDropTarget.xiSlot(10, position: Position.st),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![10], 9, reason: 'he stands on the place he was dropped on');
      expect(out.assignment!.containsKey(9), isFalse,
          reason: 'his old place is empty now');
      expect(out.assignment!.length, 10, reason: 'nobody is lost or duplicated');
    });

    test('a bench man dropped on a spare place with a FULL XI is refused '
        'and nobody is overwritten', () {
      final squad = {
        ...natural(_f433Positions),
        11: _card(11, Position.gk),
        12: _card(12, Position.st),
      };
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[12]!,
        // The spare places carry the stand-in slot 1 (the LB's slot).
        target: const SquadDropTarget.xiSlot(1, position: Position.cam),
      );
      expect(out.isAccepted, isFalse);
      expect(out.assignment, isNull, reason: 'the LB is not touched');
      expect(out.rejection, contains('full'));
    });

    test('a pool man dropped on a spare place with a FULL XI is refused', () {
      final squad = natural(_f433Positions);
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: _card(99, Position.st),
        target: const SquadDropTarget.xiSlot(1, position: Position.cam),
      );
      expect(out.isAccepted, isFalse);
      expect(out.assignment, isNull);
      expect(out.rejection, contains('full'));
    });

    test('the keeper can not be dropped on a spare place (goal stays '
        'filled)', () {
      final squad = natural(_f433Positions);
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[0]!,
        target: const SquadDropTarget.xiSlot(1, position: Position.cam),
      );
      expect(out.isAccepted, isFalse);
      expect(out.rejection, contains('goalkeeper'));
    });

    test('an XI man dropped on a spare place leaves nobody behind', () {
      final squad = natural(_f433Positions);
      final out = planSquadDrop(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[9]!, // the ST
        target: const SquadDropTarget.xiSlot(1, position: Position.cam),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      // Every one of the 11 men is still in the XI, once.
      expect(out.assignment!.length, 11);
      expect(out.assignment!.values.toSet().length, 11);
      expect(out.assignment![9], 9, reason: 'his vacated place morphs to CAM');
      expect(out.formation!.slots[9].position, Position.cam);
    });
  });

  group('squadDragLayout (the drag preview, owner request 2026-11-13)', () {
    test('a 3-4-3 with no RB shows the spare RB place', () {
      // The 3-4-3: 3 CB, no RB. Holding its ST opens his ST place and
      // the layout must ALSO offer the RB place the mix may take.
      final squad = {
        for (var i = 0; i < 11; i++)
          i: _card(i, _f343Positions[i]),
      };
      final layout = squadDragLayout(
        formation: formationByCode('3-4-3'),
        squad: squad,
        dragged: squad[9]!, // the ST
      );
      expect(layout.isLegal, isTrue, reason: layout.problem);
      // The spare places: every outfield position the 3-4-3 does not
      // field — RB, LB, CDM and CAM (LM/RM fielded, CB at 3/3, CM/LW/
      // RW fielded, ST is the held man's own place).
      final extras = layout.slots.skip(11).map((s) => s.position).toSet();
      expect(extras, {
        Position.rb,
        Position.lb,
        Position.cdm,
        Position.cam,
      }, reason: 'the spare places render beyond the XI');
      // The held ST's own place is marked.
      expect(layout.slots.any((s) => s.isHeld), isTrue);
      // Dropping the ST onto the RB place is accepted and redefines a
      // slot to RB.
      final out = planSquadDrop(
        formation: formationByCode('3-4-3'),
        squad: squad,
        dragged: squad[9]!, // the ST
        target: SquadDropTarget.xiSlot(1, position: Position.rb),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.formation, isNotNull);
      expect(
        out.formation!.slots.where((s) => s.position == Position.rb),
        isNotEmpty,
        reason: 'the shape now fields an RB',
      );
      expect(
        out.formation!.slots.where((s) => s.position == Position.st),
        isEmpty,
        reason: 'the dragged ST left his place — no ST remains',
      );
    });

    test('a lone ST placeholder sits dead centre; a pair halves', () {
      // Holding the CAM of a 4-3-3: the shape keeps its lone ST dead
      // centre (50), and the spare second-ST place joins the layout.
      final squad = {
        for (var i = 0; i < 11; i++) i: _card(i, _f433Positions[i]),
      };
      final layout = squadDragLayout(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[8]!, // the LW
      );
      final stPlace = layout.slots.firstWhere(
        (s) => s.position == Position.st,
      );
      expect(stPlace.x, 50, reason: 'the lone ST stays dead centre');
      expect(stPlace.isHeld, isFalse);
      // His own LW place is the marked one.
      final heldPlace = layout.slots.singleWhere((s) => s.isHeld);
      expect(heldPlace.position, Position.lw);
    });

    test('holding the third CM closes the pair ranks', () {
      // A 4-3-3: CDM + CM + CM. Holding one CM leaves a lone CM — his
      // place re-spreads to the CENTRE (50), not the left (32).
      final squad = {
        for (var i = 0; i < 11; i++) i: _card(i, _f433Positions[i]),
      };
      final layout = squadDragLayout(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[7]!, // a CM
      );
      final cmPlaces = layout.slots
          .where((s) => s.position == Position.cm && !s.isHeld)
          .toList();
      expect(cmPlaces, hasLength(1),
          reason: 'the held CM left his place');
      expect(cmPlaces.single.x, 50, reason: 'the remaining CM centres');
    });

    test('a bench man facing a full XI is offered no spare places; the '
        'keeper never is', () {
      final squad = {
        for (var i = 0; i < 11; i++) i: _card(i, _f433Positions[i]),
        11: _card(11, Position.st),
      };
      final bench = squadDragLayout(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[11]!,
      );
      expect(bench.slots, hasLength(11),
          reason: 'nothing to turn into a spare place');
      final keeper = squadDragLayout(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[0]!,
      );
      expect(keeper.slots, hasLength(11));
    });

    test('a keeper drag is refused outright', () {
      final squad = {
        for (var i = 0; i < 11; i++) i: _card(i, _f433Positions[i]),
      };
      final layout = squadDragLayout(
        formation: formationByCode('4-3-3'),
        squad: squad,
        dragged: squad[0]!,
      );
      expect(layout.isLegal, isFalse);
      expect(layout.problem, contains('goalkeeper'));
    });
  });

  group('the custom formation plays (engine contract)', () {
    test('autoPick fills a custom formation with natural players', () {
      // The 3-5-2-ish custom: double pivot, strike pair, no wingers.
      final eleven = customFormation(const [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cdm,
        Position.lw, Position.cam,
        Position.st, Position.st,
      ])!;
      final players = [
        _card(1, Position.gk),
        _card(2, Position.lb),
        _card(3, Position.cb),
        _card(4, Position.cb),
        _card(5, Position.rb),
        _card(6, Position.cdm),
        _card(7, Position.cdm),
        _card(8, Position.lw),
        _card(9, Position.cam),
        _card(10, Position.st),
        _card(11, Position.st),
        _card(12, Position.cm), // spare
      ];
      final assignment = const SquadEngine().autoPick(players, eleven);
      // All 11 XI slots filled, every one natural.
      for (var slot = 0; slot < 11; slot++) {
        final id = assignment[slot]!;
        expect(players.firstWhere((p) => p.ownedId == id).position,
            eleven.slots[slot].position,
            reason: 'slot $slot keeps its natural man');
      }
      expect(eleven.code, startsWith('C|'));
    });

    test('changeFormation-style round trip through the code', () {
      final f = customFormation(const [
        Position.gk,
        Position.lb, Position.cb, Position.cb, Position.rb,
        Position.cdm, Position.cm, Position.cm, Position.cam,
        Position.lw, Position.rw,
      ])!;
      // The 4-2-3-1 look built by hand — identical mix to the preset
      // 4-2-3-1 but carried as a custom code; the layout solver treats
      // them identically (same anchors, same depth ladder).
      expect(f.code, startsWith('C|'));
      final again = formationOfCode(f.code);
      expect(again.slots.length, 11);
      expect(again.slots.first.position, Position.gk);
    });
  });
}

const _f433Positions = [
  Position.gk,
  Position.lb, Position.cb, Position.cb, Position.rb,
  Position.cdm, Position.cm, Position.cm,
  Position.lw, Position.st, Position.rw,
];

const _f442Positions = [
  Position.gk,
  Position.lb, Position.cb, Position.cb, Position.rb,
  Position.lm, Position.cm, Position.cm, Position.rm,
  Position.st, Position.st,
];

const _f343Positions = [
  Position.gk,
  Position.cb, Position.cb, Position.cb,
  Position.lm, Position.cm, Position.cm, Position.rm,
  Position.lw, Position.st, Position.rw,
];
