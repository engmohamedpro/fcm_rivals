// Regression tests for the tactics setup surface:
//
//  * the control card's top row carries formation / style / mentality and
//    CLOSES with the team rating — one line, no overflow, at any width
//    (a previous rating + Auto Pick + TACTICS row overflowed ~40px on
//    phones; the actions now live on their own full-width row below);
//  * showStamina toggles the stamina bars and showStats the stat rows
//    (the Tactics tab hides both, the pre-match phase shows them);
//  * T-0064: the nine ordered axes render as stepped sliders (one
//    commit per gesture, effect summary under the track), chips stay
//    only for the final third + the offside toggle, and an RTL Arabic
//    pump mirrors the drag onto the same enums.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart'
    show FcmButton, FcmDropdown, FcmScaleSlider;
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/match/tactics_sections.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_view.dart';

PlayerCard _card(int id, Position position, {int stamina = 100}) => PlayerCard(
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
      overall: 80,
      attack: 82,
      support: 75,
      defence: 40,
      goalkeeping: 0,
    ),
  ),
);

Widget _host({
  bool showStamina = true,
  bool showStats = true,
  List<PlayerCard>? bench,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: Colors.black,
    body: SingleChildScrollView(
      child: TacticsSetupView(
        formationCode: '4-3-3',
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        xi: const {},
        bench: bench ?? const [],
        reserves: const [],
        onFormation: (_) {},
        onTactics: (_) {},
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
  for (final e
      in find
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
      expect(
        mentalityFromScale(mentalityToScale(m)),
        m,
        reason: '${m.displayName} round-trips',
      );
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

  testWidgets('setup row closes with the team rating, actions below', (
    WidgetTester tester,
  ) async {
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
    // The setup label and the control card's TACTICS button.
    expect(find.text('TACTICS'), findsNWidgets(2));
    expect(find.text('MENTALITY'), findsOneWidget);
    expect(find.text('Auto Pick'), findsOneWidget);

    // The rating ends the setup row: right of the TACTICS label
    // (the setup row's first info value), on its line.
    final tacticsLabel = tester.getTopLeft(find.text('TACTICS').first);
    final rating = tester.getTopLeft(find.text('TEAM RATING'));
    expect(rating.dx, greaterThan(tacticsLabel.dx));
    expect((rating.dy - tacticsLabel.dy).abs(), lessThan(4));

    // The formation dropdown sits under the setup row, and the action
    // buttons on the full-width row under it.
    final ratingBottom = tester.getBottomLeft(find.text('TEAM RATING'));
    final formation = tester.getTopLeft(find.text('4-3-3'));
    final autoPick = tester.getTopLeft(find.text('Auto Pick'));
    // The TACTICS action button (the 14pt one) shares its row with
    // Auto Pick.
    final tacticsButton = tester.getTopLeft(
      find
          .descendant(
            of: find.byType(FcmButton),
            matching: find.text('TACTICS'),
          )
          .first,
    );
    expect(formation.dy, greaterThan(ratingBottom.dy));
    expect(autoPick.dy, greaterThan(formation.dy));
    expect((tacticsButton.dy - autoPick.dy).abs(), lessThan(8));
  });

  testWidgets('bench and reserves always show their full quota of slots', (
    WidgetTester tester,
  ) async {
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
    final firstEmpty = tester.getTopLeft(find.byType(FcmMiniCard).at(1 + 11));
    expect(firstEmpty.dx, greaterThan(cardLeft.dx));

    // Even a completely empty squad keeps both sections visible.
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('Bench (0/7)'), findsOneWidget);
    expect(find.text('Reserves (0/5)'), findsOneWidget);
    expect(find.byType(FcmMiniCard), findsNWidgets(11 + 7 + 5));
  });

  testWidgets('stamina bars render only when shown', (
    WidgetTester tester,
  ) async {
    final bench = [_card(1, Position.st, stamina: 50)];

    await tester.pumpWidget(_host(bench: bench));
    await tester.pumpAndSettle();
    // Ghost placeholders render no stamina bar, so tracks come only
    // from the one real card.
    expect(
      _staminaTracks(),
      greaterThan(0),
      reason: 'stamina bar shown when enabled',
    );

    await tester.pumpWidget(_host(bench: bench, showStamina: false));
    await tester.pumpAndSettle();
    expect(
      _staminaTracks(),
      0,
      reason: 'no stamina bar when showStamina is false',
    );
  });

  testWidgets('stat rows render only when shown', (WidgetTester tester) async {
    final bench = [_card(1, Position.st)];

    await tester.pumpWidget(_host(bench: bench));
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsOneWidget);
    expect(find.text('SUP'), findsOneWidget);
    expect(find.text('DEF'), findsOneWidget);

    // The Tactics tab's shape: no stats, no stamina — just the shield
    // and the surname.
    await tester.pumpWidget(
      _host(bench: bench, showStamina: false, showStats: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsNothing);
    expect(find.text('SUP'), findsNothing);
    expect(find.text('DEF'), findsNothing);
  });

  testWidgets('tactic options sheet: formation absent, mentality is the '
      '0-100 scale slider with a floating step label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: FcmButton(
                  compact: true,
                  label: 'TACTICS',
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    mentality: Mentality.balanced,
                    onTactics: (_) {},
                    onMentality: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    // The sheet holds the three custom-tactics sections and the
    // mentality SCALE — the formation is not here (it lives on the
    // control card).
    expect(find.text('TACTIC OPTIONS'), findsOneWidget);
    expect(find.text('MENTALITY'), findsOneWidget);
    // T-0064: the nine ordered axes plus the mentality scale.
    expect(find.byType(FcmScaleSlider), findsNWidgets(10));
    expect(find.byType(TacticsGroupScaffold), findsOneWidget);
    expect(find.text('In Possession'), findsOneWidget);
    expect(find.text('Out of Possession'), findsOneWidget);
    expect(find.text('Transitions'), findsOneWidget);
    expect(find.textContaining('FORMATION'), findsNothing);

    // Dead centre default: the marker's floating label reads Balanced,
    // the scale's ends are named Very Defensive / Very Attacking. The
    // marker assertion is scoped to the MENTALITY slider (the last of
    // ten, T-0064) so the nine axis pills can never disturb it.
    expect(
      find.descendant(
        of: find.byType(FcmScaleSlider).at(9),
        matching: find.text('Balanced'),
      ),
      findsOneWidget,
    );
    expect(find.text('Very Defensive'), findsOneWidget);
    expect(find.text('Very Attacking'), findsOneWidget);
    // 'Balanced' appears inside the tactics scaffold once per group at
    // the defaults: the final-third CHIP (In Possession — categorical,
    // stays chips, T-0064) and the tackling / counter-press /
    // attack-on-recovery slider PILLS (Out of Possession +
    // Transitions — their default step is Balanced). Scoped to the
    // scaffold: a future instruction row may move this count, but it
    // can never touch the mentality label above.
    expect(
      find.descendant(
        of: find.byType(TacticsGroupScaffold),
        matching: find.text('Balanced'),
      ),
      findsNWidgets(4),
    );
    // Every group ships real controls at its defaults — no section
    // renders a placeholder state line any more.
    expect(find.text('Default setup'), findsNothing);

    // DONE sits below the fold of the scrollable sheet on the default
    // test viewport (ten sliders tall since T-0064) — reveal it, then
    // tap.
    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('TACTIC OPTIONS'), findsNothing);
  });

  testWidgets('sliding the mentality scale commits the landed-on step '
      'once per gesture', (WidgetTester tester) async {
    // The sheet now carries the In Possession controls too, so it is
    // taller than the default test viewport — give the test a tall
    // screen so the whole sheet (slider included) renders unscrolled.
    tester.view.physicalSize = const Size(1600, 3600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    // The committed steps, in drag order.
    final committed = <Mentality>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: FcmButton(
                  compact: true,
                  label: 'TACTICS',
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    mentality: Mentality.balanced,
                    onTactics: (_) {},
                    onMentality: committed.add,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    // T-0064: the sheet holds ten sliders — the mentality one is the
    // LAST (the scaffold's nine axes render first, sheet order:
    // buildUp, tempo, width, defensiveLine, pressing, tackling,
    // counterPress, attackOnRecovery, restDefence, mentality).
    final slider = find.byType(FcmScaleSlider).at(9);
    // The mentality slider sits below the fold of the capped sheet —
    // reveal it before measuring and dragging.
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final track = tester.getRect(slider);

    // Drag from centre to ~100 (Very Attacking): ONE commit at the end
    // of the gesture, never per intermediate tick. The drag path
    // crosses other steps on the way.
    final center = Offset(
      track.left + track.width / 2,
      track.top + track.height / 2,
    );
    await tester.dragFrom(center, Offset(track.width / 2, 0));
    await tester.pumpAndSettle();
    expect(committed, isNotEmpty);
    expect(committed.last, Mentality.veryAttacking);
    // The floating label followed the marker: the pill rides above the
    // track, 'Very Attacking' also captions the scale's right end.
    expect(find.text('Very Attacking'), findsNWidgets(2));
    // No mentality pill still reads Balanced (the STYLE dropdown's
    // 'Balanced' label is unrelated and stays).
    expect(
      find.descendant(of: slider, matching: find.text('Balanced')),
      findsNothing,
    );

    // A drag that lands back on the same step never re-commits it.
    final right = Offset(track.right - 12, track.top + track.height / 2);
    await tester.dragFrom(right, const Offset(6, 0));
    await tester.pumpAndSettle();
    expect(committed, [Mentality.veryAttacking]);

    // Drag to the far left (0): Very Defensive commits.
    await tester.dragFrom(right, Offset(-(track.width - 24), 0));
    await tester.pumpAndSettle();
    expect(committed, [Mentality.veryAttacking, Mentality.veryDefensive]);
  });

  testWidgets('T-0064: nine axis sliders + final-third chips + offside '
      'toggle + readouts all render, no overflow', (tester) async {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: FcmButton(
                  compact: true,
                  label: 'TACTICS',
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    mentality: Mentality.balanced,
                    onTactics: (_) {},
                    onMentality: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    // The nine axes + mentality = ten stepped sliders; the sheet lives
    // inside its 0.85-height cap with every row expanded (no overflow
    // exception escapes the pump).
    expect(find.byType(FcmScaleSlider), findsNWidgets(10));
    expect(tester.takeException(), isNull);

    // The final third stays a categorical CHIP row: all four styles
    // render as chips, not a slider.
    expect(find.text('Work Ball into Box'), findsOneWidget);
    expect(find.text('Early Crosses'), findsOneWidget);
    expect(find.text('Shoot on Sight'), findsOneWidget);

    // The offside-trap toggle chip stays (Off at the default).
    expect(find.text('Off'), findsOneWidget);

    // GDD 10.3 readouts survive: the honest possession estimate and
    // the rest-defence hint.
    expect(find.textContaining('Est. possession'), findsOneWidget);
    expect(
      find.textContaining('More players back means cover'),
      findsOneWidget,
    );

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });

  testWidgets('T-0064: dragging the pressing slider to the max end '
      'commits High Press once with its summary', (tester) async {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final committed = <TeamTactics>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: FcmButton(
                  compact: true,
                  label: 'TACTICS',
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    mentality: Mentality.balanced,
                    onTactics: committed.add,
                    onMentality: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    // The pressing axis is the fifth slider (Out of Possession).
    final pressing = find.byType(FcmScaleSlider).at(4);
    await tester.ensureVisible(pressing);
    await tester.pumpAndSettle();
    final track = tester.getRect(pressing);
    final centre = Offset(
      track.left + track.width / 2,
      track.top + track.height / 2,
    );

    // Default: the pill reads the localized 'Mid' (pressMid); the
    // row's summary is the identity ('No modifiers').
    expect(
      find.descendant(of: pressing, matching: find.text('Mid')),
      findsOneWidget,
    );

    // Drag to the max (aggressive) end: ONE commit for the whole
    // gesture — never per intermediate tick.
    await tester.dragFrom(centre, Offset(track.width / 2, 0));
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(
      committed.last.outOfPossession.pressing,
      PressingIntensity.high,
    );
    // The pill names the snapped step ('High' — pressHigh) and the
    // visible summary is the High Press bundle (GDD 10.3), in both the
    // row and the section header.
    expect(
      find.descendant(of: pressing, matching: find.text('High')),
      findsNWidgets(2), // the pill + the scale's aggressive-end label
    );
    expect(
      find.descendant(of: pressing, matching: find.text('Mid')),
      findsNothing,
    );
    expect(find.textContaining('Defence +34%'), findsWidgets);
    expect(find.textContaining('Chances +16%'), findsWidgets);
    expect(find.textContaining('Stamina use +30%'), findsWidgets);

    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });

  testWidgets('T-0064: dragging the build-up slider to the max end '
      'commits Long Ball (In Possession)', (tester) async {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final committed = <TeamTactics>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: FcmButton(
                  compact: true,
                  label: 'TACTICS',
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    mentality: Mentality.balanced,
                    onTactics: committed.add,
                    onMentality: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    final buildUp = find.byType(FcmScaleSlider).at(0);
    await tester.ensureVisible(buildUp);
    await tester.pumpAndSettle();
    final track = tester.getRect(buildUp);
    await tester.dragFrom(
      Offset(track.left + track.width / 2, track.top + track.height / 2),
      Offset(track.width / 2, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(committed.last.inPossession.buildUp, BuildUpStyle.longBall);
    expect(
      find.descendant(of: buildUp, matching: find.text('Long Ball')),
      findsNWidgets(2), // the pill + the scale's aggressive-end label
    );
    expect(find.textContaining('Passing -9%'), findsWidgets);

    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });

  testWidgets('T-0064: dragging the counter-press slider to the max end '
      'commits Immediate Counter-Press (Transitions)', (tester) async {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final committed = <TeamTactics>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: FcmButton(
                  compact: true,
                  label: 'TACTICS',
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    mentality: Mentality.balanced,
                    onTactics: committed.add,
                    onMentality: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    final counterPress = find.byType(FcmScaleSlider).at(6);
    await tester.ensureVisible(counterPress);
    await tester.pumpAndSettle();
    final track = tester.getRect(counterPress);
    await tester.dragFrom(
      Offset(track.left + track.width / 2, track.top + track.height / 2),
      Offset(track.width / 2, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(committed.last.transitions.counterPress, CounterPress.immediate);
    expect(
      find.descendant(
        of: counterPress,
        matching: find.text('Immediate Counter-Press'),
      ),
      findsNWidgets(2), // the pill + the scale's aggressive-end label
    );
    expect(find.textContaining('Stamina use +14%'), findsWidgets);

    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });

  testWidgets('T-0064 (RTL Arabic): the mirrored drag commits the same '
      'enum and the mentality names localize', (tester) async {
    tester.view.physicalSize = const Size(1600, 4000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final committed = <TeamTactics>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: FcmButton(
                  compact: true,
                  label: 'TACTICS',
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    mentality: Mentality.balanced,
                    onTactics: committed.add,
                    onMentality: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('TACTICS'));
    await tester.pumpAndSettle();

    // Arabic ambient direction: the mentality pill reads the localized
    // 'متوازن' at the default, and the scale's safe end label is the
    // localized 'دفاعي للغاية' (T-0064 requirement 6).
    expect(find.text('متوازن'), findsOneWidget);
    expect(find.text('دفاعي للغاية'), findsOneWidget);
    expect(find.text('هجومي للغاية'), findsOneWidget);

    // The pressing slider mirrors: the aggressive (max) end sits at the
    // LEFT, so dragging LEFT from the centre commits the same High
    // Press enum as the LTR drag to the right.
    final pressing = find.byType(FcmScaleSlider).at(4);
    await tester.ensureVisible(pressing);
    await tester.pumpAndSettle();
    final track = tester.getRect(pressing);
    await tester.dragFrom(
      Offset(track.left + track.width / 2, track.top + track.height / 2),
      Offset(-track.width / 2, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(
      committed.last.outOfPossession.pressing,
      PressingIntensity.high,
      reason: 'the RTL mirrored drag commits the same enum as LTR',
    );
    expect(
      find.descendant(of: pressing, matching: find.text('High')),
      findsNWidgets(2), // the pill + the mirrored aggressive-end label
    );
    expect(find.textContaining('Defence +34%'), findsWidgets);

    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });
}
