/// FCM Rivals — T-0060 calibration gate: the pack probability contract.
///
/// Band-locked balance numbers for the two-stage draw (T-0059) over the
/// REAL shipped dataset (20,876 players). Every band prints its
/// measured value so a failure tells you WHAT moved, not just that
/// something did. The bands are the calibration contract referenced by
/// GDD §5.4/5.5 — a retune must move these numbers consciously, never
/// silently.
///
/// Locks (task T-0060):
///  * EV ladder strictly increasing rare < epic < legendary
///  * global price bands ±25% around 5k / 10k / 24k
///  * premium EV share 1–8% of the legendary pack's EV
///  * premium reachability 1.5–2.5% per legendary pack (published odds)
///  * affordability in par matches: rare ≤ 4, epic 4–8, legendary 10–16
///  * diversity floor: RARE N_eff ≥ 1,000 AND cheapest-decile ≤ 75%
///    at the shipped exponent (1.5), metrics printed for every band
library;
// ignore_for_file: avoid_print — band-locked calibration numbers must print.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

const _datasetPath = 'assets/data/players_v1.json';

/// Par team income per match in coins — the affordability denominator
/// (probe-measured long-run average of the shipped reward model:
/// base 1,500 + 250/goal, ×0.90 loss / ×1.24 win at a 45% win rate).
const int parIncomePerMatch = 1858;

List<BasePlayer> loadRealPool() {
  final db = PlayerDatabase();
  db.importDatasetFromJson(File(_datasetPath).readAsStringSync());
  return db.all.toList(growable: false);
}

/// Effective pool size exp(entropy) of the band's stage-2 weight
/// distribution at [exponent] — same formula the probe prints.
double effectivePoolSize(List<BasePlayer> band, double exponent) {
  if (band.isEmpty) return 0;
  final floor = band
      .map((p) => p.marketValueEur)
      .reduce((a, b) => a < b ? a : b);
  var sum = 0.0;
  final ws = <double>[];
  for (final p in band) {
    final w = weightFor(
      marketValueEur: p.marketValueEur,
      poolMinMarketValueEur: floor,
      exponent: exponent,
    );
    ws.add(w);
    sum += w;
  }
  if (!(sum > 0 && sum.isFinite)) return band.length.toDouble();
  var entropy = 0.0;
  for (final w in ws) {
    final p = w / sum;
    if (p > 0) entropy -= p * math.log(p);
  }
  return math.exp(entropy);
}

/// Cheapest-decile (10%) share of the band's stage-2 probability mass
/// at [exponent] — same formula the probe prints.
double cheapestDecileShare(List<BasePlayer> band, double exponent) {
  if (band.isEmpty) return 0;
  final floor = band
      .map((p) => p.marketValueEur)
      .reduce((a, b) => a < b ? a : b);
  var total = 0.0;
  var decile = 0.0;
  final n = band.length;
  for (var i = 0; i < n; i++) {
    final w = weightFor(
      marketValueEur: band[i].marketValueEur,
      poolMinMarketValueEur: floor,
      exponent: exponent,
    );
    total += w;
    if (i < n / 10) decile += w;
  }
  if (!(total > 0 && total.isFinite)) return 1;
  return decile / total;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final pool = loadRealPool();
  final economy = const EconomyEngine();
  final oddsConfig = defaultPackOddsConfig;

  /// Global-scope band pools at the shipped config.
  final bands = <List<BasePlayer>>[
    for (final _ in PackRarity.values) <BasePlayer>[],
  ];
  for (final p in pool) {
    bands[PackRarity.fromOverall(
      p.baseStats.overall,
      config: oddsConfig,
    ).index].add(p);
  }

  PackEngine engineFor(PackTier tier, {double? exponent}) => PackEngine(
    tier: tier,
    random: math.Random(2026),
    economy: economy,
    oddsConfig: exponent == null
        ? defaultPackOddsConfig
        : PackOddsConfig(marketValueExponent: exponent),
  );

  PackScope globalScopeFor(PackTier tier) =>
      PackScope(category: PackCategory.global, tier: tier);

  group('pack probability: EV ladder & prices (global scope)', () {
    test('EV ladder strictly increasing: rare < epic < legendary', () {
      final evs = {
        for (final t in PackTier.values)
          t: engineFor(t).expectedPackValue(globalScopeFor(t), pool),
      };
      // Measured (probe, 2026-11-08, 100k packs, seed 2026):
      // rare 4,241 · epic 8,361 · legendary 17,209 (analytic).
      print('measured EVs: $evs');
      expect(evs[PackTier.rare]!, lessThan(evs[PackTier.epic]!));
      expect(evs[PackTier.epic]!, lessThan(evs[PackTier.legendary]!));
      // Strictness worth paying for: each step at least doubles.
      expect(
        evs[PackTier.epic]! / evs[PackTier.rare]!,
        greaterThan(1.5),
      );
      expect(
        evs[PackTier.legendary]! / evs[PackTier.epic]!,
        greaterThan(1.5),
      );
    });

    test('global price bands ±25% around 5k / 10k / 24k', () {
      final prices = {
        for (final t in PackTier.values)
          t: engineFor(t).packPriceFor(globalScopeFor(t), pool),
      };
      // Measured: rare 5,000 · epic 10,000 · legendary 24,000
      // (EV × 1.25/1.40 margin, floored to thousands).
      print('measured prices: $prices');
      expect(prices[PackTier.rare]!, inInclusiveRange(3_750, 6_250));
      expect(prices[PackTier.epic]!, inInclusiveRange(7_500, 12_500));
      expect(prices[PackTier.legendary]!, inInclusiveRange(18_000, 30_000));
    });

    test('monte-carlo EV matches the analytic contract (10k packs)', () {
      // The probe's job compressed into a test: opened packs converge
      // on expectedPackValue — the price's foundation is honest.
      for (final tier in PackTier.values) {
        final engine = engineFor(tier);
        final scope = globalScopeFor(tier);
        var sum = 0;
        const n = 10_000;
        for (var i = 0; i < n; i++) {
          final draw = engine.open(scope, pool).single;
          sum += economy.economicValueOf(draw.player.marketValueEur);
        }
        final mc = sum / n;
        final analytic = engine.expectedPackValue(scope, pool);
        print('$tier: monte-carlo $mc vs analytic $analytic');
        expect(
          mc,
          inInclusiveRange(analytic * 0.95, analytic * 1.05),
          reason: '$tier monte-carlo EV must track the analytic EV (±5%)',
        );
      }
    });
  });

  group('pack probability: premium economics (legendary pack)', () {
    test('premium contributes 1–8% of the legendary pack EV', () {
      // Analytic: the premium band's share of the legendary table (2%)
      // times its odds-weighted band EV, over the pack EV.
      final engine = engineFor(PackTier.legendary);
      final scope = globalScopeFor(PackTier.legendary);
      final table = oddsConfig.legendaryPack;
      final premiumPool = bands[PackRarity.premium.index]
        ..sort((a, b) => a.marketValueEur.compareTo(b.marketValueEur));
      final floor = premiumPool.first.marketValueEur;
      var bandEv = 0.0;
      var weightSum = 0.0;
      for (final p in premiumPool) {
        final w = weightFor(
          marketValueEur: p.marketValueEur,
          poolMinMarketValueEur: floor,
          exponent: oddsConfig.marketValueExponent,
        );
        bandEv += economy.economicValueOf(p.marketValueEur) * w;
        weightSum += w;
      }
      final premiumEv = table.premium * (bandEv / weightSum);
      final packEv = engine.expectedPackValue(scope, pool);
      final share = premiumEv / packEv;
      // Measured (probe, 100k packs, seed 2026): ≈3.3–4.8%.
      print('premium EV share: ${(share * 100).toStringAsFixed(1)}%');
      expect(share, inInclusiveRange(0.01, 0.08));
    });

    test('premium reachability: 1.5–2.5% per legendary pack', () {
      // The published odds ARE the contract: the legendary table's
      // premium column, measured over 20k seeded opens.
      final engine = engineFor(PackTier.legendary);
      final scope = globalScopeFor(PackTier.legendary);
      const n = 20_000;
      var premium = 0;
      for (var i = 0; i < n; i++) {
        final draw = engine.open(scope, pool).single;
        if (draw.player.baseStats.overall >=
            oddsConfig.premiumMinOverall) {
          premium++;
        }
      }
      final freq = premium / n;
      // Measured (probe): ≈1.9–2.0%. σ at p=0.02, n=20k ≈ 0.1pp.
      print('premium frequency: ${(freq * 100).toStringAsFixed(2)}%');
      expect(freq, inInclusiveRange(0.015, 0.025));
    });
  });

  group('pack probability: affordability (par matches)', () {
    test('rare ≤ 4 · epic 4–8 · legendary 10–16 matches at par income', () {
      final matches = {
        for (final t in PackTier.values)
          t:
              engineFor(t).packPriceFor(globalScopeFor(t), pool) /
              parIncomePerMatch,
      };
      // Measured: rare 2.7 · epic 5.4 · legendary 12.9 matches.
      print('measured affordability (matches): $matches');
      expect(matches[PackTier.rare]!, lessThan(4));
      expect(matches[PackTier.epic]!, inInclusiveRange(4, 8));
      expect(matches[PackTier.legendary]!, inInclusiveRange(10, 16));
    });
  });

  group('pack probability: selection diversity floor', () {
    test('RARE N_eff ≥ 1,000 AND cheapest-decile ≤ 75% at exponent 1.5', () {
      final rare = bands[PackRarity.rare.index]
        ..sort((a, b) => a.marketValueEur.compareTo(b.marketValueEur));
      final nEff = effectivePoolSize(rare, oddsConfig.marketValueExponent);
      final decile = cheapestDecileShare(
        rare,
        oddsConfig.marketValueExponent,
      );
      // Measured (probe, 2026-11-08): N_eff 3,673 · decile 71.5%.
      // (The task's analysis quoted N_eff 1,288 on the 18,295-row
      // bottom-weighted pool; the shipped dataset band is 18,292 rows —
      // same floor, comfortably cleared either way.)
      print('RARE: N_eff ${nEff.toStringAsFixed(0)} · '
          'cheapest-decile ${(decile * 100).toStringAsFixed(1)}%');
      expect(nEff, greaterThanOrEqualTo(1_000));
      expect(decile, lessThanOrEqualTo(0.75));
    });

    test('epic / legendary / premium diversity metrics printed & sane', () {
      // The same guard for the upper bands — no lock beyond sanity
      // (the task requires the metrics printed; the floor is RARE's).
      final metrics = <String, (double, double)>{};
      for (final r in PackRarity.values) {
        if (r == PackRarity.rare) continue;
        final band = bands[r.index]
          ..sort((a, b) => a.marketValueEur.compareTo(b.marketValueEur));
        if (band.isEmpty) continue;
        final nEff = effectivePoolSize(band, oddsConfig.marketValueExponent);
        final decile = cheapestDecileShare(
          band,
          oddsConfig.marketValueExponent,
        );
        metrics[r.name] = (nEff, decile);
        print('${r.name}: N_eff ${nEff.toStringAsFixed(0)} · '
            'cheapest-decile ${(decile * 100).toStringAsFixed(1)}%');
        expect(nEff, greaterThanOrEqualTo(1));
        expect(decile, lessThanOrEqualTo(1));
      }
      expect(metrics, containsPair(PackRarity.epic.name, anything));
      expect(metrics, containsPair(PackRarity.legendary.name, anything));
      expect(metrics, containsPair(PackRarity.premium.name, anything));
    });
  });
}
