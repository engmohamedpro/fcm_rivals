/// T-0056: injured players in MATCHDAY squad surfaces — badge on the
/// pitch and strips, and fully inert selection: no pickup
/// (SquadDraggable), no drop target. The store's save-time refusal
/// (T-0055) stays the backstop; these tests lock the UI layer over a
/// real in-memory store.
///
/// T-0117 narrowed WHERE that behaviour lives: the Team tab is the
/// pure management surface (no condition chrome — its contracts are
/// in team_tab_purity_test.dart). These badges/inertness expectations
/// therefore assert on the matchday flag surface (SquadPitch/
/// SquadCardRow with showCondition: true), which is what the pre-match
/// duplicate and the live surfaces render.
library;

import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/injury_badge.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/formations.dart'
    show Formation, formationByCode;
import 'package:fcm_rivals/features/squad/squad_drag.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart'
    show PlayerCard;
import 'package:fcm_rivals/features/squad/squad_view.dart';
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
    // A fresh club owns packs, not players (GDD 5.8): open three
    // starting packs to materialize the owned instances below.
    final packs = await store.getAvailablePacks();
    for (var i = 0; i < 3; i++) {
      await store.openPack(packId: packs[i].id, random: math.Random(5));
    }
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

  /// The club's saved squad (slot → card) as the matchday pitch
  /// renders it: showCondition TRUE (the pre-match duplicate's view).
  /// The slot mapping lives in the DB rows, not on PlayerCard.
  Future<Map<int, PlayerCard>> savedXi() async {
    final club = await store.getClub();
    final rows = await (db.select(db.ownedPlayers)
          ..where((o) => o.clubId.equals(club!.id)))
        .get();
    final cards = await store.getCollection();
    final byId = {for (final c in cards) c.ownedId: c};
    return {
      for (final r in rows)
        if (r.squadSlot != null &&
            r.squadSlot! < Formation.startingXiSize)
          r.squadSlot!: byId[r.id]!,
    };
  }

  Future<void> pumpMatchdayPitch(WidgetTester tester,
      {Locale? locale}) async {
    final xi = await savedXi();
    await tester.pumpWidget(
      locale == null
          ? MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SquadPitch(
                    formation: formationByCode('4-3-3'),
                    assignments: xi,
                    showStamina: true,
                    showStats: false,
                    showCondition: true,
                  ),
                ),
              ),
            )
          : MaterialApp(
              locale: locale,
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SquadPitch(
                    formation: formationByCode('4-3-3'),
                    assignments: xi,
                    showStamina: true,
                    showStats: false,
                    showCondition: true,
                  ),
                ),
              ),
            ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('an injured starter wears the badge and is inert — no '
      'pickup, no drop target; fit players stay draggable', (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedSquad(injuredMatchesOut: 3);
    });
    await pumpMatchdayPitch(tester);

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
    await tester.runAsync(() async {
      await seedSquad(injuredMatchesOut: 1);
    });
    await pumpMatchdayPitch(tester, locale: const Locale('ar'));

    expect(find.byType(InjuryBadge), findsWidgets);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('with the injury healed, the card is selectable again',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedSquad(injuredMatchesOut: 0);
    });
    await pumpMatchdayPitch(tester);

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
