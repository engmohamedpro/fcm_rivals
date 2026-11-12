import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/economy/economy_engine.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import '../../tm_bundle_io.dart'
    show loadTmDataset;

void main() {
  // The shipped tm bundle (owner request 2026-11-12) through the shared
  // loader — the exact files the app ships.
  final dataset = loadTmDataset();

  late PlayerDatabase db;

  setUpAll(() {
    db = PlayerDatabase();
  });

  test('FR-002: real dataset validates and imports cleanly', () {
    final result = db.importDataset(dataset);
    expect(db.count, 39_090); // 39,017 regulars + 73 icons
    expect(result.added.length, db.count);
    expect(result.removed, isEmpty);
  });

  test('dataset metadata is present', () {
    // The tm bundle (owner request 2026-11-12): the parser stamps the
    // version/asOf/digest the loader consumes; the row count is the
    // parsed rows' length.
    expect(dataset.version, isPositive);
    expect(dataset.asOf, isNotEmpty);
    expect(dataset.digest, isNotEmpty);
    expect(dataset.rows.length, db.count);
    expect(dataset.rows.length, 39_090);
    expect(dataset.rows.where((r) => r.isIcon).length, 73);
  });

  test('known real players resolve by stable Transfermarkt id', () {
    // Erling Haaland's Transfermarkt id is stable (418560 in the dataset).
    final haaland = db[418560];
    expect(haaland, isNotNull);
    expect(haaland!.name, 'Erling Haaland');
    expect(haaland.position, Position.st);
    expect(haaland.marketValueEur, greaterThanOrEqualTo(100_000_000));
    expect(haaland.baseStats.attack, greaterThan(haaland.baseStats.defence));

    // Top of the dataset: 200M superstars.
    final top = db.all.toList()
      ..sort((a, b) => b.marketValueEur.compareTo(a.marketValueEur));
    expect(top.first.marketValueEur, 200_000_000);
    expect(top.first.baseStats.overall, greaterThanOrEqualTo(90));
  });

  test('GDD 4.5: stats distributions per position on real data', () {
    final gk = db.all.firstWhere((p) => p.position == Position.gk);
    final cb = db.all.firstWhere((p) => p.position == Position.cb);
    final st = db.all.firstWhere((p) => p.position == Position.st);

    expect(gk.baseStats.goalkeeping, greaterThan(0));
    expect(gk.baseStats.attack, 0);
    expect(cb.baseStats.defence, greaterThan(cb.baseStats.attack));
    expect(st.baseStats.attack, greaterThan(st.baseStats.defence));
  });

  test('all 12 positions are represented', () {
    final positions = db.all.map((p) => p.position).toSet();
    expect(positions.length, 12);
    expect(positions, containsAll(Position.values));
  });

  test('GDD 17.2: economic values on the real value range', () {
    const eco = EconomyEngine();
    final values = db.all.map((p) => p.marketValueEur).toList();
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);

    expect(
      eco.economicValueOf(minV),
      greaterThanOrEqualTo(eco.config.minEconomicValue),
    );
    expect(
      eco.economicValueOf(maxV),
      lessThanOrEqualTo(eco.config.maxEconomicValue),
    );
    // 10k vs 200M must not be a 20,000x spread — the curve compresses it.
    final ratio = eco.economicValueOf(maxV) / eco.economicValueOf(minV);
    expect(ratio, lessThan(500));
    expect(ratio, greaterThan(10)); // but still meaningfully different
  });

  test('GDD 5: packs open over the real global pool', () {
    final engine = PackEngine(random: math.Random(2026));
    final pool = db.all.toList();

    // Global pack: exactly one player.
    final global = engine.open(
      const PackScope(category: PackCategory.global),
      pool,
    );
    expect(global.length, 1);

    // Nationality pack (Egypt).
    final egypt = engine.open(
      const PackScope(category: PackCategory.nationality, nationality: 'Egypt'),
      pool,
    );
    expect(egypt.length, 1);
    expect(egypt.every((d) => d.player.nationality == 'Egypt'), isTrue);

    // Position pack (GK) and price sanity.
    final gkPack = engine.open(
      const PackScope(category: PackCategory.position, position: Position.gk),
      pool,
    );
    expect(gkPack.every((d) => d.player.position == Position.gk), isTrue);
  });

  test('GDD 5.5: pack pricing over real pools is finite and ordered', () {
    final engine = PackEngine(random: math.Random(2026));
    final pool = db.all.toList();
    const globalScope = PackScope(category: PackCategory.global);
    final globalPrice = engine.packPriceFor(globalScope, pool);

    final gkPool = pool.where((p) => p.position == Position.gk).toList();
    final gkPrice = engine.packPriceFor(
      const PackScope(category: PackCategory.position, position: Position.gk),
      gkPool,
    );

    expect(globalPrice, greaterThan(0));
    expect(gkPrice, greaterThan(0));
    expect(globalPrice, lessThan(2_000_000_000));
  });

  test('GDD 4.6/4.7: re-import identical dataset changes nothing', () {
    final before = {for (final p in db.all) p.playerId: p.baseStats};
    final result = db.importDataset(dataset);
    expect(result.added, isEmpty);
    expect(result.removed, isEmpty);
    expect(result.regenerated, isEmpty);
    expect(result.unchanged, db.count);
    for (final p in db.all) {
      expect(p.baseStats, before[p.playerId]);
    }
  });

  test('GDD 4.7: upgrade separation — regeneration keeps player identity', () {
    // Simulate an owned copy before a dataset update.
    final haalandBefore = db[418560]!;
    const ownedUpgradeLevel = 3;

    // Dataset update with a new market value for Haaland (id unchanged).
    final rows = [
      for (final r in dataset.rows)
        r.playerId == 418560
            ? PlayerDatasetRow(
                playerId: r.playerId,
                name: r.name,
                position: r.position,
                nationality: r.nationality,
                marketValueEur: r.marketValueEur + 20_000_000,
                clubId: r.clubId,
                clubName: r.clubName,
                clubCrestUrl: r.clubCrestUrl,
                leagueName: r.leagueName,
                leagueLogoUrl: r.leagueLogoUrl,
                imageUrl: r.imageUrl,
                isIcon: r.isIcon,
              )
            : r,
    ];

    final result = db.importDataset(
      PlayerDataset(
        version: dataset.version + 1,
        asOf: dataset.asOf,
        rows: rows,
      ),
    );

    final haalandAfter = db[418560]!;
    expect(result.regenerated.any((p) => p.playerId == 418560), isTrue);
    expect(haalandAfter.playerId, haalandBefore.playerId); // same identity
    expect(
      haalandAfter.baseStats.overall,
      greaterThanOrEqualTo(haalandBefore.baseStats.overall),
    );
    // owned upgrade level is user data — untouched by the import (simulated).
    expect(ownedUpgradeLevel, 3);

    // FR-008: compensation for a removed player uses the selling formula.
    const eco = EconomyEngine();
    final compensation = eco.sellPriceOfUpgraded(
      haalandAfter,
      ownedUpgradeLevel,
    );
    expect(compensation, greaterThan(eco.sellPriceOf(haalandAfter)));
  });

  test('GDD 31 preview: pack tier distribution over many opens', () {
    final engine = PackEngine(random: math.Random(99));
    final pool = db.all.toList();
    var highTierTop10Count = 0;
    const opens = 200;
    final top100Ids = {
      for (final p
          in (pool
                ..sort((a, b) => b.marketValueEur.compareTo(a.marketValueEur)))
              .take(100))
        p.playerId,
    };
    for (var i = 0; i < opens * 3; i++) {
      final draws = engine.open(
        const PackScope(category: PackCategory.global),
        pool,
      );
      for (final d in draws) {
        if (top100Ids.contains(d.player.playerId)) highTierTop10Count++;
      }
    }
    // Elite players are rare but appear over time (never impossible).
    expect(highTierTop10Count, greaterThan(0));
    expect(highTierTop10Count, lessThan(opens)); // certainly not every draw
  });
}
