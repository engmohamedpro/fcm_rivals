// Campus tab (GDD 3.5): one compact card per building — icon, title,
// level pips, LV number, ONE effect line (current → next value) and the
// price button. The text-diet regression: no invested totals, no
// "Not built yet." filler, no "Next:"/"for every player" long forms,
// and no in-page header — the list is the screen, with uniform 16px
// gutters on every side and between cards.
//
// Runs real drift I/O over an in-memory database, so async flushes use
// tester.runAsync (FakeAsync doesn't perform real I/O) — the same
// harness pattern as the store screen tests.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmButton, FcmPill;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/facilities/campus_screen.dart';
import 'package:fcm_rivals/features/facilities/facilities.dart';

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

  Future<void> seedStore(WidgetTester tester, {int coins = 50_000}) async {
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
    if (coins != 0) {
      // createClub starts the wallet at 0; top it up for upgrade tests.
      await tester.runAsync(() async {
        final club = await store.getClub();
        await (db.update(db.clubs)..where((c) => c.id.equals(club!.id))).write(
          ClubsCompanion(coins: Value(coins)),
        );
      });
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: const MaterialApp(home: Scaffold(body: CampusScreen())),
      ),
    );
    // Real drift I/O: let the club/campus providers resolve.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> bootScreen(WidgetTester tester, {int coins = 50_000}) async {
    await seedStore(tester, coins: coins);
    await pumpScreen(tester);
  }

  testWidgets('six facility cards, compact: one title and one effect line '
      'each, level pips and a price button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // One card per facility, each with its title; every building sits
    // at level 0 on a fresh club.
    for (final f in Facility.values) {
      expect(find.text(f.title), findsOneWidget);
    }
    expect(find.text('LV 0'), findsNWidgets(6));
    expect(find.byType(FacilityCard), findsNWidgets(6));
    // Price button per card (level 1 costs 4k).
    expect(find.byType(FcmButton), findsNWidgets(6));

    // The text diet: none of the old verbose fragments survive.
    expect(find.textContaining('for every player'), findsNothing);
    expect(find.textContaining('natural'), findsNothing);
    expect(find.textContaining('Not built yet'), findsNothing);
    expect(find.textContaining('Next:'), findsNothing);
    // The old invested-total corner showed e.g. '55.6k in'.
    expect(find.textContaining('k in'), findsNothing);
    expect(find.text('Maximum level reached.'), findsNothing);

    // No header at all: the tab jumps straight into the facility list
    // (the shell's masthead already names the game).
    expect(find.text('Club campus'), findsNothing);
    expect(
      find.text('Permanent boosts — every level costs more.'),
      findsNothing,
    );
    expect(find.textContaining('shopping spree'), findsNothing);
    expect(find.textContaining('across seasons'), findsNothing);
  });

  testWidgets('upgrading a facility levels it up and advances the effect '
      'line and pips', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // Level-0 card: dimmed first-level effect ('+0.9% Attack'), no
    // arrow chip duplicating it, price button showing 4k.
    expect(find.text('+0.9% Attack'), findsOneWidget);
    expect(find.text('+1.8%'), findsNothing);

    // Tap the Attack Academy's price button (first card in the list).
    final card = tester
        .widgetList<FacilityCard>(find.byType(FacilityCard))
        .first;
    expect(card.facility, Facility.attack);
    await tester.tap(find.byType(FcmButton).first);
    await tester.pumpAndSettle();
    // Real I/O for the upgrade write + provider invalidation.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    // Now level 1: live effect with the gold '+1.8%' next-level delta.
    expect(find.text('LV 1'), findsOneWidget);
    expect(find.text('+1.8%'), findsOneWidget);
    final campus = await tester.runAsync(() => store.getCampus());
    expect(campus!.levelOf(Facility.attack), 1);
  });

  testWidgets('a maxed facility shows MAX instead of a price button', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Seed WITHOUT pumping the screen yet, doctor the database, then
    // pump once — the provider then resolves against the final state.
    await seedStore(tester);
    await tester.runAsync(() async {
      final club = await store.getClub();
      await db
          .into(db.facilityLevels)
          .insert(
            FacilityLevelsCompanion.insert(
              clubId: club!.id,
              facility: Facility.attack.name,
              level: const Value(10),
            ),
          );
    });
    await pumpScreen(tester);

    expect(find.text('LV 10'), findsOneWidget);
    expect(find.byType(FcmPill), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    // Five price buttons remain for the other facilities.
    expect(find.byType(FcmButton), findsNWidgets(5));
    // Maxed card shows the final effect with no next-level delta.
    expect(find.text('+9.0% Attack'), findsOneWidget);
  });
}
