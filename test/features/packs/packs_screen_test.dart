// Packs tab store behaviour (GDD 5.5): the tiered grid — three tiers of
// the global pack and three per position, cells coloured by tier — plus
// the BUY confirmation flow and the contents list behind tapping a cell.
//
// The store runs real drift I/O over an in-memory database, so async
// flushes use tester.runAsync (FakeAsync doesn't perform real I/O).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmButton;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/packs/pack_contents_screen.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart'
    show PackTier;
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
  /// state can adjust the database between this and [pumpScreen].
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

  testWidgets('tiered store grid: three global tiers, cells labelled by '
      'tier, owned packs stack under their tier', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // The three global tiers render with tier labels under the titles.
    expect(find.text('Global Pack'), findsNWidgets(3));
    expect(find.text('BRONZE'), findsNWidgets(13));
    expect(find.text('SILVER'), findsNWidgets(13));
    expect(find.text('GOLD'), findsNWidgets(13));
    // No rewarded-ad offer anywhere.
    expect(find.text('Free pack — watch an ad'), findsNothing);

    // Free bronze packs: three of each of the 4 cheapest positions
    // (RM/GK/RB/CM for the bundled dataset) — FREE ×3 under those bronze
    // cells — plus one of every other position (FREE ×1).
    expect(find.text('FREE ×3'), findsNWidgets(4));
    expect(find.text('FREE ×1'), findsNWidgets(8));
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    expect(packs!.length, 20);
    expect(packs.every((p) => p.tier == 'bronze'), isTrue);
    // Owned cells show CLAIM, unowned BUY — same size, style and layout:
    // 39 cells minus the 12 owned scopes (4 cheapest at ×3 + 8 others at
    // ×1 stack under their bronze cells).
    expect(find.text('CLAIM'), findsNWidgets(12));
    expect(find.text('BUY'), findsNWidgets(27));
  });

  testWidgets('CLAIM opens the owned pack straight into the reveal — no dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    final packsBefore = await tester.runAsync(() => store.getAvailablePacks());
    final claimedId = packsBefore!.first.id;

    await tester.tap(find.text('CLAIM').first);
    // Real drift I/O resolves openPack before the reveal route builds.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    // First pump processes the push, the following ones walk the route
    // transition fully onstage.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // No purchase confirmation of any kind — straight to the sealed pack.
    expect(find.text('YES'), findsNothing);
    expect(find.text('NO'), findsNothing);
    expect(find.textContaining('Buy'), findsNothing);
    expect(find.text('TAP TO OPEN'), findsOneWidget);

    // The claimed pack is consumed from the inventory.
    final packsAfter = await tester.runAsync(() => store.getAvailablePacks());
    expect(packsAfter!.any((p) => p.id == claimedId), isFalse);
    expect(packsAfter.length, packsBefore.length - 1);
  });

  testWidgets('BUY opens a YES/NO confirmation and YES buys the tiered pack',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    final clubBefore = await tester.runAsync(() => store.getClub());
    final offers = await tester.runAsync(() => store.getStoreOffers());
    // The first BUY on screen is the Bronze Global Pack cell.
    final bronzeGlobal =
        offers!.firstWhere((o) => o.tier == PackTier.bronze && o.scopeValue == null);

    await tester.tap(find.text('BUY').first);
    await tester.pump();

    // Confirmation shows the price and the balance, with YES and NO.
    expect(find.text('Buy Bronze Global Pack?'), findsOneWidget);
    expect(
        find.textContaining('${_group(bronzeGlobal.price)} Coins'),
        findsOneWidget);
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
    // The pack landed in the inventory as a BRONZE pack and the coins
    // were charged at the bronze price.
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    final bought = packs!
        .where((p) => p.category == 'global' && p.tier == 'bronze');
    expect(bought, isNotEmpty);
    final clubAfter = await tester.runAsync(() => store.getClub());
    expect(clubAfter!.coins, clubBefore!.coins - bronzeGlobal.price);
  });

  testWidgets('NO closes the confirmation without buying',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    await tester.tap(find.text('BUY').first);
    await tester.pump();
    await tester.tap(find.text('NO'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Buy Bronze Global Pack?'), findsNothing);
    expect(find.text('BUY'), findsNWidgets(27));
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
    await tester.tap(find.text('BUY').first);
    await tester.pump();

    expect(find.text('Not enough coins'), findsOneWidget);
    final yes =
        tester.widget<FcmButton>(find.widgetWithText(FcmButton, 'YES'));
    expect(yes.onPressed, isNull, reason: 'YES must be disabled');
    expect(find.textContaining('Balance:'), findsOneWidget);
    expect(find.textContaining('after'), findsNothing);
  });

  testWidgets('tapping a cell opens the pack contents, best rated first',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // The ⓘ badge on the first cell opens the contents screen.
    await tester.tap(find.byIcon(Icons.info_outline_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PackContentsScreen), findsOneWidget);
    expect(find.text('Bronze Global Pack'), findsOneWidget);

    // The list shows every eligible player, ranked #1 (best) at the top,
    // with ratings but no stat rows.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('ATT'), findsNothing);
    expect(find.text('SUP'), findsNothing);

    // Back returns to the store (the fullscreen dialog route shows a
    // close icon rather than a back arrow).
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PackContentsScreen), findsNothing);
    expect(find.text('BUY'), findsWidgets);
  });
}

/// Mirrors the dialog's thousands separator so the test finds real text.
String _group(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
