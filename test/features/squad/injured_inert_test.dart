/// T-0056: injured players in squad selection — badge on the pitch and
/// strips, and fully inert selection: no pickup (SquadDraggable), no
/// drop target. The store's save-time refusal (T-0055) stays the
/// backstop; these tests lock the UI layer over a real in-memory store.
library;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/injury_badge.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/squad_drag.dart';
import 'package:fcm_rivals/features/squad/squad_screen.dart';
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

  /// Dataset + club + three owned players: an INJURED starter in slot 0
  /// and two fit players in slots 1 and 2.
  Future<void> seedSquad({required int injuredMatchesOut}) async {
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
    final rows = owned.take(3).toList();
    await (db.update(
      db.ownedPlayers,
    )..where((o) => o.id.equals(rows[0].id))).write(
      OwnedPlayersCompanion(
        squadSlot: const Value(0),
        injuryMatchesRemaining: Value(injuredMatchesOut),
        injuryKind: injuredMatchesOut > 0
            ? const Value('serious')
            : const Value(null),
      ),
    );
    await (db.update(
      db.ownedPlayers,
    )..where((o) => o.id.equals(rows[1].id))).write(
      const OwnedPlayersCompanion(squadSlot: Value(1)),
    );
    await (db.update(
      db.ownedPlayers,
    )..where((o) => o.id.equals(rows[2].id))).write(
      const OwnedPlayersCompanion(squadSlot: Value(2)),
    );
  }

  Future<void> pumpSquad(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: locale == null
            ? const MaterialApp(home: Scaffold(body: SquadScreen()))
            : MaterialApp(
                locale: locale,
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: SquadScreen()),
              ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('an injured starter wears the badge and is inert — no '
      'pickup, no drop target; fit players stay draggable', (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await seedSquad(injuredMatchesOut: 3);
    await pumpSquad(tester);

    // The badge is on the pitch.
    expect(find.byType(InjuryBadge), findsWidgets);
    // NO draggable wraps an injured card — he cannot be picked up.
    expect(
      find.byWidgetPredicate(
        (w) => w is SquadDraggable && w.card.injuryMatchesRemaining > 0,
      ),
      findsNothing,
      reason: 'the injured starter is non-selectable in the squad save '
          'flow (requirement 1)',
    );
    // The fit players remain draggable.
    expect(
      find.byWidgetPredicate(
        (w) => w is SquadDraggable && w.card.injuryMatchesRemaining == 0,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('the same squad renders badges in Arabic (RTL locale)',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await seedSquad(injuredMatchesOut: 1);
    await pumpSquad(tester, locale: const Locale('ar'));

    expect(find.byType(InjuryBadge), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('with the injury healed, the card is selectable again',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await seedSquad(injuredMatchesOut: 0);
    await pumpSquad(tester);

    expect(find.byType(InjuryBadge), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is SquadDraggable && w.card.injuryMatchesRemaining == 0,
      ),
      findsNWidgets(3),
      reason: 'all three returned players drag',
    );
  });
}
