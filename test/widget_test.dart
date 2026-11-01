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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('club creation leads to the game shell with 36 packs',
      (WidgetTester tester) async {
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
    await tester.tap(find.text('Start managing'));
    await tester.pump();

    // Club creation + provider invalidation run real async work.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // Game shell with the four tabs.
    expect(find.text('Match'), findsWidgets);
    expect(find.text('Packs'), findsWidgets);
    expect(find.text('Squad'), findsWidgets);
    expect(find.text('Collection'), findsWidgets);

    // The Match tab opens first: the friendly match entry point renders.
    expect(find.text('Play friendly match'), findsOneWidget);

    // Switch to the Packs tab and check the starting packs render.
    await tester.tap(find.text('Packs'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('ST Position Pack'), findsNWidgets(3));
    expect(find.text('LW Position Pack'), findsNWidgets(3));

    // store-level check: all 36 packs exist and remain unopened
    final packs = await store.getAvailablePacks();
    expect(packs.length, 36);
    expect(packs.map((p) => p.scopeValue).toSet().length, 12);
    await db.close();
  });
}
