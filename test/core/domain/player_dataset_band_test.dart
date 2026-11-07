// Dataset band contract (T-0046): the retuned market-value → OVR curve
// measured against the real player dataset (assets/data/players_v1.json,
// 20,876 rows, asOf 2026-11-01). Population-level assertions only — no
// player names are hardcoded, so the dataset can be refreshed without
// touching this test.
//
// The 90+ population is PRINTED, not banded: T-0049's red-premium tier
// is calibrated against that print, so the two tasks cannot drift apart
// silently (measured 2026-11-07 on the shipped two-segment curve:
// 31 rows, 0.148%).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart';

void main() {
  final gen = const BaseStatsGenerator();
  final rows = (jsonDecode(
    File('assets/data/players_v1.json').readAsStringSync(),
  )['players'] as List)
      .cast<List<dynamic>>();
  // Row layout: [id, name, position, nationality, marketValueEur].
  final values = [for (final r in rows) r[4] as int];
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

  test('median OVR stays 55-60', () {
    final mid = sorted.length ~/ 2;
    final median = (sorted[mid - 1] + sorted[mid]) / 2;
    expect(median, inInclusiveRange(55, 60), reason: 'median $median');
  });

  test('p90 OVR stays 70-74', () {
    final p90 = sorted[(0.9 * n).floor()];
    expect(p90, inInclusiveRange(70, 74), reason: 'p90 $p90');
  });

  test('at most 2% of the dataset clamps at the 30 floor', () {
    final floored = overalls.where((o) => o <= 30).length / n;
    expect(floored, lessThanOrEqualTo(0.02), reason: 'floor share $floored');
  });

  test('80+ population stays within 2.0-3.5%', () {
    final elite = overalls.where((o) => o >= 80).length / n;
    expect(elite, inInclusiveRange(0.020, 0.035), reason: '80+ share $elite');
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
