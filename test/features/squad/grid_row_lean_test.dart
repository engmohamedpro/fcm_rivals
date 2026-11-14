// T-0145: the grid-row lean chevrons (ADR-014's hidden bonus made
// FELT). A player standing ABOVE his position's natural line wears a
// small up chevron (attack-leaning), BELOW it a down chevron
// (defence-leaning), ON it no mark at all. Only on the drag-enabled
// GRID surface (the Team tab); preset formations stand on natural rows
// by construction, and the keeper never leans.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/mini_card.dart'
    show FcmMiniCard, RowShift;
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_drag.dart'
    show SquadDragHost, SquadSwapping;
import 'package:fcm_rivals/features/squad/squad_pitch_view.dart'
    show SquadPitch, rowShiftOf;

void main() {
  // The natural-line ladder (T-0145): CB/LB/RB row 1, CDM row 2, the
  // CM trio row 3, CAM/wingers row 4, ST row 5.
  test('naturalRowOf matches the spine ladder', () {
    expect(naturalRowOf(Position.gk), 0);
    expect(naturalRowOf(Position.cb), 1);
    expect(naturalRowOf(Position.lb), 1);
    expect(naturalRowOf(Position.rb), 1);
    expect(naturalRowOf(Position.cdm), 2);
    expect(naturalRowOf(Position.cm), 3);
    expect(naturalRowOf(Position.cam), 4);
    expect(naturalRowOf(Position.lw), 4);
    expect(naturalRowOf(Position.st), 5);
  });

  test('rowShiftOf reads the lean against the natural line', () {
    // A ST (natural row 5) dropped to row 3 leans DOWN.
    expect(
      rowShiftOf(Position.st, [const GridCell(2, 3)], 0),
      RowShift.down,
    );
    // A CB (natural row 1) pushed to row 3 leans UP.
    expect(
      rowShiftOf(Position.cb, [const GridCell(2, 3)], 0),
      RowShift.up,
    );
    // A CM standing on his natural row 3 reads neutral.
    expect(
      rowShiftOf(Position.cm, [const GridCell(2, 3)], 0),
      RowShift.none,
    );
    // The keeper never leans, whatever the cell says.
    expect(
      rowShiftOf(Position.gk, [const GridCell(2, 4)], 0),
      RowShift.none,
    );
    // A slot beyond the cells list (defensive: never on a legal XI).
    expect(
      rowShiftOf(Position.st, const [], 0),
      RowShift.none,
    );
  });

  testWidgets(
    'the Team-tab grid renders the lean chevron only off the natural row',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // A custom GRID formation (the drag surface): the ST slot's cell
      // sits on row 3 — one row BELOW the striker's natural line — and
      // a CB slot's cell sits on row 3, two rows ABOVE his. Everyone
      // else stands on his natural row.
      //
      // Serialisation: 'C|POS@col.row,…' (GK first, slot order).
      // Serialisation is POS@COL.ROW. Every cell unique. The ST stands
      // on row 3 (two rows BELOW his natural line 5 → the down
      // chevron); the second CDM stands on row 3 (one row ABOVE his
      // natural line 2 → the up chevron); everyone else on his
      // natural row (or the keeper).
      const formationCode =
          'C|GK@2.0,CB@1.1,CB@2.1,CB@3.1,CDM@2.2,'
          'CM@1.3,CM@3.3,CDM@2.3,CAM@2.4,LW@0.4,ST@0.3';
      final formation = formationOfCode(formationCode);

      PlayerCard card(int slot) => PlayerCard(
        ownedId: slot,
        upgradeLevel: 0,
        staminaPercent: 100,
        base: BasePlayer(
          playerId: 100 + slot,
          name: 'Slot $slot',
          position: formation.slots[slot].position,
          nationality: 'N$slot',
          clubName: 'C$slot',
          marketValueEur: 1_000_000,
          baseStats: const BaseStats(
            overall: 75,
            attack: 70,
            support: 70,
            defence: 70,
            goalkeeping: 0,
          ),
        ),
      );

      // The GRID surface (the Team tab's drag scope on): the pitch
      // builds its cells and the leans render.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SquadDragHost(
              swapping: SquadSwapping(
                rejection: (_, _) => null,
                onSwap: (_, _) {},
              ),
              child: SquadPitch(
                formation: formation,
                assignments: {
                  for (var slot = 0; slot < 11; slot++) slot: card(slot),
                },
                showStats: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // DIAG: is the drag scope visible from the pitch?
      final cards = tester
          .widgetList(find.byWidgetPredicate((w) => w is FcmMiniCard))
          .cast<FcmMiniCard>()
          .where((c) => !c.ghost)
          .toList();
      expect(cards, hasLength(11), reason: 'the grid renders its XI');
      // The ST standing on row 3 leans DOWN; the CB on row 3 leans UP;
      // the rest stand on their natural rows (or are the keeper / CDMs
      // on row 2 = natural) and read neutral.
      final leans = cards.map((c) => c.rowShift).toList();
      expect(leans, contains(RowShift.down), reason: 'the dropped ST');
      expect(leans, contains(RowShift.up), reason: 'the pushed CB');
      expect(leans.where((s) => s == RowShift.none).length, 9);
    },
  );
}
