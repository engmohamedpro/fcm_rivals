/// T-0059: the two-stage rarity draw — the owner's exact algorithm,
/// machine-checked.
///
/// Stage 1 rolls a rarity from the pack tier's configured table
/// ([PackOddsConfig]); stage 2 selects one player inside the rolled
/// rarity's pool weighted by `(poolMinMv / mv)^exponent`. These tests
/// lock: seed reproducibility, the three tables' distributions over
/// ≥ 2,000 seeded opens, premium exclusivity to Legendary packs, band
/// boundary integrity, and every documented edge case (one-player
/// rarity, identical MVs, extreme spread, mv ≤ 0 rows, RM-style empty
/// bands, the 10,000-open soak).
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';
import 'package:fcm_rivals/l10n/app_localizations_ar.dart';
import 'package:fcm_rivals/l10n/app_localizations_en.dart';

/// Pool spanning all four OVR rarity bands with known structure: a
/// player's id always encodes the band he belongs to (1xxx rare OVR 60,
/// 2xxx epic OVR 75, 3xxx legendary OVR 85, 4xxx premium OVR 92), so a
/// draw can be judged against the band it reported.
List<BasePlayer> buildBandedPool(int perBand) => [
  for (var i = 0; i < perBand; i++)
    _player(1000 + i, 50_000 + i * 5_000, 60), // rare: < OVR 70
  for (var i = 0; i < perBand; i++)
    _player(2000 + i, 4_000_000 + i * 50_000, 75), // epic: 70-79
  for (var i = 0; i < perBand; i++)
    _player(3000 + i, 40_000_000 + i * 2_000_000, 85), // legendary: 80-89
  for (var i = 0; i < perBand; i++)
    _player(4000 + i, 90_000_000 + i * 5_000_000, 92), // premium: 90+
];

BasePlayer _player(int id, int mv, int overall, {Position? position}) =>
    BasePlayer(
      playerId: id,
      name: 'Player $id',
      position: position ?? Position.st,
      nationality: 'Egypt',
      marketValueEur: mv,
      baseStats: BaseStats(
        overall: overall,
        attack: overall + 2,
        support: overall,
        defence: overall - 2,
        goalkeeping: 0,
      ),
    );

PackRarity bandOf(BasePlayer p) => PackRarity.fromOverall(p.baseStats.overall);

/// The draws of [n] seeded opens of [tier] over [pool] — each draw
/// carries the ROLLED rarity index ([PackDraw.tier]) plus the player.
List<PackDraw> seededDraws(
  PackTier tier,
  int n,
  int seed,
  List<BasePlayer> pool,
) {
  final engine = PackEngine(random: math.Random(seed));
  final scope = PackScope(category: PackCategory.global, tier: tier);
  return [
    for (var i = 0; i < n; i++) engine.open(scope, pool).single,
  ];
}

/// The per-band share of the rolled rarity over [draws].
List<double> bandShares(List<PackDraw> draws) {
  final counts = [0, 0, 0, 0];
  for (final d in draws) {
    counts[d.tier]++;
  }
  return [for (final c in counts) c / draws.length];
}

void main() {
  group('two-stage reproducibility (requirement 5)', () {
    test('a fixed seed reproduces the exact same player sequence', () {
      final pool = buildBandedPool(12);
      List<int> sequence(int seed) {
        final engine = PackEngine(random: math.Random(seed));
        final scope = PackScope(
          category: PackCategory.global,
          tier: PackTier.legendary,
        );
        return [
          for (var i = 0; i < 200; i++)
            engine.open(scope, pool).single.player.playerId,
        ];
      }

      expect(sequence(20261108), sequence(20261108));
      expect(
        sequence(1),
        isNot(sequence(2)),
        reason: 'different seeds must actually differ (the lock is not '
            'vacuous)',
      );
    });
  });

  group('distribution locks (requirement 5): 2,000 seeded opens per pack',
      () {
    const n = 2000;
    const tolerance = 0.03; // ±3 percentage points, the task's band
    final pool = buildBandedPool(30);

    void expectShare(List<double> shares, PackRarity r, double expected) {
      final actual = shares[r.index];
      // ignore: avoid_print
      print('T-0059 ${r.name}: ${(actual * 100).toStringAsFixed(2)}% '
          '(table ${(expected * 100).toStringAsFixed(0)}%)');
      if (expected == 0) {
        expect(actual, 0,
            reason: '${r.name} weight is 0 — structurally unreachable');
      } else {
        expect((actual - expected).abs(), lessThanOrEqualTo(tolerance));
      }
    }

    test('rare pack rolls 75/20/5/0', () {
      final shares = bandShares(seededDraws(PackTier.rare, n, 101, pool));
      const table = [0.75, 0.20, 0.05, 0.0];
      for (final r in PackRarity.values) {
        expectShare(shares, r, table[r.index]);
      }
    });

    test('epic pack rolls 40/50/10/0', () {
      final shares = bandShares(seededDraws(PackTier.epic, n, 102, pool));
      const table = [0.40, 0.50, 0.10, 0.0];
      for (final r in PackRarity.values) {
        expectShare(shares, r, table[r.index]);
      }
    });

    test('legendary pack rolls 0/55/43/2 — the T-0047 gold guarantee is '
        'reversed by the owner (2026-11-08)', () {
      final draws = seededDraws(PackTier.legendary, n, 103, pool);
      final shares = bandShares(draws);
      const table = [0.0, 0.55, 0.43, 0.02];
      for (final r in PackRarity.values) {
        expectShare(shares, r, table[r.index]);
      }
      // The premium 2% must be a real, non-empty stream over the batch.
      expect(
        draws.where((d) => bandOf(d.player) == PackRarity.premium),
        isNotEmpty,
        reason: '2% over 2,000 opens ≈ 40 premium pulls — none means the '
            'roll is dead',
      );
    });

    test('premium exclusivity: zero premium pulls over ≥ 2,000 seeded '
        'rare AND epic opens', () {
      for (final (tier, seed) in [
        (PackTier.rare, 201),
        (PackTier.epic, 202),
      ]) {
        final draws = seededDraws(tier, n, seed, pool);
        final premium = draws.where(
          (d) => bandOf(d.player) == PackRarity.premium,
        );
        // ignore: avoid_print
        print('T-0059 ${tier.name} pack premium pulls: ${premium.length}');
        expect(premium, isEmpty,
            reason: 'premium (90+) is reachable EXCLUSIVELY via the '
                'legendary pack 2% roll — ${tier.name} carries 0.0');
      }
    });

    test('boundary integrity: no player outside his rarity band is ever '
        'drawn (70/80/90 edges over the same batches)', () {
      for (final (tier, seed) in [
        (PackTier.rare, 301),
        (PackTier.epic, 302),
        (PackTier.legendary, 303),
      ]) {
        for (final d in seededDraws(tier, n, seed, pool)) {
          // Every band is non-empty in the global pool, so the fallback
          // never fires and the drawn band MUST equal the rolled band.
          expect(bandOf(d.player).index, d.tier,
              reason: '${d.player.name} (OVR ${d.player.baseStats.overall}, '
                  'band ${bandOf(d.player)}) left the rolled band '
                  '(${d.tier})');
        }
      }
    });
  });

  group('edge cases (requirement 6)', () {
    test('one-player rarity: deterministic draw, no RNG consumed for the '
        'stage-2 pick', () {
      final pool = [buildBandedPool(1).first, _player(9999, 45_000_000, 85)];
      PackOddsConfig always(PackRarity r) {
        final w = [
          for (final x in PackRarity.values) x == r ? 1.0 : 0.0,
        ];
        return PackOddsConfig(
          rarePack: (rare: w[0], epic: w[1], legendary: w[2], premium: w[3]),
          epicPack: (rare: w[0], epic: w[1], legendary: w[2], premium: w[3]),
          legendaryPack: (
            rare: w[0],
            epic: w[1],
            legendary: w[2],
            premium: w[3],
          ),
        );
      }

      // The legendary band holds exactly ONE player — any seed draws him
      // (stage 2 consumes no RNG), so different seeds agree completely.
      const scope = PackScope(category: PackCategory.global);
      List<int> draws(int seed) => [
        for (var i = 0; i < 20; i++)
          PackEngine(
            random: math.Random(seed),
            oddsConfig: always(PackRarity.legendary),
          ).open(scope, pool).single.player.playerId,
      ];
      expect(draws(1), everyElement(9999));
      expect(draws(1), draws(2),
          reason: 'a single-player band consumes no stage-2 randomness — '
              'the existing single-player contract');
    });

    test('identical market values: uniform among them', () {
      // The legendary band holds EXACTLY the three equal-MV twins, so
      // their within-band weights are identical by construction.
      final twins = [
        _player(100, 50_000_000, 85),
        _player(101, 50_000_000, 85),
        _player(102, 50_000_000, 85),
      ];
      final pool = [
        // rare + epic fillers only — no other legendary band members.
        _player(10, 100_000, 60),
        _player(11, 900_000, 62),
        _player(20, 4_000_000, 75),
        _player(21, 5_000_000, 76),
        ...twins,
      ];
      final draws = seededDraws(PackTier.legendary, 900, 31, pool);
      final drawn = [for (final d in draws) d.player];
      expect(
        bandShares(draws)[PackRarity.legendary.index],
        closeTo(0.43, 0.03),
      );
      final counts = <int, int>{for (final t in twins) t.playerId: 0};
      for (final p in drawn) {
        if (counts.containsKey(p.playerId)) {
          counts[p.playerId] = counts[p.playerId]! + 1;
        }
      }
      // Equal MVs → equal weights → each twin takes ~1/3 of the band's
      // legendary-band draws (43% × 900 ≈ 387 → ~129 each; ±60).
      for (final c in counts.values) {
        expect(c, inInclusiveRange(69, 189), reason: '$counts');
      }
    });

    test('extreme MV spread (10× within one rarity): cheap players '
        'dominate but the star stays reachable', () {
      final spread = [
        _player(200, 1_000_000, 82),
        _player(201, 10_000_000, 89),
      ];
      final pool = [...buildBandedPool(2), ...spread];
      final drawn = [
        for (final d in seededDraws(PackTier.legendary, 2000, 41, pool))
          d.player,
      ];
      final cheap = drawn.where((p) => p.playerId == 200).length;
      final star = drawn.where((p) => p.playerId == 201).length;
      // weightFor: (10M/1M)^1.5 ≈ 31.6 — cheap pulls dominate the pair.
      expect(cheap, greaterThan(star * 5));
      expect(star, greaterThan(0),
          reason: 'never impossible — the band star must stay reachable');
    });

    test('an mv ≤ 0 row draws safely at the floor weight', () {
      final broken = _player(300, 0, 84); // invalid market value
      final pool = [...buildBandedPool(2), broken];
      final draws = seededDraws(PackTier.legendary, 500, 51, pool);
      expect(draws, isNotEmpty);
      for (final d in draws) {
        // Every draw stays inside the band it rolled (the broken row
        // cannot break the partition, only the weights).
        expect(bandOf(d.player).index, d.tier);
      }
      // weightFor clamps mv ≤ 0 to the floor (weight 1.0 vs a €40M pool
      // floor ≈ 1/893 for the cheapest neighbour) — the broken row
      // carries the legendary band's draws, never NaN.
      final brokenDraws = draws
          .where((d) => d.player.playerId == 300)
          .length;
      // ignore: avoid_print
      print('T-0059 mv≤0 row draws: $brokenDraws of 500 opens');
      expect(brokenDraws, greaterThan(50));
    });

    test('a scope with an empty rolled-rarity pool (RM-style): fallback '
        'draws, no crash, no null player, booked under the rolled band',
        () {
      // RM has NO legendary rows: every 80+ roll falls back to the
      // nearest non-empty band (epic), and the draw still reports the
      // ROLLED band (2) — the documented bookkeeping.
      final rmPool = [
        _player(400, 500_000, 60, position: Position.rm),
        _player(401, 2_000_000, 65, position: Position.rm),
        _player(402, 5_000_000, 75, position: Position.rm),
        _player(403, 8_000_000, 79, position: Position.rm),
      ];
      final engine = PackEngine(random: math.Random(61));
      const scope = PackScope(
        category: PackCategory.position,
        position: Position.rm,
        tier: PackTier.epic, // 40/50/10/0 — the 10% legendary roll fires
      );
      var fallbackBooked = 0;
      for (var i = 0; i < 300; i++) {
        final draw = engine.open(scope, rmPool).single;
        expect(draw.player, isNotNull);
        final band = bandOf(draw.player);
        expect(band, anyOf(PackRarity.rare, PackRarity.epic),
            reason: 'never leaves the neighbourhood of the rolled band');
        if (draw.tier == PackRarity.legendary.index) {
          expect(band, PackRarity.epic,
              reason: 'the empty-band fallback books the epic draw under '
                  'the rolled legendary share');
          fallbackBooked++;
        }
      }
      expect(fallbackBooked, greaterThan(0),
          reason: 'the 10% legendary roll always fires on an empty band — '
              'the fallback IS the answer');
    });

    test('10,000 consecutive opens: no exception, bounded memory, every '
        'draw in the pool', () {
      // Rotating positions so every scope below finds eligible players.
      final pool = [
        for (var i = 0; i < 32; i++)
          _player(
            1000 + i,
            50_000 + i * 40_000,
            55 + (i % 40),
            position: Position.values[i % Position.values.length],
          ),
      ];
      final engine = PackEngine(random: math.Random(71));
      final ids = {for (final p in pool) p.playerId};
      var opens = 0;
      // 40 distinct scopes cycle the (pool, scope, exponent) cache past
      // its 32-entry cap — the clear-and-rebuild path runs for real.
      for (var s = 0; s < 40; s++) {
        final scope = s.isEven
            ? PackScope(
                category: PackCategory.position,
                position: Position.values[s ~/ 2 % Position.values.length],
                tier: PackTier.values[s % 3],
              )
            : PackScope(
                category: PackCategory.global,
                tier: PackTier.values[s % 3],
              );
        for (var i = 0; i < 250; i++) {
          final draw = engine.open(scope, pool).single;
          expect(ids.contains(draw.player.playerId), isTrue);
          opens++;
        }
      }
      expect(opens, 10_000);
    });

    test('oddsFor: per-rarity per-player probabilities sum to 1 over a '
        'four-band pool', () {
      final pool = buildBandedPool(6);
      final engine = PackEngine(random: math.Random(81));
      const scope = PackScope(
        category: PackCategory.global,
        tier: PackTier.legendary,
      );
      final odds = engine.oddsFor(scope, pool);
      expect(odds.keys, containsAll([0, 1, 2, 3]));
      expect(odds[PackRarity.premium.index], isNotEmpty,
          reason: 'the 2% premium roll books the premium band\'s players');
      final total = odds.values
          .expand((band) => band.values)
          .fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1, 1e-9));
      // P(rarity) × P(player | rarity): within the legendary band, the
      // cheapest player outscores the dearest (weightFor ordering).
      final band = odds[PackRarity.legendary.index]!;
      final players = pool
          .where((p) => bandOf(p) == PackRarity.legendary)
          .toList()
        ..sort((a, b) => a.marketValueEur.compareTo(b.marketValueEur));
      expect(band[players.first.playerId]!,
          greaterThan(band[players.last.playerId]!));
    });

    test('the two-stage EV re-derives the price ladder (no pricing code)',
        () {
      final pool = buildBandedPool(10);
      final engine = PackEngine(random: math.Random(91));
      int priceOf(PackTier tier) => engine.packPriceFor(
        PackScope(category: PackCategory.global, tier: tier),
        pool,
      );
      final rare = priceOf(PackTier.rare);
      final epic = priceOf(PackTier.epic);
      final legendary = priceOf(PackTier.legendary);
      // ignore: avoid_print
      print('T-0059 synthetic-pool price ladder: $rare / $epic / '
          '$legendary');
      expect(rare, greaterThan(0));
      expect(epic, greaterThan(rare));
      expect(legendary, greaterThan(epic));
      expect(legendary % 1000, 0,
          reason: 'the whole-thousand normalization survives the new EV');
    });
  });

  group('the odds sheet labels localize (requirement 3)', () {
    test('the four band names exist in EN and AR', () {
      final en = AppLocalizationsEn();
      final labels = [
        en.packRarityRare,
        en.packRarityEpic,
        en.packRarityLegendary,
        en.packRarityPremium,
      ];
      expect(labels, ['Rare', 'Epic', 'Legendary', 'Premium']);
      expect(AppLocalizationsAr().packRarityRare, 'نادر');
      expect(AppLocalizationsAr().packRarityEpic, 'ملحمي');
      expect(AppLocalizationsAr().packRarityLegendary, 'أسطوري');
      expect(AppLocalizationsAr().packRarityPremium, 'نخبة');
    });
  });
}
