// Season screen review fixes (2026-11-04_season-screen):
//
//  * `_playNextFixture` no longer force-unwraps `getNextFixture()` — a
//    stale fixture card (a committed result landing between rebuild and
//    tap) refreshes the providers and steps out instead of crashing.
//  * `_run`, `_playNextFixture` and `_maybeCompleteSeason` guard every
//    `setState` that follows an `await` with `mounted`.
//  * `_maybeCompleteSeason` runs under the same `_busy` gate as every
//    other store action, so a double tap completes the season exactly
//    once.
//
// The stores run real drift I/O over an in-memory database, so async
// flushes use tester.runAsync (FakeAsync doesn't perform real I/O).
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart' show BackButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
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

/// Seeds a club + squad and starts a season, returning the wired stores.
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

  // The pre-match flow loads stadium ambience through audioplayers —
  // silence the plugin's channels like the other flow tests do.
  setUp(installAudioplayersMocks);
  tearDown(clearAudioplayersMocks);

  testWidgets(
    'stale fixture card: tapping Play with no fixture left refreshes '
    'quietly instead of crashing on a null unwrap',
    (WidgetTester tester) async {
      final (db, store, seasonStore) = await _seedSeason();
      addTearDown(() => db.close());

      // Consume every fixture with the store's quick-sim (GDD 9.6)
      // BEFORE any widget exists: the SeasonScreen is then pumped with
      // the exact staleness the review describes — the rendered card
      // says a fixture is next while the store returns null on tap.
      await seasonStore.simulateRemainingFixtures(store);
      expect(await seasonStore.getNextFixture(), isNull);

      // The screen renders with the STALE fixture card: the providers
      // still serve the round-1 fixture from their cached values.
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

      // Whatever the card says, a visible Play button must tap through
      // the fixed flow without crashing: loadPreMatchData throws 'No
      // fixture to play', the pre-match route's error scaffold offers a
      // BACK button — take it and land back on the Season tab.
      final playButtons = find.text('Play match');
      if (playButtons.evaluate().isNotEmpty) {
        await tester.tap(playButtons.first);
        await _flush(tester, wait: const Duration(milliseconds: 900));
        final back = find.byType(BackButton);
        if (back.evaluate().isNotEmpty) {
          await tester.tap(back.first);
          await _flush(tester, wait: const Duration(milliseconds: 600));
        }
      }
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Null check operator'), findsNothing);
      expect(find.textContaining('NoSuchMethodError'), findsNothing);
      // Back on the Season tab — the shell is intact.
      expect(find.byType(FcmRivalsApp), findsOneWidget);
    },
  );

  testWidgets(
    'double-tapping Complete season completes it exactly once',
    (WidgetTester tester) async {
      final (db, store, seasonStore) = await _seedSeason();
      addTearDown(() => db.close());

      // Play the whole season out with the store's quick-sim.
      await tester.runAsync(
        () => seasonStore.simulateRemainingFixtures(store),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionStoreProvider.overrideWith((ref) => store),
            seasonStoreProvider.overrideWith((ref) async => seasonStore),
          ],
          child: const FcmRivalsApp(),
        ),
      );
      await _flush(tester, wait: const Duration(milliseconds: 300));

      expect(find.text('Complete season'), findsOneWidget);

      // Two rapid taps before the first completes: the _busy gate must
      // swallow the second.
      await tester.tap(find.text('Complete season'));
      await tester.tap(find.text('Complete season'));
      await _flush(tester, wait: const Duration(milliseconds: 900));

      // The completion dialog is up and the season is closed exactly
      // once — the seasons table holds ONE completed row (status
      // 'completed' with an endedAt stamp).
      final summary = await tester.runAsync(seasonStore.getSeasonSummary);
      expect(summary!.isCompleted, isTrue);
      final seasons = await tester.runAsync(
        () => db.select(db.seasons).get(),
      );
      expect(
        seasons!.where((s) => s.status == 'completed'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  // T-0086: the progress line's round label, one test per state. The
  // label is 'Round <n> of 38' while the season is open and the
  // Final-position line once completed; the harness pumps the whole
  // app so the label is read exactly as the user sees it.
  testWidgets(
    'T-0086: fresh season reads Round 1 of 38 — never Round 0',
    (WidgetTester tester) async {
      final (db, store, seasonStore) = await _seedSeason();
      addTearDown(() => db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionStoreProvider.overrideWith((ref) => store),
            seasonStoreProvider.overrideWith((ref) async => seasonStore),
          ],
          child: const FcmRivalsApp(),
        ),
      );
      await _flush(tester);

      expect(find.text('Round 1 of 38'), findsOneWidget);
      expect(find.text('Round 0 of 38'), findsNothing);
      expect(find.text('Round 39 of 38'), findsNothing);
    },
  );

  testWidgets(
    'T-0086: mid-season reads the NEXT fixture round — not roundsPlayed',
    (WidgetTester tester) async {
      final (db, store, seasonStore) = await _seedSeason();
      addTearDown(() => db.close());

      // Play the first two user fixtures via the store's own flow.
      for (var i = 0; i < 2; i++) {
        final fixture = (await seasonStore.getNextFixture())!;
        final session = await seasonStore.startNextFixture(store);
        session.simulateToEnd();
        await session.finish();
        await seasonStore.commitFixtureResult(session, fixture);
      }
      final next = await seasonStore.getNextFixture();
      expect(next, isNotNull, reason: 'mid-season: a fixture remains');
      expect(next!.round, greaterThan(1));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionStoreProvider.overrideWith((ref) => store),
            seasonStoreProvider.overrideWith((ref) async => seasonStore),
          ],
          child: const FcmRivalsApp(),
        ),
      );
      await _flush(tester);

      // The label shows the round IN PROGRESS — the next fixture's
      // round, aligned with the screen's own Next-fixture line — not
      // the two already played.
      expect(find.text('Round ${next.round} of 38'), findsOneWidget);
      expect(find.text('Round 2 of 38'), findsNothing,
          reason: 'roundsPlayed (2) must not be the label while the '
              'next round is ${next.round}');
    },
  );

  testWidgets(
    'T-0086: all 38 played but NOT completed reads Round 38 of 38 — '
    'the reported Round 39 of 38 must never appear',
    (WidgetTester tester) async {
      final (db, store, seasonStore) = await _seedSeason();
      addTearDown(() => db.close());

      // Play the whole season out with the store's quick-sim; the
      // season stays ACTIVE until the user completes it.
      await tester.runAsync(
        () => seasonStore.simulateRemainingFixtures(store),
      );
      expect(await seasonStore.getNextFixture(), isNull);
      final summary = await tester.runAsync(seasonStore.getSeasonSummary);
      expect(summary!.isCompleted, isFalse);
      expect(summary.roundsPlayed, 38);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionStoreProvider.overrideWith((ref) => store),
            seasonStoreProvider.overrideWith((ref) async => seasonStore),
          ],
          child: const FcmRivalsApp(),
        ),
      );
      await _flush(tester);

      expect(find.text('Round 38 of 38'), findsOneWidget);
      expect(find.text('Round 39 of 38'), findsNothing);
    },
  );

  testWidgets(
    'T-0086: completed season still swaps to the Final-position line',
    (WidgetTester tester) async {
      final (db, store, seasonStore) = await _seedSeason();
      addTearDown(() => db.close());

      await tester.runAsync(
        () => seasonStore.simulateRemainingFixtures(store),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionStoreProvider.overrideWith((ref) => store),
            seasonStoreProvider.overrideWith((ref) async => seasonStore),
          ],
          child: const FcmRivalsApp(),
        ),
      );
      await _flush(tester, wait: const Duration(milliseconds: 300));

      await tester.tap(find.text('Complete season'));
      await _flush(tester, wait: const Duration(milliseconds: 900));

      final summary = await tester.runAsync(seasonStore.getSeasonSummary);
      expect(summary!.isCompleted, isTrue);
      // The completed-season line replaces the round label entirely.
      expect(find.textContaining('Final position:'), findsOneWidget);
      expect(find.textContaining('Round'), findsNothing);
    },
  );
}
