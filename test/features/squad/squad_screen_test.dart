// Tactics tab with an empty squad: the tab never hides the tactical
// setup behind a placeholder — a fresh club with zero owned players
// still gets the control card, the pitch with its eleven empty slots
// and a working Auto Pick. The hint panel sits ABOVE the view instead
// of replacing it.
//
// The store runs real drift I/O over an in-memory database, so async
// flushes use tester.runAsync (FakeAsync doesn't perform real I/O).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/features/squad/squad_screen.dart';
import 'package:fcm_rivals/features/squad/squad_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CollectionStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = CollectionStore(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> bootScreen(WidgetTester tester) async {
    final jsonText = await tester.runAsync(
      () => rootBundle.loadString('assets/data/players_v1.json'),
    );
    await tester.runAsync(() => store.importBundledDataset(jsonText!));
    // Club with zero opened packs: the squad map resolves empty.
    await tester.runAsync(
      () => store.createClub(
        clubName: 'Pyramid United',
        managerName: 'Mohamed',
        crestIndex: 0,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: const MaterialApp(home: Scaffold(body: SquadScreen())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('empty squad still shows the full tactical setup', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // The hint explains how to fill the squad…
    expect(
      find.text('Open packs to collect players, then tap Auto Pick.'),
      findsOneWidget,
    );
    // …but the setup itself is fully present: control card with the
    // team rating and the default 4-3-3, and the pitch with eleven
    // empty slots.
    expect(find.byType(TacticsSetupView), findsOneWidget);
    expect(find.byType(SquadPitch), findsOneWidget);
    expect(find.text('4-3-3'), findsWidgets);
    expect(find.text('TEAM RATING'), findsOneWidget);
    expect(find.text('TACTICS'), findsOneWidget);

    // Bench and reserves stay visible even with nothing assigned: full
    // quota of ghost placeholder cards — 7 bench slots, 5 reserve slots.
    expect(find.text('Bench (0/7)'), findsOneWidget);
    expect(find.text('Reserves (0/5)'), findsOneWidget);
    expect(
      find.byType(FcmMiniCard),
      findsNWidgets(11 + 12),
      reason: '11 formation ghost slots plus 12 bench/reserve ghosts',
    );

    // Auto Pick works with an empty collection: it simply assigns
    // nothing and confirms.
    await tester.tap(find.text('Auto Pick'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Best squad selected'), findsOneWidget);
    expect(find.byType(TacticsSetupView), findsOneWidget);
  });
}
