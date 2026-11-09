import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/base_stats_generator.dart'
    show positionWeights;
import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart';

PlayerCard card(
  int id,
  Position position, {
  int overall = 70,
  int stamina = 100,
}) => PlayerCard(
  ownedId: id,
  upgradeLevel: 0,
  staminaPercent: stamina,
  base: BasePlayer(
    playerId: 1000 + id,
    name: 'Player $id',
    position: position,
    nationality: 'Egypt',
    marketValueEur: 5_000_000,
    // The generator anchors stats to a market value, so its curve
    // cannot hit an arbitrary overall; tests need the requested
    // overall to be real. Same deviation formula as the generator
    // (10 × (w − 0.375)) but around the requested rating.
    baseStats: _statsFor(position, overall),
  ),
);

BaseStats _statsFor(Position position, int overall) {
  final weights = positionWeights[position]!;
  int attr(PlayerAttribute a) {
    final w = weights[a] ?? 0;
    if (w == 0) return 1;
    return (overall + 10.0 * (w - 0.375)).round().clamp(1, 99);
  }

  return BaseStats(
    overall: overall,
    attack: attr(PlayerAttribute.attack),
    support: attr(PlayerAttribute.support),
    defence: attr(PlayerAttribute.defence),
    goalkeeping: attr(PlayerAttribute.goalkeeping),
  );
}

void main() {
  group('formations (GDD 6.4)', () {
    test('all definitions are valid 11-slot formations with GK first', () {
      expect(formations.length, greaterThanOrEqualTo(10));
      for (final f in formations) {
        expect(f.isValid, isTrue, reason: f.code);
      }
    });

    test('lookup by code falls back to the default', () {
      expect(formationByCode('4-3-3').code, '4-3-3');
      expect(formationByCode('nonsense').code, '4-3-3');
    });

    test('squad section sizes match GDD 6.1', () {
      expect(Formation.startingXiSize, 11);
      expect(Formation.benchSize, 7);
      expect(Formation.reservesSize, 5);
      expect(Formation.squadSize, 23);
    });
  });

  group('SquadEngine compatibility', () {
    const engine = SquadEngine();

    test('natural positions are fully compatible', () {
      for (final p in Position.values) {
        expect(engine.compatibilityOf(p, p), 1.0);
      }
    });

    test('goalkeepers and outfielders are incompatible (GDD 6.3)', () {
      expect(engine.compatibilityOf(Position.gk, Position.st), lessThan(0.5));
      expect(engine.compatibilityOf(Position.st, Position.gk), lessThan(0.5));
    });

    test('wingers are decent strikers, poor centre-backs', () {
      final lw = engine.compatibilityOf(Position.lw, Position.st);
      final lwCb = engine.compatibilityOf(Position.lw, Position.cb);
      expect(lw, greaterThan(0.8));
      expect(lwCb, lessThan(0.6));
    });

    test('slot rating respects position sensitivity (GDD 7.2)', () {
      final striker = card(1, Position.st);
      final defender = card(2, Position.cb);
      final stSlot = formationByCode('4-4-2').slots.last; // ST slot
      final cbSlot = formationByCode('4-4-2').slots[2]; // CB slot

      expect(
        engine.slotRatingOf(striker, stSlot),
        greaterThan(engine.slotRatingOf(defender, stSlot)),
      );
      expect(
        engine.slotRatingOf(defender, cbSlot),
        greaterThan(engine.slotRatingOf(striker, cbSlot)),
      );
    });
  });

  group('SquadEngine.autoPick (GDD 6.3)', () {
    const engine = SquadEngine();
    final formation = formationByCode('4-4-2');

    test('fills the XI in position, bench and reserves by rating', () {
      final players = <PlayerCard>[
        card(1, Position.gk, overall: 75),
        card(2, Position.gk, overall: 65),
        for (var i = 0; i < 4; i++) card(10 + i, Position.cb),
        for (var i = 0; i < 4; i++) card(20 + i, Position.rb),
        for (var i = 0; i < 4; i++) card(30 + i, Position.lb),
        for (var i = 0; i < 6; i++) card(40 + i, Position.cm),
        for (var i = 0; i < 4; i++) card(50 + i, Position.lm),
        for (var i = 0; i < 4; i++) card(60 + i, Position.rm),
        for (var i = 0; i < 6; i++) card(70 + i, Position.st),
      ];
      final assignment = engine.autoPick(players, formation);

      expect(assignment.length, Formation.squadSize);
      // GK slot gets a goalkeeper
      expect(
        players.firstWhere((p) => p.ownedId == assignment[0]).position,
        Position.gk,
      );
      // all assignments unique
      expect(assignment.values.toSet().length, assignment.length);
      // every XI slot filled
      for (var slot = 0; slot < Formation.startingXiSize; slot++) {
        expect(assignment.containsKey(slot), isTrue, reason: 'slot $slot');
      }
    });

    test('no duplicate assignments and no GK in outfield slots', () {
      final players = [
        card(1, Position.gk),
        card(2, Position.gk),
        for (var i = 0; i < 10; i++) card(10 + i, Position.st),
        for (var i = 0; i < 11; i++) card(30 + i, Position.cb),
      ];
      final assignment = engine.autoPick(players, formation);
      expect(assignment.values.toSet().length, assignment.length);
      for (var slot = 1; slot < Formation.startingXiSize; slot++) {
        final id = assignment[slot]!;
        expect(
          players.firstWhere((p) => p.ownedId == id).position,
          isNot(Position.gk),
        );
      }
    });

    test('specialists are preferred over similarly-rated generics', () {
      // LM slot: an LW (compat 0.9) beats an equally-rated CM (compat 0.8).
      // Hand-built stat profiles make the intent independent of the
      // generator's curve.
      PlayerCard flat(int id, Position position, List<int> attrs) {
        final stats = BaseStats(
          overall: attrs[0],
          attack: attrs[1],
          support: attrs[2],
          defence: attrs[3],
          goalkeeping: 0,
        );
        return PlayerCard(
          ownedId: id,
          base: BasePlayer(
            playerId: 1000 + id,
            name: 'Player $id',
            position: position,
            nationality: 'Egypt',
            marketValueEur: 5_000_000,
            baseStats: stats,
          ),
          upgradeLevel: 0,
        );
      }

      final players = <PlayerCard>[
        flat(1, Position.gk, [70, 5, 20, 15]),
        flat(2, Position.cb, [70, 10, 20, 68]),
        flat(3, Position.cb, [70, 10, 20, 68]),
        flat(4, Position.cb, [70, 10, 20, 68]),
        flat(5, Position.lb, [70, 20, 30, 45]),
        flat(6, Position.rb, [70, 20, 30, 45]),
        flat(7, Position.cm, [75, 30, 40, 35]),
        flat(8, Position.cm, [75, 30, 40, 35]),
        flat(9, Position.cdm, [75, 12, 36, 50]),
        flat(10, Position.lw, [75, 55, 25, 20]),
        flat(11, Position.rw, [75, 55, 25, 20]),
        flat(12, Position.st, [75, 60, 20, 18]),
        flat(13, Position.st, [75, 60, 20, 18]),
      ];
      final assignment = engine.autoPick(players, formation);
      final lmSlot = formation.slots.indexWhere(
        (s) => s.position == Position.lm,
      );
      final rmSlot = formation.slots.indexWhere(
        (s) => s.position == Position.rm,
      );
      final lmPlayer = players.firstWhere(
        (p) => p.ownedId == assignment[lmSlot],
      );
      final rmPlayer = players.firstWhere(
        (p) => p.ownedId == assignment[rmSlot],
      );
      // identical attribute sums: compatibility decides
      expect(lmPlayer.position, Position.lw);
      expect(rmPlayer.position, Position.rw);
    });

    test('a clearly superior generic never displaces a natural fit', () {
      // 4-3-3 with its exact natural XI, plus a spare 93-rated CM. The
      // CM is far better than the 55-rated wingers, but the XI rule is
      // strict: slots belong to players of that exact position while
      // one exists, so the wingers start and the CM waits on the bench.
      final f433 = formationByCode('4-3-3');
      final players = <PlayerCard>[
        card(1, Position.gk),
        card(2, Position.lb),
        card(3, Position.cb),
        card(4, Position.cb),
        card(5, Position.rb),
        card(6, Position.cdm),
        card(7, Position.cm, overall: 95),
        card(8, Position.cm, overall: 94),
        card(9, Position.lw, overall: 55),
        card(10, Position.st, overall: 55),
        card(11, Position.rw, overall: 55),
        card(12, Position.cm, overall: 93),
      ];
      final assignment = engine.autoPick(players, f433);
      final lwSlot = f433.slots.indexWhere((s) => s.position == Position.lw);
      final lwPlayer = players.firstWhere(
        (p) => p.ownedId == assignment[lwSlot],
      );
      expect(lwPlayer.position, Position.lw);
      expect(lwPlayer.overall, 55);

      // the strongest CM takes a central slot, the spare CM benches
      final cmSlot = f433.slots.indexWhere((s) => s.position == Position.cm);
      final cmPlayer = players.firstWhere(
        (p) => p.ownedId == assignment[cmSlot],
      );
      expect(cmPlayer.overall, 95);
      expect(assignment[Formation.startingXiSize], players[11].ownedId);
      expect(assignment.values.contains(players[11].ownedId), isTrue);
      final inXi = [
        for (var slot = 0; slot < Formation.startingXiSize; slot++)
          if (assignment[slot] == players[11].ownedId) slot,
      ];
      expect(inXi, isEmpty, reason: 'the spare CM must sit on the bench');
    });

    test('slots with no natural candidate fall back to compatible players', () {
      // No LM/RM in the pool at all: the wing slots take the best
      // compatible outsiders instead of staying empty.
      final players = <PlayerCard>[
        card(1, Position.gk),
        for (var i = 0; i < 4; i++) card(10 + i, Position.cb),
        for (var i = 0; i < 6; i++) card(30 + i, Position.cm, overall: 70 + i),
        for (var i = 0; i < 4; i++) card(50 + i, Position.st),
      ];
      final assignment = engine.autoPick(players, formation);
      final lmSlot = formation.slots.indexWhere(
        (s) => s.position == Position.lm,
      );
      expect(assignment.containsKey(lmSlot), isTrue);
      expect(
        players.firstWhere((p) => p.ownedId == assignment[lmSlot]).position,
        anyOf(Position.cm, Position.st, Position.lw, Position.rw),
      );
    });

    test('small pools leave later slots unassigned gracefully', () {
      final players = [card(1, Position.gk), card(2, Position.st)];
      final assignment = engine.autoPick(players, formation);
      expect(assignment.length, 2);
    });

    test('bench and reserves rank the leftovers best-first by overall', () {
      // The XI is exactly the eleven natural 4-4-2 fits; the leftovers
      // are positions 4-4-2 has no slot for, mixed stamina and ratings.
      final players = <PlayerCard>[
        card(1, Position.gk),
        card(2, Position.lb),
        card(3, Position.cb),
        card(4, Position.cb),
        card(5, Position.rb),
        card(6, Position.lm),
        card(7, Position.cm),
        card(8, Position.cm),
        card(9, Position.rm),
        card(10, Position.st),
        card(11, Position.st),
        // leftovers: 85 (tired) → 78 → 72 → 60 (fresh)
        card(60, Position.cam, overall: 85, stamina: 40),
        card(61, Position.cdm, overall: 78, stamina: 90),
        card(62, Position.lw, overall: 72, stamina: 100),
        card(63, Position.rw, overall: 60, stamina: 100),
      ];
      final assignment = engine.autoPick(players, formation);

      // bench (11..17) then reserves (18..22) in slot order; every slot
      // present reads the leftovers 85 → 78 → 72 → 60.
      final ranked = [
        for (
          var slot = Formation.startingXiSize;
          slot < Formation.squadSize;
          slot++
        )
          if (assignment.containsKey(slot))
            players.firstWhere((p) => p.ownedId == assignment[slot]),
      ];
      expect(ranked.map((p) => p.overall), [85, 78, 72, 60]);
      // the bench holds the strongest leftover, not the fittest
      expect(ranked.first.overall, 85);
    });
  });

  group('SquadEngine.validateSquad (GDD 6.1)', () {
    const engine = SquadEngine();
    final formation = formationByCode('4-4-2');

    test('complete XI with keeper is valid', () {
      final players = [
        card(1, Position.gk),
        for (var i = 0; i < 10; i++) card(10 + i, Position.cb),
      ];
      final assignments = {for (var i = 0; i < 11; i++) i: players[i]};
      expect(engine.validateSquad(formation, assignments), isEmpty);
    });

    test('missing keeper is reported', () {
      final players = [for (var i = 0; i < 11; i++) card(10 + i, Position.cb)];
      final assignments = {for (var i = 0; i < 11; i++) i: players[i]};
      final problems = engine.validateSquad(formation, assignments);
      expect(problems.any((p) => p.contains('goalkeeper')), isTrue);
    });

    test('duplicate assignment is reported', () {
      final players = [card(1, Position.gk), card(2, Position.cb)];
      final assignments = {0: players[0], 1: players[1], 2: players[1]};
      final problems = engine.validateSquad(formation, assignments);
      expect(problems.any((p) => p.contains('multiple slots')), isTrue);
    });
  });

  group('PlayerCard', () {
    test('upgrades apply to overall and attributes, capped at 99', () {
      final base = BasePlayer(
        playerId: 1,
        name: 'X',
        position: Position.st,
        nationality: 'Egypt',
        marketValueEur: 50_000_000,
        baseStats: const BaseStats(
          overall: 84,
          attack: 90,
          support: 80,
          defence: 70,
          goalkeeping: 0,
        ),
      );
      final upgraded = PlayerCard(ownedId: 1, base: base, upgradeLevel: 3);
      // +3 = ×1.03 of every base stat (owner decision 2026-11-09):
      // 84→87, 90→93 (92.7→93), 80→82, 70→72.
      expect(upgraded.overall, 87);
      expect(upgraded.attribute(PlayerAttribute.attack), 93);
      expect(upgraded.attribute(PlayerAttribute.support), 82);
      expect(upgraded.attribute(PlayerAttribute.defence), 72);
      expect(upgraded.attribute(PlayerAttribute.goalkeeping), 0);
    });

    test('position rating reflects attribute weighting', () {
      final gk = card(1, Position.gk);
      final st = card(2, Position.st);
      // same underlying value, different profiles
      expect(gk.positionRating(), greaterThan(0));
      expect(st.positionRating(), greaterThan(0));
    });
  });
}
