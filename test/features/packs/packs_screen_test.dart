// Packs tab store behaviour (GDD 5.5): the grid holds ONLY pack cells —
// no rewarded-ad offer — and every unowned cell shows a BUY button that
// opens a YES/NO confirmation with the price and the coin balance. The
// purchase itself goes through CollectionStore.buyPack, which charges
// atomically and re-lists the pack in the inventory.
//
// The store runs real drift I/O over an in-memory database, so async
// flushes use tester.runAsync (FakeAsync doesn't perform real I/O).
import 'package:drift/native.dart' show NativeDatabase;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmButton;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/packs/packs_screen.dart';

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

  /// Dataset + club, no widgets yet — tests that need a doctored club
  /// state can adjust the database between this and [_pump].
  Future<void> seedStore(WidgetTester tester) async {
    final jsonText = await tester
        .runAsync(() => rootBundle.loadString('assets/data/players_v1.json'));
    await tester.runAsync(() => store.importBundledDataset(jsonText!));
    await tester.runAsync(() => store.createClub(
        clubName: 'Pyramid United', managerName: 'Mohamed', crestIndex: 0));
  }

  /// Pumps the store screen; a Scaffold hosts it exactly like the game
  /// shell does, so buy snackbars have a messenger to present to.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) => store),
      ],
      child: const MaterialApp(home: Scaffold(body: PacksScreen())),
    ));
    // Real drift I/O: let the offers/packs/club providers resolve.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> bootScreen(WidgetTester tester) async {
    await seedStore(tester);
    await pumpScreen(tester);
  }

  testWidgets('store grid shows pack cells only — no rewarded-ad offer',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    expect(find.text('Free pack — watch an ad'), findsNothing);
    expect(find.text('One global pack (1 player) for a completed rewarded ad'),
        findsNothing);
    // 12 position packs + the global pack; every unowned cell carries a
    // BUY button (36 owned starting packs cover the position cells, so
    // only the global pack is unowned and shows the button).
    expect(find.text('Global Pack'), findsOneWidget);
    expect(find.text('ST Pack'), findsOneWidget);
    expect(find.text('FREE ×3'), findsNWidgets(12));
    expect(find.text('BUY'), findsOneWidget);
  });

  testWidgets('BUY opens a YES/NO confirmation and YES buys the pack',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    final clubBefore = await tester.runAsync(() => store.getClub());
    final offers = await tester.runAsync(() => store.getStoreOffers());
    final global = offers!.firstWhere((o) => o.scopeValue == null);

    await tester.tap(find.text('BUY'));
    await tester.pump();

    // Confirmation shows the price and the balance, with YES and NO.
    expect(find.text('Buy Global Pack?'), findsOneWidget);
    expect(
        find.textContaining('${_group(global.price)} Coins'), findsOneWidget);
    expect(find.textContaining('Balance:'), findsOneWidget);
    expect(find.text('YES'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);

    await tester.tap(find.text('YES'));
    await tester.pump();
    // buyPack + provider invalidation run real drift I/O.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Pack bought — open it from the grid'), findsOneWidget);
    // The pack landed in the inventory and the coins were charged.
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    final bought =
        packs!.where((p) => p.category == 'global' && p.openedAt == null);
    expect(bought, isNotEmpty);
    final clubAfter = await tester.runAsync(() => store.getClub());
    expect(clubAfter!.coins, clubBefore!.coins - global.price);
    // The bought pack shows as owned: FREE ×1 replaces the price cell.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('BUY'), findsNothing);
    expect(find.text('FREE ×1'), findsOneWidget);
  });

  testWidgets('NO closes the confirmation without buying',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    await tester.tap(find.text('BUY'));
    await tester.pump();
    await tester.tap(find.text('NO'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Buy Global Pack?'), findsNothing);
    expect(find.text('BUY'), findsOneWidget);
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    expect(packs!.where((p) => p.category == 'global'), isEmpty);
  });

  testWidgets('a pack the club cannot afford disables YES in the dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await seedStore(tester);

    // Drain the wallet below the cheapest pack BEFORE the first pump, so
    // clubProvider resolves with the drained balance.
    final offers = await tester.runAsync(() => store.getStoreOffers());
    final cheapest =
        offers!.map((o) => o.price).reduce((a, b) => a < b ? a : b);
    await tester.runAsync(() async {
      final club = await store.getClub();
      await (db.update(db.clubs)..where((c) => c.id.equals(club!.id)))
          .write(ClubsCompanion(coins: Value(cheapest - 1)));
    });

    await pumpScreen(tester);
    await tester.tap(find.text('BUY'));
    await tester.pump();

    expect(find.text('Buy Global Pack?'), findsOneWidget);
    expect(find.text('Not enough coins'), findsOneWidget);
    final yes = tester.widget<FcmButton>(
        find.widgetWithText(FcmButton, 'YES'));
    expect(yes.onPressed, isNull, reason: 'YES must be disabled');
    expect(find.textContaining('Balance:'), findsOneWidget);
    expect(find.textContaining('after'), findsNothing);
  });
}

/// Mirrors the dialog's thousands separator so the test finds real text.
String _group(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
