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
import 'package:fcm_rivals/core/ui/fcm_widgets.dart';
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;

import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_store.dart';
import 'package:fcm_rivals/features/squad/squad_pitch_view.dart' show SquadPitch;
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

/// Pumps the auto-play ticker until the match reaches full time (at 3x:
/// 267ms pumped time per match minute), dismissing the half-time pep-talk
/// sheet with the default 'no talk' choice when it appears so the clock
/// resumes. Bounded to ~150 match minutes of pumping so a broken ticker
/// fails fast instead of hanging.
Future<void> _playToFullTime(WidgetTester tester) async {
  for (var i = 0; i < 300; i++) {
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
      // T-0118: the fixture line shows the bare opponent name (the
      // home/away pill sits in the card's top end) with the #N table
      // position, so the old 'vs X (home)' prefix is gone. The name
      // also appears in the build-up screen later, so the finder
      // targets the fixture card's Text.rich via the table-position
      // suffix the card uniquely renders.
      expect(find.text('Start your first season'), findsNothing);
      expect(
        find.textContaining(opponent.opponentName),
        findsWidgets,
      );
      expect(find.text('Play match'), findsOneWidget);

      // Kick-off: the matchday build-up screen comes first (GDD 13): the
      // opponent analysis (header with position and form, loss/draw/win
      // row, then the opponent's starting XI on the Team tab's pitch —
      // 2026-11-13 replaced the strength bars and top-player cards),
      // then the dressing-room pep talk.
      await tester.tap(find.text('Play match'));
      await _flush(tester, wait: const Duration(milliseconds: 900));
      expect(find.text(opponent.opponentName), findsOneWidget);
      expect(find.text('LOSS'), findsOneWidget);
      expect(find.text('WIN'), findsOneWidget);
      expect(find.text('STRENGTH'), findsNothing);
      // The formation section sits below the fold: scroll the analysis.
      // T-0131: the "Their starting XI" label is gone — the opponent's
      // crest + name lead the card now, so scroll to the pitch itself.
      await tester.dragUntilVisible(
        find.byType(SquadPitch),
        find.byType(Scrollable).first,
        const Offset(0, -120),
      );
      await _flush(tester, wait: const Duration(milliseconds: 200));
      // All eleven opponent starters stand on the pitch surface.
      expect(find.byType(SquadPitch), findsOneWidget);
      expect(
        tester
            .widgetList<FcmMiniCard>(find.byType(FcmMiniCard))
            .where((c) => !c.ghost)
            .length,
        11,
      );

      // Continue into the tactics phase (GDD 10.4): the SAME screen as
      // the Tactics tab — a compact control card (team rating + TACTICS
      // button) over the pitch with per-player stats and stamina bars,
      // then bench and reserves — but match-only. T-0132: the intro
      // title block is gone; the phase opens straight onto the surface.
      await tester.tap(find.text('CONTINUE'));
      await _flush(tester, wait: const Duration(milliseconds: 600));
      expect(find.text('TEAM RATING'), findsOneWidget);
      // The control card's TACTICS button — the setup summary row is
      // gone on match surfaces (T-0092), so the word appears once.
      expect(find.text('TACTICS'), findsOneWidget);

      // The tactic options live in a bottom sheet behind the TACTICS
      // button; the label and the button share the word, so tap the
      // BUTTON itself. The sheet shows the three instruction-group
      // sections (GDD 10.2) with their real phase-1/2/3 controls at
      // the defaults: In Possession, Out of Possession and
      // Transitions, each with its visible summary.
      await tester.tap(
        find.descendant(
          of: find.byType(FcmButton),
          matching: find.text('TACTICS'),
        ),
      );
      await _flush(tester, wait: const Duration(milliseconds: 600));
      expect(find.text('TACTIC OPTIONS'), findsOneWidget);
      expect(find.text('In Possession'), findsOneWidget);
      expect(find.text('Out of Possession'), findsOneWidget);
      expect(find.text('Transitions'), findsOneWidget);
      // The Transitions rows assert the CURRENT structure, not a
      // fragile count: the row labels render uppercased (the
      // attack-on-recovery row reads 'ON RECOVERY' since the axis
      // copy table's naming pass) and the default mid-slider band
      // pills read '3 stay back' (rest defence) — the slider bands
      // come from the axis copy table, not the enum display names.
      // T-0128: the sheet is tabbed — those rows live on the
      // Transitions tab, not the opening In-Possession page.
      await tester.tap(find.text('Transitions'));
      await _flush(tester, wait: const Duration(milliseconds: 400));
      expect(find.text('COUNTER-PRESS'), findsOneWidget);
      expect(find.text('ON RECOVERY'), findsOneWidget);
      expect(find.text('REST DEFENCE'), findsOneWidget);
      expect(find.text('3 stay back'), findsOneWidget);
      expect(find.text('Default setup'), findsNothing);

      // Close the options sheet — DONE sits below the fold of the
      // scrollable sheet (ten sliders tall since T-0064) — reveal it,
      // then tap.
      await tester.ensureVisible(find.text('DONE'));
      await _flush(tester, wait: const Duration(milliseconds: 300));
      await tester.tap(find.text('DONE'));
      await _flush(tester, wait: const Duration(milliseconds: 600));

      // On to the dressing room (GDD 15.1 pre-match pep talk).
      await tester.tap(find.text('TO DRESSING ROOM'));
      await _flush(tester, wait: const Duration(milliseconds: 600));
      expect(find.text('DRESSING ROOM'), findsOneWidget);
      expect(find.text('Deliver your team talk'), findsOneWidget);

      // The tactic selection did NOT touch the club's saved default setup:
      // match-only semantics (GDD 10.4) — persistence happens nowhere before
      // kick-off, and never for tactics/mentality/formation chosen here.
      final clubAfterTactics = await tester.runAsync(store.getClub);
      expect(clubAfterTactics!.tactics, '{}');

      // Kick off with the default 'no talk' tile selected.
      await tester.tap(find.text('KICK OFF'));
      await _flush(tester, wait: const Duration(milliseconds: 900));

      // The live match screen is pushed over the shell: real club names on
      // the scoreboard, the auto-play controls (pause + 1x–3x speed; no
      // skip-to-end exists anywhere) and the tactics entry point.
      expect(find.text('D1'), findsOneWidget);
      expect(find.text('Round 1'), findsOneWidget);
      // Broadcast abbreviations replace the full club names (owner
      // request 2026-11-13): 'FC Rivals' reads 'FCR' on the scoreline.
      expect(find.text('FCR'), findsOneWidget);
      expect(find.text(opponent.opponentName), findsNothing,
          reason: 'the scoreline abbreviates, full names are gone');
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
      expect(find.text('4x'), findsNothing);
      expect(find.text('Next minute'), findsNothing);
      expect(find.text('Sim to end'), findsNothing);

      // The match plays itself: pump real time and the ticker advances
      // match minutes. Flip to 3x first (267ms per match minute), handle
      // the half-time talk when the clock holds, then play to full time.
      await tester.tap(find.text('3x'));
      await tester.pump(const Duration(milliseconds: 50));
      await _playToFullTime(tester);

      // T-0100: full time lands straight on the report — the
      // post-match recovery touchline card is gone.
      await _flush(tester);
      await _flush(tester);
      expect(find.text('Post-match recovery'), findsNothing);

      // The report screen shows the result and reward, named for the real
      // fixture (GDD 14 post-match screen). The full-match momentum graph
      // replaced the team-statistics table.
      expect(find.textContaining('Full time: FC Rivals'), findsOneWidget);
      expect(find.textContaining('Reward:'), findsOneWidget);
      expect(find.text('Team statistics'), findsNothing);
      expect(find.text('Momentum'), findsOneWidget);

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
