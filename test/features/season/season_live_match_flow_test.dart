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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_store.dart';
import 'package:fcm_rivals/main.dart';

const List<List<String>> _seedPositions = [
  ['GK', 'Keeper'], ['CB', 'Back'], ['CM', 'Midfield'], ['RW', 'Wing'],
  ['ST', 'Striker'], ['CDM', 'Anchor'], ['LW', 'Winger'], ['CAM', 'Playmaker'],
  ['LB', 'Leftback'], ['RB', 'Rightback'], ['LM', 'Leftmid'], ['RM', 'Rightmid'],
];

final List<List<dynamic>> seedRows = [
  for (var p = 0; p < _seedPositions.length; p++)
    for (var i = 0; i < 5; i++)
      [
        p * 10 + i + 1,
        '${_seedPositions[p][1]} ${p * 10 + i + 1}',
        _seedPositions[p][0],
        20 + i,
        'Egypt',
        i % 2 == 0 ? 'Al Ahly' : 'Zamalek',
        'EG1',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

String datasetJson(List<List<dynamic>> rows) => json.encode({
      'format': 'fcm-rivals-players',
      'version': 1,
      'asOf': '2026-11-01',
      'leagues': const {'EG1': 'Egyptian Premier League'},
      'digest': 'test',
      'players': rows,
    });

/// Flushes pending real async I/O (drift transactions) and settles frames.
Future<void> _flush(WidgetTester tester, {Duration wait = const Duration(milliseconds: 300)}) async {
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
    // The half-time sheet holds the clock — dismiss via the barrier
    // (same as the 'no talk' choice below the fold).
    if (find.text('Half-time pep talk').evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(400, 20));
      await tester.pump(const Duration(milliseconds: 400));
    }
    if (find.text('Post-match recovery').evaluate().isNotEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'league fixture plays as a live match from the Season tab and commits',
      (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = CollectionStore(db: db);
    await store.applyDatasetUpdate(
        PlayerDataset.fromJson(datasetJson(seedRows)));
    await store.createClub(
        clubName: 'FC Rivals', managerName: 'Mohamed', crestIndex: 0);
    for (final pack in await store.getAvailablePacks()) {
      await store.openPack(packId: pack.id, random: math.Random(17));
    }
    await store.autoPickSquad();
    final seasonStore = SeasonStore(db: db, random: math.Random(4));
    await seasonStore.startSeason(division: 1);
    final opponent = (await seasonStore.getNextFixture())!;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) => store),
        seasonStoreProvider.overrideWith((ref) async => seasonStore),
      ],
      child: const FcmRivalsApp(),
    ));
    await _flush(tester, wait: const Duration(milliseconds: 200));

    // The Season tab lists the round-1 home fixture against an AI club.
    expect(find.text('Start your first season'), findsNothing);
    expect(find.textContaining('vs ${opponent.opponentName}'),
        findsOneWidget);
    expect(find.text('Play match'), findsOneWidget);

    // Kick-off: the matchday build-up screen comes first (GDD 13): the
    // VS header with the forecast, then the dressing-room pep talk.
    await tester.tap(find.text('Play match'));
    await _flush(tester, wait: const Duration(milliseconds: 900));
    expect(find.text('MATCH FORECAST'), findsOneWidget);
    expect(find.text('STRENGTH'), findsOneWidget);
    expect(find.textContaining('simulated matches'), findsOneWidget);

    // Continue into the dressing room (GDD 15.1 pre-match pep talk).
    await tester.tap(find.text('CONTINUE'));
    await _flush(tester, wait: const Duration(milliseconds: 600));
    expect(find.text('DRESSING ROOM'), findsOneWidget);
    expect(find.text('Deliver your team talk'), findsOneWidget);

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

    // Post-match recovery sheet (GDD 15.3/19.3) — dismiss for the default
    // recovery (same as the 'No pep talk' tile below the fold).
    await _flush(tester);
    expect(find.text('Post-match recovery'), findsOneWidget);
    await tester.tapAt(const Offset(400, 20));
    await _flush(tester);

    // The report screen shows the result and reward, named for the real
    // fixture (GDD 14 post-match screen).
    expect(find.textContaining('Full time: FC Rivals'), findsOneWidget);
    expect(find.textContaining('Reward:'), findsOneWidget);
    expect(find.text('Team statistics'), findsOneWidget);

    // Back to the Season tab; providers refresh after the route pops.
    await tester.pageBack();
    await _flush(tester);

    // The fixture committed (FR-038): exactly one result row for the
    // fixture, the user club has played once in the standings and the
    // next fixture is round 2 (AI lockstep kept the round in sync).
    final results = await tester.runAsync(() async =>
        (db.select(db.matchResults)
              ..where((r) => r.fixtureId.equals(opponent.fixtureId)))
            .get());
    expect(results, hasLength(1));

    final standings = await tester.runAsync(seasonStore.getStandings);
    final user = standings!.firstWhere((e) => e.name == 'FC Rivals');
    expect(user.played, 1);

    final next = await tester.runAsync(seasonStore.getNextFixture);
    expect(next!.round, 2);

    await db.close();
  });
}
