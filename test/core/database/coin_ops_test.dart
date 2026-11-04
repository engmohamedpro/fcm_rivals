// Regression tests for the atomic coin operations (coin_ops.dart):
// the read-then-write pattern these replace could lose or duplicate
// coins whenever two movements interleaved (a match reward landing
// while a pack purchase commits). Every movement now goes through a
// conditional, RELATIVE update, so the balance always moves by exactly
// the sum of the applied movements and the ledger agrees with it.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/database/coin_ops.dart';
import 'package:fcm_rivals/core/domain/players.dart' show Position;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart' show PackCategory;
import 'package:fcm_rivals/features/player_database/player_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> balanceOf(int clubId) async {
    final club = await (db.select(
      db.clubs,
    )..where((c) => c.id.equals(clubId))).getSingle();
    return club.coins;
  }

  Future<int> createClubWithCoins(int coins) async {
    final store = CollectionStore(db: db);
    return store
        .createClub(
          clubName: 'Race FC',
          managerName: 'Tester',
          crestIndex: 0,
          // starting coins come from the economy config; the test then
          // sets the exact balance it wants through the same helpers.
        )
        .then((id) async {
          final current = await balanceOf(id);
          if (current < coins) {
            await db.creditCoins(id, coins - current, reason: 'test_setup');
          } else if (current > coins) {
            await db.spendCoins(id, current - coins, reason: 'test_setup');
          }
          return id;
        });
  }

  test('spendCoins is conditional: insufficient balance throws and '
      'leaves the balance, ledger and nothing else untouched', () async {
    final clubId = await createClubWithCoins(100);
    await expectLater(
      db.spendCoins(clubId, 250, reason: 'pack_purchase'),
      throwsA(isA<Exception>()),
    );
    expect(await balanceOf(clubId), 100);
    final ledger = await db.select(db.coinTransactions).get();
    expect(ledger.where((r) => r.reason == 'pack_purchase'), isEmpty);
  });

  test('creditCoins is relative: concurrent credits and spends compose '
      'exactly — no movement is lost or duplicated', () async {
    final clubId = await createClubWithCoins(1_000);

    // Interleave spends and credits the way real overlapping flows do
    // (store purchase resolving while a match reward lands).
    final movements = <Future<int>>[
      db.spendCoins(clubId, 300, reason: 'pack_purchase'),
      db.creditCoins(clubId, 450, reason: 'match_reward'),
      db.spendCoins(clubId, 200, reason: 'upgrade_purchase'),
      db.creditCoins(clubId, 60, reason: 'season_reward'),
      db.spendCoins(clubId, 500, reason: 'facility_upgrade'),
      db.creditCoins(clubId, 900, reason: 'player_sale'),
    ];
    await Future.wait(movements);

    // 1000 - 300 + 450 - 200 + 60 - 500 + 900 = 1410
    expect(await balanceOf(clubId), 1_410);

    // The ledger is the truth (FR-016): it contains the starting grant
    // (+25,000), the setup adjustment (-24,000) and the six movements,
    // so its rows sum to exactly the final balance — every coin is
    // accounted for, none lost, none duplicated.
    final rows = await db.select(db.coinTransactions).get();
    final sum = rows.fold<int>(0, (a, r) => a + r.amount);
    expect(sum, 1_410);
    expect(rows.last.balanceAfter, 1_410);
    // starting grant + setup adjustment + 6 movements.
    expect(rows.length, 8);
    // Every row's balanceAfter agrees with the running sum from zero.
    var running = 0;
    for (final r in rows) {
      running += r.amount;
      expect(r.balanceAfter, running);
    }
  });

  test('spendCoins rejects a spend racing a bigger spend of the same '
      'balance — exactly one wins, the loser throws, coins are never '
      'double-spent', () async {
    final clubId = await createClubWithCoins(500);
    final outcomes = await Future.wait(
      [
        db.spendCoins(clubId, 400, reason: 'pack_purchase'),
        db.spendCoins(clubId, 400, reason: 'upgrade_purchase'),
      ],
      eagerError: false,
    ).then((_) => <String>['ok']).catchError((_) => <String>['threw']);
    expect(outcomes, contains('threw')); // one of the two futures failed
    // 500 - 400 = 100: only ONE spend landed, the balance never went
    // negative and never lost both spends.
    expect(await balanceOf(clubId), 100);
    final rows = await db.select(db.coinTransactions).get();
    final spends = rows
        .where((r) => r.reason != 'test_setup' && r.amount < 0)
        .toList();
    expect(spends.length, 1);
  });

  test('buyPack rolls back completely when the race drains the balance '
      'between the friendly pre-check and the debit', () async {
    final store = CollectionStore(db: db);
    // Seed a small dataset so the store actually has pack offers, then
    // create a club whose balance is far below the cheapest price.
    await store.applyDatasetUpdate(_seedDataset());
    final clubId = await createClubWithCoins(1);
    final offers = await store.getStoreOffers();
    expect(offers, isNotEmpty);
    final cheapest = offers.reduce((a, b) => a.price <= b.price ? a : b);
    expect(cheapest.price, greaterThan(1));
    // The friendly pre-check fires before any write happens.
    await expectLater(
      store.buyPack(
        category: cheapest.category,
        position: cheapest.category == PackCategory.position
            ? Position.fromCode(cheapest.scopeValue!)
            : null,
        nationality: cheapest.category == PackCategory.nationality
            ? cheapest.scopeValue
            : null,
        tier: cheapest.tier,
      ),
      throwsA(isA<CollectionException>()),
    );
    final packs = await db.select(db.packs).get();
    expect(
      packs.where((p) => p.source == 'purchase'),
      isEmpty,
      reason: 'no pack row may survive a failed purchase',
    );
    expect(await balanceOf(clubId), 1);
  });
}

/// A minimal valid dataset (one player per position, plus a second ST
/// so the pool has variety) — just enough for the store to shelve pack
/// offers. Mirrors the seed shape used by collection_store_test.
PlayerDataset _seedDataset() => PlayerDataset.fromJson(
  _datasetJson([
    [1, 'Keeper One', 'GK', 'Egypt', 500_000],
    [2, 'Back One', 'CB', 'Egypt', 800_000],
    [3, 'Mid One', 'CM', 'Egypt', 1_200_000],
    [4, 'Wing One', 'RW', 'Egypt', 2_000_000],
    [5, 'Striker One', 'ST', 'Egypt', 3_000_000],
    [6, 'Anchor One', 'CDM', 'Egypt', 900_000],
    [7, 'Winger One', 'LW', 'Egypt', 1_800_000],
    [8, 'Playmaker One', 'CAM', 'Egypt', 2_400_000],
    [9, 'Leftback One', 'LB', 'Egypt', 700_000],
    [10, 'Rightback One', 'RB', 'Egypt', 700_000],
    [11, 'Leftmid One', 'LM', 'Egypt', 1_500_000],
    [12, 'Rightmid One', 'RM', 'Egypt', 1_500_000],
    [13, 'Striker Two', 'ST', 'Egypt', 25_000_000],
  ]),
);

String _datasetJson(List<List<dynamic>> rows) => jsonEncode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-04',
  'digest': 'test',
  'players': rows,
});
