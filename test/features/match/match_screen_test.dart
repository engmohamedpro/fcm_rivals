// Live match screen behaviour (GDD 13) after the compact redesign:
//
//  * the header fuses scoreboard, clock and controls into one panel —
//    no separate controls block below it;
//  * the MOMENTUM bar sits above the commentary — one vertical line
//    per minute, home pressure above the baseline, away pressure below
//    it (the broadcast stats rows are gone entirely);
//  * the commentary is ONE moment at a time, lower-third style
//    (Football Manager style): the newest line replaces the last over
//    the open pitch — no scrolling history, no per-row entrance
//    animation (the jank source at 4x speed).
//
// The match drives itself on a real ticker, so frames are pumped in
// bounded loops — the backdrop's 34s loop never settles.
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/match/commentary_ticker.dart';
import 'package:fcm_rivals/features/match/live_match_views.dart';
import 'package:fcm_rivals/features/match/match_screen.dart';
import 'package:fcm_rivals/features/match/match_session.dart';
import 'package:fcm_rivals/features/match/stamina.dart' show PepTalk;
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';

import '../../helpers/audioplayers_mocks.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

String datasetJson(List<List<dynamic>> rows) => json.encode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': rows,
});

const _positions = [
  'GK',
  'CB',
  'CM',
  'RW',
  'ST',
  'CDM',
  'LW',
  'CAM',
  'LB',
  'RB',
  'LM',
  'RM',
];

final _rows = <List<dynamic>>[
  for (var p = 0; p < _positions.length; p++)
    for (var i = 0; i < 5; i++)
      [
        p * 10 + i + 1,
        'Player ${p * 10 + i + 1}',
        _positions[p],
        // Distinct per player: the UI fixtures stay chemistry-neutral
        // (0%), so engineered results (e.g. the defeat that shows the
        // ad-boosted recovery row) keep their meaning now that the
        // engine applies nationality chemistry (T-0067).
        'Country ${p * 10 + i + 1}',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

/// Opens every starting pack, inserts any seed players the packs missed
/// and auto-picks the XI — mirrors match_session_test's seeding.
Future<CollectionStore> seededSquadStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(datasetJson(_rows)));
  await store.createClub(
    clubName: 'FC Rivals',
    managerName: 'Mohamed',
    crestIndex: 0,
  );
  for (final pack in await store.getAvailablePacks()) {
    await store.openPack(packId: pack.id, random: math.Random(17));
  }
  final club = await store.getClub();
  final drawnIds = (await store.getCollection())
      .map((c) => c.base.playerId)
      .toSet();
  final now = DateTime.now();
  for (final row in _rows) {
    if (drawnIds.contains(row[0] as int)) continue;
    await db
        .into(db.ownedPlayers)
        .insert(
          OwnedPlayersCompanion.insert(
            clubId: club!.id,
            playerId: row[0] as int,
            acquiredAt: now,
          ),
        );
  }
  await store.autoPickSquad();
  return store;
}

Future<MatchSession> _session(CollectionStore store) => MatchSession.create(
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

  // The live match screen plays stadium ambience through audioplayers:
  // quiet the plugin's channels so widget tests don't drown in
  // MissingPluginException noise.
  setUp(installAudioplayersMocks);
  tearDown(clearAudioplayersMocks);

  testWidgets('compact header, momentum bar and one-moment commentary '
      'ticker with no scrolling history', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = memoryDb();
    addTearDown(() => db.close());
    final store = await seededSquadStore(db);
    final session = await _session(store);

    await tester.pumpWidget(
      MaterialApp(
        home: MatchScreen(session: session, title: 'League · Round 1'),
      ),
    );
    await tester.pump();
    // Kick-off minute (800ms at 1x) produces the first commentary lines.
    await _play(tester, frames: 10);

    // The header is ONE fused panel: play/pause, the speed segments and
    // the tactics button all live inside it — no separate controls row.
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('3x'), findsOneWidget);
    // 4x is gone — the ladder stops at 3x.
    expect(find.text('4x'), findsNothing);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

    // The momentum bar rides where the old stats strip sat — between
    // the header and the feed, with the team names at its two ends and
    // the MOMENTUM label centred. The broadcast stats rows are gone.
    expect(find.byType(MomentumBar), findsOneWidget);
    expect(find.text('MOMENTUM'), findsOneWidget);
    expect(find.text('Possession'), findsNothing);
    expect(find.text('Shots'), findsNothing);
    expect(find.text('On target'), findsNothing);
    expect(find.text('Expected goals'), findsNothing);
    expect(find.text('Passes'), findsNothing);
    expect(find.text('Fouls'), findsNothing);
    expect(find.text('Corners'), findsNothing);
    expect(find.text('Match stats'), findsNothing);

    // Commentary is ONE moment at a time, lower-third style — the
    // newest line replaces the last; there is no scrolling history.
    expect(find.byType(CommentaryTicker), findsOneWidget);
    final first = tester
        .widget<CommentaryTicker>(find.byType(CommentaryTicker))
        .line;

    // Play a few more minutes: the moment swaps, the bar repaints in
    // place, and the ticker never multiplies.
    await _play(tester, frames: 80);
    expect(find.byType(CommentaryTicker), findsOneWidget);
    final later = tester
        .widget<CommentaryTicker>(find.byType(CommentaryTicker))
        .line;
    // The moment moved on: a later minute, a different line — but the
    // bar never stacked a second ticker.
    expect(later.minute, greaterThan(first.minute));
    // No scrolling surface exists any more — the pitch owns the space.
    expect(
      find.byType(Scrollable),
      findsNothing,
      reason: 'the ticker replaced the scrolling history feed',
    );
  });

  testWidgets('full-time report: user team ratings tab opens first, '
      'opponent one tap away; xG and pass accuracy absent', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Flushes pending real async I/O (drift persistence) + bounded frames.
    Future<void> flush({
      Duration wait = const Duration(milliseconds: 300),
    }) async {
      await tester.runAsync(() => Future<void>.delayed(wait));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final db = memoryDb();
    addTearDown(() => db.close());
    final store = await seededSquadStore(db);
    final session = await _session(store);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: MaterialApp(
          home: MatchScreen(session: session, title: 'League · Round 1'),
        ),
      ),
    );
    await tester.pump();

    // Race to full time at 3x (267ms per match minute).
    await tester.tap(find.text('3x'));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.text('HALF TIME').evaluate().isNotEmpty) {
        await tester.tap(find.text('Say nothing — back to the match'));
        await tester.pump(const Duration(milliseconds: 400));
      }
      if (find.text('Post-match recovery').evaluate().isNotEmpty) break;
    }
    // The full-time touchline card: skip the talk, then let the match
    // session persist stamina/rewards and produce the report.
    await tester.tap(find.text('No pep talk — default recovery'));
    await flush();
    for (var i = 0; i < 5; i++) {
      if (find.textContaining('Full time:').evaluate().isNotEmpty) break;
      await flush();
    }

    // The report is up.
    expect(find.textContaining('Full time:'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    // The team-statistics table is GONE — the full-match momentum graph
    // replaces it under the 'Momentum' section title (the live bar's
    // series at full time). xG and pass accuracy never appear.
    expect(find.text('Team statistics'), findsNothing);
    expect(find.text('Momentum'), findsOneWidget);
    expect(find.byType(MomentumBar), findsOneWidget);
    expect(find.text('Expected goals'), findsNothing);
    expect(find.text('Pass accuracy'), findsNothing);

    // ONE tabbed ratings panel: the user's club ('FC Rivals') is the
    // active tab and its squad is the list shown — the opponent's
    // players are one tap away, not stacked below.
    expect(find.text('Player ratings'), findsOneWidget);
    final clubTab = find.text('FC Rivals');
    expect(clubTab, findsWidgets);

    // FC Rivals players are listed under the open tab.
    int ratingRows() => find
        .byType(Padding)
        .evaluate()
        .where((e) => e.widget is Padding && (e.widget as Padding).child is Row)
        .length;
    final shownForClub = ratingRows();
    expect(find.textContaining('Player ').evaluate().length, greaterThan(0));

    // Switch to the opponent tab: a different set of rows appears
    // (opponent players are generated, not the 'Player N' dataset).
    // The opponent's name also appears as the momentum-graph legend
    // ABOVE the ratings section — target the tappable tab specifically
    // (the FcmPressable carrying the label), or the tap lands on the
    // inert legend and the list never switches.
    final opponentTab = find.widgetWithText(FcmPressable, 'Al Ahly');
    expect(opponentTab, findsOneWidget);
    await tester.tap(opponentTab);
    await tester.pump(const Duration(milliseconds: 300));
    // The opponent squad is listed now — every 'Player N' name has been
    // swapped for 'Al Ahly XX' rows ('Player ratings' section header is
    // the only 'Player ' text left).
    // 'Player ratings' (section header) is the only 'Player ' text left
    // on the screen after the swap — the ratings list shows opponent
    // rows. The Man of the Match can be a user player ('Player N') OR
    // an opponent player ('Al Ahly XX'): whoever rated highest won it,
    // so accept either and only pin down that the list itself swapped.
    final remaining = find
        .textContaining('Player ')
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .where((t) => t.startsWith('Player '))
        .toList();
    expect(remaining, contains('Player ratings'));
    expect(remaining.length, lessThanOrEqualTo(2));
    if (remaining.length == 2) {
      final mom = remaining.where((t) => t != 'Player ratings').first;
      expect(
        RegExp(r'^Player ([1-9]|[1-5]\d|60)$').hasMatch(mom),
        isTrue,
        reason: 'MoM must be a user player when a user player wins it',
      );
    }
    expect(find.text('Al Ahly ST'), findsWidgets);

    // And back — the user's squad returns.
    await tester.tap(clubTab.first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Player ').evaluate().length, greaterThan(0));
    expect(ratingRows(), shownForClub);
  });

  // ---------------------------------------------------------------------
  // Post-match recovery card (GDD 15.3/19.3): the finish flow waits on a
  // Completer resolved by the card's taps — no polling — and the choice
  // is committed exactly once. Probed outcomes make the win/loss paths
  // deterministic: seed 7 + opponent 40 is a WIN, seed 3 + opponent 95
  // is a LOSS.
  // ---------------------------------------------------------------------

  /// The store each pumped session was built from, so the provider
  /// override can hand the SAME store to the screen's club lookups.
  final Map<MatchSession, CollectionStore> seededStoreCache = {};

  /// The database behind the current test's session — overriding
  /// databaseProvider keeps the club lookups on the SAME executor
  /// instead of opening a second drift instance (drift warns and
  /// races when two instances share one executor).
  AppDatabase? sessionDb;

  Future<MatchSession> winSession(CollectionStore store) async {
    final session = await MatchSession.create(
      store: store,
      seed: 7,
      opponentName: 'Al Ahly',
      opponentAverageOverall: 40,
    );
    seededStoreCache[session] = store;
    return session;
  }

  Future<MatchSession> lossSession(CollectionStore store) async {
    final session = await MatchSession.create(
      store: store,
      seed: 3,
      opponentName: 'Al Ahly',
      opponentAverageOverall: 95,
    );
    seededStoreCache[session] = store;
    return session;
  }

  Future<void> pumpMatch(
    WidgetTester tester,
    MatchSession session, {
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionStoreProvider.overrideWith(
            (ref) => seededStoreCache[session]!,
          ),
          databaseProvider.overrideWith((ref) => sessionDb!),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MatchScreen(session: session, title: 'League · Round 1'),
        ),
      ),
    );
    await tester.pump();
    // Race to full time at 3x (267ms per match minute).
    await tester.tap(find.text('3x'));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Bounded pump loop until the recovery card is up, dismissing the
  /// half-time talk on the way (the same pattern the full-time test
  /// above uses).
  Future<void> driveToRecoveryCard(
    WidgetTester tester, {
    String cardTitle = 'Post-match recovery',
  }) async {
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.text('HALF TIME').evaluate().isNotEmpty) {
        await tester.tap(find.text('Say nothing — back to the match'));
        await tester.pump(const Duration(milliseconds: 400));
      }
      if (find.text(cardTitle).evaluate().isNotEmpty) return;
    }
    fail('The recovery card never came up');
  }

  Future<void> flushFrames(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('recovery card: pep-talk tap is committed once and shown in '
      'the report (double tap picks the first)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = memoryDb();
    addTearDown(() => db.close());
    sessionDb = db;
    final store = await seededSquadStore(db);
    final session = await winSession(store);

    await pumpMatch(tester, session);
    await driveToRecoveryCard(tester);

    // Two rapid taps on different options in the same frame: the first
    // wins, the second is swallowed by the choice guard.
    await tester.tap(find.text(PepTalk.restEveryone.displayName));
    await tester.tap(find.text(PepTalk.focusExhausted.displayName));
    await tester.pump(const Duration(milliseconds: 100));

    // The card is gone immediately — the report lands after persistence.
    expect(find.text('Post-match recovery'), findsNothing);
    await flushFrames(tester);
    for (var i = 0; i < 5; i++) {
      if (find.textContaining('Full time:').evaluate().isNotEmpty) break;
      await flushFrames(tester);
    }

    expect(find.textContaining('Full time:'), findsOneWidget);
    // The chosen talk is restated on the report — not the second tap's.
    expect(
      find.textContaining(
        '${PepTalk.restEveryone.displayName} '
        '(+${(PepTalk.restEveryone.recoveryBonus * 100).round()}% recovery)',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(PepTalk.focusExhausted.displayName),
      findsNothing,
    );
    // A win never offered the ad boost — and none was applied.
    expect(find.textContaining('Ad-boosted recovery applied'), findsNothing);
  });

  testWidgets('recovery card: ad-boosted recovery after a defeat', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = memoryDb();
    addTearDown(() => db.close());
    sessionDb = db;
    final store = await seededSquadStore(db);
    final session = await lossSession(store);

    await pumpMatch(tester, session);
    await driveToRecoveryCard(tester);

    // A defeat offers the ad-boosted recovery row.
    expect(find.text('Watch ad: boosted recovery'), findsOneWidget);
    await tester.tap(find.text('Watch ad: boosted recovery'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Post-match recovery'), findsNothing);

    await flushFrames(tester);
    for (var i = 0; i < 5; i++) {
      if (find.textContaining('Full time:').evaluate().isNotEmpty) break;
      await flushFrames(tester);
    }

    expect(find.textContaining('Full time:'), findsOneWidget);
    expect(find.textContaining('Ad-boosted recovery applied'), findsOneWidget);
    // The boost replaced the pep talk (mutually exclusive, GDD 19.4).
    expect(find.textContaining(PepTalk.restEveryone.displayName), findsNothing);
  });

  testWidgets('recovery card: scrim skip demands a second tap — the '
      'first only arms the hint', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = memoryDb();
    addTearDown(() => db.close());
    sessionDb = db;
    final store = await seededSquadStore(db);
    final session = await winSession(store);

    await pumpMatch(tester, session);
    await driveToRecoveryCard(tester);

    // A stray tap on the dim scrim must NOT skip: it only arms the hint.
    await tester.tapAt(const Offset(400, 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('Tap outside again to skip without a pep talk'),
      findsOneWidget,
    );
    expect(find.text('Post-match recovery'), findsOneWidget);
    expect(find.textContaining('Full time:'), findsNothing);

    // The second tap confirms the skip.
    await tester.tapAt(const Offset(400, 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Post-match recovery'), findsNothing);

    await flushFrames(tester);
    for (var i = 0; i < 5; i++) {
      if (find.textContaining('Full time:').evaluate().isNotEmpty) break;
      await flushFrames(tester);
    }

    expect(find.textContaining('Full time:'), findsOneWidget);
    // Skipped: neither a pep talk nor the ad boost was applied.
    expect(find.textContaining(PepTalk.restEveryone.displayName), findsNothing);
    expect(find.textContaining('Ad-boosted recovery applied'), findsNothing);
  });

  testWidgets('recovery card: Arabic locale renders the card, options and '
      'the armed skip hint through the ARB bundle', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = memoryDb();
    addTearDown(() => db.close());
    sessionDb = db;
    final store = await seededSquadStore(db);
    // A defeat so the ad-boosted row is on the card too.
    final session = await lossSession(store);

    await pumpMatch(tester, session, locale: const Locale('ar'));
    await driveToRecoveryCard(tester, cardTitle: 'الاستشفاء بعد المباراة');

    // Every option row renders localized copy, not enum displayNames.
    expect(find.text('راحة، الجميع يستحقها!'), findsOneWidget);
    expect(find.text('شاهد إعلانًا: استشفاء معزز'), findsOneWidget);
    expect(find.text('بدون حديث — الاستشفاء الافتراضي'), findsOneWidget);
    // And the EN literal is gone.
    expect(find.text('Watch ad: boosted recovery'), findsNothing);
    expect(
      find.text(PepTalk.restEveryone.displayName),
      findsNothing,
      reason: 'the enum displayName must not leak into the AR UI',
    );

    // First scrim tap arms the hint — in Arabic copy.
    await tester.tapAt(const Offset(400, 200));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text('اضغط خارج البطاقة مرة أخرى للتخطي بدون حديث'),
      findsOneWidget,
    );
  });

  testWidgets('disposing the screen while the recovery card is up '
      'surfaces no setState-after-dispose error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = memoryDb();
    addTearDown(() => db.close());
    sessionDb = db;
    final store = await seededSquadStore(db);
    final session = await winSession(store);

    await pumpMatch(tester, session);
    await driveToRecoveryCard(tester);

    // Tear the screen down mid-finish: the parked Completer errors out
    // in dispose, the finish proceeds with the default recovery and the
    // mounted guards keep every setState/ref access away.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // The match screen is gone and no framework error surfaced (any
    // setState() after dispose() or ref use after dispose fails the
    // test by itself).
    expect(find.text('Post-match recovery'), findsNothing);
  });
}
