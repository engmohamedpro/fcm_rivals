// App smoke test: boots through onboarding → club creation → game shell
// with a real in-memory database and the bundled dataset.
//
// The database and dataset bootstrap run real async I/O, so the test uses
// tester.runAsync (FakeAsync doesn't perform real I/O) and overrides the
// collection store provider with an in-memory AppDatabase.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/main.dart';

/// The shell has always-on ambient animations (animated backdrop), so
/// pumpAndSettle would never return; pump a bounded run of frames instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('club creation leads to the game shell with the 22 starter-formation packs',
      (WidgetTester tester) async {
    // Phone-like portrait surface (800x1200 logical): the default 800x600
    // test surface leaves only ~466px of list viewport after the AppBar and
    // bottom nav, so beyond the first ~4 pack rows the rest sit in the
    // scroll cache area where default finders skip them.
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    final store = CollectionStore(db: db);
    final jsonText = await tester
        .runAsync(() => rootBundle.loadString('assets/data/players_v1.json'));
    await tester.runAsync(() => store.importBundledDataset(jsonText!));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // The production providers use path_provider which is unavailable
        // in tests; this override injects the in-memory database store.
        collectionStoreProvider.overrideWith((ref) => store),
      ],
      child: const FcmRivalsApp(),
    ));

    // Real drift I/O — flush with runAsync, then pump fixed frames (the
    // loading spinner never settles under pumpAndSettle).
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));

    // Onboarding first: club creation form.
    expect(find.text('Create your club'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Pyramid United');
    await tester.enterText(find.byType(TextFormField).at(1), 'Mohamed');
    await tester.ensureVisible(find.text('Start managing'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start managing'));
    await tester.pump();

    // Club creation + provider invalidation run real async work.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    // The season summary provider resolves asynchronously as well.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 100));

    // Game shell with the four tabs (league matches are played live
    // from the Season tab; the squad lives on the Team tab).
    expect(find.text('Season'), findsWidgets);
    expect(find.text('Team'), findsWidgets);
    expect(find.text('Collection'), findsWidgets);
    expect(find.text('Store'), findsWidgets);
    expect(find.text('Match'), findsNothing);

    // The Season tab opens first: the first campaign entry point renders.
    expect(find.text('Start your first season'), findsOneWidget);

    // Switch to the Store tab (last in the nav) and check the
    // sectioned store: one section per position — each with a shared
    // title, its rarity cells shelved only when the position's pool
    // holds a player of that rarity — and the free starting packs
    // stacking as FREE ×N plates under their rare cells.
    await tester.tap(find.text('Store'));
    await _settle(tester);
    expect(find.text('Global Pack'), findsNothing);
    expect(find.text('ST Pack'), findsOneWidget);
    // The tier names are stamped on the foil's plate (painted, not Text
    // widgets), so no tier labels render as text under the cells.
    expect(find.text('RARE'), findsNothing);
    expect(find.text('EPIC'), findsNothing);
    expect(find.text('LEGENDARY'), findsNothing);
    // The 22-pack starter system: two per 4-3-3 slot — ×2 badges on
    // the single-slot positions, ×4 on the doubled CB/CM cells.
    expect(find.text('FREE ×2'), findsNWidgets(7));
    expect(find.text('FREE ×4'), findsNWidgets(2));
    // No CLAIM/BUY buttons: the pack art itself is the action now —
    // owned cells open straight into the reveal, buyable cells open
    // the purchase dialog.
    expect(find.text('CLAIM'), findsNothing);
    expect(find.text('BUY'), findsNothing);

    // store-level check: the 22 free starter-formation packs (two per
    // 4-3-3 slot, all rare) exist and remain unopened.
    final packs = await store.getAvailablePacks();
    expect(packs.length, 22);
    expect(packs.every((p) => p.tier == 'rare'), isTrue);
    expect(packs.map((p) => p.scopeValue).toSet(),
        {'GK', 'LB', 'CB', 'RB', 'CDM', 'CM', 'LW', 'ST', 'RW'});
    await db.close();
  });
}
