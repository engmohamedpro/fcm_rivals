// Pack-odds regression test on the REAL dataset (review
// 2026-11-04_economy_pack-tier-bands-and-elite-ceiling; high band
// re-derived by T-0047).
//
// The relative log-scale tier bands made 'high tier' mean 'top of this
// pool', so a Legendary pack drawn from a €0.4–2.6M pool could never
// contain a star (0% ≥€20M; elite XI ≈ 140 seasons). The engine now uses
// absolute floors (low < €3M, high ≥ the curve's OVR-80 value — €25M
// under the shipped T-0046 curve, the owner's golden-legendary regrade):
// this test locks the odds over 20,000+ seeded openings on the real
// 20,876-player dataset so the elite game stays reachable and Rare stays
// honest. The floor is DERIVED, not hardcoded, so a future curve retune
// moves these bands with it.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';

Future<List<BasePlayer>> _loadDataset() async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final data = await binding.runAsync(() {
    return io.File('assets/data/players_v1.json').readAsString();
  });
  final decoded = jsonDecode(data!) as Map<String, dynamic>;
  final players = (decoded['players'] as List).cast<List<dynamic>>();
  final out = <BasePlayer>[];
  for (final p in players) {
    final pos = Position.values.firstWhere(
      (x) => x.code == (p[2] as String),
      orElse: () => Position.st,
    );
    out.add(
      BasePlayer(
        playerId: p[0] as int,
        name: p[1] as String,
        position: pos,
        nationality: p[3] as String,
        marketValueEur: p[4] as int,
        baseStats: const BaseStats(
          overall: 50,
          attack: 50,
          support: 50,
          defence: 50,
          goalkeeping: 0,
        ),
      ),
    );
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('absolute tier bands on the real dataset', () {
    late List<BasePlayer> dataset;

    // The high band starts where the curve yields OVR 80 (T-0047) — the
    // same derivation the engine's default floors use.
    final highFloor =
        PackEngine.absoluteTierFloorsEur()[1]; // €25M under the shipped curve

    setUpAll(() async {
      dataset = await _loadDataset();
    });

    test('dataset loads with the known elite structure', () {
      expect(dataset.length, greaterThan(20_000));
      // Dataset audit (T-0047): 493 players (2.36%) sit at or above the
      // OVR-80 boundary value.
      expect(dataset.where((p) => p.marketValueEur >= highFloor).length,
          greaterThan(450));
    });

    test(
      'Legendary: P(≥ OVR-80 value) ≥ 20% and P(≥€50M) ≥ 4% over 20,000 '
      'openings',
      () {
        final engine = PackEngine(random: math.Random(2026));
        const scope = PackScope(category: PackCategory.global);
        const n = 20_000;
        var geHigh = 0, ge50 = 0;
        var valueSum = 0;
        for (var i = 0; i < n; i++) {
          final d = engine.open(scope, dataset).single;
          final v = d.player.marketValueEur;
          if (v >= highFloor) geHigh++;
          if (v >= 50_000_000) ge50++;
          valueSum += v;
        }
        expect(geHigh / n, greaterThan(0.20));
        expect(ge50 / n, greaterThan(0.04));
        // Recorded for the review's tier-share table (Developer Notes).
        // E[MV] of a legendary pull ≈ €9–11M with the absolute bands.
        expect(valueSum / n, greaterThan(5_000_000));
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('Epic: 5–15% of pulls are ≥ the OVR-80 value', () {
      final engine = PackEngine(random: math.Random(2027));
      const scope = PackScope(category: PackCategory.global, tier: PackTier.epic);
      const n = 20_000;
      var geHigh = 0;
      for (var i = 0; i < n; i++) {
        final d = engine.open(scope, dataset).single;
        if (d.player.marketValueEur >= highFloor) geHigh++;
      }
      expect(geHigh / n, greaterThan(0.05));
      expect(geHigh / n, lessThan(0.15));
    });

    test('Rare: < 5% of pulls are ≥ the OVR-80 value', () {
      final engine = PackEngine(random: math.Random(2028));
      const scope = PackScope(category: PackCategory.global, tier: PackTier.rare);
      const n = 20_000;
      var geHigh = 0;
      for (var i = 0; i < n; i++) {
        final d = engine.open(scope, dataset).single;
        if (d.player.marketValueEur >= highFloor) geHigh++;
      }
      // Rare rolls weight 0.0 on the high tier, so this is structurally
      // 0 — the fallback only fires when a tier is EMPTY, never here.
      expect(geHigh / n, lessThan(0.05));
    });

    test('absolute bands classify the same player the same way everywhere',
        () {
      final engine = PackEngine(random: math.Random(1));
      // A high-floor star in a global pool and in a small pool around
      // him: 'high tier' both times — the old relative bands called a
      // €2.5M player 'high' inside a cheap pool.
      final global = engine.tiersOf(dataset);
      expect(global[2].every((p) => p.marketValueEur >= highFloor), isTrue);
      expect(global[0].every((p) => p.marketValueEur < 3_000_000), isTrue);
      final smallPool = dataset
          .where((p) => p.marketValueEur >= 1_000_000)
          .take(300)
          .toList();
      final tiers = engine.tiersOf(smallPool);
      expect(
        tiers[2].every((p) => p.marketValueEur >= highFloor),
        isTrue,
        reason: 'high tier must mean ≥ the OVR-80 value in every pool',
      );
    });
  });
}
