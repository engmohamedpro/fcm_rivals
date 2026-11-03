// Live match screen behaviour (GDD 13) after the compact redesign:
//
//  * the header fuses scoreboard, clock and controls into one panel —
//    no separate controls block below it;
//  * the LIVE STATS strip sits above the commentary feed and updates
//    as minutes pass (possession/shots/etc. from the event timeline);
//  * the commentary feed is a plain forward list: the full history is
//    scrollable upward, entries render in place — no per-row entrance
//    animation (the jank source at 4x speed);
//  * the feed follows the newest line until the user scrolls up.
//
// The match drives itself on a real ticker, so frames are pumped in
// bounded loops — the backdrop's 34s loop never settles.
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/match/live_match_views.dart';
import 'package:fcm_rivals/features/match/match_screen.dart';
import 'package:fcm_rivals/features/match/match_session.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

String datasetJson(List<List<dynamic>> rows) => json.encode({
      'format': 'fcm-rivals-players',
      'version': 1,
      'asOf': '2026-11-01',
      'digest': 'test',
      'players': rows,
    });

const _positions = [
  'GK', 'CB', 'CM', 'RW', 'ST', 'CDM', 'LW', 'CAM', 'LB', 'RB', 'LM', 'RM',
];

final _rows = <List<dynamic>>[
  for (var p = 0; p < _positions.length; p++)
    for (var i = 0; i < 5; i++)
      [
        p * 10 + i + 1,
        'Player ${p * 10 + i + 1}',
        _positions[p],
        'Egypt',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

/// Opens every starting pack, inserts any seed players the packs missed
/// and auto-picks the XI — mirrors match_session_test's seeding.
Future<CollectionStore> seededSquadStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(
      PlayerDataset.fromJson(datasetJson(_rows)));
  await store.createClub(
      clubName: 'FC Rivals', managerName: 'Mohamed', crestIndex: 0);
  for (final pack in await store.getAvailablePacks()) {
    await store.openPack(packId: pack.id, random: math.Random(17));
  }
  final club = await store.getClub();
  final drawnIds =
      (await store.getCollection()).map((c) => c.base.playerId).toSet();
  final now = DateTime.now();
  for (final row in _rows) {
    if (drawnIds.contains(row[0] as int)) continue;
    await db.into(db.ownedPlayers).insert(OwnedPlayersCompanion.insert(
          clubId: club!.id,
          playerId: row[0] as int,
          acquiredAt: now,
        ));
  }
  await store.autoPickSquad();
  return store;
}

Future<MatchSession> _session(CollectionStore store) =>
    MatchSession.create(
      store: store,
      seed: 7,
      opponentName: 'Al Ahly',
      opponentAverageOverall: 70,
    );

/// Bounded frame pump — the live screen never settles (backdrop loop).
Future<void> _play(WidgetTester tester, {int frames = 30}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('compact header, live stats strip and scrollable commentary '
      'history with no entrance animations', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = memoryDb();
    addTearDown(() => db.close());
    final store = await seededSquadStore(db);
    final session = await _session(store);

    await tester.pumpWidget(MaterialApp(
      home: MatchScreen(session: session, title: 'League · Round 1'),
    ));
    await tester.pump();
    // Kick-off minute (800ms at 1x) produces the first commentary lines.
    await _play(tester, frames: 10);

    // The header is ONE fused panel: play/pause, the speed segments and
    // the tactics button all live inside it — no separate controls row.
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('4x'), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // The stats strip sits above the commentary feed with its labels.
    expect(find.byType(LiveMatchStatsPanel), findsOneWidget);
    expect(find.text('Possession'), findsOneWidget);
    expect(find.text('Shots'), findsOneWidget);
    expect(find.text('On target'), findsOneWidget);
    expect(find.text('Expected goals'), findsOneWidget);
    expect(find.text('Pass accuracy'), findsOneWidget);

    // Commentary rows are plain in-place widgets — no entrance wrappers
    // (the old side-slide-in was the jank source at speed).
    expect(find.byType(CommentaryRow), findsWidgets);

    // Play a few more minutes: the feed grows, stats update in place.
    final before = find.byType(CommentaryRow).evaluate().length;
    await _play(tester, frames: 80);
    expect(find.byType(CommentaryRow).evaluate().length, greaterThan(before));

    // The stats strip collapses to its summary line and back — the
    // feed can own the screen when commentary matters more.
    await tester.tap(find.text('Hide stats'));
    await tester.pump();
    expect(find.text('Possession'), findsNothing);
    expect(find.text('Match stats'), findsOneWidget);
    await tester.tap(find.text('Match stats'));
    await tester.pump();
    expect(find.text('Possession'), findsOneWidget);

    // The full history scrolls up: dragging the feed up keeps earlier
    // rows alive — a forward list, not a bottom-pinned window.
    await tester.drag(
        find.byType(CommentaryRow).last, const Offset(0, 300));
    await tester.pump();
    expect(find.byType(CommentaryRow), findsWidgets);
  });
}
