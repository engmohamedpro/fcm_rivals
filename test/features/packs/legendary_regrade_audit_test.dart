/// T-0047 regrade audit: gold from OVR 80, Legendary packs guarantee gold.
///
/// Locks the owner's regrade rule end to end on the real 20,876-player
/// dataset: the population-level gold share stays in the real elite band
/// ("few elite, large middle", GDD 4.5), every store shelf that carried a
/// legendary pool before the regrade still carries one (pools only grow),
/// and seeded openings prove a Legendary pack can never produce a
/// non-gold card.
library;

import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/features/collection/pack_catalog.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

const _datasetPath = 'assets/data/players_v1.json';

List<BasePlayer> _loadPool() {
  final db = PlayerDatabase();
  db.importDatasetFromJson(io.File(_datasetPath).readAsStringSync());
  return db.all.toList(growable: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<BasePlayer> pool;

  setUpAll(() => pool = _loadPool());

  group('T-0047 regrade audit (the owner rule: 80+ renders gold)', () {
    test('population gold share lands in the real elite band', () {
      final gold = pool
          .where(
            (p) =>
                CardRarity.fromOverall(p.baseStats.overall) ==
                CardRarity.legendary,
          )
          .length;
      // ignore: avoid_print
      print('gold population: $gold / ${pool.length} '
          '(${(gold / pool.length * 100).toStringAsFixed(2)}%)');
      // The 80+ band is the game's elite shape: 493 players / 2.36%
      // measured on the shipped dataset. Pack pulls deliberately
      // OVERSAMPLE this band inside Legendary packs (a star is a star);
      // this band locks the population the pull economy draws from.
      expect(gold / pool.length, inInclusiveRange(0.015, 0.035));
    });

    test('store shelves: every previously-golden position pool stays '
        'shelved and can only grow', () {
      final registry = PlayerDatabase();
      registry.importDatasetFromJson(
        io.File(_datasetPath).readAsStringSync(),
      );
      final offers = storeOffersFor(registry, const EconomyEngine());
      final legendaryShelf = <String, int>{
        for (final o in offers)
          if (o.tier == PackTier.legendary && o.scopeValue != null)
            o.scopeValue!: o.eligibleCount,
      };
      var positionsWithGold = 0;
      for (final position in Position.values) {
        final oldCount = pool
            .where(
              (p) =>
                  p.position == position && p.baseStats.overall >= 82,
            )
            .length; // the pre-regrade legendary threshold
        final newCount = pool
            .where(
              (p) =>
                  p.position == position && p.baseStats.overall >= 80,
            )
            .length;
        expect(newCount, greaterThanOrEqualTo(oldCount),
            reason: '${position.code}: the regrade can only grow pools');
        if (oldCount > 0) {
          positionsWithGold++;
          expect(legendaryShelf[position.code], isNotNull,
              reason: '${position.code} carried a legendary shelf before '
                  'the regrade — it must not silently empty');
          expect(legendaryShelf[position.code]!, greaterThan(0));
        }
        // ignore: avoid_print
        print('${position.code}: legendary pool 82+ = $oldCount, '
            '80+ = $newCount, shelved = ${legendaryShelf[position.code]}');
      }
      expect(positionsWithGold, greaterThan(0),
          reason: 'the audit is only meaningful if some position had a '
              'legendary pool before the regrade');
    });

    test('seeded pack audit: Legendary packs are 100% gold, shares '
        'printed for the report', () {
      const n = 2000;
      final gold = <PackTier, int>{};
      var legendarySub80 = 0;
      for (final tier in PackTier.values) {
        final engine = PackEngine(random: math.Random(4700 + tier.index));
        final scope = PackScope(category: PackCategory.global, tier: tier);
        var tierGold = 0;
        for (var i = 0; i < n; i++) {
          final draw = engine.open(scope, pool).single;
          final isGold =
              CardRarity.fromOverall(draw.player.baseStats.overall) ==
                  CardRarity.legendary;
          if (isGold) tierGold++;
          if (tier == PackTier.legendary &&
              draw.player.baseStats.overall < 80) {
            legendarySub80++;
          }
        }
        gold[tier] = tierGold;
        // ignore: avoid_print
        print('${tier.label}: gold share '
            '${(tierGold / n * 100).toStringAsFixed(2)}% '
            'over $n seeded openings');
      }
      // THE owner rule: a Legendary pack can only ever produce gold.
      expect(legendarySub80, 0);
      expect(gold[PackTier.legendary], n);
      // The other tiers keep their shape: Rare structurally cannot roll
      // the gold band, Epic carries a meaningful but minority share.
      expect(gold[PackTier.rare]! / n, lessThan(0.05));
      expect(gold[PackTier.epic]! / n, inInclusiveRange(0.05, 0.20));
    });
  });
}
