// Renders the redesigned campus tab as a golden image for the visual
// check (dev-only; excluded from the normal suite by the _golden suffix
// convention — run with --update-goldens to regenerate).
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/facilities/campus_screen.dart';

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

  testWidgets('campus visual snapshot', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

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
    // A mid-progress campus: attack 3, recovery 1, rest level 0.
    await tester.runAsync(() async {
      final club = await store.getClub();
      Future<void> set(String f, int l) => db
          .into(db.facilityLevels)
          .insert(
            FacilityLevelsCompanion.insert(
              clubId: club!.id,
              facility: f,
              level: Value(l),
            ),
          );
      await set('attack', 3);
      await set('recovery', 1);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: const MaterialApp(home: Scaffold(body: CampusScreen())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();

    // Layout metrics instead of a binary golden (anti-aliasing differs
    // per platform): every card renders within bounds and nothing
    // overflows — the compact design must stay compact.
    expect(tester.takeException(), isNull);
    final cards = tester
        .widgetList<FacilityCard>(find.byType(FacilityCard))
        .toList();
    expect(cards.length, 6);
    for (final card in cards) {
      final rect = tester.getRect(find.byWidget(card));
      expect(
        rect.height,
        lessThan(150),
        reason: '${card.facility.title} card grew beyond compact budget',
      );
      expect(rect.width, greaterThan(300));
    }
    // First card is mid-progress (attack level 3): its delta chip shows.
    expect(find.text('+2.7% Attack'), findsOneWidget);
    expect(find.text('+3.6%'), findsOneWidget);
    expect(find.text('LV 3'), findsOneWidget);
  });
}
