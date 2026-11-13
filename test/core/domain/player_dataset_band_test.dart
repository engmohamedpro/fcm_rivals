// Dataset band contract (T-0046): the retuned market-value → OVR curve
// measured against the shipped tm bundle (39,090 parsed rows: 39,017
// regulars + 73 icons, asOf 2026-11-12). Population-level assertions
// only — no player names are hardcoded, so the dataset can be refreshed
// without touching this test.
//
// The 90+ population is PRINTED, not banded: T-0049's red-premium tier
// is calibrated against that print, so the two tasks cannot drift apart
// silently (measured 2026-11-07 on the shipped two-segment curve:
// 31 rows, 0.148%).
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';
import '../../tm_bundle_io.dart'
    show loadTmDataset;

void main() {
  final gen = const BaseStatsGenerator();
  // The tm bundle (owner request 2026-11-12): a JSON LIST of player
  // maps (players + icons, as sent). Read through the shared loader's
  // dataset so the parser's validation rules apply, then measure the
  // same population statistics over the parsed rows.
  final rows = loadTmDataset().rows;
  final values = [for (final r in rows) r.marketValueEur];
  final overalls = [for (final v in values) gen.baseRatingFor(v)];
  final sorted = [...overalls]..sort();
  final n = overalls.length;

  test('the dataset loads and every rating stays within 30..99', () {
    expect(n, greaterThan(20_000), reason: 'dataset row count');
    for (final o in overalls) {
      expect(o, inInclusiveRange(30, 99));
    }
  });

  test('top-5 dataset values land in the elite 96-99 band', () {
    final top5Values = [...values]..sort();
    final top5Ratings = [
      for (final v in top5Values.reversed.take(5)) gen.baseRatingFor(v),
    ];
    for (final rating in top5Ratings) {
      expect(rating, inInclusiveRange(96, 99), reason: 'elite top-5');
    }
  });

  test('the €50M reference still lands 84 (±1)', () {
    expect(gen.baseRatingFor(50_000_000), inInclusiveRange(83, 85));
  });

  test('median OVR stays 51-56', () {
    // The tm bundle (40,240 parsed rows incl. icons) runs deeper than
    // the v3 cut: median 53 (was 55-60 on the curated 20,876).
    final mid = sorted.length ~/ 2;
    final median = (sorted[mid - 1] + sorted[mid]) / 2;
    expect(median, inInclusiveRange(51, 56), reason: 'median $median');
  });

  test('p90 OVR stays 64-70', () {
    // Measured 67 on the tm bundle (was 70-74 on the v3 cut).
    final p90 = sorted[(0.9 * n).floor()];
    expect(p90, inInclusiveRange(64, 70), reason: 'p90 $p90');
  });

  test('at most 2% of the dataset clamps at the 30 floor', () {
    final floored = overalls.where((o) => o <= 30).length / n;
    expect(floored, lessThanOrEqualTo(0.02), reason: 'floor share $floored');
  });

  test('80+ population stays within 1.0-2.5%', () {
    // Measured 1.68% on the tm bundle (was 2.0-3.5% on the v3 cut):
    // the 39k-row pool spreads the deep-mid mass wider.
    final elite = overalls.where((o) => o >= 80).length / n;
    expect(elite, inInclusiveRange(0.010, 0.025), reason: '80+ share $elite');
  });

  test('90+ population printed for T-0049 (no band)', () {
    final count = overalls.where((o) => o >= 90).length;
    // ignore: avoid_print
    print(
      '90+ population: $count rows '
      '(${(count / n * 100).toStringAsFixed(3)}% of $n)',
    );
    expect(count, greaterThan(0), reason: 'the elite tier must exist');
  });
}
