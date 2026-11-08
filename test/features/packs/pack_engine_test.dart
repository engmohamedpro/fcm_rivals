import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';
import 'package:fcm_rivals/features/packs/pack_rarity.dart';

BasePlayer mkPlayer(
  int id,
  int marketValueEur, {
  int overall = 60,
  Position position = Position.st,
  String nationality = 'Egypt',
}) => BasePlayer(
  playerId: id,
  name: 'Player $id',
  position: position,
  nationality: nationality,
  marketValueEur: marketValueEur,
  baseStats: BaseStats(
    overall: overall,
    attack: overall + 2,
    support: overall,
    defence: overall - 2,
    goalkeeping: 0,
  ),
);

/// Pool spanning all four OVR rarity bands with known structure (T-0059
/// two-stage engine): a player's id always encodes the band he is drawn
/// from — 1xxx rare (OVR 60, cheap MVs), 2xxx epic (OVR 75), 3xxx
/// legendary (OVR 85), 4xxx premium (OVR 92).
List<BasePlayer> buildPool(int perBand) => [
  for (var i = 0; i < perBand; i++)
    mkPlayer(1000 + i, 50_000 + i * 5_000, overall: 60),
  for (var i = 0; i < perBand; i++)
    mkPlayer(2000 + i, 4_000_000 + i * 50_000, overall: 75),
  for (var i = 0; i < perBand; i++)
    mkPlayer(3000 + i, 40_000_000 + i * 2_000_000, overall: 85),
  for (var i = 0; i < perBand; i++)
    mkPlayer(4000 + i, 90_000_000 + i * 5_000_000, overall: 92),
];

/// A config whose every table is the given uniform distribution over the
/// four bands — for tests that need a specific stage-1 shape instead of
/// the shipped tables.
PackOddsConfig uniformConfig() {
  const w = (rare: 0.25, epic: 0.25, legendary: 0.25, premium: 0.25);
  return PackOddsConfig(rarePack: w, epicPack: w, legendaryPack: w);
}

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

    test('the single player comes from a rolled rarity band, all bands '
        'reachable under a uniform table', () {
      final engine = PackEngine(random: math.Random(11), oddsConfig: uniformConfig());
      final pool = buildPool(10);
      final counts = [0, 0, 0, 0];
      for (var i = 0; i < 800; i++) {
        final d = engine
            .open(const PackScope(category: PackCategory.global), pool)
            .single;
        counts[d.tier]++;
        final id = d.player.playerId;
        // pool ids encode their band: 1xxx rare, 2xxx epic, 3xxx
        // legendary, 4xxx premium
        expect(id ~/ 1000, d.tier + 1);
      }
      // uniform stage-1 table => each band roughly a quarter
      for (final c in counts) {
        expect(c, inInclusiveRange(150, 250));
      }
    });

    test('the odds config can bias the rarity roll', () {
      final config = uniformConfig();
      final allRare = PackOddsConfig(
        rarePack: (
          rare: 1.0,
          epic: 0.0,
          legendary: 0.0,
          premium: 0.0,
        ),
        epicPack: config.rarePack,
        legendaryPack: config.rarePack,
      );
      final engine = PackEngine(random: math.Random(4), oddsConfig: allRare);
      final pool = buildPool(10);
      for (var i = 0; i < 50; i++) {
        expect(
          engine
              .open(const PackScope(category: PackCategory.global), pool)
              .single
              .tier,
          PackRarity.rare.index,
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
        mkPlayer(5001, 5_000_000, overall: 75, nationality: 'Brazil'),
        mkPlayer(5002, 8_000_000, overall: 62, nationality: 'Brazil',
            position: Position.gk),
        mkPlayer(5003, 15_000_000, overall: 77, nationality: 'Egypt',
            position: Position.lw),
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

    test('GDD 5.5: pack pricing is positive and grows with pool wealth',
        () {
      final engine = PackEngine(random: math.Random(1));
      final cheapPool = [
        for (var i = 0; i < 30; i++)
          mkPlayer(100 + i, 100_000 + i * 10_000, overall: 60),
      ];
      final richPool = [
        for (var i = 0; i < 30; i++)
          mkPlayer(200 + i, 50_000_000 + i * 2_000_000, overall: 85),
      ];
      const scope = PackScope(category: PackCategory.global);
      final cheapPrice = engine.packPriceFor(scope, cheapPool);
      final richPrice = engine.packPriceFor(scope, richPool);
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

      // priciest legendary-band player must have LOWER probability than
      // the cheapest (weightFor: (poolMinMv / mv)^1.5)
      final bandOdds = odds[PackRarity.legendary.index]!;
      final cheapest = pool.firstWhere(
        (p) => p.baseStats.overall >= 80 && p.baseStats.overall < 90,
      );
      final priciest = pool.lastWhere(
        (p) => p.baseStats.overall >= 80 && p.baseStats.overall < 90,
      );
      expect(bandOdds[priciest.playerId]!,
          lessThan(bandOdds[cheapest.playerId]!));
      expect(bandOdds[priciest.playerId]!, greaterThan(0));

      // per-player probabilities include the rarity roll, so the whole
      // table sums to 1 (band shares × within-band shares)
      final total = odds.values
          .expand((band) => band.values)
          .fold<double>(0, (a, b) => a + b);
      expect(total, closeTo(1, 1e-9));
    });

    test('GDD 5.4: empirically, cheap players are drawn more often', () {
      // Within the rare band, the cheapest third should win the band's
      // draws clearly above its uniform share (weightFor exponent 1.5).
      final engine = PackEngine(random: math.Random(31));
      final pool = buildPool(30);
      final cheapIds = pool
          .where((p) => p.baseStats.overall < 70)
          .toList()
        ..sort((a, b) => a.marketValueEur.compareTo(b.marketValueEur));
      final cheapestThird = cheapIds.take(10).map((p) => p.playerId).toSet();
      var rareBandDraws = 0;
      var cheapHits = 0;
      for (var i = 0; i < 900; i++) {
        final result = engine
            .open(const PackScope(category: PackCategory.global), pool)
            .single;
        if (result.tier != PackRarity.rare.index) continue;
        rareBandDraws++;
        if (cheapestThird.contains(result.player.playerId)) cheapHits++;
      }
      expect(rareBandDraws, greaterThan(200));
      // cheap third wins clearly more than its uniform 1/3 share
      expect(cheapHits, greaterThan(rareBandDraws * 0.40));
    });

    test('FR-011: odds respond to value — zero exponent is uniform', () {
      final engine = PackEngine(
        random: math.Random(9),
        oddsConfig: const PackOddsConfig(marketValueExponent: 0.0),
      );
      final pool = buildPool(20);
      final flat = engine.oddsFor(
        const PackScope(category: PackCategory.global),
        pool,
      );
      // exponent 0 => uniform within band
      final bandFlat = flat[PackRarity.legendary.index]!;
      expect(bandFlat.values.toSet().length, 1);
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
        [mkPlayer(1, 300_000, overall: 62), mkPlayer(2, 900_000, overall: 66)],
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

    test('legendary packs draw the gold band far more often than rare', () {
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
      var rareGold = 0, legendaryGold = 0;
      const runs = 600;
      for (var i = 0; i < runs; i++) {
        final rareTier = rare.open(rareScope, pool).single.tier;
        if (rareTier == PackRarity.legendary.index ||
            rareTier == PackRarity.premium.index) {
          rareGold++;
        }
        final legendaryTier = legendary.open(legendaryScope, pool).single.tier;
        if (legendaryTier == PackRarity.legendary.index ||
            legendaryTier == PackRarity.premium.index) {
          legendaryGold++;
        }
      }
      // rare table [75, 20, 5, 0]: gold band (legendary + premium) is
      // only the 5% legendary roll — never premium. legendary table
      // [0, 55, 43, 2]: gold dominates.
      expect(rareGold, lessThan(runs * 0.10));
      expect(legendaryGold, greaterThan(runs * 0.40));
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
              overall: p.baseStats.overall,
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

    test('the scope tier picks the odds table over the engine default',
        () {
      // The engine's default tier is rare (75/20/5/0), but the scope's
      // legendary tier drives its own table (0/55/43/2) — the gold band
      // dominates despite the engine default.
      final engine = PackEngine(random: math.Random(8));
      const scope = PackScope(
        category: PackCategory.global,
        tier: PackTier.legendary,
      );
      var epicOrBetter = 0;
      for (var i = 0; i < 100; i++) {
        if (engine.open(scope, pool).single.tier !=
            PackRarity.rare.index) {
          epicOrBetter++;
        }
      }
      expect(epicOrBetter, greaterThan(90));
    });
  });
}
