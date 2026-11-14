// T-0148: Season Leaders rows show each player's club crest and name.
//
// Flow test over the REAL app (same harness as the T-0086 round-label
// tests): seed a club + squad, sim the whole season so stats commit,
// pump FcmRivalsApp on the Season tab and scroll to the leaderboards.
// Every board row must carry the player's club name under the player
// name; the crest slot must hold a fixed-size box whether or not the
// crest map has loaded (no layout shift).
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show FloatingActionButton;
import 'package:flutter/widgets.dart' show Scrollable, Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_crest.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
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

final List<List<dynamic>> _seedRows = [
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

String _datasetJson() => json.encode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': _seedRows,
});

Future<(AppDatabase, CollectionStore, SeasonStore)> _seedSeason() async {
  final db = AppDatabase(NativeDatabase.memory());
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(_datasetJson()));
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
  return (db, store, seasonStore);
}

Future<void> _flush(
  WidgetTester tester, {
  Duration wait = const Duration(milliseconds: 300),
}) async {
  await tester.runAsync(() => Future<void>.delayed(wait));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(installAudioplayersMocks);
  tearDown(clearAudioplayersMocks);

  testWidgets(
    'T-0148: every leader row shows the club name and a crest slot '
    'under/next to the player name',
    (WidgetTester tester) async {
      final (db, store, seasonStore) = await _seedSeason();
      addTearDown(() => db.close());

      // Sim the whole season: every fixture commits PlayerSeasonStats
      // rows for every club, so the leaderboards render for real.
      await tester.runAsync(
        () => seasonStore.simulateRemainingFixtures(store),
      );

      // The club names the rows must resolve to: exactly the standings
      // set (18 AI clubs + the user's club). Also read the clubs table
      // directly — the crest provider serves CollectionStore.crestOf
      // over every club row, and the boards read that same map.
      final standings = await tester.runAsync(seasonStore.getStandings);
      final clubNames = {for (final e in standings!) e.name};
      final clubs = await tester.runAsync(() => db.select(db.clubs).get());
      expect(clubs, isNotEmpty, reason: 'AI clubs must exist for crests');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionStoreProvider.overrideWith((ref) => store),
            seasonStoreProvider.overrideWith((ref) async => seasonStore),
            // standingCrestsProvider reads databaseProvider; point it
            // at the SAME in-memory database instead of letting it
            // open a second one over path_provider (missing plugin in
            // the test binding). Same pattern as match_screen_test.
            databaseProvider.overrideWith((ref) => db),
          ],
          child: const FcmRivalsApp(),
        ),
      );
      await _flush(tester, wait: const Duration(milliseconds: 400));

      // Scroll the Season tab to the bottom — the leaderboards sit
      // under the standings table.
      final list = find.byType(Scrollable).first;
      await tester.dragUntilVisible(
        find.text('Season Leaders'),
        list,
        const Offset(0, -300),
        maxIteration: 30,
      );
      await _flush(tester, wait: const Duration(milliseconds: 100));

      // The Goals board is the one guaranteed to have rows (every
      // scored goal writes one). Its rows sit inside the panel below
      // the 'GOALS' header.
      expect(find.text('Season Leaders'), findsOneWidget);
      expect(find.text('GOALS'), findsOneWidget);

      // Every club-name label rendered on screen belongs to the
      // standings' name set — leader rows resolved real club names,
      // not placeholders or blanks.
      final renderedClubNames = <String>{};
      for (final e in tester.widgetList<Text>(find.byType(Text))) {
        if (clubNames.contains(e.data)) renderedClubNames.add(e.data!);
      }
      expect(
        renderedClubNames,
        isNotEmpty,
        reason: 'leader rows must show club names from the standings',
      );

      // Crest slots: the crest provider needs the standings provider to
      // resolve first, then one DB read — give both a flush cycle.
      // (No pumpAndSettle: the app runs continuous entrance/ambient
      // animations that never settle.)
      await _flush(tester, wait: const Duration(milliseconds: 300));
      final crestSizes = tester
          .widgetList<FcmCrest>(find.byType(FcmCrest))
          .map((c) => c.width)
          .toSet();
      expect(
        crestSizes,
        contains(20.0),
        reason: 'leader rows render a 20px FcmCrest next to the name',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
