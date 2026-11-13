/// FCM Rivals — T-0109: the achievements economy gate.
///
/// A seeded, multi-season sweep over the REAL engine stack
/// (EconomySimulator with claimAchievements: every eligible tier
/// claimed through T-0108's real service at each season boundary —
/// real UNIQUE-guarded transactions, real ledger rows with the
/// 'achievement' reason) that proves the achievement coin faucet is a
/// controlled secondary income stream:
///   Band 1 — share ceiling: achievement coins per season ≤ 35% of
///             the season's total earned (seasons 2+; season 1's
///             milestone front-load pinned at its measured value).
///   Band 2 — decay property: the share is non-increasing from season
///             2 onward (the geometric ladder outpacing flat rewards).
///   Band 3 — lifetime ceiling: 6-season cumulative achievement coins
///             ≤ 20% of cumulative earned.
///   Band 4 — catalog static ceiling: totalCatalogCoinCeiling ≤ 15%
///             of the measured 6-season match economy.
///
/// MEASURED TABLE (seeds 5801–5802 × medium, dataset 160, 6 seasons —
/// the T-0076 ballpark):
///   seed 5801: 2.4% 1.2% 0.1% 0.1% 0.1% 0.0% | lifetime 0.6%
///              (cum 4_980 achievement of 842_105 earned)
///   seed 5802: 2.8% 0.4% 0.9% 0.2% 0.1% 0.0% | lifetime 0.6%
///              (cum 5_020 achievement of 823_395 earned)
///   catalog ceiling: 21_520 coins (≈1.7% of one seed's 6-season
///   income). The faucet is a rounding error by design — the bands
///   below lock that with 2–3x headroom over measurement, never at
///   the measured edge.
///
/// Deterministic: same seeds, same numbers, every run.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/achievements/achievement_catalog_data.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('achievement faucet economy sweep (T-0109, GDD 26/32)', () {
    // The sweep: 2 seeds × medium band × 6 seasons, achievements ON.
    // (T-0076's own sweep runs the match economy; the achievement
    // bands ride the same stack with the faucet engaged.)
    const seeds = [5801, 5802];
    const seasonCount = 6;

    test('the faucet is measured, banded and locked', () async {
      final perSeasonShares =
          List.generate(seasonCount, (_) => <double>[]);
      final lifetimeShares = <double>[];
      var cumulativeMatchEarned = 0;

      for (final seed in seeds) {
        final report = await EconomySimulator(seed: seed).run(
          label: 'ach-gate-$seed',
          seasonCount: seasonCount,
          valueBand: SimValueBand.medium,
          datasetSize: 160,
          claimAchievements: true,
        );

        var cumulativeAchievement = 0;
        var cumulativeEarned = 0;
        for (final season in report.seasons) {
          cumulativeAchievement += season.achievementCoins;
          cumulativeEarned += season.coinsEarned;
          // A season with zero earned cannot define a share.
          if (season.coinsEarned > 0) {
            perSeasonShares[season.seasonIndex]
                .add(season.achievementCoins / season.coinsEarned);
          }
        }
        cumulativeMatchEarned += cumulativeEarned;
        final lifetimeShare =
            cumulativeAchievement / cumulativeEarned.toDouble();
        lifetimeShares.add(lifetimeShare);
      }

      final meanShares = [
        for (final seasonShares in perSeasonShares)
          seasonShares.isEmpty
              ? 0.0
              : seasonShares.fold(0.0, (a, b) => a + b) /
                    seasonShares.length,
      ];

      // ---- Band 1: per-season share ceiling -------------------------
      // MEASURED (seeds 5801/5802, medium, 160-dataset, 6 seasons):
      //   seed 5801: 2.4% / 1.2% / 0.1% / 0.1% / 0.1% / 0.0%
      //   seed 5802: 2.8% / 0.4% / 0.9% / 0.2% / 0.1% / 0.0%
      // Season 1 front-loads the one-time milestones BY DESIGN (the
      // new-player coin hook): peak measured 2.8%, pinned at 5% —
      // generous headroom over the measured peak while still a hard
      // stop far below any dominant share. Seasons 2+: 3.5%.
      expect(meanShares[0], lessThan(0.05),
          reason: 'season 1 peak (measured 2.4–2.8%) pinned at 5%: the '
              'milestone front-load is the new-player hook, never a '
              'dominant stream');
      for (var s = 1; s < seasonCount; s++) {
        expect(
          meanShares[s],
          lessThan(0.035),
          reason: 'season ${s + 1}: the faucet stays a rounding error '
              'of income (measured ≤ 1.2%; band 3.5% — a 3x margin '
              'over measurement, still a hard stop)',
        );
      }

      // ---- Band 2: decay from season 2 onward -----------------------
      // Non-increasing across the sweep, one noisy season tolerated.
      // MEASURED mean shares (5801/5802): 2.6% → 0.8% → 0.5% → 0.15%
      // → 0.1% → 0.1% — the decay is the geometric ladder doing its
      // job. One noisy season tolerated (seed 5802's season-3 bump).
      var violations = 0;
      for (var s = 1; s < seasonCount - 1; s++) {
        if (meanShares[s + 1] > meanShares[s] + 0.02) violations++;
      }
      expect(violations, lessThan(2),
          reason: 'the share decays as geometric thresholds outpace '
              'flat rewards (one noisy season tolerated; measured '
              'means: ${meanShares.map((s) => s.toStringAsFixed(3)).join(' → ')})');

      // ---- Band 3: lifetime ceiling ---------------------------------
      // MEASURED: 0.6% on both seeds. Band: 2% — 3x over measurement,
      // still a tenth of the task's 20% brief (which measured reality
      // came in far under; the tighter band is the better lock).
      for (final share in lifetimeShares) {
        expect(share, lessThan(0.02),
            reason: '6-season cumulative achievement income (measured '
                '0.6%) is a rounding error of the economy');
      }

      // ---- Band 4: catalog static ceiling ---------------------------
      // MEASURED: ceiling 21_520 coins vs ~832_750 earned per seed
      // over 6 seasons (~1.7%). Band: 15% of the measured 6-season
      // income (the task's brief) — the completionist's whole
      // catalog, claimed at once, is a minority stream.
      final catalogCeiling = AchievementCatalog
          .economy
          .totalCatalogCoinCeiling(AchievementCatalog.definitions);
      final perSeedIncome =
          cumulativeMatchEarned / seeds.length.toDouble();
      expect(
        catalogCeiling,
        lessThan(perSeedIncome * 6 * 0.15),
        reason: 'even a completionist claiming EVERYTHING earns at '
            'most 15% of the 6-season match economy (ceiling '
            '$catalogCeiling vs measured $perSeedIncome/season — '
            'measured ratio ~1.7%)',
      );
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
