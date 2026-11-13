// Squad capacity: a club owns at most 30 DISTINCT players (extra copies
// of one player count once); a full squad can neither buy nor open
// packs; blocks of 5 slots are bought with Coins at a rising price.
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

const _positions = [
  'GK', 'CB', 'CM', 'RW', 'ST', 'CDM', 'LW', 'CAM', 'LB', 'RB', 'LM', 'RM',
];

/// 12 positions x 5 players = 60 distinct players.
String _dataset() => json.encode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': [
    for (var p = 0; p < _positions.length; p++)
      for (var i = 0; i < 5; i++)
        [
          p * 10 + i + 1,
          'Player ${p * 10 + i + 1}',
          _positions[p],
          'Egypt',
          500_000 + (i * 3_000_000) + p * 100_000,
        ],
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CollectionStore store;
  late int clubId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = CollectionStore(db: db);
    await store.applyDatasetUpdate(PlayerDataset.fromJson(_dataset()));
    clubId = await store.createClub(
      clubName: 'FC Rivals',
      managerName: 'Mohamed',
      crestIndex: 0,
    );
  });

  tearDown(() async => db.close());

  /// Gives the club one owned copy of each of [distinct] different
  /// players, plus [extraCopies] more copies of the first of them.
  Future<void> own(int distinct, {int extraCopies = 0}) async {
    final ids = (await db.select(db.players).get())
        .map((p) => p.playerId)
        .take(distinct)
        .toList();
    final now = DateTime.now();
    for (final id in ids) {
      await db.into(db.ownedPlayers).insert(
        OwnedPlayersCompanion.insert(
          clubId: clubId,
          playerId: id,
          acquiredAt: now,
        ),
      );
    }
    for (var c = 0; c < extraCopies; c++) {
      await db.into(db.ownedPlayers).insert(
        OwnedPlayersCompanion.insert(
          clubId: clubId,
          playerId: ids.first,
          acquiredAt: now,
        ),
      );
    }
  }

  test('a new club starts with 30 slots, none used, and a priced next '
      'block', () async {
    final cap = await store.getSquadCapacity();
    const cfg = EconomyConfig();
    expect(cap.capacity, 30);
    expect(cap.owned, 0);
    expect(cap.isFull, isFalse);
    expect(cap.blocksBought, 0);
    expect(cap.nextBlockSlots, cfg.squadSlotsPerPurchase);
    expect(cap.nextBlockPrice, cfg.squadSlotBasePrice);
  });

  test('copies of one player count as ONE player', () async {
    await own(3, extraCopies: 5); // 8 owned rows, 3 distinct players
    final cap = await store.getSquadCapacity();
    expect(cap.owned, 3);
    expect(cap.free, 27);
  });

  test('the slot price rises by one step per block', () {
    const engine = EconomyEngine();
    expect(engine.squadCapacity(0), 30);
    expect(engine.squadCapacity(2), 40);
    expect(engine.squadSlotBlockPrice(0), 8000);
    expect(engine.squadSlotBlockPrice(1), 12000);
    expect(engine.squadSlotBlockPrice(2), 16000);
  });

  test('a full squad cannot open a pack — and the pack stays unopened',
      () async {
    await own(30);
    final pack = (await store.getAvailablePacks()).first;
    await expectLater(
      store.openPack(packId: pack.id, random: math.Random(1)),
      throwsA(
        isA<CollectionException>().having(
          (e) => e.message,
          'message',
          contains('squad is full'),
        ),
      ),
    );
    expect((await store.getAvailablePacks()).length, 22);
  });

  test('a full squad cannot BUY a pack either — no coins are charged',
      () async {
    await own(30);
    final before = (await store.getClub())!.coins;
    await expectLater(
      store.buyPack(category: PackCategory.global, tier: PackTier.rare),
      throwsA(isA<CollectionException>()),
    );
    expect((await store.getClub())!.coins, before);
  });

  test('one free slot is enough: the pack opens and fills it', () async {
    await own(29, extraCopies: 4); // duplicates do not use slots
    final pack = (await store.getAvailablePacks()).first;
    final result = await store.openPack(
      packId: pack.id,
      random: math.Random(1),
    );
    expect(result.players, isNotEmpty);
    expect((await store.getSquadCapacity()).owned, lessThanOrEqualTo(30));
  });

  test('buying slots charges the price, raises the capacity and the next '
      'price, and writes a ledger row per block', () async {
    final start = (await store.getClub())!.coins;
    final first = await store.buySquadSlots();
    expect(first.capacity, 35);
    expect(first.blocksBought, 1);
    expect(first.nextBlockPrice, 12000);
    expect((await store.getClub())!.coins, start - 8000);

    final second = await store.buySquadSlots();
    expect(second.capacity, 40);
    expect(second.nextBlockPrice, 16000);
    expect((await store.getClub())!.coins, start - 8000 - 12000);

    final rows = await (db.select(db.coinTransactions)
          ..where((t) => t.reason.equals(
                CollectionStore.squadSlotsLedgerReason,
              )))
        .get();
    expect(rows.map((r) => r.amount), [-8000, -12000]);
  });

  test('a block the club cannot afford is refused and changes nothing',
      () async {
    await store.buySquadSlots(); // 8k
    await store.buySquadSlots(); // 12k -> 5k left, next costs 16k
    final coins = (await store.getClub())!.coins;
    await expectLater(
      store.buySquadSlots(),
      throwsA(
        isA<CollectionException>().having(
          (e) => e.message,
          'message',
          'Not enough coins',
        ),
      ),
    );
    expect((await store.getClub())!.coins, coins);
    expect((await store.getSquadCapacity()).capacity, 40);
  });

  test('buying slots lets a full squad open packs again', () async {
    await own(30);
    await store.buySquadSlots();
    final pack = (await store.getAvailablePacks()).first;
    final result = await store.openPack(
      packId: pack.id,
      random: math.Random(1),
    );
    expect(result.players, isNotEmpty);
  });

  test('the simulator switch (enforceSquadCapacity: false) lifts the cap',
      () async {
    final free = CollectionStore(db: db, enforceSquadCapacity: false);
    await own(30);
    final pack = (await free.getAvailablePacks()).first;
    final result = await free.openPack(
      packId: pack.id,
      random: math.Random(1),
    );
    expect(result.players, isNotEmpty);
  });
}
