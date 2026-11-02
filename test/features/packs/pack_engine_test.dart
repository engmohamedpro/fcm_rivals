import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart';

BasePlayer mkPlayer(
  int id,
  int marketValueEur, {
  Position position = Position.st,
  String nationality = 'Egypt',
  String club = 'Al Ahly',
  String leagueCode = 'EG1',
}) =>
    BasePlayer(
      playerId: id,
      name: 'Player $id',
      position: position,
      age: 25,
      nationality: nationality,
      club: club,
      leagueCode: leagueCode,
      marketValueEur: marketValueEur,
      baseStats: const BaseStats(
          overall: 50, attack: 55, support: 50, defence: 45, goalkeeping: 0),
    );

/// Pool spanning three decades of market value with known structure.
List<BasePlayer> buildPool(int perDecade) => [
      for (var i = 0; i < perDecade; i++)
        mkPlayer(1000 + i, 50_000 + i * 5_000), // low tier
      for (var i = 0; i < perDecade; i++)
        mkPlayer(2000 + i, 2_000_000 + i * 100_000), // mid tier
      for (var i = 0; i < perDecade; i++)
        mkPlayer(3000 + i, 40_000_000 + i * 2_000_000), // high tier
    ];

void main() {
  group('PackEngine.open', () {
    test('every pack contains exactly one player', () {
      final engine = PackEngine(random: math.Random(7));
      for (var i = 0; i < 50; i++) {
        final draws = engine.open(
            const PackScope(category: PackCategory.global), buildPool(10));
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
          random: math.Random(4), tierWeights: const [1, 0, 0]);
      final pool = buildPool(10);
      for (var i = 0; i < 50; i++) {
        expect(
            engine
                .open(const PackScope(category: PackCategory.global), pool)
                .single
                .tier,
            0);
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

    test('scope filters: nationality, league, club, position', () {
      final engine = PackEngine(random: math.Random(3));
      final pool = [
        ...buildPool(4),
        mkPlayer(5001, 5_000_000, nationality: 'Brazil', club: 'Flamengo', leagueCode: 'BR1', position: Position.gk),
        mkPlayer(5002, 8_000_000, nationality: 'Brazil', club: 'Santos', leagueCode: 'BR1', position: Position.cb),
        mkPlayer(5003, 15_000_000, nationality: 'Egypt', club: 'Al Ahly', leagueCode: 'EG1', position: Position.lw),
      ];

      final nationality = engine
          .open(const PackScope(category: PackCategory.nationality, nationality: 'Brazil'), pool)
          .map((d) => d.player.nationality)
          .toSet();
      expect(nationality, {'Brazil'});

      final league = engine
          .open(const PackScope(category: PackCategory.league, leagueCode: 'BR1'), pool)
          .map((d) => d.player.leagueCode)
          .toSet();
      expect(league, {'BR1'});

      final club = engine
          .open(const PackScope(category: PackCategory.club, club: 'Flamengo'), pool);
      expect(club.length, 1); // pool of 1 -> degenerate but graceful
      expect(club.single.player.club, 'Flamengo');

      final position = engine
          .open(const PackScope(category: PackCategory.position, position: Position.gk), pool);
      expect(position, isNotEmpty);
      expect(position.every((d) => d.player.position == Position.gk), isTrue);
    });

    test('GDD 5.5: pack pricing is positive and grows with pool wealth', () {
      final cheapEngine = PackEngine(random: math.Random(1));
      final richEngine = PackEngine(random: math.Random(1));
      final cheapPool = [
        for (var i = 0; i < 30; i++)
          mkPlayer(100 + i, 100_000 + i * 10_000),
      ];
      final richPool = [
        for (var i = 0; i < 30; i++)
          mkPlayer(200 + i, 5_000_000 + i * 500_000),
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
      final odds = engine.oddsFor(const PackScope(category: PackCategory.global), pool);

      // priciest high-tier player must have LOWER probability than cheapest
      final highTierOdds = odds[2]!;
      final cheapestHigh = pool.firstWhere((p) => p.marketValueEur >= 40_000_000);
      final priciestHigh = pool.lastWhere((p) => p.marketValueEur >= 40_000_000);
      expect(highTierOdds[priciestHigh.playerId]!,
          lessThan(highTierOdds[cheapestHigh.playerId]!));
      expect(highTierOdds[priciestHigh.playerId]!, greaterThan(0));

      // each tier's probabilities sum to 1
      for (final t in [0, 1, 2]) {
        final sum = odds[t]!.values.fold<double>(0, (a, b) => a + b);
        expect(sum, closeTo(1, 1e-9));
      }
    });

    test('GDD 5.4: empirically, cheap players are drawn more often', () {
      // With inverse-value odds, the cheapest third of tier 0 should win the
      // tier-0 draw more than half the time.
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
      // cheap third should win the tier-0 draw well over half the time
      expect(lowHits, greaterThan(tier0Draws * 0.55));
    });

    test('FR-011: odds respond to value — zero smoothing is uniform', () {
      final engine = PackEngine(random: math.Random(9));
      final pool = buildPool(20);
      final flat = engine.oddsFor(
          const PackScope(category: PackCategory.global), pool,
          oddsSmoothing: 0.0);
      // smoothing 0 => uniform within tier
      final highFlat = flat[2]!;
      expect(highFlat.values.toSet().length, 1);
    });

    test('empty scope yields empty draws', () {
      final engine = PackEngine(random: math.Random(1));
      final draws = engine.open(
          const PackScope(category: PackCategory.nationality, nationality: 'Atlantis'),
          buildPool(5));
      expect(draws, isEmpty);
    });

    test('tiny pools degrade gracefully', () {
      final engine = PackEngine(random: math.Random(2));
      final draws = engine.open(
          const PackScope(category: PackCategory.club, club: 'Small FC'), [
        mkPlayer(1, 300_000, club: 'Small FC'),
        mkPlayer(2, 900_000, club: 'Small FC'),
      ]);
      expect(draws.length, 1);
    });
  });

  group('PackScope', () {
    test('scope matching semantics per category', () {
      const scope = PackScope(category: PackCategory.league, leagueCode: 'GB1');
      expect(scope.matches(mkPlayer(1, 1, leagueCode: 'GB1')), isTrue);
      expect(scope.matches(mkPlayer(2, 1, leagueCode: 'ES1')), isFalse);
      expect(const PackScope(category: PackCategory.global)
          .matches(mkPlayer(3, 1)), isTrue);
    });
  });
}
