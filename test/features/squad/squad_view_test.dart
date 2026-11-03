// Regression tests for the tactics setup surface:
//
//  * the control card's top row carries formation / style / mentality and
//    CLOSES with the team rating — one line, no overflow, at any width
//    (a previous rating + Auto Pick + TACTICS row overflowed ~40px on
//    phones; the actions now live on their own full-width row below);
//  * showStamina toggles the stamina bars and showStats the stat rows
//    (the Tactics tab hides both, the pre-match phase shows them).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart'
    show FcmButton, FcmDropdown, FcmScaleSlider;
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_view.dart';

PlayerCard _card(int id, Position position, {int stamina = 100}) =>
    PlayerCard(
      ownedId: id,
      upgradeLevel: 0,
      staminaPercent: stamina,
      base: BasePlayer(
        playerId: 1000 + id,
        name: 'Player $id',
        position: position,
        nationality: 'Egypt',
        marketValueEur: 5_000_000,
        baseStats: const BaseStats(
            overall: 80, attack: 82, support: 75, defence: 40, goalkeeping: 0),
      ),
    );

Widget _host({
  bool showStamina = true,
  bool showStats = true,
  List<PlayerCard>? bench,
}) =>
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SingleChildScrollView(
          child: TacticsSetupView(
            formationCode: '4-3-3',
            style: PlayingStyle.balanced,
            mentality: Mentality.balanced,
            xi: const {},
            bench: bench ?? const [],
            reserves: const [],
            onFormation: (_) {},
            onStyle: (_) {},
            onMentality: (_) {},
            onAutoPick: () {},
            showStamina: showStamina,
            showStats: showStats,
          ),
        ),
      ),
    );

/// Number of 5px-tall decorated boxes under the mini cards: the stamina
/// track (and its fill) — zero means no stamina bar is rendered.
int _staminaTracks() {
  var count = 0;
  for (final e in find
      .descendant(
        of: find.byType(FcmMiniCard),
        matching: find.byType(DecoratedBox),
      )
      .evaluate()) {
    if ((e.renderObject as RenderBox).size.height == 5) count++;
  }
  return count;
}

void main() {
  test('mentality scale mapping is exact at every named step', () {
    // Round-trip: each mentality's scale position maps back to itself.
    for (final m in Mentality.values) {
      expect(mentalityFromScale(mentalityToScale(m)), m,
          reason: '${m.displayName} round-trips');
    }
    // The poles and the centre.
    expect(mentalityFromScale(0), Mentality.veryDefensive);
    expect(mentalityFromScale(100), Mentality.veryAttacking);
    expect(mentalityFromScale(50), Mentality.balanced);
    expect(mentalityToScale(Mentality.balanced), 50);
    // Off-scale values clamp, and in-between positions land in the
    // nearest step's band.
    expect(mentalityFromScale(-5), Mentality.veryDefensive);
    expect(mentalityFromScale(105), Mentality.veryAttacking);
    expect(mentalityFromScale(41), Mentality.cautious);
    expect(mentalityFromScale(59), Mentality.positive);
  });

  testWidgets('setup row closes with the team rating, actions below',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(340, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('TEAM RATING'), findsOneWidget);
    // The formation picker sits DIRECTLY on the control card as a
    // dropdown showing the live shape — no 'FORMATION' info label
    // anymore, and no formation inside the tactic options sheet.
    expect(find.byType(FcmDropdown<String>), findsOneWidget);
    expect(find.text('4-3-3'), findsOneWidget);
    expect(find.text('FORMATION'), findsNothing);
    expect(find.text('STYLE'), findsOneWidget);
    expect(find.text('MENTALITY'), findsOneWidget);
    expect(find.text('Auto Pick'), findsOneWidget);
    expect(find.text('TACTICS'), findsOneWidget);

    // The rating ends the setup row: right of STYLE, on its line.
    final style = tester.getTopLeft(find.text('STYLE'));
    final rating = tester.getTopLeft(find.text('TEAM RATING'));
    expect(rating.dx, greaterThan(style.dx));
    expect((rating.dy - style.dy).abs(), lessThan(4));

    // The formation dropdown sits under the setup row, and the action
    // buttons on the full-width row under it.
    final ratingBottom = tester.getBottomLeft(find.text('TEAM RATING'));
    final formation = tester.getTopLeft(find.text('4-3-3'));
    final autoPick = tester.getTopLeft(find.text('Auto Pick'));
    final tactics = tester.getTopLeft(find.text('TACTICS'));
    expect(formation.dy, greaterThan(ratingBottom.dy));
    expect(autoPick.dy, greaterThan(formation.dy));
    expect((tactics.dy - autoPick.dy).abs(), lessThan(8));
  });

  testWidgets('bench and reserves always show their full quota of slots',
      (WidgetTester tester) async {
    // One bench player, no reserves: 6 bench placeholders + all 5
    // reserve placeholders render after the real card.
    await tester.pumpWidget(_host(bench: [_card(1, Position.st)]));
    await tester.pumpAndSettle();

    expect(find.text('Bench (1/7)'), findsOneWidget);
    expect(find.text('Reserves (0/5)'), findsOneWidget);
    // The one real card plus the ghost placeholders — same widget, the
    // ghost ones render dimmed and wordless: 11 empty formation slots,
    // 6 bench and 5 reserve placeholders.
    expect(find.byType(FcmMiniCard), findsNWidgets(1 + 11 + 6 + 5));

    // The bench placeholders sit after the real bench card in the bench
    // strip: its surname reads '1' (from 'Player 1').
    final cardLeft = tester.getTopLeft(find.text('1'));
    final firstEmpty =
        tester.getTopLeft(find.byType(FcmMiniCard).at(1 + 11));
    expect(firstEmpty.dx, greaterThan(cardLeft.dx));

    // Even a completely empty squad keeps both sections visible.
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('Bench (0/7)'), findsOneWidget);
    expect(find.text('Reserves (0/5)'), findsOneWidget);
    expect(find.byType(FcmMiniCard), findsNWidgets(11 + 7 + 5));
  });

  testWidgets('stamina bars render only when shown',
      (WidgetTester tester) async {
    final bench = [_card(1, Position.st, stamina: 50)];

    await tester.pumpWidget(_host(bench: bench));
    await tester.pumpAndSettle();
    // Ghost placeholders render no stamina bar, so tracks come only
    // from the one real card.
    expect(_staminaTracks(), greaterThan(0),
        reason: 'stamina bar shown when enabled');

    await tester.pumpWidget(_host(bench: bench, showStamina: false));
    await tester.pumpAndSettle();
    expect(_staminaTracks(), 0,
        reason: 'no stamina bar when showStamina is false');
  });

  testWidgets('stat rows render only when shown',
      (WidgetTester tester) async {
    final bench = [_card(1, Position.st)];

    await tester.pumpWidget(_host(bench: bench));
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('SUP'), findsOneWidget);
    expect(find.text('DEF'), findsOneWidget);

    // The Tactics tab's shape: no stats, no stamina — just the shield
    // and the surname.
    await tester.pumpWidget(
        _host(bench: bench, showStamina: false, showStats: false));
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsNothing);
    expect(find.text('SUP'), findsNothing);
    expect(find.text('DEF'), findsNothing);
  });

  testWidgets('tactic options sheet: formation absent, mentality is the '
      '0-100 scale slider with a floating step label',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Builder(builder: (context) {
          return Center(
            child: FcmButton(
              compact: true,
              label: 'TACTICS',
              onPressed: () => showTacticsOptionsSheet(
                context,
                style: PlayingStyle.balanced,
                mentality: Mentality.balanced,
                onStyle: (_) {},
                onMentality: (_) {},
              ),
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    // The sheet holds the style dropdown and the mentality SCALE —
    // the formation is not here (it lives on the control card).
    expect(find.text('TACTIC OPTIONS'), findsOneWidget);
    expect(find.text('PLAYING STYLE'), findsOneWidget);
    expect(find.text('MENTALITY'), findsOneWidget);
    expect(find.byType(FcmScaleSlider), findsOneWidget);
    expect(find.byType(FcmDropdown<PlayingStyle>), findsOneWidget);
    expect(find.textContaining('FORMATION'), findsNothing);

    // Dead centre default: the marker's floating label reads Balanced
    // (also the style dropdown's selected label — one each), the
    // scale's ends are named Very Defensive / Very Attacking.
    expect(find.text('Balanced'), findsNWidgets(2));
    expect(find.text('Very Defensive'), findsOneWidget);
    expect(find.text('Very Attacking'), findsOneWidget);
    // The centre default carries no modifiers.
    expect(find.text('No modifiers'), findsOneWidget);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('TACTIC OPTIONS'), findsNothing);
  });

  testWidgets('sliding the mentality scale commits the landed-on step '
      'once per gesture', (WidgetTester tester) async {
    // The committed steps, in drag order.
    final committed = <Mentality>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Builder(builder: (context) {
          return Center(
            child: FcmButton(
              compact: true,
              label: 'TACTICS',
              onPressed: () => showTacticsOptionsSheet(
                context,
                style: PlayingStyle.balanced,
                mentality: Mentality.balanced,
                onStyle: (_) {},
                onMentality: committed.add,
              ),
            ),
          );
        }),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    final slider = find.byType(FcmScaleSlider);
    expect(slider, findsOneWidget);
    final track = tester.getRect(slider);

    // Drag from centre to ~100 (Very Attacking): ONE commit at the end
    // of the gesture, never per intermediate tick. The drag path
    // crosses other steps on the way.
    final center = Offset(track.left + track.width / 2,
        track.top + track.height / 2);
    await tester.dragFrom(center, Offset(track.width / 2 - 8, 0));
    await tester.pumpAndSettle();
    expect(committed, [Mentality.veryAttacking]);
    // The floating label followed the marker: the pill rides above the
    // track, 'Very Attacking' also captions the scale's right end.
    expect(find.text('Very Attacking'), findsNWidgets(2));
    // No mentality pill still reads Balanced (the STYLE dropdown's
    // 'Balanced' label is unrelated and stays).
    expect(
        find.descendant(of: slider, matching: find.text('Balanced')),
        findsNothing);

    // A drag that lands back on the same step never re-commits it.
    final right = Offset(
        track.right - 12, track.top + track.height / 2);
    await tester.dragFrom(right, const Offset(6, 0));
    await tester.pumpAndSettle();
    expect(committed, [Mentality.veryAttacking]);

    // Drag to the far left (0): Very Defensive commits.
    await tester.dragFrom(right, Offset(-(track.width - 24), 0));
    await tester.pumpAndSettle();
    expect(committed,
        [Mentality.veryAttacking, Mentality.veryDefensive]);
  });
}
