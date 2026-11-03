import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/ads/ad_engine.dart';
import 'package:fcm_rivals/features/ads/ad_store.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart' show PackCategory;
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_store.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

String datasetJson(List<List<dynamic>> rows, {int version = 1}) => json.encode({
  'format': 'fcm-rivals-players',
  'version': version,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': rows,
});

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
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Ad economy surfaces (GDD 19.3 Other Proposed)', () {
    late AppDatabase db;
    late AdStore ads;
    late CollectionStore collection;
    late int clubId;

    setUp(() async {
      db = memoryDb();
      ads = AdStore(db: db);
      collection = CollectionStore(db: db, adStore: ads);
      await collection.applyDatasetUpdate(
        PlayerDataset.fromJson(datasetJson(seedRows)),
      );
      await collection.createClub(
        clubName: 'FC Rivals',
        managerName: 'Mohamed',
        crestIndex: 0,
      );
      clubId = (await collection.getClub())!.id;
    });

    tearDown(() async => db.close());

    test('engine math: discount, selling bonus, reward multipliers', () {
      const engine = AdEngine();
      // Discount: 20% off, never below 50.
      expect(engine.discountedUpgradeCost(1000), 800);
      expect(engine.discountedUpgradeCost(60), 50);
      expect(engine.discountedUpgradeCost(40), 40); // below floor stays full
      // Selling bonus: +20%.
      expect(engine.sellingBonus(500), 600);
      expect(engine.sellingBonus(0), 0);
      // Multipliers.
      expect(engine.boostedMatchReward(1000), 1500);
      expect(engine.boostedSeasonReward(1000), 1250);
    });

    test(
      'free pack: one per day, delivered unopened, duplicate rejected',
      () async {
        final now = DateTime(2026, 11, 2, 12);
        final result = await ads.grantFreePack(
          clubId: clubId,
          category: PackCategory.global,
          playbackCompleted: true,
          now: now,
        );
        expect(result.kind, AdRewardKind.freePack);

        final packs = await (db.select(
          db.packs,
        )..where((p) => p.clubId.equals(clubId))).get();
        final free = packs.where((p) => p.source == 'ad_free').toList();
        expect(free, hasLength(1));
        expect(free.first.opened, isFalse);
        expect(free.first.price, 0);

        // Same day: rejected even for a different scope.
        expect(
          () => ads.grantFreePack(
            clubId: clubId,
            category: PackCategory.position,
            scopeValue: 'ST',
            playbackCompleted: true,
            now: now.add(const Duration(hours: 2)),
          ),
          throwsA(isA<AdException>()),
        );

        // Uncompleted playback grants nothing.
        expect(
          () => ads.grantFreePack(
            clubId: clubId,
            category: PackCategory.global,
            playbackCompleted: false,
            now: DateTime(2026, 11, 3, 12),
          ),
          throwsA(isA<AdException>()),
        );
      },
    );

    test(
      'upgrade discount: buyUpgrade charges less and consumes the boost',
      () async {
        // Open packs so the club owns sellable/upgradeable cards.
        for (final pack in await collection.getAvailablePacks()) {
          await collection.openPack(packId: pack.id, random: math.Random(17));
        }
        final club = (await collection.getClub())!;
        final cards = await collection.getCollection();
        final card = cards.first;
        final fullCost = const EconomyEngine().upgradeCostOf(
          card.base,
          card.upgradeLevel,
        );

        // No boost: full price.
        final full = await collection.buyUpgrade(
          ownedId: card.ownedId,
          random: math.Random(1),
        );
        expect(full.discountApplied, isFalse);
        expect(full.coins, fullCost);
        expect(full.upgradeLevel, 1);

        // Grant the discount, buy again: cheaper, boost consumed.
        await ads.grantBoost(
          clubId: clubId,
          kind: AdRewardKind.upgradeDiscount,
          playbackCompleted: true,
        );
        expect(await ads.upgradeDiscountActive(clubId), isTrue);
        final discounted = await collection.buyUpgrade(
          ownedId: card.ownedId,
          random: math.Random(2),
        );
        expect(discounted.discountApplied, isTrue);
        expect(discounted.coins, lessThan(discounted.fullCost));
        // Consumed: a third purchase is full price again.
        expect(await ads.upgradeDiscountActive(clubId), isFalse);

        // Coins moved exactly by the charged prices.
        final after = (await collection.getClub())!;
        expect(after.coins, club.coins - full.coins - discounted.coins);
      },
    );

    test('selling bonus: boosts one sale then consumes', () async {
      for (final pack in await collection.getAvailablePacks()) {
        await collection.openPack(packId: pack.id, random: math.Random(17));
      }
      // Pick a player who is NOT in the squad (store refuses to sell those).
      final squad = await collection.getSquad();
      final inSquadIds = squad.values.map((c) => c.ownedId).toSet();
      final cards = await collection.getCollection();
      final sellable = cards
          .where((c) => !inSquadIds.contains(c.ownedId))
          .toList();
      expect(sellable, isNotEmpty);
      final card = sellable.first;

      final clubBefore = (await collection.getClub())!;
      final normalPrice = const EconomyEngine().sellPriceOfUpgraded(
        card.base,
        card.upgradeLevel,
      );

      await ads.grantBoost(
        clubId: clubId,
        kind: AdRewardKind.sellingBonus,
        playbackCompleted: true,
      );
      expect(await ads.sellingBonusActive(clubId), isTrue);
      final sale = await collection.sellPlayers([card.ownedId]);
      expect(sale.credit, (normalPrice * 1.2).round()); // +20% (GDD 19.3)
      expect(await ads.sellingBonusActive(clubId), isFalse);

      // A second sale is back to the normal price.
      final second = sellable.length > 1 ? sellable[1] : null;
      if (second != null) {
        final normal2 = await collection.sellPlayers([second.ownedId]);
        final base2 = const EconomyEngine().sellPriceOfUpgraded(
          second.base,
          second.upgradeLevel,
        );
        expect(normal2.credit, base2);
      }
      final clubAfter = (await collection.getClub())!;
      expect(clubAfter.coins, greaterThan(clubBefore.coins));
    });

    test(
      'daily reward multiplier: match rewards boosted for the day',
      () async {
        final now = DateTime(2026, 11, 2, 15);
        await ads.grantBoost(
          clubId: clubId,
          kind: AdRewardKind.dailyRewardMultiplier,
          playbackCompleted: true,
          now: now,
        );
        expect(await ads.dailyMultiplierActive(clubId, now: now), isTrue);

        // A match reward paid through applyMatchResult is boosted 1.5x.
        final clubBefore = (await collection.getClub())!;
        await collection.applyMatchResult(
          clubId: clubId,
          rewardCoins: 1000,
          players: const [],
          now: now,
        );
        final clubAfter = (await collection.getClub())!;
        expect(clubAfter.coins - clubBefore.coins, 1500);

        // Next day (no new ad): back to normal.
        final nextDay = DateTime(2026, 11, 3, 15);
        expect(await ads.dailyMultiplierActive(clubId, now: nextDay), isFalse);
        await collection.applyMatchResult(
          clubId: clubId,
          rewardCoins: 1000,
          players: const [],
          now: nextDay,
        );
        final clubNext = (await collection.getClub())!;
        expect(clubNext.coins - clubAfter.coins, 1000);
      },
    );

    test(
      'season reward multiplier: boosts one completion then consumes',
      () async {
        for (final pack in await collection.getAvailablePacks()) {
          await collection.openPack(packId: pack.id, random: math.Random(17));
        }
        await collection.autoPickSquad();
        final seasonStore = SeasonStore(db: db, random: math.Random(5));
        await seasonStore.startSeason(division: 1);

        // Watch the season-multiplier ad mid-season.
        await ads.grantBoost(
          clubId: clubId,
          kind: AdRewardKind.seasonRewardMultiplier,
          playbackCompleted: true,
        );
        expect(await ads.seasonMultiplierActive(clubId), isTrue);

        await seasonStore.simulateRemainingFixtures(collection);
        final completion = await seasonStore.completeSeason(collection);
        // The completion paid base * 1.25 (GDD 19.3 season multiplier).
        final base = seasonStore.engine.seasonRewardCoins(
          division: completion.division,
          position: completion.finalPosition,
        );
        expect(completion.rewardCoins, (base * 1.25).round());
        // And the boost is spent — a hypothetical second completion of the
        // same data would not double-boost.
        expect(await ads.seasonMultiplierActive(clubId), isFalse);
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );

    test('boost ads: one grant per day per kind, fresh next day', () async {
      final day = DateTime(2026, 11, 2, 10);
      // The grant key is day-scoped: a second boost ad of the same kind
      // the same day is a duplicate (GDD 19.4 duplicate prevention).
      await ads.grantBoost(
        clubId: clubId,
        kind: AdRewardKind.upgradeDiscount,
        playbackCompleted: true,
        now: day,
      );
      expect(
        () => ads.grantBoost(
          clubId: clubId,
          kind: AdRewardKind.upgradeDiscount,
          playbackCompleted: true,
          now: day.add(const Duration(hours: 4)),
        ),
        throwsA(isA<AdException>()),
      );

      // Different kinds still fine the same day (per-kind scoping).
      await ads.grantBoost(
        clubId: clubId,
        kind: AdRewardKind.sellingBonus,
        playbackCompleted: true,
        now: day.add(const Duration(hours: 5)),
      );

      // Next day the same kind grants again.
      final nextDay = DateTime(2026, 11, 3, 9);
      await ads.grantBoost(
        clubId: clubId,
        kind: AdRewardKind.upgradeDiscount,
        playbackCompleted: true,
        now: nextDay,
      );
      final rows = await db.select(db.adUsages).get();
      final upgradeGrants = rows
          .where(
            (r) =>
                r.rewardKind == 'upgradeDiscount' &&
                r.rewardKey.startsWith('upgradeDiscount:grant:'),
          )
          .toList();
      expect(upgradeGrants, hasLength(2));
    });
  });
}
