/// FCM Rivals — pack probability transparency probe (T-0060, GDD 5.4/5.5).
///
/// The audit tool for the two-stage draw (T-0059): opens N seeded packs
/// per tier over the REAL shipped dataset and measures whether the
/// shipped economy is what it claims — rarity distribution vs the
/// configured tables (binomial 3σ), per-player selection shares vs
/// theory, reward MV stats, premium frequency, EV in coins, and the
/// selection-diversity metrics (effective pool size N_eff and the
/// cheapest-decile share) that guard the "cheap players must not become
/// the only realistic rewards" rule.
///
/// Pure Dart, zero Flutter imports — the whole engine chain runs under
/// plain `dart run` by design.
///
/// Usage:
///   dart run tool/pack_probability_probe.dart                       # 100k packs, seed 2026
///   dart run tool/pack_probability_probe.dart --packs 100000 --seed 2026
///   dart run tool/pack_probability_probe.dart --exponent 1.0        # candidate sweep
///   dart run tool/pack_probability_probe.dart --json out.json       # machine-readable
library;
// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings — CLI report tool.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

/// Par team income per match in coins — the affordability denominator.
/// Derived from the shipped reward model (economy_balance_test's
/// win-rate-par measurement): ~0.9 goals when losing / ~1.8 when winning
/// around a 45% win rate lands the long-run average at ≈1,858 coins per
/// match (base 1,500 + 250/goal, ×0.90 loss / ×1.24 win).
const int parIncomePerMatch = 1858;

const _playersPath = 'assets/data/tm-players.json';
const _iconsPath = 'assets/data/tm-icons.json';
const _clubsPath = 'assets/data/tm-clubs.json';
const _leaguesPath = 'assets/data/tm-leagues.json';

List<BasePlayer> loadPool() {
  final db = PlayerDatabase();
  db.importDataset(
    PlayerDataset.fromTmBundle(
      playersJson: File(_playersPath).readAsStringSync(),
      iconsJson: File(_iconsPath).readAsStringSync(),
      clubsJson: File(_clubsPath).readAsStringSync(),
      leaguesJson: File(_leaguesPath).readAsStringSync(),
    ),
  );
  return db.all.toList(growable: false);
}

/// One tier's measured probe result — every field printed in the report.
class TierProbe {
  TierProbe({required this.tier, required this.packs});

  final PackTier tier;
  final int packs;

  /// Rolled-band counts (PackRarity index order: rare/epic/legendary/premium).
  final List<int> rolledCounts = [0, 0, 0, 0];

  /// Economic value of each opened pack's reward (coins).
  final List<int> rewardEvs = [];

  /// Market value of each opened pack's reward (Eur).
  final List<int> rewardMvs = [];

  /// Premium draws that actually delivered a 90+ OVR player.
  int premiumDelivered = 0;

  /// Per-player draw counts within the tier's rolled bands.
  final Map<int, int> playerCounts = {};

  /// Whether each opened pack's reward was a 90+ OVR premium player
  /// (same order as [rewardEvs]/[rewardMvs]).
  final List<bool> rewardPremium = [];

  void record(PackDraw draw, EconomyEngine economy) {
    rolledCounts[draw.tier]++;
    rewardMvs.add(draw.player.marketValueEur);
    rewardEvs.add(economy.economicValueOf(draw.player.marketValueEur));
    final isPremium = draw.player.baseStats.overall >=
        defaultPackOddsConfig.premiumMinOverall;
    rewardPremium.add(isPremium);
    if (isPremium) {
      premiumDelivered++;
    }
    playerCounts.update(
      draw.player.playerId,
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
}

/// Theoretical per-player probability under the two-stage model:
/// [PackEngine.oddsFor] already returns `P(rarity roll) × P(player |
/// rarity)` per band — summing the four bands' maps gives the exact
/// per-player theory the measured shares are compared against.
Map<int, double> theoreticalShares(
  PackEngine engine,
  PackScope scope,
  List<BasePlayer> pool,
) {
  final result = <int, double>{};
  final perOdds = engine.oddsFor(scope, pool);
  for (var r = 0; r < PackRarity.values.length; r++) {
    for (final entry in perOdds[r]!.entries) {
      result.update(
        entry.key,
        (v) => v + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }
  return result;
}

/// Effective pool size: exp(entropy) of the stage-2 weight distribution
/// of [band] — the size a UNIFORM pool would need to carry the same
/// entropy. Exponent-dependent diversity measure (T-0060 context).
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

/// Share of the stage-2 probability mass taken by the cheapest decile
/// (10%) of [band] at [exponent] — the bottom-heaviness guard.
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

String pad(Object? o, int width) => o.toString().padRight(width);

void main(List<String> args) {
  var packs = 100_000;
  var seed = 2026;
  double? exponent;
  String? jsonOut;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--packs':
        packs = int.parse(args[++i]);
      case '--seed':
        seed = int.parse(args[++i]);
      case '--exponent':
        exponent = double.parse(args[++i]);
      case '--json':
        jsonOut = args[++i];
      case '--help' || '-h':
        stdout.writeln(
          'usage: dart run tool/pack_probability_probe.dart '
          '[--packs N] [--seed S] [--exponent E] [--json FILE]',
        );
        exit(0);
      default:
        stderr.writeln('unknown flag: ${args[i]}');
        exit(2);
    }
  }

  final pool = loadPool();
  final economy = const EconomyEngine();
  final oddsConfig = exponent == null
      ? defaultPackOddsConfig
      : PackOddsConfig(marketValueExponent: exponent);
  oddsConfig.validate();
  // Band pools of the global scope (the probe's diversity substrate).
  final bands = <List<BasePlayer>>[
    for (final _ in PackRarity.values) <BasePlayer>[],
  ];
  for (final p in pool) {
    bands[PackRarity.fromOverall(
      p.baseStats.overall,
      config: oddsConfig,
    ).index].add(p);
  }

  stdout.writeln('FCM Rivals — pack probability transparency probe');
  stdout.writeln(
    'dataset: tm-bundle (${pool.length} players) · '
    'packs: $packs · seed: $seed · exponent: '
    '${oddsConfig.marketValueExponent}',
  );
  stdout.writeln(
    'pool bands: '
    'rare ${bands[0].length} / epic ${bands[1].length} / '
    'legendary ${bands[2].length} / premium ${bands[3].length}',
  );
  stdout.writeln('');

  final json = <String, dynamic>{
    'packs': packs,
    'seed': seed,
    'exponent': oddsConfig.marketValueExponent,
    'tiers': <String, dynamic>{},
  };

  for (final tier in PackTier.values) {
    final engine = PackEngine(
      tier: tier,
      random: math.Random(seed),
      economy: economy,
      oddsConfig: oddsConfig,
    );
    final probe = TierProbe(tier: tier, packs: packs);
    final scope = PackScope(category: PackCategory.global, tier: tier);
    final sw = Stopwatch()..start();
    for (var i = 0; i < packs; i++) {
      final draws = engine.open(scope, pool);
      if (draws.isEmpty) {
        stderr.writeln('empty draw at pack $i — pool exhausted?');
        exit(3);
      }
      probe.record(draws.single, economy);
    }
    sw.stop();

    // ---- Rarity distribution vs theoretical (+ binomial 3σ) ----
    final table = oddsConfig.oddsFor(tier);
    final tableShares = [
      table.rare,
      table.epic,
      table.legendary,
      table.premium,
    ];
    stdout.writeln(
      '=== ${tier.label.toUpperCase()} pack — $packs opens '
      '(${(sw.elapsedMilliseconds / 1000).toStringAsFixed(1)}s) ===',
    );
    stdout.writeln(
      'rarity     measured    theoretical   abs.dev    3σ bound    verdict',
    );
    final rarityJson = <String, dynamic>{};
    for (var r = 0; r < PackRarity.values.length; r++) {
      final p = tableShares[r];
      final measured = probe.rolledCounts[r] / packs;
      final sigma = p > 0 ? math.sqrt(p * (1 - p) / packs) : 0.0;
      final bound3 = 3 * sigma;
      final dev = (measured - p).abs();
      final ok = dev <= bound3;
      stdout.writeln(
        '${pad(PackRarity.values[r].name, 10)} '
        '${pad((measured * 100).toStringAsFixed(2) + '%', 11)} '
        '${pad((p * 100).toStringAsFixed(2) + '%', 13)} '
        '${pad((dev * 100).toStringAsFixed(3) + 'pp', 10)} '
        '${pad((bound3 * 100).toStringAsFixed(3) + 'pp', 11)} '
        '${ok ? 'within 3σ' : 'OUT OF BAND'}',
      );
      rarityJson[PackRarity.values[r].name] = {
        'measured': double.parse((measured * 100).toStringAsFixed(4)),
        'theoretical': p * 100,
        'absDevPp': double.parse((dev * 100).toStringAsFixed(4)),
        'sigma3Pp': double.parse((bound3 * 100).toStringAsFixed(4)),
        'within3Sigma': ok,
      };
    }

    // ---- Reward MV stats + EV ----
    final mvs = probe.rewardMvs..sort();
    final evs = probe.rewardEvs;
    final meanMv = mvs.fold<num>(0, (a, b) => a + b) / mvs.length;
    final meanEv = evs.fold<num>(0, (a, b) => a + b) / evs.length;
    final price = engine.packPriceFor(scope, pool);
    final analyticEv = engine.expectedPackValue(scope, pool);
    final premiumFreq = probe.premiumDelivered / packs;
    // Premium EV share: the coin value the 90+ OVR rewards actually
    // carried, over the total — measured, not threshold-guessed.
    var premiumEvSum = 0;
    for (var i = 0; i < packs; i++) {
      if (probe.rewardPremium[i]) premiumEvSum += evs[i];
    }
    final premiumEvShare = meanEv > 0
        ? premiumEvSum / (evs.fold<num>(0, (a, b) => a + b))
        : 0.0;
    stdout.writeln(
      'reward MV: avg €${(meanMv / 1e6).toStringAsFixed(2)}M · '
      'min €${(mvs.first / 1e6).toStringAsFixed(2)}M · '
      'max €${(mvs.last / 1e6).toStringAsFixed(2)}M',
    );
    stdout.writeln(
      'EV per pack (coins): monte-carlo ${meanEv.round()} · '
      'analytic expectedPackValue $analyticEv · '
      'store price $price '
      '(margin ${tier == PackTier.legendary ? 1.40 : 1.25}x, '
      'floored to thousands) · '
      'affordability ${(price / parIncomePerMatch).toStringAsFixed(1)} '
      'matches at par income ($parIncomePerMatch/match)',
    );
    stdout.writeln(
      'premium delivered: ${probe.premiumDelivered} '
      '(${(premiumFreq * 100).toStringAsFixed(3)}% per pack) · '
      'premium EV share ${(premiumEvShare * 100).toStringAsFixed(1)}%',
    );

    // ---- Top-20 per-player selection shares vs theory ----
    final theory = theoreticalShares(engine, scope, pool);
    final ranked = probe.playerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final byId = {for (final p in pool) p.playerId: p};
    stdout.writeln('top-20 players by measured share (vs theoretical):');
    for (final e in ranked.take(20)) {
      final player = byId[e.key]!;
      final measuredShare = e.value / packs;
      final t = theory[e.key] ?? 0.0;
      stdout.writeln(
        '  ${pad(player.name, 22)} '
        '${pad(player.baseStats.overall, 3)} '
        '${pad('€${(player.marketValueEur / 1e6).toStringAsFixed(1)}M', 9)} '
        'measured ${(measuredShare * 100).toStringAsFixed(4)}% · '
        'theory ${(t * 100).toStringAsFixed(4)}%',
      );
    }

    // ---- Diversity: N_eff + cheapest-decile share per band ----
    stdout.writeln('selection diversity per rarity band:');
    final diversityJson = <String, dynamic>{};
    for (var r = 0; r < PackRarity.values.length; r++) {
      final band = bands[r]..sort(
        (a, b) => a.marketValueEur.compareTo(b.marketValueEur),
      );
      final nEff = effectivePoolSize(band, oddsConfig.marketValueExponent);
      final decile = cheapestDecileShare(
        band,
        oddsConfig.marketValueExponent,
      );
      stdout.writeln(
        '  ${pad(PackRarity.values[r].name, 10)} '
        'pool ${pad(band.length, 6)} '
        'N_eff ${pad(nEff.toStringAsFixed(0), 6)} '
        'cheapest-decile ${(decile * 100).toStringAsFixed(1)}%',
      );
      diversityJson[PackRarity.values[r].name] = {
        'pool': band.length,
        'nEff': double.parse(nEff.toStringAsFixed(1)),
        'cheapestDecileShare': double.parse(
          (decile * 100).toStringAsFixed(2),
        ),
      };
    }
    stdout.writeln('');

    json['tiers'][tier.name] = {
      'rarity': rarityJson,
      'rewardMv': {
        'avgEur': meanMv.round(),
        'minEur': mvs.first,
        'maxEur': mvs.last,
      },
      'evCoinsMonteCarlo': meanEv.round(),
      'evCoinsAnalytic': analyticEv,
      'price': price,
      'affordabilityMatches':
          double.parse((price / parIncomePerMatch).toStringAsFixed(2)),
      'premiumFrequency': double.parse(
        (premiumFreq * 100).toStringAsFixed(4),
      ),
      'premiumEvShare': double.parse(
        (premiumEvShare * 100).toStringAsFixed(2),
      ),
      'diversity': diversityJson,
    };
  }

  if (jsonOut != null) {
    File(jsonOut).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(json),
    );
    stdout.writeln('json report written to $jsonOut');
  }
}
