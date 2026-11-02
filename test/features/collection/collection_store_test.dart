import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/formations.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

String datasetJson(List<List<dynamic>> rows, {int version = 1}) =>
    json.encode({
      'format': 'fcm-rivals-players',
      'version': version,
      'asOf': '2026-11-01',
      'leagues': const {'EG1': 'Egyptian Premier League'},
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
        20 + i,
        'Egypt',
        i % 2 == 0 ? 'Al Ahly' : 'Zamalek',
        'EG1',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

Future<CollectionStore> seededStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(datasetJson(seedRows)));
  await store.createClub(
      clubName: 'FC Rivals', managerName: 'Mohamed', crestIndex: 0);
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

    test('creates the club with starting coins and 36 packs', () async {
      final club = await store.getClub();
      expect(club, isNotNull);
      expect(club!.name, 'FC Rivals');
      expect(club.managerName, 'Mohamed');
      expect(club.coins, const EconomyEngine().config.startingCoins);

      final packs = await store.getAvailablePacks();
      expect(packs.length, 36); // 3 per position × 12 positions
      expect(
          packs.every((p) => p.category == 'position' && !p.opened), isTrue);
      expect(packs.map((p) => p.scopeValue).toSet().length, 12);
    });

    test('ledger records the starting grant (FR-016)', () async {
      final club = await store.getClub();
      final ledger =
          await (db.select(db.coinTransactions)..limit(10)).get();
      expect(ledger.length, 1);
      expect(ledger.first.reason, 'starting_grant');
      expect(ledger.first.amount, club!.coins);
      expect(ledger.first.balanceAfter, club.coins);
    });

    test('rejects a second club and empty names', () async {
      expect(
          () => store.createClub(
              clubName: 'Other', managerName: 'M', crestIndex: 1),
          throwsA(isA<CollectionException>()));

      final fresh = memoryDb();
      final freshStore = CollectionStore(db: fresh);
      expect(
          () => freshStore.createClub(
              clubName: '  ', managerName: 'M', crestIndex: 0),
          throwsA(isA<CollectionException>()));
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
      final stPack = packs.firstWhere((p) => p.scopeValue == 'ST');
      final result = await store.openPack(
          packId: stPack.id, random: math.Random(11));
      expect(result.players.length, 1);
      expect(result.players.every((p) => p.position.code == 'ST'), isTrue);

      // pack consumed
      final remaining = await store.getAvailablePacks();
      expect(remaining.length, 35);
      expect(remaining.any((p) => p.id == stPack.id), isFalse);

      // players persisted as owned instances
      final collection = await store.getCollection();
      expect(collection.length, 1);

      // double-open rejected
      expect(
          () => store.openPack(packId: stPack.id, random: math.Random(1)),
          throwsA(isA<CollectionException>()));
    });

    test('collection grows across packs and duplicates are separate copies',
        () async {
      final packs = await store.getAvailablePacks();
      // first packs in insertion order: 3×ST then LW
      for (final pack in packs.take(4)) {
        await store.openPack(packId: pack.id, random: math.Random(5));
      }
      final collection = await store.getCollection();
      expect(collection.length, 4); // 4 packs × 1 player
      // every draw matches its pack's position scope
      expect(collection.every((c) => c.position.code == 'ST' || c.position.code == 'LW'),
          isTrue);
      // duplicates (same base player) are separate owned copies — the raw
      // material for merging (GDD 5.7)
      final byPlayer = <int, int>{};
      for (final c in collection) {
        byPlayer[c.base.playerId] = (byPlayer[c.base.playerId] ?? 0) + 1;
      }
      expect(byPlayer.values.any((v) => v >= 2) || collection.length == 12,
          isTrue);
    });
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

    test('sells for the upgraded selling formula and records the ledger',
        () async {
      final packs = await store.getAvailablePacks();
      await store.openPack(packId: packs.first.id, random: math.Random(9));
      final drawn = await store.getCollection();
      final ownedIds = drawn.map((c) => c.ownedId).toList();
      final before = (await store.getClub())!.coins;
      final expectedTotal = drawn
          .map((c) => const EconomyEngine()
              .sellPriceOfUpgraded(c.base, c.upgradeLevel))
          .fold<int>(0, (a, b) => a + b);

      final result = await store.sellPlayers(ownedIds);
      expect(result.credit, expectedTotal);
      expect((await store.getClub())!.coins, before + expectedTotal);
      expect(await store.getCollection(), isEmpty);

      final ledger = await (db.select(db.coinTransactions)
            ..where((t) => t.reason.equals('player_sale')))
          .get();
      expect(ledger.single.amount, expectedTotal);
      expect(ledger.single.balanceAfter, before + expectedTotal);
    });

    test('squad players cannot be sold', () async {
      final ownedId = await openOne('ST');
      await store.autoPickSquad();
      final inSquad = (await store.getSquad()).values.isNotEmpty;
      if (inSquad) {
        expect(() => store.sellPlayers([ownedId]),
            throwsA(isA<CollectionException>()));
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
      final duplicatePair = byPlayer.entries
          .firstWhere((e) => e.value.length >= 2, orElse: () => throw StateError('no duplicates drawn'));
      final target = duplicatePair.value[0];
      final duplicate = duplicatePair.value[1];

      final result = await store.mergeDuplicates(
          targetOwnedId: target, duplicateOwnedId: duplicate, random: math.Random(1));
      expect(result.newUpgradeLevel, 1);
      expect(result.attributeGain.values.fold(0, (a, b) => a + b), 1);

      final after = await store.getCollection();
      final mergedCard = after.firstWhere((c) => c.ownedId == target);
      expect(mergedCard.upgradeLevel, 1);
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
        db.into(db.ownedPlayers).insert(OwnedPlayersCompanion.insert(
            clubId: club!.id, playerId: 41, acquiredAt: now)),
        db.into(db.ownedPlayers).insert(OwnedPlayersCompanion.insert(
            clubId: club.id, playerId: 42, acquiredAt: now)),
      ]);
      expect(
          () => store.mergeDuplicates(
              targetOwnedId: ids[0],
              duplicateOwnedId: ids[1],
              random: math.Random(1)),
          throwsA(isA<CollectionException>()));
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
          () => store.saveSquad({0: collection[0].ownedId, 1: collection[0].ownedId}),
          throwsA(isA<CollectionException>()));
    });

    test('getSquad iterates slots in order; bench and reserves rank '
        'best-first (GDD 6.3)', () async {
      // Regression: getSquad() used to return rows in database insertion
      // order, so the Tactics tab — which walks squad.entries — displayed
      // bench and reserves unranked even though Auto Pick persisted the
      // ranked assignment. The map must iterate slot 0, 1, 2, …
      await openAll();
      await store.autoPickSquad();
      final squad = await store.getSquad();

      final iterated = squad.keys.toList();
      final sorted = [...iterated]..sort();
      expect(iterated, sorted,
          reason: 'getSquad() must iterate in slot order');

      // Bench (11..17) then reserves (18..22) hold the leftovers
      // best-first by overall: each strip reads highest → lowest.
      final ranked = [
        for (var slot = Formation.startingXiSize;
            slot < Formation.squadSize && squad.containsKey(slot);
            slot++)
          squad[slot]!,
      ];
      expect(ranked.length, Formation.benchSize + Formation.reservesSize);
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i - 1].overall, greaterThanOrEqualTo(ranked[i].overall),
            reason: 'slot ${Formation.startingXiSize + i - 1} vs '
                '${Formation.startingXiSize + i}');
      }
      // the bench holds the strongest leftovers, not the fittest
      final bench = ranked.take(Formation.benchSize);
      final reserves = ranked.skip(Formation.benchSize);
      if (reserves.isNotEmpty) {
        expect(bench.map((c) => c.overall).reduce(math.max),
            greaterThanOrEqualTo(reserves.map((c) => c.overall).reduce(math.min)));
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

    test('removed player is compensated with the exact selling formula',
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
          version: 2);
      final report =
          await store.applyDatasetUpdate(PlayerDataset.fromJson(v2));

      expect(report.importResult.removed.length, drawnIds.length);
      expect(report.compensations.length, collection.length);

      // each copy compensated with the exact upgraded selling formula
      var expectedTotal = 0;
      for (final card in collection) {
        final expected = const EconomyEngine()
            .sellPriceOfUpgraded(card.base, card.upgradeLevel);
        final comp = report.compensations
            .firstWhere((c) => c.playerName == card.base.name);
        expect(comp.coins, expected);
        expectedTotal += expected;
      }
      expect(report.totalCompensation, expectedTotal);

      // coins credited exactly once, ledger row written
      expect((await store.getClub())!.coins, clubBefore.coins + expectedTotal);
      final ledger = await (db.select(db.coinTransactions)
            ..where((t) => t.reason.equals('removal_compensation')))
          .get();
      expect(ledger.single.amount, expectedTotal);

      // owned copies gone
      final after = await store.getCollection();
      expect(after.isEmpty, isTrue);
    });

    test('unchanged players keep their stats; upgrades survive (FR-006/007)',
        () async {
      final packs = await store.getAvailablePacks();
      await store.openPack(packId: packs.first.id, random: math.Random(23));
      final before = await store.getCollection();

      // v2: identical rows, new version
      final report = await store.applyDatasetUpdate(
          PlayerDataset.fromJson(datasetJson(seedRows, version: 2)));
      expect(report.importResult.removed, isEmpty);
      expect(report.importResult.regenerated, isEmpty);

      final after = await store.getCollection();
      expect(after.length, before.length);
      for (final card in after) {
        final old = before.firstWhere((c) => c.ownedId == card.ownedId);
        expect(card.base.baseStats, old.base.baseStats);
      }
    });

    test('market value change regenerates stats but keeps identity', () async {
      final packs = await store.getAvailablePacks();
      await store.openPack(packId: packs.first.id, random: math.Random(23));
      final before = await store.getCollection();

      final bumped = seedRows
          .map((r) => r[0] == before.first.base.playerId
              ? [r[0], r[1], r[2], r[3], r[4], r[5], r[6], (r[7] as int) * 4]
              : r)
          .toList();
      final report = await store.applyDatasetUpdate(
          PlayerDataset.fromJson(datasetJson(bumped, version: 2)));

      expect(report.importResult.regenerated.length, 1);
      final after = await store.getCollection();
      final changed =
          after.firstWhere((c) => c.base.playerId == before.first.base.playerId);
      expect(changed.base.marketValueEur,
          before.first.base.marketValueEur * 4);
    });
  });

  group('importBundledDataset (idempotent per version)', () {
    test('re-importing the same version is a no-op', () async {
      final db = memoryDb();
      final store = CollectionStore(db: db);
      await store.importBundledDataset(datasetJson(seedRows));
      expect(
          (await (db.select(db.players)).get()).length, seedRows.length);

      await store.importBundledDataset(datasetJson(seedRows));
      expect((await (db.select(db.players)).get()).length, seedRows.length);
      await db.close();
    });
  });
}
