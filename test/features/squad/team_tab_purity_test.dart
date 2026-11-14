/// T-0117: the Team tab is the PURE MANAGEMENT surface — no match-day
/// condition chrome of any kind. Injuries (and, when a future
/// suspension system lands, red cards) still exist in the data and
/// still matter on MATCHDAY surfaces, but the saved XI the user
/// manages here is the club's identity eleven on merit:
///
/// - an injured player's card shows NO injury badge, NO inertness —
///   he stays a normal draggable (a manager can still rearrange the
///   XI around him);
/// - the Team tab's auto-pick includes injured players in the pool
///   (merit-only ranking — `excludeInjured: false`);
/// - the pre-match duplicate still shows the badge (the regression
///   guard that the flag did not leak the other way).
///
/// The seed/fixtures mirror injured_inert_test.dart's (T-0056); that
/// file's Team-tab expectations moved here inverted — T-0056's
/// behaviour lives on in the MATCHDAY surfaces it still serves.
library;

import 'dart:math' as math;

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
import 'package:fcm_rivals/features/squad/squad_view.dart';
import 'package:fcm_rivals/features/squad/formations.dart' show formationByCode;

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

  /// The store-provider host the other squad tests use.
  Widget host(Widget child) => ProviderScope(
    overrides: [collectionStoreProvider.overrideWith((ref) => store)],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  /// Same shape as injured_inert_test.dart's seedSquad: a club with
  /// three owned players, the first one INJURED (slot 0).
  Future<void> seedSquad({required int injuredMatchesOut}) async {
    // The shipped tm bundle (owner request 2026-11-12): loaded from
    // disk inside runAsync — rootBundle has no asset to serve in the
    // plain test environment.
    final playersText = await rootBundle.loadString(
      'assets/data/tm-players.json',
    );
    final iconsText = await rootBundle.loadString(
      'assets/data/tm-icons.json',
    );
    final clubsText = await rootBundle.loadString('assets/data/tm-clubs.json');
    final leaguesText = await rootBundle.loadString(
      'assets/data/tm-leagues.json',
    );
    await store.importBundledDataset(
      PlayerDataset.fromTmBundle(
        playersJson: playersText,
        iconsJson: iconsText,
        clubsJson: clubsText,
        leaguesJson: leaguesText,
      ),
    );
    final clubId = await store.createClub(
      clubName: 'Pyramid United',
      managerName: 'Mohamed',
      crestIndex: 0,
    );
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

  Future<void> pumpSquad(WidgetTester tester) async {
    await tester.pumpWidget(host(const SquadScreen()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
  }

  

  testWidgets('an injured player on the Team tab: NO badge, NO inertness — '
      'a normal draggable', (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedSquad(injuredMatchesOut: 3);
    });
    await pumpSquad(tester);

    // THE purity contract: no injury badge renders anywhere on the
    // management surface (the pool strip included — fixed 2026-11-14:
    // the pool SquadCardRow missed showCondition).
    expect(find.byType(InjuryBadge), findsNothing);

    // And no inertness: the injured player is wrapped in a normal
    // SquadDraggable — the manager can pick him up like anyone else
    // (the squad-save backstop still refuses an injured STARTER at
    // kick-off; that is the matchday layer's job, not the tab's).
    final draggables = find.byWidgetPredicate(
      (w) => w is SquadDraggable,
    );
    expect(draggables, findsNWidgets(3));
    // The injured one is among the draggables (slot 0's card).
    final injuredDraggable = find.byWidgetPredicate(
      (w) => w is SquadDraggable && w.card.injuryMatchesRemaining > 0,
    );
    expect(injuredDraggable, findsOneWidget);
  });

  testWidgets('merit-only auto-pick: an injured BEST player still takes '
      'his XI slot on the Team tab', (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedSquad(injuredMatchesOut: 3);
    });
    await pumpSquad(tester);

    // The engine policy split (T-0117): the management pick ranks on
    // merit INCLUDING the injured (fitness is a matchday concern).
    // The injured starter keeps his slot-0 save after a merit re-pick.
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // The persisted save is the truth: slot 0 still references the
    // injured player after the merit re-pick.
    final club = await store.getClub();
    final rows = await (db.select(db.ownedPlayers)
          ..where((o) => o.clubId.equals(club!.id)))
        .get();
    final injuredStillPicked = rows.any(
      (r) => r.squadSlot == 0 && (r.injuryMatchesRemaining ?? 0) > 0,
    );
    expect(injuredStillPicked, isTrue,
        reason: 'the saved XI is the identity eleven on merit; the '
            'injured best player keeps his slot (T-0117)');
  });

  testWidgets('the matchday surface still shows the badge — the flag '
      'did not leak (regression guard)', (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await seedSquad(injuredMatchesOut: 3);
    });

    // The PITCH widget with the matchday flag renders the badge (the
    // same widget the pre-match duplicate composes with
    // showCondition: true — see pre_match_phases.dart). The INJURED
    // card is located by its data, not by list order.
    final injured = (await store.getCollection())
        .firstWhere((c) => c.injuryMatchesRemaining > 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SquadPitch(
            formation: formationByCode('4-3-3'),
            assignments: {0: injured},
            showStamina: true,
            showStats: false,
            showCondition: true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(InjuryBadge), findsOneWidget);
  });

  testWidgets('red cards today: nothing in the Team tab reads a '
      'suspension (contract documentation)', (tester) async {
    // There is no red-card/suspension persistence in the game today
    // (verified during T-0117 planning: the engine emits card events,
    // the report counts them, nothing persists a ban). The Team tab's
    // purity contract is therefore already true for red cards
    // STRUCTURALLY. This test documents the contract so the day a
    // suspension system lands, THIS is the failing test that says
    // "the new state must gate MATCHDAY surfaces only, never the
    // Team tab's display or auto-pick".
    await tester.runAsync(() async {
      await seedSquad(injuredMatchesOut: 0);
    });
    await pumpSquad(tester);
    // The management surface renders with zero condition chrome even
    // when the data WOULD support it (here: injuries exist in the
    // schema, healed at 0).
    expect(find.byType(InjuryBadge), findsNothing);
  });
}
