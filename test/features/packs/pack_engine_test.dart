import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';

BasePlayer mkPlayer(
  int id,
  int marketValueEur, {
  Position position = Position.st,
  String nationality = 'Egypt',
}) => BasePlayer(
  playerId: id,
  name: 'Player $id',
  position: position,
  nationality: nationality,
  marketValueEur: marketValueEur,
  baseStats: const BaseStats(
    overall: 50,
    attack: 55,
    support: 50,
    defence: 45,
    goalkeeping: 0,
  ),
);

/// Pool spanning three market-value strata with known structure, aligned
/// with the engine's ABSOLUTE tier floors (low < €3M, mid €3–20M,
/// high ≥ €20M): a player's id always encodes the tier he is drawn from.
List<BasePlayer> buildPool(int perDecade) => [
  for (var i = 0; i < perDecade; i++)
    mkPlayer(1000 + i, 50_000 + i * 5_000), // low tier (< €3M)
  for (var i = 0; i < perDecade; i++)
    mkPlayer(2000 + i, 4_000_000 + i * 50_000), // mid tier (€3–20M)
  for (var i = 0; i < perDecade; i++)
    mkPlayer(3000 + i, 40_000_000 + i * 2_000_000), // high tier (≥ €20M)
];

void main() {
  group('PackEngine.open', () {
    test('every pack contains exactly one player', () {
      final engine = PackEngine(random: math.Random(7));
      for (var i = 0; i < 50; i++) {
        final draws = engine.open(
          const PackScope(category: PackCategory.global),
          buildPool(10),
        );
        expect(draws.length, 1);
      }
    });

    test('the single player comes from a rolled tier, all tiers reachable', () {
      final engine = PackEngine(random: math.Random(11));
      final pool = buildPool(10);
      final counts = [0, 0, 0];
      for (var i = 0; i < 600; i++) {
        final d = engine
            .open(const PackScope(category: PackCategory.global), pool)
            .single;
        counts[d.tier]++;
        final id = d.player.playerId;
        // pool ids encode their tier: 1xxx low, 2xxx mid, 3xxx high
        expect(id ~/ 1000, d.tier + 1);
      }
      // equal tier weights by default => each tier roughly a third
      for (final c in counts) {
        expect(c, inInclusiveRange(150, 250));
      }
    });

    test('tierWeights can bias the tier roll', () {
      final engine = PackEngine(
        random: math.Random(4),
        tierWeights: const [1, 0, 0],
      );
      final pool = buildPool(10);
      for (var i = 0; i < 50; i++) {
        expect(
          engine
              .open(const PackScope(category: PackCategory.global), pool)
              .single
              .tier,
          0,
        );
      }
    });

    test('deterministic with a seeded rng (replayability)', () {
      final pool = buildPool(10);
      final a = PackEngine(random: math.Random(42))
          .open(const PackScope(category: PackCategory.global), pool)
          .map((d) => d.player.playerId)
          .toList();
      final b = PackEngine(random: math.Random(42))
          .open(const PackScope(category: PackCategory.global), pool)
          .map((d) => d.player.playerId)
          .toList();
      expect(a, b);
    });

    test('scope filters: nationality, position', () {
      final engine = PackEngine(random: math.Random(3));
      final pool = [
        ...buildPool(4),
        mkPlayer(5001, 5_000_000, nationality: 'Brazil', position: Position.gk),
        mkPlayer(5002, 8_000_000, nationality: 'Brazil', position: Position.cb),
        mkPlayer(5003, 15_000_000, nationality: 'Egypt', position: Position.lw),
      ];

      final nationality = engine
          .open(
            const PackScope(
              category: PackCategory.nationality,
              nationality: 'Brazil',
            ),
            pool,
          )
          .map((d) => d.player.nationality)
          .toSet();
      expect(nationality, {'Brazil'});

      final position = engine.open(
        const PackScope(category: PackCategory.position, position: Position.gk),
        pool,
      );
      expect(position, isNotEmpty);
      expect(position.every((d) => d.player.position == Position.gk), isTrue);
    });

    test('GDD 5.5: pack pricing is positive and grows with pool wealth', () {
      final cheapEngine = PackEngine(random: math.Random(1));
      final richEngine = PackEngine(random: math.Random(1));
      final cheapPool = [
        for (var i = 0; i < 30; i++) mkPlayer(100 + i, 100_000 + i * 10_000),
      ];
      final richPool = [
        for (var i = 0; i < 30; i++) mkPlayer(200 + i, 5_000_000 + i * 500_000),
      ];
      const scope = PackScope(category: PackCategory.global);
      final cheapPrice = cheapEngine.packPriceFor(scope, cheapPool);
      final richPrice = richEngine.packPriceFor(scope, richPool);
      expect(cheapPrice, greaterThan(0));
      expect(richPrice, greaterThan(cheapPrice));
    });

    test('GDD 5.4: high-value players have lower odds but never zero', () {
      final engine = PackEngine(random: math.Random(5));
      final pool = buildPool(30);
      final odds = engine.oddsFor(
        const PackScope(category: PackCategory.global),
        pool,
      );

      // priciest high-tier player must have LOWER probability than cheapest
      final highTierOdds = odds[2]!;
      final cheapestHigh = pool.firstWhere(
        (p) => p.marketValueEur >= 40_000_000,
      );
      final priciestHigh = pool.lastWhere(
        (p) => p.marketValueEur >= 40_000_000,
      );
      expect(
        highTierOdds[priciestHigh.playerId]!,
        lessThan(highTierOdds[cheapestHigh.playerId]!),
      );
      expect(highTierOdds[priciestHigh.playerId]!, greaterThan(0));

      // per-player probabilities now include the tier roll, so the whole
      // table sums to 1 (tier shares × within-tier shares)
      final total = odds.values
          .expand((tier) => tier.values)
          .fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1, 1e-9));
    });

    test('GDD 5.4: empirically, cheap players are drawn more often', () {
      // With inverse-value odds inside a tier, the cheapest third of the
      // low tier should win the low-tier draw more often than its uniform
      // share — the wider absolute low band (< €3M) dilutes the edge, so
      // the bar is 'clearly above uniform' rather than 'over half'.
      final engine = PackEngine(random: math.Random(31));
      final pool = buildPool(30);
      final lowIds = pool.take(10).map((p) => p.playerId).toSet();
      var tier0Draws = 0;
      var lowHits = 0;
      for (var i = 0; i < 900; i++) {
        final result = engine
            .open(const PackScope(category: PackCategory.global), pool)
            .single;
        if (result.tier != 0) continue;
        tier0Draws++;
        if (lowIds.contains(result.player.playerId)) lowHits++;
      }
      expect(tier0Draws, greaterThan(200));
      // cheap third wins clearly more than its uniform 1/3 share
      expect(lowHits, greaterThan(tier0Draws * 0.40));
    });

    test('FR-011: odds respond to value — zero smoothing is uniform', () {
      final engine = PackEngine(random: math.Random(9));
      final pool = buildPool(20);
      final flat = engine.oddsFor(
        const PackScope(category: PackCategory.global),
        pool,
        oddsSmoothing: 0.0,
      );
      // smoothing 0 => uniform within tier
      final highFlat = flat[2]!;
      expect(highFlat.values.toSet().length, 1);
    });

    test('empty scope yields empty draws', () {
      final engine = PackEngine(random: math.Random(1));
      final draws = engine.open(
        const PackScope(
          category: PackCategory.nationality,
          nationality: 'Atlantis',
        ),
        buildPool(5),
      );
      expect(draws, isEmpty);
    });

    test('tiny pools degrade gracefully', () {
      final engine = PackEngine(random: math.Random(2));
      final draws = engine.open(
        const PackScope(
          category: PackCategory.nationality,
          nationality: 'Egypt',
        ),
        [mkPlayer(1, 300_000), mkPlayer(2, 900_000)],
      );
      expect(draws.length, 1);
    });
  });

  group('PackScope', () {
    test('scope matching semantics per category', () {
      const scope = PackScope(
        category: PackCategory.nationality,
        nationality: 'Egypt',
      );
      expect(scope.matches(mkPlayer(1, 1)), isTrue);
      expect(scope.matches(mkPlayer(2, 1, nationality: 'Brazil')), isFalse);
      expect(
        const PackScope(category: PackCategory.global).matches(mkPlayer(3, 1)),
        isTrue,
      );
    });
  });

  group('PackTier (GDD 5.5 variety)', () {
    final pool = buildPool(30);

    test('legendary packs draw the high tier far more often than rare', () {
      final rare = PackEngine(random: math.Random(3));
      final legendary = PackEngine(random: math.Random(3));
      const rareScope = PackScope(
        category: PackCategory.global,
        tier: PackTier.rare,
      );
      const legendaryScope = PackScope(
        category: PackCategory.global,
        tier: PackTier.legendary,
      );
      var rareHigh = 0, legendaryHigh = 0;
      const runs = 600;
      for (var i = 0; i < runs; i++) {
        if (rare.open(rareScope, pool).single.tier == 2) rareHigh++;
        if (legendary.open(legendaryScope, pool).single.tier == 2) {
          legendaryHigh++;
        }
      }
      // bronze weights [1, .12, 0]: the high tier is only reachable via
      // fallback when the rolled low/mid tier is somehow empty — never
      // here. gold weights [.05, .45, 1]: high dominates.
      expect(rareHigh, 0);
      expect(legendaryHigh, greaterThan(runs * 0.6));
    });

    test('legendary packs cost more than epic, epic more than rare', () {
      final engine = PackEngine(random: math.Random(1));
      int priceOf(PackTier tier) => engine.packPriceFor(
        PackScope(category: PackCategory.global, tier: tier),
        pool,
      );
      final rare = priceOf(PackTier.rare);
      final epic = priceOf(PackTier.epic);
      final legendary = priceOf(PackTier.legendary);
      expect(rare, greaterThan(0));
      expect(epic, greaterThan(rare));
      expect(legendary, greaterThan(epic));
    });

    test('tier pricing holds per position scope too', () {
      final engine = PackEngine(random: math.Random(1));
      // Mixed-position pool so every position scope has candidates.
      final mixed = [
        for (final position in Position.values)
          ...buildPool(3).map(
            (p) => mkPlayer(
              p.playerId * 100 + position.index,
              p.marketValueEur,
              position: position,
            ),
          ),
      ];
      for (final position in [Position.st, Position.gk, Position.cb]) {
        int priceOf(PackTier tier) => engine.packPriceFor(
          PackScope(
            category: PackCategory.position,
            position: position,
            tier: tier,
          ),
          mixed,
        );
        expect(priceOf(PackTier.rare), greaterThan(0));
        expect(priceOf(PackTier.epic), greaterThan(priceOf(PackTier.rare)));
        expect(
          priceOf(PackTier.legendary),
          greaterThan(priceOf(PackTier.epic)),
        );
      }
    });

    test('fromName round-trips and falls back to bronze', () {
      for (final tier in PackTier.values) {
        expect(PackTier.fromName(tier.name), tier);
      }
      expect(PackTier.fromName(null), PackTier.rare);
      expect(PackTier.fromName('platinum'), PackTier.rare);
    });

    test('scope tier overrides the engine tierWeights', () {
      // Engine biased entirely to low, but the scope's gold weights win.
      final engine = PackEngine(
        random: math.Random(8),
        tierWeights: const [1, 0, 0],
      );
      const scope = PackScope(
        category: PackCategory.global,
        tier: PackTier.legendary,
      );
      var high = 0;
      for (var i = 0; i < 100; i++) {
        if (engine.open(scope, pool).single.tier == 2) high++;
      }
      expect(high, greaterThan(60));
    });
  });
}
