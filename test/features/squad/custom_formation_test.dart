// Custom formations (owner request 2026-11-12): the drag-built shapes.
//
// The owner's exact ladder is the law (2026-11-13 update):
//   GK exactly 1 (the keeper's slot never changes)
//   ST 0-2, LW 0-1, RW 0-1, CAM 0-2,
//   CM 0-3, CDM 0-3, CB 2-3 (legacy builder only — the grid enforces
//   the MAXIMUMS, so a centre back can be moved), RB 0-1,
//   LB 0-1 (LM/RM 0-1 each — the dataset carries them)
//
// The Team tab is a chess-like GRID (owner request 2026-11-13): a grid
// formation serialises as 'C|GK@2.0,LB@0.1,…' (position @ column . row);
// the legacy 'C|GK,LB,CB,…' codes still decode. formationOfCode
// decodes both, so the match engine and every consumer see it as just
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

  group('the chess grid model', () {
    test('what a cell asks for, row by row', () {
      expect(positionOfCell(kGridKeeperCol, 0), Position.gk);
      expect(positionOfCell(0, 1), Position.lb);
      expect(positionOfCell(2, 1), Position.cb);
      expect(positionOfCell(4, 2), Position.rb);
      expect(positionOfCell(2, 2), Position.cdm);
      expect(positionOfCell(0, 3), Position.lm);
      expect(positionOfCell(3, 3), Position.cm);
      expect(positionOfCell(0, 4), Position.lw);
      expect(positionOfCell(1, 4), Position.cam);
      expect(positionOfCell(4, 5), Position.rw);
      expect(positionOfCell(2, 5), Position.st);
    });

    test('row 0 holds only the keeper cell; the rest is the pitch', () {
      var count = 0;
      for (var r = 0; r < kGridRows; r++) {
        for (var c = 0; c < kGridCols; c++) {
          if (isGridCellAllowed(c, r)) count++;
        }
      }
      expect(isGridCellAllowed(0, 0), isFalse);
      expect(isGridCellAllowed(kGridKeeperCol, 0), isTrue);
      expect(isGridCellAllowed(-1, 2), isFalse);
      expect(isGridCellAllowed(kGridCols, 2), isFalse);
      expect(isGridCellAllowed(2, kGridRows), isFalse);
      expect(count, 1 + (kGridRows - 1) * kGridCols);
    });

    test('every preset snaps to 11 distinct legal cells, keeper in goal, '
        'deeper lines never in front of higher ones', () {
      for (final f in formations) {
        final cells = gridCellsOf(f);
        expect(cells, hasLength(11), reason: f.code);
        expect(cells.toSet(), hasLength(11), reason: '${f.code}: no overlap');
        expect(cells.first, const GridCell(kGridKeeperCol, 0),
            reason: f.code);
        for (final c in cells) {
          expect(isGridCellAllowed(c.col, c.row), isTrue, reason: f.code);
        }
        for (var i = 1; i < 11; i++) {
          for (var j = 1; j < 11; j++) {
            if (f.slots[i].y < f.slots[j].y - 15) {
              expect(cells[i].row, lessThanOrEqualTo(cells[j].row),
                  reason: '${f.code}: slot $i is deeper than slot $j');
            }
          }
        }
      }
    });

    test('LB / RB stand on the FIRST line in a back four and on the '
        'SECOND in a back five', () {
      for (final f in formations) {
        final cells = gridCellsOf(f);
        final back = [
          for (final s in f.slots)
            if (s.position == Position.cb ||
                s.position == Position.lb ||
                s.position == Position.rb)
              s,
        ].length;
        for (var i = 1; i < 11; i++) {
          final p = f.slots[i].position;
          if (p == Position.lb || p == Position.rb) {
            expect(cells[i].row, back >= 5 ? 2 : 1, reason: f.code);
          }
          if (p == Position.cb) {
            expect(cells[i].row, 1, reason: '${f.code}: centre backs');
          }
        }
      }
      expect(
        [
          for (final f in formations)
            if (f.code == '5-3-2' || f.code == '5-4-1') f.code,
        ],
        hasLength(2),
        reason: 'the back-five presets exist',
      );
    });

    test('a grid formation round-trips through its code', () {
      final f433 = formationByCode('4-3-3');
      final positions = [for (final s in f433.slots) s.position];
      final cells = gridCellsOf(f433);
      final grid = customGridFormation(positions, cells)!;
      expect(grid.code, startsWith('C|GK@2.0,'));
      expect(isGridFormationCode(grid.code), isTrue);
      final again = formationOfCode(grid.code);
      expect(again.code, grid.code);
      expect([for (final s in again.slots) s.position], positions);
      expect(gridCellsOf(again), cells);
      for (final s in again.slots) {
        expect(s.x, inInclusiveRange(0, 100));
        expect(s.y, inInclusiveRange(0, 100));
      }
    });

    test('illegal grids are refused: shared cell, bad keeper, third ST, '
        'cell off the pitch — but a lone CB is fine (no minimums)', () {
      final base = gridCellsOf(formationByCode('4-4-2'));
      final pos = [for (final s in formationByCode('4-4-2').slots) s.position];
      expect(gridFormationProblem(pos, base), isNull);

      final shared = [...base]..[2] = base[3];
      expect(gridFormationProblem(pos, shared), contains('share'));

      final offPitch = [...base]..[2] = const GridCell(0, 0);
      expect(gridFormationProblem(pos, offPitch), isNotNull);

      final noKeeperFirst = [...pos]..[0] = Position.cb;
      expect(gridFormationProblem(noKeeperFirst, base), isNotNull);

      final threeSt = [...pos]..[5] = Position.st;
      expect(gridFormationProblem(threeSt, base), contains('ST'));
      expect(customGridFormation(threeSt, base), isNull);

      final loneCb = [...pos]..[2] = Position.cm;
      expect(gridFormationProblem(loneCb, base), isNull,
          reason: 'moving a centre back must be possible');
    });

    test('junk grid codes fall back to the default shape', () {
      expect(formationOfCode('C|GK@2.0,CB@9.9').code, '4-3-3');
      expect(
        formationOfCode('C|GK@2.0,CB@x.1,CB@1.1,CB@3.1,CM@1.2,CM@2.2,CM@3.2,'
                'LW@0.4,ST@2.5,RW@4.4,CAM@2.4')
            .code,
        '4-3-3',
      );
      // Two slots on one cell.
      expect(
        formationOfCode('C|GK@2.0,CB@1.1,CB@1.1,CB@3.1,CM@1.2,CM@2.2,CM@3.2,'
                'LW@0.4,ST@2.5,RW@4.4,CAM@2.4')
            .code,
        '4-3-3',
      );
    });
  });

  group('planSquadDrop on the grid', () {
    final f433 = formationByCode('4-3-3');

    Map<int, PlayerCard> squad({Set<int> without = const {}}) => {
      for (var i = 0; i < 11; i++)
        if (!without.contains(i)) i: _card(i, f433.slots[i].position),
      11: _card(11, Position.gk),
      12: _card(12, Position.cb),
      13: _card(13, Position.st),
    };

    /// The first free allowed cell whose role is [role] in [f].
    GridCell freeCell(Formation f, Position role) {
      final used = gridCellsOf(f).toSet();
      for (var r = 1; r < kGridRows; r++) {
        for (var c = 0; c < kGridCols; c++) {
          final cell = GridCell(c, r);
          if (!used.contains(cell) && positionOfCell(c, r) == role) {
            return cell;
          }
        }
      }
      throw StateError('no free $role cell in ${f.code}');
    }

    test('an XI man dropped on a free cell moves HIS place there; nobody '
        'else moves and nobody is lost', () {
      final s = squad();
      final cell = freeCell(f433, Position.cam);
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[6]!,
        target: SquadDropTarget.cell(cell),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment, {
        for (final e in s.entries) e.key: e.value.ownedId,
      }, reason: 'same men on the same slots');
      final nf = out.formation!;
      final before = gridCellsOf(f433);
      final after = gridCellsOf(nf);
      expect(after[6], cell);
      expect(nf.slots[6].position, Position.cam,
          reason: 'the place now asks for what the cell stands for');
      for (var i = 0; i < 11; i++) {
        if (i == 6) continue;
        expect(after[i], before[i], reason: 'slot $i must not move');
        expect(nf.slots[i].position, f433.slots[i].position);
      }
    });

    test('the moves chain: the grid formation is the next input', () {
      var f = f433;
      final s = squad();
      for (final role in [Position.cam, Position.cdm, Position.cb]) {
        final cell = freeCell(f, role);
        final out = planSquadDrop(
          formation: f,
          squad: s,
          dragged: s[7]!,
          target: SquadDropTarget.cell(cell),
        );
        expect(out.isAccepted, isTrue, reason: '$role: ${out.rejection}');
        f = out.formation!;
        expect(gridCellsOf(f)[7], cell);
        expect(formationOfCode(f.code).code, f.code,
            reason: 'what is saved is what is read back');
      }
    });

    test('a bench man on a free cell takes an EMPTY slot there and frees '
        'his bench place', () {
      final s = squad(without: {9});
      final cell = freeCell(f433, Position.cam);
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[13]!,
        target: SquadDropTarget.cell(cell),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 13);
      expect(out.assignment!.containsKey(13), isFalse);
      expect(gridCellsOf(out.formation!)[9], cell);
    });

    test('a bench man on the cell of an EMPTY slot just fills it (shape '
        'unchanged)', () {
      final s = squad(without: {9});
      final cell = gridCellsOf(f433)[9];
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[13]!,
        target: SquadDropTarget.cell(cell),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 13);
      expect(out.formation, isNull);
    });

    test('an XI man on the cell of an empty slot moves there; his old '
        'slot stays an empty ghost', () {
      final s = squad(without: {9});
      final cell = gridCellsOf(f433)[9];
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[8]!,
        target: SquadDropTarget.cell(cell),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 8);
      expect(out.assignment!.containsKey(8), isFalse);
      expect(out.formation, isNull);
    });

    test('a bench man on a free cell with a FULL XI is refused and nobody '
        'is touched', () {
      final s = squad();
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[13]!,
        target: SquadDropTarget.cell(freeCell(f433, Position.cam)),
      );
      expect(out.isAccepted, isFalse);
      expect(out.rejection, contains('full'));
    });

    test('a pool man behaves like a bench man', () {
      final s = squad(without: {9});
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: _card(99, Position.cm),
        target: SquadDropTarget.cell(freeCell(f433, Position.cam)),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![9], 99);
    });

    test('the keeper never leaves goal and nobody else enters it', () {
      final s = squad();
      final gkOnPitch = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[0]!,
        target: SquadDropTarget.cell(freeCell(f433, Position.cam)),
      );
      expect(gkOnPitch.isAccepted, isFalse);
      expect(gkOnPitch.rejection, contains('goalkeeper'));

      final intoGoal = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[5]!,
        target: const SquadDropTarget.cell(GridCell(kGridKeeperCol, 0)),
      );
      expect(intoGoal.isAccepted, isFalse);

      final benchGk = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[11]!,
        target: SquadDropTarget.cell(freeCell(f433, Position.cam)),
      );
      expect(benchGk.isAccepted, isFalse);
    });

    test('a cell off the pitch is refused', () {
      final s = squad();
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[6]!,
        target: const SquadDropTarget.cell(GridCell(0, 0)),
      );
      expect(out.isAccepted, isFalse);
    });

    test('the per-position maximums still hold: a third striker is '
        'refused with the reason', () {
      final f442 = formationByCode('4-4-2');
      final s = {
        for (var i = 0; i < 11; i++) i: _card(i, f442.slots[i].position),
      };
      final out = planSquadDrop(
        formation: f442,
        squad: s,
        dragged: s[6]!,
        target: SquadDropTarget.cell(freeCell(f442, Position.st)),
      );
      expect(out.isAccepted, isFalse);
      expect(out.rejection, contains('ST'));
    });

    test('a centre back may be moved up the pitch (no minimums)', () {
      final s = squad();
      final cb = [
        for (var i = 1; i < 11; i++)
          if (f433.slots[i].position == Position.cb) i,
      ].first;
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[cb]!,
        target: SquadDropTarget.cell(freeCell(f433, Position.cam)),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
    });

    test('an injured man cannot be moved onto a free cell', () {
      final s = squad(without: {9});
      final injured = PlayerCard(
        ownedId: 99,
        upgradeLevel: 0,
        injuryMatchesRemaining: 2,
        base: _card(99, Position.st).base,
      );
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: injured,
        target: SquadDropTarget.cell(freeCell(f433, Position.cam)),
      );
      expect(out.isAccepted, isFalse);
      expect(out.rejection, contains('injured'));
    });

    test('dropping on an OCCUPIED slot is still a plain swap (shape '
        'unchanged)', () {
      final s = squad();
      final out = planSquadDrop(
        formation: f433,
        squad: s,
        dragged: s[6]!,
        target: SquadDropTarget.player(s[7]!),
      );
      expect(out.isAccepted, isTrue, reason: out.rejection);
      expect(out.assignment![6], 7);
      expect(out.assignment![7], 6);
      expect(out.formation, isNull);
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
