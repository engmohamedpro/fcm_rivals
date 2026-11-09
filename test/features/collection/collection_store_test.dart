import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart'
    show PlayerAttribute, Position;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

String datasetJson(List<List<dynamic>> rows, {int version = 1}) => json.encode({
  'format': 'fcm-rivals-players',
  'version': version,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': rows,
});

/// 5 players per position so every position pack has a real tiered pool.
const List<List<String>> _seedPositions = [
  ['GK', 'Keeper'],
  ['CB', 'Back'],
  ['CM', 'Midfield'],
  ['RW', 'Wing'],
  ['ST', 'Striker'],
  ['CDM', 'Anchor'],
  ['LW', 'Winger'],
  ['CAM', 'Playmaker'],
  ['LB', 'Leftback'],
  ['RB', 'Rightback'],
  ['LM', 'Leftmid'],
  ['RM', 'Rightmid'],
];

final List<List<dynamic>> seedRows = [
  for (var p = 0; p < _seedPositions.length; p++)
    for (var i = 0; i < 5; i++)
      [
        p * 10 + i + 1,
        '${_seedPositions[p][1]} ${p * 10 + i + 1}',
        _seedPositions[p][0],
        'Egypt',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
  // One legendary-priced striker so the store's tier shelving has a
  // legendary player to find in at least one position: €40M rates 86,
  // above the 82 legendary line. Every other position tops out in the
  // epic band, so their Legendary packs stay off the shelf.
  [999, 'Legend Striker', 'ST', 'Egypt', 40_000_000],
];

Future<CollectionStore> seededStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(datasetJson(seedRows)));
  await store.createClub(
    clubName: 'FC Rivals',
    managerName: 'Mohamed',
    crestIndex: 0,
  );
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('club creation (FR-001, GDD 5.8)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });

    tearDown(() async => db.close());

    test('creates the club with starting coins and the 22 starter-formation '
        'packs (GDD 5.8)', () async {
      final club = await store.getClub();
      expect(club, isNotNull);
      expect(club!.name, 'FC Rivals');
      expect(club.managerName, 'Mohamed');
      expect(club.coins, const EconomyEngine().config.startingCoins);
      // The chosen starter formation is the club's initial setup.
      expect(club.formationCode, '4-3-3');

      // The free packs: TWO per formation slot of the default 4-3-3 —
      // 11 slots × 2 = 22 packs, all rare, all unopened.
      final packs = await store.getAvailablePacks();
      expect(packs.length, 22);
      expect(packs.every((p) => p.category == 'position' && !p.opened), isTrue);
      expect(packs.every((p) => p.tier == 'rare'), isTrue);
      final counts = <String, int>{};
      for (final p in packs) {
        counts[p.scopeValue!] = (counts[p.scopeValue!] ?? 0) + 1;
      }
      // Slot census of the 4-3-3: GK 1, LB 1, CB 2, RB 1, CDM 1, CM 2,
      // LW 1, ST 1, RW 1 — doubled.
      expect(
        counts,
        equals({
          'GK': 2,
          'LB': 2,
          'CB': 4,
          'RB': 2,
          'CDM': 2,
          'CM': 4,
          'LW': 2,
          'ST': 2,
          'RW': 2,
        }),
      );
    });

    test('a different starter formation reshaapes the 22 packs to its '
        'slots', () async {
      final fresh = memoryDb();
      addTearDown(fresh.close);
      final freshStore = CollectionStore(db: fresh);
      await freshStore.applyDatasetUpdate(
        PlayerDataset.fromJson(datasetJson(seedRows)),
      );
      await freshStore.createClub(
        clubName: 'Wing Kings',
        managerName: 'Sara',
        crestIndex: 1,
        formationCode: '3-5-2',
      );
      final club = await freshStore.getClub();
      expect(club!.formationCode, '3-5-2');
      final packs = await freshStore.getAvailablePacks();
      expect(packs.length, 22);
      final counts = <String, int>{};
      for (final p in packs) {
        counts[p.scopeValue!] = (counts[p.scopeValue!] ?? 0) + 1;
      }
      // Slot census of the 3-5-2: GK 1, CB 3, LM 1, CM 2, CDM 1, RM 1,
      // ST 2 — doubled.
      expect(
        counts,
        equals({
          'GK': 2,
          'CB': 6,
          'LM': 2,
          'CM': 4,
          'CDM': 2,
          'RM': 2,
          'ST': 4,
        }),
      );
    });

    test('ledger records the starting grant (FR-016)', () async {
      final club = await store.getClub();
      final ledger = await (db.select(db.coinTransactions)..limit(10)).get();
      expect(ledger.length, 1);
      expect(ledger.first.reason, 'starting_grant');
      expect(ledger.first.amount, club!.coins);
      expect(ledger.first.balanceAfter, club.coins);
    });

    test('rejects a second club and empty names', () async {
      expect(
        () => store.createClub(
          clubName: 'Other',
          managerName: 'M',
          crestIndex: 1,
        ),
        throwsA(isA<CollectionException>()),
      );

      final fresh = memoryDb();
      final freshStore = CollectionStore(db: fresh);
      expect(
        () => freshStore.createClub(
          clubName: '  ',
          managerName: 'M',
          crestIndex: 0,
        ),
        throwsA(isA<CollectionException>()),
      );
      await fresh.close();
    });
  });

  group('pack opening (FR-010, FR-012, NFR-003)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });

    tearDown(() async => db.close());

    test('position pack yields one player of that position, once', () async {
      final packs = await store.getAvailablePacks();
      final gkPack = packs.firstWhere((p) => p.scopeValue == 'GK');
      final result = await store.openPack(
        packId: gkPack.id,
        random: math.Random(11),
      );
      expect(result.players.length, 1);
      expect(result.players.every((p) => p.position.code == 'GK'), isTrue);
      // The owned id of the drawn player rides along for sell-from-reveal.
      expect(result.ownedIds.length, 1);
      final collection = await store.getCollection();
      expect(collection.first.ownedId, result.ownedIds.first);

      // pack consumed
      final remaining = await store.getAvailablePacks();
      expect(remaining.length, 21);
      expect(remaining.any((p) => p.id == gkPack.id), isFalse);

      // players persisted as owned instances
      expect(collection.length, 1);

      // double-open rejected
      expect(
        () => store.openPack(packId: gkPack.id, random: math.Random(1)),
        throwsA(isA<CollectionException>()),
      );
    });

    test(
      'collection grows across packs and duplicates are separate copies',
      () async {
        final packs = await store.getAvailablePacks();
        // Open the whole free inventory: 22 packs, one player each.
        for (final pack in packs) {
          await store.openPack(packId: pack.id, random: math.Random(5));
        }
        final collection = await store.getCollection();
        expect(collection.length, 22); // 22 packs × 1 player
        // every draw matches its pack's position scope
        for (final pack in packs) {
          expect(
            collection.any((c) => c.position.code == pack.scopeValue),
            isTrue,
            reason: 'pack ${pack.scopeValue} contributed a player',
          );
        }
        // duplicates (same base player) are separate owned copies — the raw
        // material for merging (GDD 5.7): same base id, distinct owned ids.
        final byPlayer = <int, List<PlayerCard>>{};
        for (final c in collection) {
          byPlayer.putIfAbsent(c.base.playerId, () => []).add(c);
        }
        final allOwnedIds = collection.map((c) => c.ownedId).toSet();
        expect(
          allOwnedIds.length,
          22,
          reason: 'every drawn card is its own owned instance',
        );
        // when a base player was drawn twice, the copies stay separate
        final dupes = byPlayer.values
            .where((copies) => copies.length >= 2)
            .length;
        if (dupes > 0) {
          for (final copies in byPlayer.values) {
            final ids = copies.map((c) => c.ownedId).toSet();
            expect(ids.length, copies.length);
          }
        }
      },
    );
  });

  group('store offers (GDD 5.5 variety)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });

    tearDown(() async => db.close());

    test('position sections only, tiers shelved when the pool has the '
        'rarity — 24 offers', () async {
      final offers = await store.getStoreOffers();
      // The global pack is gone: every offer is position-scoped.
      expect(offers.any((o) => o.category == PackCategory.global), isFalse);
      expect(offers.every((o) => o.scopeValue != null), isTrue);
      // Every position holds rare and epic players, so 12 sections × 2
      // tiers; only ST (with its €40M legend) also shelves Legendary.
      expect(offers.length, 12 * 2 + 1);
      expect(
        offers.where((o) => o.scopeValue == 'ST').map((o) => o.tier).toSet(),
        PackTier.values.toSet(),
      );
      // A position without legendary players shelves no Legendary pack.
      expect(
        offers.where((o) => o.scopeValue == 'GK').map((o) => o.tier).toSet(),
        {PackTier.rare, PackTier.epic},
      );
      // Titles carry the tier, e.g. 'Legendary ST Position Pack'.
      expect(
        offers.map((o) => o.title).contains('Legendary ST Position Pack'),
        isTrue,
      );
      expect(
        offers.map((o) => o.title).contains('Epic ST Position Pack'),
        isTrue,
      );
    });

    test('gold costs most, bronze least, for the same scope', () async {
      final offers = await store.getStoreOffers();
      for (final scope in ['ST', 'GK']) {
        final scoped = offers.where((o) => o.scopeValue == scope);
        final byTier = {for (final o in scoped) o.tier: o.price};
        expect(byTier[PackTier.epic]!, greaterThan(byTier[PackTier.rare]!));
        if (byTier.containsKey(PackTier.legendary)) {
          expect(
            byTier[PackTier.legendary]!,
            greaterThan(byTier[PackTier.epic]!),
          );
        }
      }
    });

    test(
      'buyPack records the tier on the pack and charges its price',
      () async {
        final offers = await store.getStoreOffers();
        final legendSt = offers.firstWhere(
          (o) => o.tier == PackTier.legendary && o.scopeValue == 'ST',
        );
        // The absolute tier bands raised the legendary price above the
        // starting 25k (review economy_pack-tier-bands: 'legendary
        // prices will rise') — top the wallet up so the purchase itself
        // stays under test.
        final clubBefore = (await store.getClub())!;
        if (clubBefore.coins < legendSt.price) {
          await (db.update(db.clubs)
                ..where((c) => c.id.equals(clubBefore.id)))
              .write(ClubsCompanion(
                coins: Value(clubBefore.coins + 100_000),
              ));
        }
        final before = (await store.getClub())!.coins;
        final pack = await store.buyPack(
          category: PackCategory.position,
          position: Position.st,
          tier: PackTier.legendary,
        );
        expect(pack.tier, 'legendary');
        expect(pack.price, legendSt.price);
        expect(pack.scopeValue, 'ST');
        expect((await store.getClub())!.coins, before - legendSt.price);
        // it is unopened and openable with gold odds
        expect(pack.opened, isFalse);
        final result = await store.openPack(
          packId: pack.id,
          random: math.Random(3),
        );
        expect(result.players.length, 1);
      },
    );

    test(
      'getPackPlayers lists the scope sorted by overall, best first',
      () async {
        final players = await store.getPackPlayers(
          category: PackCategory.position,
          scopeValue: 'GK',
          tier: PackTier.legendary,
        );
        expect(players.length, 5); // the seed pool's GK count
        expect(players.every((p) => p.position.code == 'GK'), isTrue);
        final overalls = players.map((p) => p.baseStats.overall).toList();
        expect(overalls, isNot(equals(overalls.toList()..sort())));
        expect(
          overalls,
          equals(overalls.toList()..sort((a, b) => b.compareTo(a))),
        );
        // Global scope covers the whole pool — the 60 seeded positional
        // players plus the one legendary striker.
        final global = await store.getPackPlayers(
          category: PackCategory.global,
          tier: PackTier.rare,
        );
        expect(global.length, 61);
      },
    );
  });

  group('selling (FR-013, GDD 17.3)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });

    tearDown(() async => db.close());

    Future<int> openOne(String positionCode) async {
      final packs = await store.getAvailablePacks();
      final pack = packs.firstWhere((p) => p.scopeValue == positionCode);
      await store.openPack(packId: pack.id, random: math.Random(9));
      final collection = await store.getCollection();
      return collection.first.ownedId;
    }

    test(
      'sells for the upgraded selling formula and records the ledger',
      () async {
        final packs = await store.getAvailablePacks();
        await store.openPack(packId: packs.first.id, random: math.Random(9));
        final drawn = await store.getCollection();
        final ownedIds = drawn.map((c) => c.ownedId).toList();
        final before = (await store.getClub())!.coins;
        final expectedTotal = drawn
            .map(
              (c) => const EconomyEngine().sellPriceOfUpgraded(
                c.base,
                c.upgradeLevel,
              ),
            )
            .fold<int>(0, (a, b) => a + b);

        final result = await store.sellPlayers(ownedIds);
        expect(result.credit, expectedTotal);
        expect((await store.getClub())!.coins, before + expectedTotal);
        expect(await store.getCollection(), isEmpty);

        final ledger = await (db.select(
          db.coinTransactions,
        )..where((t) => t.reason.equals('player_sale'))).get();
        expect(ledger.single.amount, expectedTotal);
        expect(ledger.single.balanceAfter, before + expectedTotal);
      },
    );

    test('squad players cannot be sold', () async {
      final ownedId = await openOne('GK');
      await store.autoPickSquad();
      final inSquad = (await store.getSquad()).values.isNotEmpty;
      if (inSquad) {
        expect(
          () => store.sellPlayers([ownedId]),
          throwsA(isA<CollectionException>()),
        );
      }
    });
  });

  group('duplicate merging (FR-014, GDD 8.1/8.2)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });

    tearDown(() async => db.close());

    test('two base copies merge into +1 with one attribute point', () async {
      // open two GK packs with the same seed to force overlapping draws
      final packs = await store.getAvailablePacks();
      final gkPacks = packs.where((p) => p.scopeValue == 'GK').toList();
      await store.openPack(packId: gkPacks[0].id, random: math.Random(3));
      await store.openPack(packId: gkPacks[1].id, random: math.Random(3));

      final collection = await store.getCollection();
      final byPlayer = <int, List<int>>{};
      for (final c in collection) {
        byPlayer.putIfAbsent(c.base.playerId, () => []).add(c.ownedId);
      }
      final duplicatePair = byPlayer.entries.firstWhere(
        (e) => e.value.length >= 2,
        orElse: () => throw StateError('no duplicates drawn'),
      );
      final target = duplicatePair.value[0];
      final duplicate = duplicatePair.value[1];

      final result = await store.mergeDuplicates(
        targetOwnedId: target,
        duplicateOwnedId: duplicate,
      );
      expect(result.newUpgradeLevel, 1);

      final after = await store.getCollection();
      final mergedCard = after.firstWhere((c) => c.ownedId == target);
      expect(mergedCard.upgradeLevel, 1);
      // +1% of every base stat (owner decision 2026-11-09).
      expect(
        mergedCard.overall,
        mergedCard.base.baseStats.overall +
            (mergedCard.base.baseStats.overall * 1 / 100).round(),
      );
      for (final a in PlayerAttribute.values) {
        final baseValue = mergedCard.base.baseStats.valueOf(a);
        expect(mergedCard.attribute(a), baseValue + (baseValue / 100).round());
      }
      expect(mergedCard.overall, greaterThan(0));
      // duplicate consumed
      expect(after.any((c) => c.ownedId == duplicate), isFalse);
      expect(after.length, collection.length - 1);
    });

    test('different players cannot be merged', () async {
      // insert two owned copies of different base players directly
      final club = await store.getClub();
      final now = DateTime.now();
      final ids = await Future.wait([
        db
            .into(db.ownedPlayers)
            .insert(
              OwnedPlayersCompanion.insert(
                clubId: club!.id,
                playerId: 41,
                acquiredAt: now,
              ),
            ),
        db
            .into(db.ownedPlayers)
            .insert(
              OwnedPlayersCompanion.insert(
                clubId: club.id,
                playerId: 42,
                acquiredAt: now,
              ),
            ),
      ]);
      expect(
        () => store.mergeDuplicates(
          targetOwnedId: ids[0],
          duplicateOwnedId: ids[1],
        ),
        throwsA(isA<CollectionException>()),
      );
    });

    test('merging past the old level-5 cap works (owner 2026-11-09)', () async {
      // A +5 target (past the old cap) merges with a base copy → +6,
      // no 'Maximum upgrade level reached' error, duplicate consumed.
      final club = await store.getClub();
      final now = DateTime.now();
      final ids = await Future.wait([
        db
            .into(db.ownedPlayers)
            .insert(
              OwnedPlayersCompanion.insert(
                clubId: club!.id,
                playerId: 41,
                acquiredAt: now,
                upgradeLevel: const Value(5),
              ),
            ),
        db
            .into(db.ownedPlayers)
            .insert(
              OwnedPlayersCompanion.insert(
                clubId: club.id,
                playerId: 41,
                acquiredAt: now,
              ),
            ),
      ]);
      final result = await store.mergeDuplicates(
        targetOwnedId: ids[0],
        duplicateOwnedId: ids[1],
      );
      expect(result.newUpgradeLevel, 6);

      final after = await store.getCollection();
      final merged = after.firstWhere((c) => c.ownedId == ids[0]);
      expect(merged.upgradeLevel, 6);
      // Duplicate consumed.
      expect(after.any((c) => c.ownedId == ids[1]), isFalse);
      // The legacy point columns were zeroed by the merge.
      final row = await (db.select(
        db.ownedPlayers,
      )..where((o) => o.id.equals(ids[0]))).getSingle();
      expect(row.upgradedAttack, 0);
      expect(row.upgradedGoalkeeping, 0);
    });

    test('rebalance: old-style random points are ignored for stats', () async {
      // A pre-2026-11-09 save row: +3 level with randomly allocated
      // points (e.g. 5 ATT / 0 SUP / 1 DEF / 0 GK). The card's stats
      // must derive from the level alone — +1% per level of the base.
      final club = await store.getClub();
      final now = DateTime.now();
      final ownedId = await db
          .into(db.ownedPlayers)
          .insert(
            OwnedPlayersCompanion.insert(
              clubId: club!.id,
              playerId: 41,
              acquiredAt: now,
              upgradeLevel: const Value(3),
              upgradedAttack: const Value(5),
              upgradedDefence: const Value(1),
            ),
          );
      final cards = await store.getCollection();
      final card = cards.firstWhere((c) => c.ownedId == ownedId);
      final base = card.base.baseStats;
      expect(card.upgradeLevel, 3);
      expect(card.overall, base.overall + (base.overall * 3 / 100).round());
      for (final a in PlayerAttribute.values) {
        final baseValue = base.valueOf(a);
        expect(card.attribute(a), baseValue + (baseValue * 3 / 100).round());
      }
    });
  });

  group('squad persistence (FR-017, FR-019)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });

    tearDown(() async => db.close());

    Future<void> openAll() async {
      final packs = await store.getAvailablePacks();
      for (final pack in packs) {
        await store.openPack(packId: pack.id, random: math.Random(17));
      }
    }

    test('auto pick fills slots and persists them', () async {
      await openAll();
      final assignment = await store.autoPickSquad();
      expect(assignment.length, greaterThanOrEqualTo(11));

      final squad = await store.getSquad();
      expect(squad.length, assignment.length);
      expect(squad[0]!.position.code, 'GK'); // slot 0 is the GK slot
      for (final slot in assignment.keys) {
        expect(squad[slot]!.ownedId, assignment[slot]);
      }
    });

    test('changing formation re-runs auto pick (GDD 6.4)', () async {
      await openAll();
      await store.autoPickSquad();
      await store.changeFormation('3-5-2');
      final club = await store.getClub();
      expect(club!.formationCode, '3-5-2');
      final squad = await store.getSquad();
      expect(squad[0]!.position.code, 'GK');
      expect(squad.length, greaterThanOrEqualTo(11));
    });

    test('saveSquad rejects double-booking a player', () async {
      await openAll();
      final collection = await store.getCollection();
      expect(
        () => store.saveSquad({
          0: collection[0].ownedId,
          1: collection[0].ownedId,
        }),
        throwsA(isA<CollectionException>()),
      );
    });

    test('getSquad iterates slots in order; bench and reserves rank '
        'best-first (GDD 6.3)', () async {
      // Regression: getSquad() used to return rows in database insertion
      // order, so the Tactics tab — which walks squad.entries — displayed
      // bench and reserves unranked even though Auto Pick persisted the
      // ranked assignment. The map must iterate slot 0, 1, 2, …
      await openAll();
      // The 12 free packs leave the squad short of a full 23; top the
      // collection up straight from the seed pool so bench AND reserves
      // have ranked rows to verify.
      final club = await store.getClub();
      final now = DateTime.now();
      final drawnIds = (await store.getCollection())
          .map((c) => c.base.playerId)
          .toSet();
      for (final row in seedRows) {
        if (drawnIds.contains(row[0] as int)) continue;
        await db
            .into(db.ownedPlayers)
            .insert(
              OwnedPlayersCompanion.insert(
                clubId: club!.id,
                playerId: row[0] as int,
                acquiredAt: now,
              ),
            );
      }
      await store.autoPickSquad();
      final squad = await store.getSquad();

      final iterated = squad.keys.toList();
      final sorted = [...iterated]..sort();
      expect(iterated, sorted, reason: 'getSquad() must iterate in slot order');

      // Bench (11..17) then reserves (18..22) hold the leftovers
      // best-first by overall: each strip reads highest → lowest.
      final ranked = [
        for (
          var slot = Formation.startingXiSize;
          slot < Formation.squadSize && squad.containsKey(slot);
          slot++
        )
          squad[slot]!,
      ];
      expect(ranked.length, Formation.benchSize + Formation.reservesSize);
      for (var i = 1; i < ranked.length; i++) {
        expect(
          ranked[i - 1].overall,
          greaterThanOrEqualTo(ranked[i].overall),
          reason:
              'slot ${Formation.startingXiSize + i - 1} vs '
              '${Formation.startingXiSize + i}',
        );
      }
      // the bench holds the strongest leftovers, not the fittest
      final bench = ranked.take(Formation.benchSize);
      final reserves = ranked.skip(Formation.benchSize);
      if (reserves.isNotEmpty) {
        expect(
          bench.map((c) => c.overall).reduce(math.max),
          greaterThanOrEqualTo(reserves.map((c) => c.overall).reduce(math.min)),
        );
      }
    });
  });

  group('dataset update compensation (GDD 4.8, FR-007, FR-008)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });

    tearDown(() async => db.close());

    test(
      'removed player is compensated with the exact selling formula',
      () async {
        final packs = await store.getAvailablePacks();
        await store.openPack(packId: packs.first.id, random: math.Random(23));
        final collection = await store.getCollection();
        expect(collection, isNotEmpty);
        final clubBefore = (await store.getClub())!;

        // dataset v2 drops every drawn player id (duplicates included)
        final drawnIds = collection.map((c) => c.base.playerId).toSet();
        final v2 = datasetJson(
          seedRows.where((r) => !drawnIds.contains(r[0])).toList(),
          version: 2,
        );
        final report = await store.applyDatasetUpdate(
          PlayerDataset.fromJson(v2),
        );

        expect(report.importResult.removed.length, drawnIds.length);
        expect(report.compensations.length, collection.length);

        // each copy compensated with the exact upgraded selling formula
        var expectedTotal = 0;
        for (final card in collection) {
          final expected = const EconomyEngine().sellPriceOfUpgraded(
            card.base,
            card.upgradeLevel,
          );
          final comp = report.compensations.firstWhere(
            (c) => c.playerName == card.base.name,
          );
          expect(comp.coins, expected);
          expectedTotal += expected;
        }
        expect(report.totalCompensation, expectedTotal);

        // coins credited exactly once, ledger row written
        expect(
          (await store.getClub())!.coins,
          clubBefore.coins + expectedTotal,
        );
        final ledger = await (db.select(
          db.coinTransactions,
        )..where((t) => t.reason.equals('removal_compensation'))).get();
        expect(ledger.single.amount, expectedTotal);

        // owned copies gone
        final after = await store.getCollection();
        expect(after.isEmpty, isTrue);
      },
    );

    test(
      'unchanged players keep their stats; upgrades survive (FR-006/007)',
      () async {
        final packs = await store.getAvailablePacks();
        await store.openPack(packId: packs.first.id, random: math.Random(23));
        final before = await store.getCollection();

        // v2: identical rows, new version
        final report = await store.applyDatasetUpdate(
          PlayerDataset.fromJson(datasetJson(seedRows, version: 2)),
        );
        expect(report.importResult.removed, isEmpty);
        expect(report.importResult.regenerated, isEmpty);

        final after = await store.getCollection();
        expect(after.length, before.length);
        for (final card in after) {
          final old = before.firstWhere((c) => c.ownedId == card.ownedId);
          expect(card.base.baseStats, old.base.baseStats);
        }
      },
    );

    test('market value change regenerates stats but keeps identity', () async {
      final packs = await store.getAvailablePacks();
      await store.openPack(packId: packs.first.id, random: math.Random(23));
      final before = await store.getCollection();

      final bumped = seedRows
          .map(
            (r) => r[0] == before.first.base.playerId
                ? [r[0], r[1], r[2], r[3], (r[4] as int) * 4]
                : r,
          )
          .toList();
      final report = await store.applyDatasetUpdate(
        PlayerDataset.fromJson(datasetJson(bumped, version: 2)),
      );

      expect(report.importResult.regenerated.length, 1);
      final after = await store.getCollection();
      final changed = after.firstWhere(
        (c) => c.base.playerId == before.first.base.playerId,
      );
      expect(changed.base.marketValueEur, before.first.base.marketValueEur * 4);
    });
  });

  group('importBundledDataset (idempotent per version)', () {
    test('re-importing the same version is a no-op', () async {
      final db = memoryDb();
      final store = CollectionStore(db: db);
      await store.importBundledDataset(PlayerDataset.fromJson(datasetJson(seedRows)));
      expect((await (db.select(db.players)).get()).length, seedRows.length);

      await store.importBundledDataset(PlayerDataset.fromJson(datasetJson(seedRows)));
      expect((await (db.select(db.players)).get()).length, seedRows.length);
      await db.close();
    });
  });
}
