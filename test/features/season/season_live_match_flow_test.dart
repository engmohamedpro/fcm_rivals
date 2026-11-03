// League fixtures play as full live matches from the Season tab (GDD
// 13/16): pre-match pep talk, live match screen with tactics, post-match
// recovery choice and report, then the result commits to the season
// (FR-038) with the round's AI fixtures resolving in lockstep (GDD 9.2).
//
// The stores run real drift I/O over an in-memory database, so async
// flushes use tester.runAsync (FakeAsync doesn't perform real I/O).
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Scrollable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmDropdown;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_store.dart';
import 'package:fcm_rivals/main.dart';

import '../../helpers/audioplayers_mocks.dart';

const List<List<String>> _seedPositions = [
  ['GK', 'Keeper'],
  ['CB', 'Back'],
  ['CM', 'Midfield'],
  ['RW', 'Wing'],
  ['ST', 'Striker'],
  ['CDM', 'Anchor'],
  ['LW', 'Winger'],
  ['CAM', 'Playmaker'],
  ['LB', 'Leftback'],
  ['RB', 'Rightback'],
  ['LM', 'Leftmid'],
  ['RM', 'Rightmid'],
];

final List<List<dynamic>> seedRows = [
  for (var p = 0; p < _seedPositions.length; p++)
    for (var i = 0; i < 5; i++)
      [
        p * 10 + i + 1,
        '${_seedPositions[p][1]} ${p * 10 + i + 1}',
        _seedPositions[p][0],
        'Egypt',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

String datasetJson(List<List<dynamic>> rows) => json.encode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': rows,
});

/// Flushes pending real async I/O (drift transactions) and settles frames.
Future<void> _flush(
  WidgetTester tester, {
  Duration wait = const Duration(milliseconds: 300),
}) async {
  await tester.runAsync(() => Future<void>.delayed(wait));
  // Ambient animations (backdrop, live dot) never settle: pump bounded frames.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps the auto-play ticker until the match reaches full time (at 4x:
/// 200ms pumped time per match minute), dismissing the half-time pep-talk
/// sheet with the default 'no talk' choice when it appears so the clock
/// resumes. Bounded to ~120 match minutes of pumping so a broken ticker
/// fails fast instead of hanging.
Future<void> _playToFullTime(WidgetTester tester) async {
  for (var i = 0; i < 220; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    // The half-time touchline card holds the clock — its title is the
    // unmistakable HALF TIME banner. 'Say nothing' skips the talk and
    // resumes play.
    if (find.text('HALF TIME').evaluate().isNotEmpty) {
      await tester.tap(find.text('Say nothing — back to the match'));
      await tester.pump(const Duration(milliseconds: 400));
    }
    if (find.text('Post-match recovery').evaluate().isNotEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The live match screen now plays stadium ambience: give the
    // audioplayers channels silent handlers so the plugin constructor
    // and asset loading succeed quietly instead of reporting
    // MissingPluginException into FlutterError.
    installAudioplayersMocks();
  });

  tearDown(clearAudioplayersMocks);

  testWidgets(
    'league fixture plays as a live match from the Season tab and commits',
    (WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = CollectionStore(db: db);
      await store.applyDatasetUpdate(
        PlayerDataset.fromJson(datasetJson(seedRows)),
      );
      await store.createClub(
        clubName: 'FC Rivals',
        managerName: 'Mohamed',
        crestIndex: 0,
      );
      for (final pack in await store.getAvailablePacks()) {
        await store.openPack(packId: pack.id, random: math.Random(17));
      }
      await store.autoPickSquad();
      final seasonStore = SeasonStore(db: db, random: math.Random(4));
      await seasonStore.startSeason(division: 1);
      final opponent = (await seasonStore.getNextFixture())!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionStoreProvider.overrideWith((ref) => store),
            seasonStoreProvider.overrideWith((ref) async => seasonStore),
          ],
          child: const FcmRivalsApp(),
        ),
      );
      await _flush(tester, wait: const Duration(milliseconds: 200));

      // The Season tab lists the round-1 home fixture against an AI club.
      expect(find.text('Start your first season'), findsNothing);
      expect(
        find.textContaining('vs ${opponent.opponentName}'),
        findsOneWidget,
      );
      expect(find.text('Play match'), findsOneWidget);

      // Kick-off: the matchday build-up screen comes first (GDD 13): the
      // opponent analysis (header with position and form, loss/draw/win
      // row, strength, top players), then the dressing-room pep talk.
      await tester.tap(find.text('Play match'));
      await _flush(tester, wait: const Duration(milliseconds: 900));
      expect(find.text(opponent.opponentName), findsOneWidget);
      expect(find.text('LOSS'), findsOneWidget);
      expect(find.text('WIN'), findsOneWidget);
      expect(find.text('STRENGTH'), findsOneWidget);
      // The top-players card sits below the fold: scroll the analysis.
      await tester.dragUntilVisible(
        find.text('TOP PLAYERS'),
        find.byType(Scrollable).first,
        const Offset(0, -120),
      );
      await _flush(tester, wait: const Duration(milliseconds: 200));
      expect(find.text('TOP PLAYERS'), findsOneWidget);

      // Continue into the tactics phase (GDD 10.4): the SAME screen as the
      // Tactics tab — a compact control card (team rating + TACTICS button)
      // over the pitch with per-player stats and stamina bars, then bench
      // and reserves — but match-only.
      await tester.tap(find.text('CONTINUE'));
      await _flush(tester, wait: const Duration(milliseconds: 600));
      expect(find.text('Set up for this match'), findsOneWidget);
      expect(find.text('TEAM RATING'), findsOneWidget);
      expect(find.text('TACTICS'), findsOneWidget);

      // The tactic options live in a bottom sheet behind the TACTICS
      // button, so the screen stays dominated by the pitch.
      await tester.tap(find.text('TACTICS'));
      await _flush(tester, wait: const Duration(milliseconds: 600));
      expect(find.text('TACTIC OPTIONS'), findsOneWidget);
      expect(find.text('PLAYING STYLE'), findsOneWidget);

      // The style dropdown's closed field shows the saved default
      // (balanced). The control card's setup row also reads 'Balanced'
      // behind the sheet, so the tap targets the FIELD inside the style
      // dropdown, not the first matching text. Tapping it stacks the
      // option list sheet on top; give the sheets' entrance animations a
      // few bounded pumps, then fling the option list if the wanted tile
      // sits below the fold.
      final styleField = find.descendant(
        of: find.byType(FcmDropdown<PlayingStyle>),
        matching: find.text('Balanced'),
      );
      await tester.tap(styleField);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      for (var i = 0; i < 6; i++) {
        final tile = find.text('Counter Attack');
        if (tile.evaluate().isNotEmpty &&
            tester.getRect(tile.first).bottom < 560) {
          break;
        }
        await tester.flingFrom(
          const Offset(400, 300),
          const Offset(0, -350),
          800,
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      // Pick a different style; the option list sheet closes on selection.
      await tester.tap(find.text('Counter Attack'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // The style dropdown field in the options sheet now carries the
      // match-only selection (the control card behind the sheet shows it
      // too — the setup row mirrors the live selection).
      expect(
        find.descendant(
          of: find.byType(FcmDropdown<PlayingStyle>),
          matching: find.text('Counter Attack'),
        ),
        findsOneWidget,
      );

      // Close the options sheet; the control card's setup summary line on
      // the tactics screen reflects the match-only selection.
      await tester.tap(find.text('DONE'));
      await _flush(tester, wait: const Duration(milliseconds: 600));
      expect(find.textContaining('Counter Attack'), findsOneWidget);

      // On to the dressing room (GDD 15.1 pre-match pep talk).
      await tester.tap(find.text('TO DRESSING ROOM'));
      await _flush(tester, wait: const Duration(milliseconds: 600));
      expect(find.text('DRESSING ROOM'), findsOneWidget);
      expect(find.text('Deliver your team talk'), findsOneWidget);

      // The tactic selection did NOT touch the club's saved default setup:
      // match-only semantics (GDD 10.4) — persistence happens nowhere before
      // kick-off, and never for style/mentality/formation chosen here.
      final clubAfterTactics = await tester.runAsync(store.getClub);
      expect(clubAfterTactics!.playingStyle, 'balanced');

      // Kick off with the default 'no talk' tile selected.
      await tester.tap(find.text('KICK OFF'));
      await _flush(tester, wait: const Duration(milliseconds: 900));

      // The live match screen is pushed over the shell: real club names on
      // the scoreboard, the auto-play controls (pause + 1x–4x speed; no
      // skip-to-end exists anywhere) and the tactics entry point.
      expect(find.text('League · Round 1'), findsOneWidget);
      expect(find.text('FC Rivals'), findsWidgets);
      expect(find.text(opponent.opponentName), findsWidgets);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('4x'), findsOneWidget);
      expect(find.text('Next minute'), findsNothing);
      expect(find.text('Sim to end'), findsNothing);

      // The match plays itself: pump real time and the ticker advances
      // match minutes. Flip to 4x first (200ms per match minute), handle
      // the half-time talk when the clock holds, then play to full time.
      await tester.tap(find.text('4x'));
      await tester.pump(const Duration(milliseconds: 50));
      await _playToFullTime(tester);

      // Post-match recovery touchline card (GDD 15.3/19.3) over the
      // full-time scoreboard — take the 'rest everyone' focus.
      await _flush(tester);
      await _flush(tester);
      expect(find.text('Post-match recovery'), findsOneWidget);
      await tester.tap(find.text('Rest, everyone deserves it!'));
      await _flush(tester);

      // The report screen shows the result and reward, named for the real
      // fixture (GDD 14 post-match screen).
      expect(find.textContaining('Full time: FC Rivals'), findsOneWidget);
      expect(find.textContaining('Reward:'), findsOneWidget);
      expect(find.text('Team statistics'), findsOneWidget);

      // The report ends with CONTINUE — the only exit (no back button
      // above); the route pops and the Season tab providers refresh.
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await _flush(tester);

      // The fixture committed (FR-038): exactly one result row for the
      // fixture, the user club has played once in the standings and the
      // next fixture is round 2 (AI lockstep kept the round in sync).
      final results = await tester.runAsync(
        () async => (db.select(
          db.matchResults,
        )..where((r) => r.fixtureId.equals(opponent.fixtureId))).get(),
      );
      expect(results, hasLength(1));

      final standings = await tester.runAsync(seasonStore.getStandings);
      final user = standings!.firstWhere((e) => e.name == 'FC Rivals');
      expect(user.played, 1);

      final next = await tester.runAsync(seasonStore.getNextFixture);
      expect(next!.round, 2);

      await db.close();
    },
  );
}
