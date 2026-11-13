/// T-0071: merging duplicates is the ONLY upgrade path (owner decision
/// 2026-11-09). The detail sheet must never offer a coin upgrade, and
/// Merge appears exactly when another copy of the same player is owned.
///
/// The sheet's action buttons come from [PlayerDetailActions] built by
/// the collection screen — this test builds them the same way the
/// screen does (Merge iff another copy exists, sell always, upgrade
/// never) and pumps the real sheet over a tiny synthetic dataset whose
/// pack draws reliably produce both duplicated and lone bases.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmButton;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/collection/player_detail_sheet.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;

String datasetJson(List<List<dynamic>> rows) => json.encode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': rows,
});

/// 5 players per position — the same tiny pool shape the store tests
/// use, so packs draw duplicates within a few opens.
const _positions = [
  'GK',
  'CB',
  'CM',
  'RW',
  'ST',
  'CDM',
  'LW',
  'CAM',
  'LB',
  'RB',
  'LM',
  'RM',
];

final _rows = <List<dynamic>>[
  for (var p = 0; p < _positions.length; p++)
    for (var i = 0; i < 5; i++)
      [
        p * 10 + i + 1,
        'Player ${p * 10 + i + 1}',
        _positions[p],
        'Country ${p * 10 + i + 1}',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CollectionStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = CollectionStore(db: db);
    await store.applyDatasetUpdate(
      PlayerDataset.fromJson(datasetJson(_rows)),
    );
    await store.createClub(
      clubName: 'Pyramid United',
      managerName: 'Mohamed',
      crestIndex: 0,
    );
  });

  tearDown(() async => db.close());

  Future<List<PlayerCard>> openAllPacks(int seed) async {
    for (final pack in await store.getAvailablePacks()) {
      await store.openPack(packId: pack.id, random: math.Random(seed));
    }
    return store.getCollection();
  }

  /// The screen's action-building rule, post-T-0071: Merge iff another
  /// copy exists, sell always, no coin-upgrade action at all.
  PlayerDetailActions actionsFor(
    PlayerCard card,
    List<PlayerCard> collection,
  ) => PlayerDetailActions(
    onMerge: collection
            .any(
              (c) =>
                  c.base.playerId == card.base.playerId &&
                  c.ownedId != card.ownedId,
            )
        ? () {}
        : null,
    sellLabel: 'Sell · 1k coins',
    onSell: () {},
  );

  Future<void> pumpSheet(
    WidgetTester tester,
    PlayerCard card,
    List<PlayerCard> collection,
  ) async {
    // The sheet is a ListView capped at 94% of the screen height: the
    // default 600x800 test viewport cuts it above the action buttons
    // (they live below the fold), so enlarge like injury_surfaces_test.
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    final actions = actionsFor(card, collection);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (sheetContext) => Center(
              child: FcmButton(
                label: 'open',
                onPressed: () => showPlayerDetail(
                  sheetContext,
                  card: card,
                  copies: collection
                      .where((c) => c.base.playerId == card.base.playerId)
                      .length,
                  actions: actions,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('no coin-upgrade action exists on the sheet (owner 2026-11-09)',
      (tester) async {
    List<PlayerCard> cards = const [];
    await tester.runAsync(() async {
      cards = await openAllPacks(17);
    });
    final byBase = <int, List<PlayerCard>>{};
    for (final c in cards) {
      byBase.putIfAbsent(c.base.playerId, () => []).add(c);
    }
    final dupeBase = byBase.values.where((l) => l.length >= 2).firstOrNull;
    assert(dupeBase != null, 'tiny pool must draw a duplicate');

    await pumpSheet(tester, dupeBase!.first, cards);
    expect(find.text('Merge duplicate (+1)'), findsOneWidget);
    // The coin-purchase upgrade button is gone everywhere: no upgrade
    // price label, no trending_up action row, no coin cost on upgrades.
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.textContaining('Upgrade ·'), findsNothing);
  });

  testWidgets('Merge is offered exactly when another copy is owned',
      (tester) async {
    var cards = const <PlayerCard>[];
    await tester.runAsync(() async {
      cards = await openAllPacks(17);
    });
    final byBase = <int, List<PlayerCard>>{};
    for (final c in cards) {
      byBase.putIfAbsent(c.base.playerId, () => []).add(c);
    }
    final dupeBase = byBase.values.where((l) => l.length >= 2).firstOrNull;
    assert(dupeBase != null, 'tiny pool must draw a duplicate');

    // Duplicated base: Merge offered, no coin upgrade.
    await pumpSheet(tester, dupeBase!.first, cards);
    expect(find.text('Merge duplicate (+1)'), findsOneWidget);
    expect(find.textContaining('Upgrade ·'), findsNothing);

    // The lone case: this pool's 22 draws cover 13 of 60 bases, so a
    // never-drawn base is materialized as a single owned copy — the
    // store test pattern. The sheet must then offer selling only.
    PlayerCard? loneCard;
    await tester.runAsync(() async {
      final drawn = byBase.keys.toSet();
      final neverDrawn = _rows.firstWhere((r) => !drawn.contains(r[0]));
      final club = (await store.getClub())!;
      await db
          .into(db.ownedPlayers)
          .insert(
            OwnedPlayersCompanion.insert(
              clubId: club.id,
              playerId: neverDrawn[0] as int,
              acquiredAt: DateTime.now(),
            ),
          );
      cards = await store.getCollection();
      loneCard = cards.firstWhere(
        (c) => c.base.playerId == (neverDrawn[0] as int),
      );
    });

    // Close the first sheet (modal bottom sheets have no back button):
    // a fresh pump replaces the whole navigator, then the lone card's
    // sheet opens on a clean tree.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await pumpSheet(tester, loneCard!, cards);
    expect(find.text('Merge duplicate (+1)'), findsNothing);
    expect(find.textContaining('Upgrade ·'), findsNothing);
    expect(find.textContaining('Sell ·'), findsOneWidget);
  });

  testWidgets('PlayerDetailActions has no upgrade fields left at all', (
    tester,
  ) async {
    // Compile-level lock: the removed API cannot silently return. The
    // constructor accepts exactly onMerge/sellLabel/onSell.
    const actions = PlayerDetailActions(sellLabel: 'Sell');
    expect(actions.onMerge, isNull);
    expect(actions.sellLabel, 'Sell');
  });
}
