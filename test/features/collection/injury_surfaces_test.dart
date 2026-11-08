/// T-0056: the collection surfaces' injury state — the grid card badge
/// and the detail sheet's availability line — over a real in-memory
/// store, in EN (fallback) and AR (delegates scoped in).
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmButton;
import 'package:fcm_rivals/core/ui/injury_badge.dart';
import 'package:fcm_rivals/features/collection/collection_collection_screen.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/collection/player_detail_sheet.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/l10n/app_localizations.dart';

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

  /// Dataset + club + one owned player, marked injured when [matchesOut]
  /// is positive.
  Future<int> seedOwned({required int matchesOut}) async {
    final jsonText = await rootBundle.loadString(
      'assets/data/players_v1.json',
    );
    await store.importBundledDataset(PlayerDataset.fromJson(jsonText));
    final clubId = await store.createClub(
      clubName: 'Pyramid United',
      managerName: 'Mohamed',
      crestIndex: 0,
    );
    final owned = await (db.select(
      db.ownedPlayers,
    )..where((o) => o.clubId.equals(clubId))).get();
    final row = owned.first;
    if (matchesOut > 0) {
      await (db.update(
        db.ownedPlayers,
      )..where((o) => o.id.equals(row.id))).write(
        OwnedPlayersCompanion(
          injuryMatchesRemaining: Value(matchesOut),
          injuryKind: const Value('serious'),
        ),
      );
    }
    return row.id;
  }

  Future<PlayerCard> ownedCard(int ownedId) async =>
      (await store.getCollection()).firstWhere((c) => c.ownedId == ownedId);

  Future<void> pumpSheet(
    WidgetTester tester,
    PlayerCard card, {
    Locale? locale,
    required String trigger,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: locale == null
            ? null
            : AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (sheetContext) => Center(
              child: FcmButton(
                label: trigger,
                onPressed: () =>
                    showPlayerDetail(sheetContext, card: card),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(trigger));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('the detail sheet states the availability with the badge '
      '(EN)', (tester) async {
    final ownedId = await seedOwned(matchesOut: 3);
    await pumpSheet(tester, await ownedCard(ownedId), trigger: 'open');

    expect(find.byType(InjuryBadge), findsOneWidget);
    expect(find.text('Out for 3 matches'), findsOneWidget);
  });

  testWidgets('a fit player shows no availability line', (tester) async {
    final ownedId = await seedOwned(matchesOut: 0);
    await pumpSheet(tester, await ownedCard(ownedId), trigger: 'open');

    expect(find.textContaining('Out for'), findsNothing);
    expect(find.byType(InjuryBadge), findsNothing);
  });

  testWidgets('the Arabic sheet renders the localized line (RTL)',
      (tester) async {
    final ownedId = await seedOwned(matchesOut: 2);
    await pumpSheet(
      tester,
      await ownedCard(ownedId),
      trigger: 'افتح',
      locale: const Locale('ar'),
    );

    expect(find.text('خارج 2 مباراة'), findsOneWidget);
  });

  testWidgets('the collection grid card carries the badge over the '
      'injured player (EN)', (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await seedOwned(matchesOut: 3);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: const MaterialApp(home: Scaffold(body: CollectionScreen())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(InjuryBadge), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });
}
