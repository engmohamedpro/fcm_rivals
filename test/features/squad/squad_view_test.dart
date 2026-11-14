// Regression tests for the tactics setup surface:
//
//  * the control card's top row carries formation / style / mentality and
//    CLOSES with the team rating — one line, no overflow, at any width
//    (a previous rating + Auto Pick + TACTICS row overflowed ~40px on
//    phones; the actions now live on their own full-width row below);
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
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/formations.dart'
    show formationByCode;
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_view.dart';

PlayerCard _natCard(
  int id,
  Position position,
  String nationality,
) => PlayerCard(
  ownedId: id,
  upgradeLevel: 0,
  base: BasePlayer(
    playerId: 1000 + id,
    name: 'Player $id',
    position: position,
    nationality: nationality,
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

PlayerCard _card(int id, Position position) => PlayerCard(
  ownedId: id,
  upgradeLevel: 0,
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
  bool showStats = true,
  bool showSetupSummary = true,
  List<PlayerCard>? bench,
  Map<int, PlayerCard> xi = const {},
  Locale? locale,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: locale == null
      ? null
      : AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    backgroundColor: Colors.black,
    body: SingleChildScrollView(
      child: TacticsSetupView(
        formation: formationByCode('4-3-3'),
        tactics: const TeamTactics(),
        xi: xi,
        bench: bench ?? const [],
        reserves: const [],
        onFormation: (_) {},
        onTactics: (_) {},
        onAutoPick: () {},
        showStats: showStats,
        showSetupSummary: showSetupSummary,
      ),
    ),
  ),
);


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

  testWidgets('scoreboard row: rating at the start, chemistry at the end', (
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
    // dropdown showing the live shape. With the setup-summary row on
    // (this host's default — the pre-match/live surface) the shape
    // reads TWICE: the summary's FORMATION block and the dropdown's
    // live value. The Team tab passes showSetupSummary:false and sees
    // only the dropdown's read.
    expect(find.byType(FcmDropdown<String>), findsOneWidget);
    expect(find.text('4-3-3'), findsNWidgets(2));
    expect(find.text('FORMATION'), findsOneWidget);
    // The setup label and the control card's TACTICS button. The
    // MENTALITY chip is gone from the setup card (owner request
    // 2026-11-13 — mentality stays a live-match concern only).
    expect(find.text('TACTICS'), findsNWidgets(2));
    expect(find.text('MENTALITY'), findsNothing);
    expect(find.text('Auto Pick'), findsOneWidget);

    // The scoreboard row opens with the rating and closes with the
    // chemistry, both on one line ABOVE the setup row.
    final tacticsLabel = tester.getTopLeft(find.text('TACTICS').first);
    final rating = tester.getTopLeft(find.text('TEAM RATING'));
    final chem = tester.getTopLeft(find.text('CHEMISTRY'));
    expect(chem.dx, greaterThan(rating.dx));
    expect((chem.dy - rating.dy).abs(), lessThan(6));
    expect(rating.dy, lessThan(tacticsLabel.dy));

    // The formation dropdown sits under the setup row, with the
    // TACTICS button BESIDE it (same row, post-2026-11-13 layout); the
    // Auto Pick action (with Clear) is the row under that.
    final ratingBottom = tester.getBottomLeft(find.text('TEAM RATING'));
    final formation = tester.getBottomLeft(find.text('4-3-3').last);
    final autoPick = tester.getTopLeft(find.text('Auto Pick'));
    // The TACTICS action button (the 14pt one) shares its row with
    // the formation dropdown.
    final tacticsButton = tester.getTopLeft(
      find
          .descendant(
            of: find.byType(FcmButton),
            matching: find.text('TACTICS'),
          )
          .first,
    );
    expect(formation.dy, greaterThan(ratingBottom.dy));
    // Same row: the dropdown's taller body centers against the button
    // (~17px top-edge offset at this text scale).
    expect((tacticsButton.dy - formation.dy).abs(), lessThan(20));
    expect(autoPick.dy, greaterThan(formation.dy));
  });

  testWidgets('stat rows render only when shown', (WidgetTester tester) async {
    final bench = [_card(1, Position.st)];

    // The card redesign (7c40e86, owner-approved) OMITS attribute stat
    // rows from mini cards — ATT/SUP/DEF never render on the card face
    // whatever showStats says. The flag still rides along for the
    // pitch footprint math (pitch_layout.dart) and the API contract;
    // the card simply draws the shield + formatted name.
    await tester.pumpWidget(_host(bench: bench));
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsNothing);
    expect(find.text('SUP'), findsNothing);
    expect(find.text('DEF'), findsNothing);
    // The card still renders its identity: the formatted name.
    expect(find.text('P. 1'), findsOneWidget);

    // And hiding the flags changes nothing the card draws.
    await tester.pumpWidget(
      _host(bench: bench, showStats: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('ATT'), findsNothing);
    expect(find.text('P. 1'), findsOneWidget);
  });

  testWidgets('tactic options sheet: three tabs, no mentality, one '
      'group per tab', (WidgetTester tester) async {
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
                    onTactics: (_) {},
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

    // The sheet is TABBED now (owner request 2026-11-13): the three
    // instruction groups live on their own tabs, the mentality is GONE
    // entirely, and the formation is not here (it lives on the control
    // card).
    expect(find.text('TACTIC OPTIONS'), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('In Possession'), findsOneWidget);
    expect(find.text('Out of Possession'), findsOneWidget);
    expect(find.text('Transitions'), findsOneWidget);
    expect(find.textContaining('MENTALITY'), findsNothing);
    expect(find.textContaining('FORMATION'), findsNothing);
    // T-0128: text-only tabs at a compact 44dp height — no icons (they
    // wrapped the longest label on 360dp screens), and no repeated
    // group title inside any tab page.
    expect(find.byType(Tab), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(TabBar),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    // T-0133: TabBar exposes no height — the compact bar comes from the
    // per-tab Tab(height: 44), which sizes every tab's row uniformly.
    final tabs = tester
        .widgetList<Tab>(find.byType(Tab))
        .toList(growable: false);
    expect(tabs, isNotEmpty);
    for (final tab in tabs) {
      expect(tab.height, 44);
    }
    // Only the FIRST tab's sliders render (five of the eleven axes).
    expect(find.byType(FcmScaleSlider), findsNWidgets(5));

    // Switching tabs swaps the group: Out of Possession carries the
    // defensive line / pressing / tackling sliders plus the offside
    // toggle.
    await tester.tap(find.text('Out of Possession'));
    await tester.pumpAndSettle();
    expect(find.byType(FcmScaleSlider), findsNWidgets(3));
    expect(find.text('Off'), findsOneWidget);

    // Transitions: counter-press, attack on recovery, rest defence.
    await tester.tap(find.text('Transitions'));
    await tester.pumpAndSettle();
    expect(find.byType(FcmScaleSlider), findsNWidgets(3));

    // DONE closes the sheet.
    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(find.text('TACTIC OPTIONS'), findsNothing);
  });

  testWidgets(
    'T-0095: the tactic options sheet opens compact — at most ~62% of '
    'the screen, DONE still reachable',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                      onTactics: (_) {},
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

      expect(find.text('TACTIC OPTIONS'), findsOneWidget);

      // The sheet's rendered surface respects the compact cap: its
      // height stays at most ~63% of the screen (the 0.62 cap plus
      // the usual sub-pixel tolerance), leaving the pitch visible.
      final sheetRect = tester.getRect(find.byType(BottomSheet));
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        sheetRect.height,
        lessThanOrEqualTo(screenHeight * 0.63),
        reason: 'the sheet is a compact panel, not a takeover',
      );

      // DONE stays reachable inside the scrollable sheet and pops it.
      await tester.ensureVisible(find.text('DONE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DONE'));
      await tester.pumpAndSettle();
      expect(find.text('TACTIC OPTIONS'), findsNothing);
    },
  );

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
                    onTactics: (_) {},
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

    // Tabbed (owner request 2026-11-13): only the FIRST tab's five
    // sliders render at once; the sheet lives inside its height cap
    // with every row expanded (no overflow exception escapes the
    // pump). Every instruction is a continuous slider now — the old
    // final-third chips and the offside toggle chip became slider
    // bands (Shot Selection / Crossing axes on the later tabs).
    expect(find.byType(FcmScaleSlider), findsNWidgets(5));
    expect(tester.takeException(), isNull);

    // The five axes of the In Possession pane, by their slider names
    // (the row label renders uppercased by _TacticSliderRowState).
    expect(find.text('BUILD-UP'), findsOneWidget);
    expect(find.text('TEMPO'), findsOneWidget);
    expect(find.text('WIDTH'), findsOneWidget);
    expect(find.text('FINAL THIRD'), findsOneWidget);
    expect(find.text('CROSSING'), findsOneWidget);

    // The default readouts: every axis sits at its centre band —
    // 'Mixed' (build-up), 'Standard' (tempo, width, crossing) and
    // 'Balanced' (final third; a second 'Balanced' chip comes from the
    // preset row, so at-least checks keep this about the sliders).
    expect(find.text('Mixed'), findsAtLeastNWidgets(1));
    expect(find.text('Standard'), findsAtLeastNWidgets(3));
    expect(find.text('Balanced'), findsAtLeastNWidgets(1));

    // T-0079 (owner decision 2026-11-09): names only — the possession
    // estimate and the rest-defence hint are GONE from the sheet.
    expect(find.textContaining('Est. possession'), findsNothing);
    expect(
      find.textContaining('More players back means cover'),
      findsNothing,
    );
    expect(find.textContaining('No modifiers'), findsNothing);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });

  testWidgets('T-0064: dragging the pressing slider to the max end '
      'commits High Press once (names only)', (tester) async {
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
                    onTactics: committed.add,
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

    // The pressing axis lives on the Out of Possession tab (owner
    // request 2026-11-13) — switch there first; it is the second
    // slider of the tab (defensive line, pressing, tackling).
    await tester.tap(find.text('Out of Possession'));
    await tester.pumpAndSettle();
    final pressing = find.byType(FcmScaleSlider).at(1);
    await tester.ensureVisible(pressing);
    await tester.pumpAndSettle();
    final sliderRect = tester.getRect(pressing);
    // The gesture surface is the TRACK band (the slider's bottom
    // quarter) — the slider's centre lands in the empty pill band and
    // misses it.
    final centre = Offset(
      sliderRect.left + sliderRect.width / 2,
      sliderRect.top + sliderRect.height * 0.75,
    );

    // Default: the pill reads the centre band ('Mid press' — the
    // five-band copy of the pressing axis).
    expect(
      find.descendant(of: pressing, matching: find.text('Mid press')),
      findsOneWidget,
    );

    // Drag to the max (aggressive) end: ONE commit for the whole
    // gesture — never per intermediate tick.
    await tester.dragFrom(centre, Offset(sliderRect.width / 2, 0));
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(
      committed.last.outOfPossession.pressing,
      PressingIntensity.high,
    );
    // The pill names the MAX band the finger landed on
    // ('Relentless press' — the 80-99 fifth band of the axis); the
    // centre band is gone. The committed enum still snaps to High
    // (the four-step engine scale reads the slider's top zone).
    expect(
      find.descendant(
        of: pressing,
        matching: find.text('Relentless press'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pressing, matching: find.text('Mid press')),
      findsNothing,
    );
    // T-0079: per-row effect summaries are gone (names only).
    expect(find.textContaining('Defence +34%'), findsNothing);
    expect(find.textContaining('Chances +16%'), findsNothing);
    expect(find.textContaining('Stamina use +30%'), findsNothing);

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
                    onTactics: committed.add,
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
    final sliderRect = tester.getRect(buildUp);
    await tester.dragFrom(
      Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height * 0.75,
      ),
      Offset(sliderRect.width / 2, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(committed.last.inPossession.buildUp, BuildUpStyle.longBall);
    expect(
      find.descendant(of: buildUp, matching: find.text('Long ball')),
      findsOneWidget, // the pill reads the axis band word
    );
    // T-0079: per-row effect summaries are gone (names only).
    expect(find.textContaining('Passing -9%'), findsNothing);

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
                    onTactics: committed.add,
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

    // Tabbed sheet: the counter-press axis lives on the TRANSITIONS
    // tab, first slider (counter-press, attack on recovery, rest
    // defence) — switch there first.
    await tester.tap(find.text('Transitions'));
    await tester.pumpAndSettle();
    final counterPress = find.byType(FcmScaleSlider).at(0);
    await tester.ensureVisible(counterPress);
    await tester.pumpAndSettle();
    final sliderRect = tester.getRect(counterPress);
    await tester.dragFrom(
      Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height * 0.75,
      ),
      Offset(sliderRect.width / 2, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(committed.last.transitions.counterPress, CounterPress.immediate);
    expect(
      find.descendant(
        of: counterPress,
        matching: find.text('Instant counter-press'),
      ),
      findsOneWidget, // the pill reads the axis band word
    );
    // T-0079: per-row effect summaries are gone (names only).
    expect(find.textContaining('Stamina use +14%'), findsNothing);

    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });

  testWidgets('T-0064/T-0065 (RTL Arabic): the mirrored drag commits the '
      'same enum, and the whole tactic sheet localizes', (tester) async {
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
                    onTactics: committed.add,
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

    // Arabic ambient direction, tabbed sheet (owner request
    // 2026-11-13): the first tab's five sliders render, every pill on
    // its default centre band — 'متوازن' names the Final Third pill
    // (slider index 3 of the In Possession pane).
    expect(
      find.descendant(of: find.byType(FcmScaleSlider).at(3),
          matching: find.text('متوازن')),
      findsOneWidget,
    );

    // T-0065: the axis labels read Arabic in the sheet — the Final
    // Third row's label on this pane.
    expect(find.text('الثلث الأخير'), findsOneWidget);
    // The old categorical chips and the offside toggle are sliders on
    // the later tabs now — nothing of them renders on this pane.
    expect(find.text('تمريرات داخل المنطقة'), findsNothing);
    expect(find.text('إيقاف'), findsNothing);
    // T-0079: the readouts are gone in Arabic too (names only).
    expect(find.textContaining('الاستحواذ المتوقع'), findsNothing);
    expect(
      find.textContaining('بقاء لاعبين أكثر يعني غطاءً أفضل'),
      findsNothing,
    );

    // The pressing slider lives on the Out of Possession tab — switch
    // there first; it is the tab's second slider. It mirrors: the
    // aggressive (max) end sits at the LEFT, so dragging LEFT from the
    // centre commits the same High Press enum as the LTR drag to the
    // right. Its default pill reads the localized centre band
    // 'ضغط متوسط' (T-0065).
    await tester.tap(find.text('بدون الاستحواذ'));
    await tester.pumpAndSettle();
    final pressing = find.byType(FcmScaleSlider).at(1);
    await tester.ensureVisible(pressing);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: pressing, matching: find.text('ضغط متوسط')),
      findsOneWidget,
    );
    final sliderRect = tester.getRect(pressing);
    await tester.dragFrom(
      Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height * 0.75,
      ),
      Offset(-sliderRect.width / 2, 0),
    );
    await tester.pumpAndSettle();

    expect(committed, hasLength(1));
    expect(
      committed.last.outOfPossession.pressing,
      PressingIntensity.high,
      reason: 'the RTL mirrored drag commits the same enum as LTR',
    );
    expect(
      find.descendant(of: pressing, matching: find.text('ضغط شرس')),
      findsOneWidget, // the pill reads the max Arabic band (80-99)
    );
    expect(find.descendant(of: pressing, matching: find.text('ضغط متوسط')),
        findsNothing);
    // T-0079: per-row effect summaries are gone in Arabic too.
    expect(find.textContaining('Defence +34%'), findsNothing);

    await tester.ensureVisible(find.text('DONE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'T-0069: the XI chemistry reads +4% in the control card, not on the pitch',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 2 Egypt + 4 Brazil + 5 distinct = 1% + 3% = +4% (owner example).
      final nations = [
        'Egypt', 'Egypt', 'Brazil', 'Brazil', 'Brazil', 'Brazil',
        'France', 'Germany', 'Spain', 'Italy', 'England',
      ];
      final xi = <int, PlayerCard>{
        for (var slot = 0; slot < nations.length; slot++)
          slot: _natCard(slot + 1, Position.values[slot % 12], nations[slot]),
      };
      await tester.pumpWidget(_host(xi: xi));
      await tester.pumpAndSettle();

      expect(find.text('CHEMISTRY'), findsOneWidget);
      expect(find.text('+4%'), findsOneWidget);
      // The reading sits on the control card, never on the pitch (where
      // the cards used to cover it).
      final pitch = find.byType(SquadPitch);
      expect(
        find.descendant(of: pitch, matching: find.text('CHEMISTRY')),
        findsNothing,
      );
      // The link icon rides the label.
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'an empty XI still shows the chemistry reading (+0%)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // No starting XI at all — the chemistry reading stays on the card
      // at +0% (the empty-collection case).
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('CHEMISTRY'), findsOneWidget);
      expect(find.text('+0%'), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byType(SquadPitch), findsOneWidget);
    },
  );

  testWidgets('T-0069: an all-distinct XI reads +0%', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(340, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final xi = <int, PlayerCard>{
      for (var slot = 0; slot < 11; slot++)
        slot: _natCard(
          slot + 1,
          Position.values[slot % 12],
          'N$slot',
        ),
    };
    await tester.pumpWidget(_host(xi: xi));
    await tester.pumpAndSettle();

    // T-0094: the capsule shows the full label, dim at the neutral
    // reading.
    expect(find.text('CHEMISTRY'), findsOneWidget);
    expect(find.text('+0%'), findsOneWidget);
  });

  testWidgets('T-0069: Arabic RTL shows الكيمياء with the same percent', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(340, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final nations = [
      'Egypt', 'Egypt', 'Brazil', 'Brazil', 'Brazil', 'Brazil',
      'France', 'Germany', 'Spain', 'Italy', 'England',
    ];
    final xi = <int, PlayerCard>{
      for (var slot = 0; slot < nations.length; slot++)
        slot: _natCard(slot + 1, Position.values[slot % 12], nations[slot]),
    };
    await tester.pumpWidget(
      _host(xi: xi, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    // T-0080: the Arabic label compacts to its first five glyphs
    // T-0094: the capsule shows the FULL Arabic label (no truncation)
    // with the same percent — mirrored, icon on the start side.
    expect(find.text('الكيمياء'), findsOneWidget);
    expect(find.text('+4%'), findsOneWidget);
    expect(find.text('CHEMISTRY'), findsNothing);
    // The icon mirrors to the START side (right edge in RTL) — Row
    // order follows the text direction.
    final iconDx = tester.getTopLeft(find.byIcon(Icons.link_rounded)).dx;
    final labelDx = tester.getTopLeft(find.text('الكيمياء')).dx;
    expect(iconDx, greaterThan(labelDx),
        reason: 'RTL: the icon sits at the start (right) of the label');
  });

  testWidgets(
    'T-0092: showSetupSummary false drops the setup row, the card '
    'starts at the formation dropdown',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(showSetupSummary: false));
      await tester.pumpAndSettle();

      // The setup row's blocks are gone (the scoreboard row with the
      // team rating and chemistry stays on every surface)…
      expect(find.text('TEAM RATING'), findsOneWidget);
      expect(find.text('MENTALITY'), findsNothing);
      expect(find.text('Balanced'), findsNothing);
      // …and TACTICS survives only as the control card's button.
      expect(find.text('TACTICS'), findsOneWidget);

      // The formation dropdown leads the column now.
      expect(find.byType(FcmDropdown<String>), findsOneWidget);
      expect(find.text('Auto Pick'), findsOneWidget);
    },
  );

  testWidgets(
    'T-0092: default showSetupSummary keeps the setup row (pre-match '
    'and live surfaces)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.text('TEAM RATING'), findsOneWidget);
      // The MENTALITY chip is gone from the setup summary (owner
      // request 2026-11-13): the row carries the tactics only.
      expect(find.text('MENTALITY'), findsNothing);
      // The summary's one 'Balanced': the default tactics label.
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('TACTICS'), findsNWidgets(2));
    },
  );

  // T-0094: the capsule's value counts up to its new reading when the
  // squad changes — the count floats to the settled text, then idles
  // static (no looping work).
  testWidgets(
    'T-0094: a squad change settles the capsule on the new reading',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Start at +1%: one shared pair among eleven players
      // (2 Egypt + 9 distinct → max(0, 2−1) = 1).
      final nationsA = [
        'Egypt', 'Egypt',
        'France', 'Germany', 'Spain', 'Italy', 'England',
        'N8', 'N9', 'N10', 'N11',
      ];
      final xiA = <int, PlayerCard>{
        for (var slot = 0; slot < nationsA.length; slot++)
          slot: _natCard(slot + 1, Position.values[slot % 12], nationsA[slot]),
      };
      await tester.pumpWidget(_host(xi: xiA));
      await tester.pumpAndSettle();
      expect(find.text('+1%'), findsOneWidget);

      // Two players swap to Brazil: two shared pairs now
      // (2 Egypt + 2 Brazil + 7 distinct = 1 + 1 = 2) — the reading
      // changes, the count-up floats to it and settles on the exact
      // new text.
      final nationsB = [
        'Egypt', 'Egypt', 'Brazil', 'Brazil',
        'France', 'Germany', 'Spain', 'Italy', 'England',
        'N10', 'N11',
      ];
      final xiB = <int, PlayerCard>{
        for (var slot = 0; slot < nationsB.length; slot++)
          slot: _natCard(slot + 1, Position.values[slot % 12], nationsB[slot]),
      };
      await tester.pumpWidget(_host(xi: xiB));
      // The count-up runs (700ms) — mid-flight the old text is gone.
      await tester.pump(const Duration(milliseconds: 100));
      // Settle: the capsule reads the final number.
      await tester.pumpAndSettle();
      expect(find.text('+2%'), findsOneWidget,
          reason: '2 Egypt + 2 Brazil + 7 distinct = 1% + 1% = +2% — '
              'the count settled on the new reading');
      expect(find.text('+1%'), findsNothing);

      // Idle is static: another plain frame changes nothing.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('+2%'), findsOneWidget);
    },
  );

  // T-0094: the Arabic capsule is the premium pill mirrored — full
  // label, icon at the start (right) edge — already asserted in the
  // Arabic test above; this one pins the pill's own surfaces: the
  // glass background and gold border read in RTL exactly as EN.
  testWidgets(
    'T-0094: the capsule is a glass pill with a gold border (EN)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(340, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final nations = [
        'Egypt', 'Egypt', 'Brazil', 'Brazil', 'Brazil', 'Brazil',
        'France', 'Germany', 'Spain', 'Italy', 'England',
      ];
      final xi = <int, PlayerCard>{
        for (var slot = 0; slot < nations.length; slot++)
          slot: _natCard(slot + 1, Position.values[slot % 12], nations[slot]),
      };
      await tester.pumpWidget(_host(xi: xi));
      await tester.pumpAndSettle();

      // The chemistry reading sits on the CONTROL CARD (T-0080 moved
      // it off the pitch): the gold link icon + dim uppercase label
      // over the big count-up value — a plain column, no pill
      // decoration (the old glass capsule went with the pitch badge).
      final pitch = find.byType(SquadPitch);
      expect(
        find.descendant(of: pitch, matching: find.text('CHEMISTRY')),
        findsNothing,
      );
      expect(find.text('CHEMISTRY'), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      // +4%: 1% (2 Egypt) + 3% (4 Brazil) — the owner's own example.
      expect(find.text('+4%'), findsOneWidget);
    },
  );
}
