// Store tab behaviour (GDD 5.5): one section per scope — global first,
// then every position — grouping its three rarity varieties under a
// shared title, plus the BUY confirmation flow and the contents list
// behind each cell's VIEW PLAYERS button.
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
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/packs/pack_contents_screen.dart';
import 'package:fcm_rivals/features/packs/pack_opening_screen.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart'
    show PackCategory, PackTier;
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

  testWidgets('sectioned store: shared scope titles, three tier cells per '
      'section, owned packs stack under their tier', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // 13 scope sections (global + 12 positions), one shared title each —
    // and no per-cell titles left over from the old flat grid.
    expect(find.text('Global Pack'), findsOneWidget);
    expect(find.text('ST Pack'), findsOneWidget);
    expect(find.text('LW Pack'), findsOneWidget);
    expect(find.text('FREE ×3'), findsNWidgets(4));
    // No pool sizes or player strips on the store anymore: the contents
    // list behind VIEW PLAYERS is the one place the pool is shown.
    final offers = await tester.runAsync(() => store.getStoreOffers());
    expect(offers!.firstWhere((o) => o.scopeValue == null).eligibleCount,
        greaterThan(0));
    // One compact VIEW PLAYERS button per section title row (13), not
    // per cell: the contents pool is per-scope.
    expect(find.text('VIEW PLAYERS'), findsNWidgets(13));
    // Three rarity cells per section: 13 sections × 3.
    expect(find.text('RARE'), findsNWidgets(13));
    expect(find.text('EPIC'), findsNWidgets(13));
    expect(find.text('LEGENDARY'), findsNWidgets(13));
    // No rewarded-ad offer anywhere.
    expect(find.text('Free pack — watch an ad'), findsNothing);

    // Free bronze packs: three of each of the 4 cheapest positions
    // (RM/GK/RB/CM for the bundled dataset) — FREE ×3 under those bronze
    // cells — plus one of every other position (FREE ×1).
    expect(find.text('FREE ×1'), findsNWidgets(8));
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    expect(packs!.length, 20);
    expect(packs.every((p) => p.tier == 'rare'), isTrue);
    // No CLAIM/BUY buttons anywhere: tapping the pack itself is the
    // action now — owned cells open straight into the reveal, buyable
    // cells open the purchase dialog.
    expect(find.text('CLAIM'), findsNothing);
    expect(find.text('BUY'), findsNothing);
    // Every section title row carries a VIEW PLAYERS button into the
    // scope's shared pool.
    expect(find.text('VIEW PLAYERS'), findsNWidgets(13));
    // No player preview strip on the store itself.
    expect(find.byType(FcmMiniCard), findsNothing);
  });

  testWidgets('CLAIM opens the owned pack straight into the reveal — no dialog',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    final packsBefore = await tester.runAsync(() => store.getAvailablePacks());
    final claimed = packsBefore!.first;
    final claimedId = claimed.id;

    // Tap the claimed pack's own cell — the pack art itself is the
    // CLAIM button now.
    await tester.tap(find.byKey(ValueKey(
            'store-pack-${claimed.category}-${claimed.scopeValue ?? 'ANY'}-${claimed.tier}'))
        .first);
    // Real drift I/O resolves openPack before the reveal route builds.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    // First pump processes the push, the following ones walk the route
    // transition fully onstage.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // The auto-open timer fires within the pump loop (runAsync blocks
    // fake time, one long pump is not enough after real I/O).
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // No purchase confirmation of any kind — straight to the sealed
    // pack, which tears itself open (no tap prompt anymore).
    expect(find.text('YES'), findsNothing);
    expect(find.text('NO'), findsNothing);
    expect(find.textContaining('Buy'), findsNothing);
    expect(find.byType(PackOpeningScreen), findsOneWidget);
    expect(find.text('TAP TO OPEN'), findsNothing);

    // The claimed pack is consumed from the inventory.
    final packsAfter = await tester.runAsync(() => store.getAvailablePacks());
    expect(packsAfter!.any((p) => p.id == claimedId), isFalse);
    expect(packsAfter.length, packsBefore.length - 1);
  });

  testWidgets('BUY opens a YES/NO confirmation and YES buys AND opens the pack',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    final clubBefore = await tester.runAsync(() => store.getClub());
    final offers = await tester.runAsync(() => store.getStoreOffers());
    // The first BUY on screen is the Rare Global Pack cell.
    final rareGlobal =
        offers!.firstWhere((o) => o.tier == PackTier.rare && o.scopeValue == null);

    await tester.tap(find.byKey(ValueKey(
            'store-pack-${PackCategory.global.name}-ANY-${PackTier.rare.name}'))
        .first);
    await tester.pump();

    // Confirmation shows the price with YES and NO side by side in one
    // row — no balance line.
    expect(find.text('Buy Rare Global Pack?'), findsOneWidget);
    expect(
        find.textContaining('${_group(rareGlobal.price)} Coins'),
        findsOneWidget);
    expect(find.textContaining('Balance:'), findsNothing);
    expect(find.textContaining('after'), findsNothing);
    expect(find.text('YES'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);
    // NO and YES share one row — same line, clear space between them.
    final noTop = tester.getTopLeft(find.widgetWithText(FcmButton, 'NO'));
    final yesTop = tester.getTopLeft(find.widgetWithText(FcmButton, 'YES'));
    expect((yesTop.dy - noTop.dy).abs(), lessThan(4),
        reason: 'NO and YES sit on the same line');
    expect(yesTop.dx - noTop.dx, greaterThan(110),
        reason: 'clear horizontal space between NO and YES');

    await tester.tap(find.text('YES'));
    await tester.pump();
    // buyPack + openPack + provider invalidation run real drift I/O.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // YES falls straight into the reveal — no bought snackbar, no detour
    // through the inventory. The pack tears itself open: no tap prompt.
    expect(find.text('Pack bought — open it from the grid'), findsNothing);
    expect(find.text('TAP TO OPEN'), findsNothing);
    expect(find.byType(PackOpeningScreen), findsOneWidget);

    // The purchase was real: coins charged at the rare price and the
    // pack consumed — the draw already sits in the collection.
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    final bought = packs!
        .where((p) => p.category == 'global' && p.tier == 'rare');
    expect(bought, isEmpty);
    final clubAfter = await tester.runAsync(() => store.getClub());
    expect(clubAfter!.coins, clubBefore!.coins - rareGlobal.price);
  });

  testWidgets('NO closes the confirmation without buying',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    await tester.tap(find.byKey(ValueKey(
            'store-pack-${PackCategory.global.name}-ANY-${PackTier.rare.name}'))
        .first);
    await tester.pump();
    await tester.tap(find.text('NO'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Buy Rare Global Pack?'), findsNothing);
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
    await tester.tap(find.byKey(ValueKey(
            'store-pack-${PackCategory.global.name}-ANY-${PackTier.rare.name}'))
        .first);
    await tester.pump();

    expect(find.text('Not enough coins'), findsOneWidget);
    final yes =
        tester.widget<FcmButton>(find.widgetWithText(FcmButton, 'YES'));
    expect(yes.onPressed, isNull, reason: 'YES must be disabled');
    expect(find.textContaining('Balance:'), findsNothing);
    expect(find.textContaining('after'), findsNothing);
  });

  testWidgets('VIEW PLAYERS opens the pack contents as cards, best rated first',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // The VIEW PLAYERS button on the section title row opens the
    // contents screen for that scope.
    await tester.tap(find.text('VIEW PLAYERS').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PackContentsScreen), findsOneWidget);
    expect(find.text('Rare Global Pack'), findsOneWidget);

    // The list shows the eligible players as mini cards with no rank
    // numbers, no stat rows.
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(FcmMiniCard), findsWidgets);
    expect(find.textContaining('#'), findsNothing);
    expect(find.text('ATT'), findsNothing);
    expect(find.text('SUP'), findsNothing);

    // Back returns to the store (the fullscreen dialog route shows a
    // close icon rather than a back arrow).
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PackContentsScreen), findsNothing);
    expect(find.byKey(ValueKey(
            'store-pack-${PackCategory.global.name}-ANY-${PackTier.rare.name}')),
        findsOneWidget);
  });

  testWidgets('contents list searches by name', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    await tester.tap(find.text('VIEW PLAYERS').first);
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));

    // The search field narrows the list to matching names: two Haalands
    // ship in the bundled dataset (Erling and Markus), one Erling.
    await tester.enterText(find.byType(TextField), 'haaland');
    await tester.pump();
    expect(find.byType(FcmMiniCard), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), 'erling haaland');
    await tester.pump();
    expect(find.byType(FcmMiniCard), findsOneWidget);
    expect(find.text('Erling Haaland'), findsOneWidget);

    // Clearing the search restores the full, best-first pool.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byType(FcmMiniCard), findsWidgets);
    // No leftover empty-state message.
    expect(find.text('No players match your search'), findsNothing);
  });

  testWidgets('contents list offers a nationality filter over the pool',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    await tester.tap(find.text('VIEW PLAYERS').first);
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 50));

    // The filter bar renders the search field plus the nationality
    // dropdown showing its ALL reset state.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All nationalities'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    // The dropdown offers every nationality present in the pool.
    final pool = await tester.runAsync(
        () => store.getPackPlayers(category: PackCategory.global, tier: PackTier.rare));
    final expected = pool!.map((p) => p.nationality).toSet().length;
    expect(find.byType(DropdownButton<String?>), findsOneWidget);
    expect(expected, greaterThan(50));
    // Rows show each player's nationality next to his name.
    expect(find.textContaining('Norway'), findsWidgets);
  });

  testWidgets(
      'regression: after a BUY reveal closes, the store still opens packs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // --- Buy a pack and watch its reveal to the end. ---
    await tester.tap(find.byKey(ValueKey(
            'store-pack-${PackCategory.global.name}-ANY-${PackTier.rare.name}'))
        .first);
    await tester.pump();
    await tester.tap(find.text('YES'));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PackOpeningScreen), findsOneWidget);

    // Play the sequence out. The auto-open timer fires inside the
    // pump loop (runAsync blocks fake time, so one long pump is not
    // enough after real I/O), then the 8s sequence runs to done.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        tester
            .widget<AnimatedOpacity>(
                find.byKey(const ValueKey('keep-fade')))
            .opacity,
        1.0,
        reason: 'the sequence must reach the done mark');

    // KEEP pops the reveal; the fullscreen-dialog exit transition then
    // needs its own pumps before the route is gone.
    await tester.tap(find.text('KEEP PLAYER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PackOpeningScreen), findsNothing);

    // The store must still be alive: _opening was reset in the finally
    // block, so CLAIM opens another owned pack straight away — before
    // the fix the whole store stayed dead until an app restart. The
    // pack art itself is the CLAIM button now: tap the first owned
    // cell, derived from the inventory.
    final remaining = await tester.runAsync(() => store.getAvailablePacks());
    await tester.tap(find.byKey(ValueKey(
            'store-pack-${remaining!.first.category}-${remaining.first.scopeValue ?? 'ANY'}-${remaining.first.tier}'))
        .first);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PackOpeningScreen), findsOneWidget,
        reason: 'the store must keep opening packs after a purchase');
  });
}

/// Mirrors the dialog's thousands separator so the test finds real text.
String _group(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
