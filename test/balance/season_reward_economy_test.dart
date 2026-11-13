/// FCM Rivals — T-0076: gate the coins-only, position-graduated season
/// rewards with a seeded multi-season economy sweep (GDD 32).
///
/// T-0074 removed the pack half of season rewards (coins only) and
/// T-0075 graduated the coin ladder strictly by final position. This
/// gate runs the REAL economy end to end — `EconomySimulator` over
/// real `SeasonStore`/`MatchSession` saves with real pack purchases —
/// and locks four regression bands so every future reward change has
/// to re-prove the economy:
///  1. per-season earned stays inside the calibrated faucet band
///     (measured 106_875–165_500, pinned with tolerance);
///  2. the season-reward share of season income never exceeds 40% —
///     the coin ladder can never dwarf match income (measured max
///     0.302);
///  3. `avgNetCoinsPerSeason` stays bounded (measured −4_017…+208; no
///     runaway accumulation across 6 seasons);
///  4. the static champion ceiling: `seasonRewardCoins(div 1, pos 1)`
///     < 0.25 × 90_000.
///
/// Progression locks: promotion observed within 6 seasons in every run
/// (measured 4–6 per save), collection grows on average season over
/// season (cards now come only from store purchases — T-0074), and the
/// squad's best XI improves.
///
/// Deviation note (T-0072 protocol, documented rather than guessed):
/// the task suggests querying `coinTransactions` by reason for the
/// season-reward share, but `EconomySimulator.run` closes its database
/// in a `finally` block and the task forbids production changes — so
/// the reward per season is computed with the same engine curve the
/// store pays through (`seasonRewardCoins(division, position)`), whose
/// equality with the ledger row is already locked by
/// `season_store_test.dart` ("ledger.first.amount ==
/// completion.rewardCoins"). The share numerator is therefore exact.
///
/// Seeds 5701/5702/5703 × {medium, high} × 6 seasons — the same
/// ballpark runtime as the existing simulator tests (~18 s per run,
/// ~110 s total). Deterministic: same seeds, same numbers every run.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/season/season_engine.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final engine = const SeasonEngine();

  group('season reward economy sweep (T-0074+T-0075, GDD 32)', () {
    // LOCKED from the first measured run (seeds 5701–5703, 6 seasons,
    // bands medium+high, dataset 160 — see Developer Notes for the raw
    // table). Margins: the earned band is the measured min/max with
    // ±10% headroom; the net ceiling is generously above the measured
    // max (+208) but far under one season's income.
    const seeds = [5701, 5702, 5703];
    const bands = [SimValueBand.medium, SimValueBand.high];
    const earnedMin = 96_000; // measured 106_875, −10%
    const earnedMax = 182_000; // measured 165_500, +10%
    const netPerSeasonCeiling = 20_000; // measured max +208
    const rewardShareCeiling = 0.40; // measured max 0.302

    final reports = <String, EconomySimReport>{};

    setUpAll(() async {
      for (final seed in seeds) {
        for (final band in bands) {
          final sim = EconomySimulator(seed: seed);
          reports['$seed:${band.name}'] = await sim.run(
            label: 'sweep-$seed-${band.name}',
            seasonCount: 6,
            valueBand: band,
            datasetSize: 160,
          );
        }
      }
    });

    test('the sweep ran the full matrix (6 seeded saves, 6 seasons each)',
        () {
      expect(reports, hasLength(seeds.length * bands.length));
      for (final r in reports.values) {
        expect(r.seasons, hasLength(6));
      }
    });

    test('per-season earned stays in the calibrated faucet band', () {
      // GDD 32 via the known faucet context: a 38-match season banks
      // 70k–160k before sinks; the sweep's own measured band (with
      // headroom) must stay consistent with it — no silent widening.
      for (final r in reports.values) {
        for (final s in r.seasons) {
          expect(
            s.coinsEarned,
            inInclusiveRange(earnedMin, earnedMax),
            reason: '${r.label} season ${s.seasonIndex} earned '
                '${s.coinsEarned} drifted outside the measured band',
          );
        }
      }
    });

    test('season-reward share of season income never exceeds 40%', () {
      // The anti-inflation property in one number: the coin ladder is
      // a minority of income in EVERY season, so the ladder's growth
      // can never dwarf match income (measured max 0.302).
      for (final r in reports.values) {
        for (final s in r.seasons) {
          final reward = engine.seasonRewardCoins(
            division: s.division,
            position: s.finalPosition,
          );
          expect(
            s.coinsEarned,
            greaterThan(0),
            reason: '${r.label} season ${s.seasonIndex} earned nothing',
          );
          expect(
            reward / s.coinsEarned,
            lessThanOrEqualTo(rewardShareCeiling),
            reason: '${r.label} season ${s.seasonIndex}: reward $reward '
                'is too large a share of ${s.coinsEarned}',
          );
        }
      }
    });

    test('no runaway accumulation: avgNetCoinsPerSeason bounded', () {
      // GDD 32: rewards do not cause Coin inflation. The measured range
      // is −4_017…+208 net per season; the ceiling keeps generous
      // headroom while staying far under one season's income.
      for (final r in reports.values) {
        expect(
          r.avgNetCoinsPerSeason,
          lessThan(netPerSeasonCeiling),
          reason: '${r.label} accumulated coins too fast',
        );
        expect(r.finalCoins, greaterThan(0));
      }
    });

    test('static champion ceiling holds (GDD 32 inflation ceiling)', () {
      expect(engine.seasonRewardCoins(division: 1, position: 1), 20_000);
      expect(
        engine.seasonRewardCoins(division: 1, position: 1),
        lessThan(0.25 * 90_000),
      );
    });

    test('progression intact: promotions happen, collection grows', () {
      var promotionSeen = 0;
      for (final r in reports.values) {
        // Promotion within 6 seasons in the majority (here: every run
        // measured 4–6 promotions).
        if (r.promotions > 0) promotionSeen++;
        expect(
          r.promotions,
          greaterThan(0),
          reason: '${r.label} never promoted in 6 seasons',
        );
        // Collection grows on average season over season — cards now
        // come only from store purchases (T-0074).
        final first = r.seasons.first.collectionSize;
        final last = r.seasons.last.collectionSize;
        expect(
          last,
          greaterThan(first),
          reason: '${r.label} collection did not grow '
              '($first -> $last)',
        );
        // The best XI improves over the save.
        expect(
          r.seasons.last.bestSquadOverall,
          greaterThan(r.seasons.first.bestSquadOverall),
          reason: '${r.label} squad did not improve',
        );
      }
      expect(promotionSeen, reports.length);
    });
  });
}
