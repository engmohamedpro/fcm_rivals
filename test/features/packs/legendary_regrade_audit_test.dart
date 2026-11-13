/// T-0047 regrade audit, reworked by T-0059: the owner's 2026-11-08
/// decision REVERSED the "Legendary pack guarantees gold" rule — the
/// pack now rolls the configured matrix 0/55/43/2 (55% EPIC / 43%
/// LEGENDARY / 2% PREMIUM). What still holds from T-0047 and is kept:
/// the population-level gold share stays in the real elite band, every
/// store shelf that carried a legendary pool before the regrade still
/// carries one, and NO sub-70 (bronze) pull is structurally possible
/// from a Legendary pack. Premium (90+) is exclusive to Legendary packs.
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/features/collection/pack_catalog.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import '../../tm_bundle_io.dart'
    show loadTmDataset;


List<BasePlayer> _loadPool() {
  final db = PlayerDatabase();
  db.importDataset(loadTmDataset());
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
      registry.importDataset(loadTmDataset());
      final offers = storeOffersFor(registry, const EconomyEngine());
      final legendaryShelf = <String, int>{
        for (final o in offers)
          if (o.tier == PackTier.legendary && o.scopeValue != null)
            o.scopeValue!: o.eligibleCount,
      };
      var positionsWithGold = 0;
      for (final position in Position.values) {
        // Owner request 2026-11-13: shelf groups — the position shelves
        // under its merged group's code ('LW' → 'LW+LM'), so the audit
        // reads the group's shelf entry.
        final shelfKey = normalizePositionScopeValue(position.code);
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
          expect(legendaryShelf[shelfKey], isNotNull,
              reason: '${position.code} carried a legendary shelf before '
                  'the regrade — it must not silently empty');
          expect(legendaryShelf[shelfKey]!, greaterThan(0));
        }
        // ignore: avoid_print
        print('${position.code}: legendary pool 82+ = $oldCount, '
            '80+ = $newCount, shelved = ${legendaryShelf[shelfKey]}');
      }
      expect(positionsWithGold, greaterThan(0),
          reason: 'the audit is only meaningful if some position had a '
              'legendary pool before the regrade');
    });

    test('seeded pack audit: Legendary packs roll the owner matrix '
        '0/55/43/2 — no bronze, 45% gold band, premium exclusive; shares '
        'printed for the report', () {
      const n = 2000;
      final gold = <PackTier, int>{};
      final premium = <PackTier, int>{};
      var legendarySub70 = 0;
      final legendaryShares = [0, 0, 0, 0];
      for (final tier in PackTier.values) {
        final engine = PackEngine(random: math.Random(4700 + tier.index));
        final scope = PackScope(category: PackCategory.global, tier: tier);
        var tierGold = 0;
        for (var i = 0; i < n; i++) {
          final draw = engine.open(scope, pool).single;
          final overall = draw.player.baseStats.overall;
          final band = PackRarity.fromOverall(overall);
          if (tier == PackTier.legendary) legendaryShares[draw.tier]++;
          if (band == PackRarity.legendary || band == PackRarity.premium) {
            tierGold++;
          }
          if (tier == PackTier.legendary && overall < 70) legendarySub70++;
          if (band == PackRarity.premium) {
            premium[tier] = (premium[tier] ?? 0) + 1;
          }
        }
        gold[tier] = tierGold;
        // ignore: avoid_print
        print('${tier.label}: gold-band share '
            '${(tierGold / n * 100).toStringAsFixed(2)}% '
            '(OVR 80+ incl. premium), premium-band pulls '
            '${premium[tier] ?? 0} over $n seeded openings');
      }
      // THE owner matrix (2026-11-08): legendary pack 0/55/43/2 within
      // ±3 percentage points — the T-0047 gold guarantee is superseded.
      final s = legendaryShares.map((c) => c / n).toList();
      expect(s[0], 0, reason: 'no rare-band (sub-70) roll exists');
      expect(s[1], inInclusiveRange(0.52, 0.58), reason: '55% EPIC');
      expect(s[2], inInclusiveRange(0.40, 0.46), reason: '43% LEGENDARY');
      expect(s[3], greaterThan(0.005), reason: '2% PREMIUM, live stream');
      expect(s[3], lessThan(0.05));
      // What survived the reversal: a Legendary pack STILL cannot make a
      // bronze card — its floor is now the epic band.
      expect(legendarySub70, 0);
      // Premium exclusivity: only the legendary pack's 2% roll reaches
      // the 90+ band; rare and epic packs never do.
      expect(premium[PackTier.legendary] ?? 0, greaterThan(0));
      expect(premium[PackTier.rare] ?? 0, 0);
      expect(premium[PackTier.epic] ?? 0, 0);
      // The other tiers keep their shape under the new tables:
      // Rare's gold band is only the 5% legendary roll; Epic's is 10%.
      expect(gold[PackTier.rare]! / n, inInclusiveRange(0.02, 0.08));
      expect(gold[PackTier.epic]! / n, inInclusiveRange(0.07, 0.13));
    });
  });
}
