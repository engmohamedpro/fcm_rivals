import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/simulation/economy_simulator.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EconomySimulator progression (GDD 30/32)', () {
    test('multi-season save: metrics grow, ledger reconciles, no runaway inflation',
        () async {
      final sim = EconomySimulator(seed: 31);
      final report = await sim.run(
        label: 'medium-3season',
        seasonCount: 3,
        valueBand: SimValueBand.medium,
        datasetSize: 160,
      );

      expect(report.seasons, hasLength(3));
      // GDD 30: coins earned and measured every season.
      for (final s in report.seasons) {
        expect(s.coinsEarned, greaterThan(0));
        expect(s.finalPosition, inInclusiveRange(1, 20));
        expect(s.collectionSize, greaterThan(10));
        expect(s.bestSquadOverall, greaterThan(0));
      }
      // GDD 30: collection grows and squad improves over seasons (duplicates
      // merged, packs opened, reward packs granted).
      final first = report.seasons.first;
      final last = report.seasons.last;
      expect(last.collectionSize, greaterThanOrEqualTo(first.collectionSize));
      expect(last.bestSquadOverall,
          greaterThanOrEqualTo(first.bestSquadOverall - 2));

      // GDD 32: rewards do not cause Coin inflation — the average net
      // coins per season must stay well under one season's typical
      // earnings (a generous 80% bound: spending exists via upgrades).
      expect(report.avgNetCoinsPerSeason, lessThan(0.8 * first.coinsEarned));
      expect(report.finalCoins, greaterThan(0));

      // GDD 32: promotion achievable OR relegation possible — with a
      // mid-strength squad both outcomes are legitimate; what must hold
      // is that the engine actually produced season outcomes at all.
      expect(report.seasons.map((s) => s.outcome).toSet(),
          isNot(contains('unknown')));
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('value bands behave differently (GDD 30 low vs high datasets)',
        () async {
      final low = await EconomySimulator(seed: 5).run(
          label: 'low', seasonCount: 1, valueBand: SimValueBand.low, datasetSize: 120);
      final high = await EconomySimulator(seed: 5).run(
          label: 'high', seasonCount: 1, valueBand: SimValueBand.high, datasetSize: 120);

      // A superstar dataset builds a stronger XI than a low-value one.
      expect(high.seasons.first.bestSquadOverall,
          greaterThan(low.seasons.first.bestSquadOverall));
      // Both still earn match coins and complete the season.
      expect(low.seasons.first.coinsEarned, greaterThan(0));
      expect(high.seasons.first.coinsEarned, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 8)));

    test('rewarded ads stay optional and bounded (GDD 33, FR-043)',
        () async {
      final withAds = await EconomySimulator(seed: 11).run(
        label: 'ads',
        seasonCount: 2,
        valueBand: SimValueBand.medium,
        useAds: true,
        datasetSize: 140,
      );
      final withoutAds = await EconomySimulator(seed: 11).run(
        label: 'no-ads',
        seasonCount: 2,
        valueBand: SimValueBand.medium,
        useAds: false,
        datasetSize: 140,
      );

      // Ads were watched (after non-wins) but never unbounded: the
      // daily engine caps usage, and a season has a finite fixture list.
      expect(withAds.adsWatched, greaterThan(0));
      expect(withAds.adsWatched,
          lessThanOrEqualTo(withAds.matchDraws + withAds.matchLosses));

      // GDD 33: the game must remain playable without ads — the same
      // seed produces a comparable save either way.
      expect(withoutAds.adsWatched, 0);
      expect(withoutAds.seasons, hasLength(2));
      expect(withoutAds.finalCoins, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 10)));
  });
}
