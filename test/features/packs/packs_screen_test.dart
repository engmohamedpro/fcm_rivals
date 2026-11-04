// Store tab behaviour (GDD 5.5): one section per position, grouping the
// tier varieties under a shared title — a tier only shelves when the
// position's pool holds a player of that rarity — plus the BUY
// confirmation flow and the contents list behind each cell's players
// icon button.
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
import 'package:fcm_rivals/core/ui/fcm_widgets.dart'
    show FcmButton, FcmCoinGlyph;
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
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
    final jsonText = await tester.runAsync(
      () => rootBundle.loadString('assets/data/players_v1.json'),
    );
    await tester.runAsync(() async {
        final dataset = PlayerDataset.fromJson(jsonText!);
        await store.importBundledDataset(dataset);
      });
    await tester.runAsync(
      () => store.createClub(
        clubName: 'Pyramid United',
        managerName: 'Mohamed',
        crestIndex: 0,
      ),
    );
  }

  /// Pumps the store screen; a Scaffold hosts it exactly like the game
  /// shell does, so buy snackbars have a messenger to present to.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: const MaterialApp(home: Scaffold(body: PacksScreen())),
      ),
    );
    // Real drift I/O: let the offers/packs/club providers resolve.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> bootScreen(WidgetTester tester) async {
    await seedStore(tester);
    await pumpScreen(tester);
  }

  testWidgets('sectioned store: shared scope titles, tier cells per '
      'section, owned packs stack under their tier', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // 12 position sections, one shared title each — the global pack is
    // gone from the store, and no per-cell titles are left over from the
    // old flat grid.
    expect(find.text('Global Pack'), findsNothing);
    expect(find.text('ST Pack'), findsOneWidget);
    expect(find.text('LW Pack'), findsOneWidget);
    expect(find.text('FREE ×3'), findsNothing);
    // A tier only shelves when the position's pool holds a player of
    // that rarity: LM and RM have no 82+ players in the bundled dataset,
    // so their sections show Rare and Epic cells only — every other
    // position carries all three tiers.
    final offers = await tester.runAsync(() => store.getStoreOffers());
    expect(
      offers!.where((o) => o.scopeValue == 'LM').map((o) => o.tier),
      containsAllInOrder([PackTier.rare, PackTier.epic]),
    );
    expect(
      offers.where((o) => o.scopeValue == 'RM').map((o) => o.tier),
      containsAllInOrder([PackTier.rare, PackTier.epic]),
    );
    expect(
      offers.where((o) => o.scopeValue == 'ST').map((o) => o.tier),
      containsAllInOrder([PackTier.rare, PackTier.epic, PackTier.legendary]),
    );
    expect(offers.length, 12 * 3 - 2);
    // No pool sizes or player strips on the store anymore: the contents
    // list behind the players icon button is the one place the pool is
    // shown.
    expect(offers.any((o) => o.scopeValue == null), isFalse);
    // One compact players icon button per section title row (12), not
    // per cell: the contents pool is per-scope. The text label is gone —
    // the icon (with its tooltip) is the whole button.
    expect(find.byIcon(Icons.people_outline_rounded), findsNWidgets(12));
    expect(find.text('VIEW PLAYERS'), findsNothing);
    // The tier name is stamped on the foil's plate (painted, not a
    // Text widget), so no tier labels render under the cells anymore.
    expect(find.text('RARE'), findsNothing);
    expect(find.text('EPIC'), findsNothing);
    expect(find.text('LEGENDARY'), findsNothing);
    // No rewarded-ad offer anywhere.
    expect(find.text('Free pack — watch an ad'), findsNothing);

    // Free starter-formation packs (22-pack system): two per 4-3-3 slot,
    // so the stack badges are ×2 on single-slot positions (GK, LB, RB,
    // CDM, LW, ST, RW), ×4 on the doubled slots (CB, CM) — nothing at
    // ×1, nothing at ×3, and the positions the shape doesn't use
    // (CAM, LM, RM) carry no free stack at all.
    expect(find.text('FREE ×1'), findsNothing);
    expect(find.text('FREE ×2'), findsNWidgets(7));
    expect(find.text('FREE ×4'), findsNWidgets(2));
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    expect(packs!.length, 22);
    expect(packs.every((p) => p.tier == 'rare'), isTrue);
    expect(packs.map((p) => p.scopeValue).toSet(), {
      'GK',
      'LB',
      'CB',
      'RB',
      'CDM',
      'CM',
      'LW',
      'ST',
      'RW',
    });
    // No CLAIM/BUY buttons anywhere: tapping the pack itself is the
    // action now — owned cells open straight into the reveal, buyable
    // cells open the purchase dialog.
    expect(find.text('CLAIM'), findsNothing);
    expect(find.text('BUY'), findsNothing);
    // Every section title row carries a players icon button into the
    // scope's shared pool.
    expect(find.byIcon(Icons.people_outline_rounded), findsNWidgets(12));
    // No player preview strip on the store itself.
    expect(find.byType(FcmMiniCard), findsNothing);
  });

  testWidgets('pack art hugs its price plate — no dead air in the cell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // The rare CAM cell is priced (CAM is not a starter-formation slot,
    // so no free stack hides its price), so it shows the coin plate.
    final cell = find
        .byKey(const ValueKey('store-pack-position-CAM-rare'))
        .first;
    final pack = find
        .descendant(of: cell, matching: find.byType(CustomPaint))
        .first;
    final price = find
        .descendant(of: cell, matching: find.byType(FcmCoinGlyph))
        .first;
    await tester.ensureVisible(cell);
    await tester.pump(const Duration(milliseconds: 100));

    // The plate hugs the pack's foot: the only space is the 4px breath
    // plus the plate slot's centring slack. Before the fix the pack sat
    // centred in a fixed-height row with ~30px of dead air above and
    // below it.
    final packBottom = tester.getBottomRight(pack).dy;
    final priceTop = tester.getTopLeft(price).dy;
    expect(
      priceTop - packBottom,
      lessThan(16),
      reason: 'price plate must sit close under the pack',
    );

    // The pack fills its cell's width by aspect ratio — sizing the cell
    // itself instead of floating centred inside a fixed-height row.
    final cellWidth = tester.getRect(cell).width;
    final packWidth = tester.getRect(pack).width;
    expect(
      packWidth,
      greaterThan(cellWidth - 2),
      reason: 'pack art must fill the cell width',
    );
  });

  testWidgets('CLAIM opens the owned pack straight into the reveal — no dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    final packsBefore = await tester.runAsync(() => store.getAvailablePacks());
    final claimed = packsBefore!.first;
    final claimedId = claimed.id;

    // Tap the claimed pack's own cell — the pack art itself is the
    // CLAIM button now. Scroll it into view first: the free stack
    // layout puts GK near the top but the sectioned store is tall.
    final claimedCell = find
        .byKey(
          ValueKey(
            'store-pack-${claimed.category}-${claimed.scopeValue ?? 'ANY'}-${claimed.tier}',
          ),
        )
        .first;
    await tester.ensureVisible(claimedCell);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(claimedCell, warnIfMissed: false);
    // Real drift I/O resolves openPack before the reveal route builds.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
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

  testWidgets(
    'BUY opens a YES/NO confirmation and YES buys AND opens the pack',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await bootScreen(tester);

      final clubBefore = await tester.runAsync(() => store.getClub());
      final offers = await tester.runAsync(() => store.getStoreOffers());
      // The first BUY on screen is the Rare CAM Pack cell — CAM is not a
      // starter-formation slot, so its cells carry no free stack.
      final rareCam = offers!.firstWhere(
        (o) => o.tier == PackTier.rare && o.scopeValue == 'CAM',
      );

      final camCell = find
          .byKey(const ValueKey('store-pack-position-CAM-rare'))
          .first;
      await tester.ensureVisible(camCell);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(camCell);
      await tester.pump();

      // Confirmation shows the price — the same C coin glyph the top bar's
      // balance chip uses, no 'Coins' word, no dollar money icon — with
      // YES and NO side by side in one row and no balance line. The price
      // row is scoped to the dialog (the store behind it shows coin
      // prices on every cell too).
      expect(find.text('Buy Rare CAM Position Pack?'), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.byType(FcmCoinGlyph)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.textContaining(_group(rareCam.price)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('Coins')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dialog,
          matching: find.byIcon(Icons.monetization_on_rounded),
        ),
        findsNothing,
      );
      expect(find.textContaining('Balance:'), findsNothing);
      expect(find.textContaining('after'), findsNothing);
      expect(find.text('YES'), findsOneWidget);
      expect(find.text('NO'), findsOneWidget);
      // NO and YES share one row — same line, clear space between them.
      final noTop = tester.getTopLeft(find.widgetWithText(FcmButton, 'NO'));
      final yesTop = tester.getTopLeft(find.widgetWithText(FcmButton, 'YES'));
      expect(
        (yesTop.dy - noTop.dy).abs(),
        lessThan(4),
        reason: 'NO and YES sit on the same line',
      );
      expect(
        yesTop.dx - noTop.dx,
        greaterThan(110),
        reason: 'clear horizontal space between NO and YES',
      );

      await tester.tap(find.text('YES'));
      await tester.pump();
      // buyPack + openPack + provider invalidation run real drift I/O.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
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
      // pack consumed by the reveal (the 22 starter packs are untouched
      // — all position-scoped rares — so the count staying at 22 is the
      // proof the bought pack was opened) — the draw already sits in the
      // collection.
      final packs = await tester.runAsync(() => store.getAvailablePacks());
      expect(packs!.length, 22);
      final clubAfter = await tester.runAsync(() => store.getClub());
      expect(clubAfter!.coins, clubBefore!.coins - rareCam.price);
    },
  );

  testWidgets('NO closes the confirmation without buying', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    final camCell = find
        .byKey(const ValueKey('store-pack-position-CAM-rare'))
        .first;
    await tester.ensureVisible(camCell);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(camCell);
    await tester.pump();
    await tester.tap(find.text('NO'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Buy Rare CAM Position Pack?'), findsNothing);
    final packs = await tester.runAsync(() => store.getAvailablePacks());
    expect(packs!.length, 22, reason: 'nothing was bought');
  });

  testWidgets('a pack the club cannot afford disables YES in the dialog', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await seedStore(tester);

    // Drain the wallet below the cheapest pack BEFORE the first pump, so
    // clubProvider resolves with the drained balance.
    final offers = await tester.runAsync(() => store.getStoreOffers());
    final cheapest = offers!
        .map((o) => o.price)
        .reduce((a, b) => a < b ? a : b);
    await tester.runAsync(() async {
      final club = await store.getClub();
      await (db.update(db.clubs)..where((c) => c.id.equals(club!.id))).write(
        ClubsCompanion(coins: Value(cheapest - 1)),
      );
    });

    await pumpScreen(tester);
    final camCell = find
        .byKey(const ValueKey('store-pack-position-CAM-rare'))
        .first;
    await tester.ensureVisible(camCell);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(camCell);
    await tester.pump();

    expect(find.text('Not enough coins'), findsOneWidget);
    final yes = tester.widget<FcmButton>(find.widgetWithText(FcmButton, 'YES'));
    expect(yes.onPressed, isNull, reason: 'YES must be disabled');
    expect(find.textContaining('Balance:'), findsNothing);
    expect(find.textContaining('after'), findsNothing);
  });

  testWidgets(
    'players icon opens the pack contents as cards, best rated first',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await bootScreen(tester);

      // The players icon button on the section title row opens the
      // contents screen for that scope.
      await tester.tap(find.byIcon(Icons.people_outline_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PackContentsScreen), findsOneWidget);
      expect(find.text('Rare ST Position Pack'), findsOneWidget);

      // The list shows the eligible players as mini cards with no rank
      // numbers, no stat rows.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
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
      expect(
        find.byKey(const ValueKey('store-pack-position-ST-rare')),
        findsOneWidget,
      );
    },
  );

  testWidgets('contents list searches by name', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    await tester.tap(find.byIcon(Icons.people_outline_rounded).first);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The search field narrows the list to matching names: one Haaland
    // is a striker in the bundled dataset (Erling), so searching the ST
    // pool finds exactly him.
    await tester.enterText(find.byType(TextField), 'haaland');
    await tester.pump();
    expect(find.byType(FcmMiniCard), findsOneWidget);
    expect(find.text('Erling Haaland'), findsOneWidget);
    // A query that matches nothing shows the empty state: the ST pool
    // holds no player with a q in its name.
    await tester.enterText(find.byType(TextField), 'qq');
    await tester.pump();
    expect(find.byType(FcmMiniCard), findsNothing);
    expect(find.text('No players match your search'), findsOneWidget);

    // Clearing the search restores the full, best-first pool.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byType(FcmMiniCard), findsWidgets);
    // No leftover empty-state message.
    expect(find.text('No players match your search'), findsNothing);
  });

  testWidgets('contents list offers a nationality filter over the pool', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    await tester.tap(find.byIcon(Icons.people_outline_rounded).first);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // The filter bar renders the search field plus the nationality
    // dropdown showing its ALL reset state.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('All nationalities'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    // The dropdown offers every nationality present in the pool.
    final pool = await tester.runAsync(
      () => store.getPackPlayers(
        category: PackCategory.position,
        scopeValue: 'ST',
        tier: PackTier.rare,
      ),
    );
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

      // --- Buy a pack and watch its reveal to the end. CAM carries no
      // starter stack, so its rare cell is a clean buy. ---
      final buyCell = find
          .byKey(const ValueKey('store-pack-position-CAM-rare'))
          .first;
      await tester.ensureVisible(buyCell);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(buyCell);
      await tester.pump();
      await tester.tap(find.text('YES'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
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
            .widget<AnimatedOpacity>(find.byKey(const ValueKey('keep-fade')))
            .opacity,
        1.0,
        reason: 'the sequence must reach the done mark',
      );

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
      final claimCell = find
          .byKey(
            ValueKey(
              'store-pack-${remaining!.first.category}-${remaining.first.scopeValue ?? 'ANY'}-${remaining.first.tier}',
            ),
          )
          .first;
      await tester.ensureVisible(claimCell);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(claimCell);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byType(PackOpeningScreen),
        findsOneWidget,
        reason: 'the store must keep opening packs after a purchase',
      );
    },
  );
}

/// Mirrors the dialog's thousands separator so the test finds real text.
String _group(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (match) => ',',
);
