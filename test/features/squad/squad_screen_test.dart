// Tactics tab with an empty squad: the tab never hides the tactical
// setup behind a placeholder — a fresh club with zero owned players
// still gets the control card, the pitch with its eleven empty slots
// and a working Auto Pick. The hint panel sits ABOVE the view instead
// of replacing it.
//
// The store runs real drift I/O over an in-memory database, so async
// flushes use tester.runAsync (FakeAsync doesn't perform real I/O).
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/core/ui/player_card.dart' show FcmMiniCard;
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmDropdown;
import 'package:fcm_rivals/features/squad/squad_screen.dart';
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

  Future<void> bootScreen(WidgetTester tester, {Locale? locale}) async {
    final jsonText = await tester.runAsync(
      () => rootBundle.loadString('assets/data/players_v1.json'),
    );
    await tester.runAsync(() async {
        final dataset = PlayerDataset.fromJson(jsonText!);
        await store.importBundledDataset(dataset);
      });
    // Club with zero opened packs: the squad map resolves empty.
    await tester.runAsync(
      () => store.createClub(
        clubName: 'Pyramid United',
        managerName: 'Mohamed',
        crestIndex: 0,
      ),
    );

    // The DEFAULT pump is a plain MaterialApp — no delegates anywhere.
    // Every localized screen must stay self-contained through l10nOf's
    // English fallback; only the AR variant installs the delegates,
    // proving the generated bundle flows end-to-end when a host scopes
    // it in. This is the regression guard for the original null-crash.
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
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('empty squad still shows the full tactical setup', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester);

    // The hint explains how to fill the squad…
    expect(
      find.text('Open packs to collect players, then tap Auto Pick.'),
      findsOneWidget,
    );
    // …but the setup itself is fully present: control card with the
    // team rating and the default 4-3-3, and the pitch with eleven
    // empty slots.
    expect(find.byType(TacticsSetupView), findsOneWidget);
    expect(find.byType(SquadPitch), findsOneWidget);
    expect(find.text('4-3-3'), findsWidgets);
    // T-0092: the setup summary row is gone on the Team tab — no TEAM
    // RATING info block, and TACTICS now counts only the control
    // card's button.
    expect(find.text('TEAM RATING'), findsNothing);
    expect(find.text('TACTICS'), findsOneWidget);

    // Bench and reserves stay visible even with nothing assigned: full
    // quota of ghost placeholder cards — 7 bench slots, 5 reserve slots.
    expect(find.text('Bench (0/7)'), findsOneWidget);
    expect(find.text('Reserves (0/5)'), findsOneWidget);
    expect(
      find.byType(FcmMiniCard),
      findsNWidgets(11 + 12),
      reason: '11 formation ghost slots plus 12 bench/reserve ghosts',
    );

    // Auto Pick works with an empty collection: it simply assigns
    // nothing and confirms.
    await tester.tap(find.text('Auto Pick'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Best squad selected'), findsOneWidget);
    expect(find.byType(TacticsSetupView), findsOneWidget);
  });

  testWidgets(
    'T-0092: the Team tab hides the setup summary row — no TACTICS/'
    'MENTALITY/TEAM RATING texts',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await bootScreen(tester);

      // None of the summary row's three blocks render: the label, the
      // localized mentality value, the rating block.
      expect(find.text('TEAM RATING'), findsNothing);
      expect(find.text('TACTICS'), findsOneWidget,
          reason: 'only the control card button remains');
      expect(find.text('MENTALITY'), findsNothing);
      expect(find.text('Balanced'), findsNothing,
          reason: 'the mentality row value is gone with the row');

      // The card still reads: formation dropdown first, then the Auto
      // Pick + TACTICS buttons.
      expect(find.byType(FcmDropdown<String>), findsOneWidget);
      expect(find.text('4-3-3'), findsWidgets);
      expect(find.text('Auto Pick'), findsOneWidget);
    },
  );

  testWidgets(
    'T-0093: the drag-to-swap hint sentence is gone from the team screen',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await bootScreen(tester);

      // The Team tab always passes swapping — the hint sentence that
      // rode above the pitch is gone, while the pitch itself and the
      // hold-to-drag machinery still render.
      expect(
        find.text('Hold a player and drop him on another to swap'),
        findsNothing,
      );
      expect(find.byType(SquadPitch), findsOneWidget);
    },
  );

  // The pattern guard for every localized screen: delegates + AR locale
  // resolve the Arabic copy end-to-end through the generated bundle.
  testWidgets('Arabic locale renders the hint through the delegates', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await bootScreen(tester, locale: const Locale('ar'));

    expect(
      find.text('افتح الحزم لجمع اللاعبين ثم اضغط الاختيار التلقائي.'),
      findsOneWidget,
    );
    expect(find.byType(TacticsSetupView), findsOneWidget);
    expect(find.byType(SquadPitch), findsOneWidget);
  });

  // T-0089: upgradable marks on the team screen. A club with a
  // hand-seeded squad: three players placed through the real save
  // path — one XI member with a second owned copy, one bench member
  // with a second owned copy, and one XI member single-copy — plus
  // whatever the starter packs naturally produced (the seeded draws
  // pair many players, so the baseline is measured, not assumed).
  Future<Set<int>> seedMarkSquad(WidgetTester tester) async {
    final jsonText = await tester.runAsync(
      () => rootBundle.loadString('assets/data/players_v1.json'),
    );
    final all = await tester.runAsync(() async {
      final dataset = PlayerDataset.fromJson(jsonText!);
      await store.importBundledDataset(dataset);
      await store.createClub(
        clubName: 'Pyramid United',
        managerName: 'Mohamed',
        crestIndex: 0,
      );
      return db.select(db.players).get();
    });
    final club = (await tester.runAsync(() => store.getClub()))!;
    final now = DateTime.now();
    // Players with position codes matching XI slot needs: GK for slot
    // 0's keeper? No — slot 0 of the 4-3-3 pitch is the keeper. Pick
    // players whose positions fit the formation slots they take: keep
    // it simple — bench slots take anyone; XI slots need matching
    // positions (the pitch renders out-of-position too, warn only).
    final byPos = <String, List<Player>>{};
    for (final p in all!) {
      byPos.putIfAbsent(p.position, () => []).add(p);
    }
    final gk = byPos['GK']!.first;
    final st = byPos['ST']!.first;
    final cm = byPos['CM']!.first;
    Future<int> seed(int playerId, {int copies = 1}) async {
      var first = 0;
      for (var c = 0; c < copies; c++) {
        final id = await db
            .into(db.ownedPlayers)
            .insert(
              OwnedPlayersCompanion.insert(
                clubId: club.id,
                playerId: playerId,
                acquiredAt: now,
              ),
            );
        first = first == 0 ? id : first;
      }
      return first;
    }

    // XI member WITH a duplicate (slot 0 = GK), bench member WITH a
    // duplicate (slot 11), XI member SINGLE-copy (slot 9 = ST in the
    // 4-3-3 front three), bench single-copy (slot 12).
    final gkId = await seed(gk.playerId, copies: 2);
    final cmId = await seed(cm.playerId, copies: 2);
    final stId = await seed(st.playerId, copies: 1);
    await tester.runAsync(
      () => store.saveSquad({0: gkId, 9: stId, 11: cmId}),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [collectionStoreProvider.overrideWith((ref) => store)],
        child: const MaterialApp(home: Scaffold(body: SquadScreen())),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    return {gk.playerId, cm.playerId};
  }

  testWidgets(
    'T-0089: squad players with a duplicate carry the mark — pitch and '
    'bench alike; single copies show none',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await seedMarkSquad(tester);

      // Exactly the two seeded members carry the mark: one on the
      // pitch (slot 0), one on the bench (slot 11). The single-copy
      // members (slot 9, slot 12-empty) show none.
      final marks = find.byIcon(Icons.upload_rounded);
      expect(marks, findsNWidgets(2),
          reason: 'the two-copy GK on the pitch and the two-copy CM on '
              'the bench carry the mark; single copies do not');
    },
  );

  testWidgets(
    'T-0089: merging the duplicate clears the mark on the next build',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(2400, 3600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await seedMarkSquad(tester);
      expect(find.byIcon(Icons.upload_rounded), findsNWidgets(2));

      // Consume the GK's duplicate through the real merge (the
      // collection's own flow): his mark must disappear while the CM's
      // stays.
      final squad = await tester.runAsync(() => store.getSquad());
      final gkCard = squad![0]!;
      final gkDup = ((await tester.runAsync(() => store.getCollection()))!)
          .firstWhere(
            (c) => c.base.playerId == gkCard.base.playerId &&
                c.ownedId != gkCard.ownedId,
          )
          .ownedId;
      await tester.runAsync(
        () => store.mergeDuplicates(
          targetOwnedId: gkCard.ownedId,
          duplicateOwnedId: gkDup,
        ),
      );
      // The real app path: the merge already invalidated the
      // collection provider on the Collection tab; the Team tab's own
      // watch re-derives when it rebuilds. Force exactly that state:
      // invalidate through the LIVE container (the one the screen is
      // watching), then let a real frame land before re-entering.
      final liveContainer = ProviderScope.containerOf(
        tester.element(find.byType(SquadScreen)),
      );
      liveContainer.invalidate(collectionProvider);
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [collectionStoreProvider.overrideWith((ref) => store)],
          child: const MaterialApp(home: Scaffold(body: SquadScreen())),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.upload_rounded), findsOneWidget,
          reason: 'the merged GK lost his mark; the CM keeps his');
    },
  );
}
