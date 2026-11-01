/// FCM Rivals — Squad Engine (GDD 6, FR-017..FR-020).
///
/// Pure Dart, storage- and UI-independent (SRS 21.1): operates on
/// [PlayerCard] values. Implements position compatibility, position-sensitive
/// slot ratings (GDD 7.2) and Auto Pick selection (GDD 6.3).
library;

import 'dart:math' as math;

import '../../core/domain/base_stats_generator.dart' show positionWeights;
import '../../core/domain/players.dart';
import 'formations.dart';

/// A user-owned player as seen by squad logic: base data plus upgrade state
/// (SRS 25.1 separation — upgrades never touch the base record).
class PlayerCard {
  const PlayerCard({
    required this.ownedId,
    required this.base,
    required this.upgradeLevel,
    this.upgradedAttack = 0,
    this.upgradedSupport = 0,
    this.upgradedDefence = 0,
    this.upgradedGoalkeeping = 0,
    this.staminaPercent = 100,
  });

  final int ownedId;
  final BasePlayer base;
  final int upgradeLevel;

  final int upgradedAttack;
  final int upgradedSupport;
  final int upgradedDefence;
  final int upgradedGoalkeeping;

  final int staminaPercent;

  Position get position => base.position;

  /// Upgraded overall: base overall + 1 per upgrade level (GDD 8.2), capped.
  int get overall => math.min(99, base.baseStats.overall + upgradeLevel);

  /// Upgraded attribute value, capped at 99.
  int attribute(PlayerAttribute a) => math
      .min(99, base.baseStats.valueOf(a) + _upgradeValueOf(a));

  int _upgradeValueOf(PlayerAttribute a) {
    switch (a) {
      case PlayerAttribute.attack:
        return upgradedAttack;
      case PlayerAttribute.support:
        return upgradedSupport;
      case PlayerAttribute.defence:
        return upgradedDefence;
      case PlayerAttribute.goalkeeping:
        return upgradedGoalkeeping;
    }
  }

  /// Position rating: weighted attributes by the player's own position
  /// (GDD 7.2) — independent of the Match Engine.
  int positionRating() {
    final weights = positionWeights[position]!;
    var total = 0.0;
    for (final e in weights.entries) {
      total += attribute(e.key) * e.value;
    }
    return total.round();
  }
}

/// Position compatibility factors: rows = player's position, columns = slot
/// position. 1.0 = natural, lower = penalty; goalkeepers are incompatible
/// with outfield slots and vice versa (GDD 6.3 "position compatibility").
const Map<Position, Map<Position, double>> _compatibility = {
  Position.gk: {
    Position.gk: 1.0,
    Position.st: 0.05, Position.lw: 0.05, Position.rw: 0.05,
    Position.cam: 0.05, Position.lm: 0.05, Position.rm: 0.05,
    Position.cm: 0.05, Position.cdm: 0.05, Position.cb: 0.05,
    Position.rb: 0.05, Position.lb: 0.05,
  },
  Position.st: {
    Position.st: 1.0,
    Position.lw: 0.9, Position.rw: 0.9, Position.cam: 0.88,
    Position.lm: 0.7, Position.rm: 0.7, Position.cm: 0.68,
    Position.cdm: 0.55, Position.cb: 0.5, Position.rb: 0.5, Position.lb: 0.5,
    Position.gk: 0.05,
  },
  Position.lw: {
    Position.lw: 1.0,
    Position.rw: 0.9, Position.st: 0.88, Position.lm: 0.88,
    Position.cam: 0.82, Position.rm: 0.72, Position.cm: 0.7,
    Position.lb: 0.68, Position.cdm: 0.58, Position.rb: 0.52,
    Position.cb: 0.5, Position.gk: 0.05,
  },
  Position.rw: {
    Position.rw: 1.0,
    Position.lw: 0.9, Position.st: 0.88, Position.rm: 0.88,
    Position.cam: 0.82, Position.lm: 0.72, Position.cm: 0.7,
    Position.rb: 0.68, Position.cdm: 0.58, Position.lb: 0.52,
    Position.cb: 0.5, Position.gk: 0.05,
  },
  Position.cam: {
    Position.cam: 1.0,
    Position.cm: 0.9, Position.st: 0.86, Position.lw: 0.8, Position.rw: 0.8,
    Position.lm: 0.8, Position.rm: 0.8, Position.cdm: 0.7,
    Position.cb: 0.5, Position.rb: 0.5, Position.lb: 0.5,
    Position.gk: 0.05,
  },
  Position.lm: {
    Position.lm: 1.0,
    Position.lw: 0.9, Position.rm: 0.85, Position.cm: 0.82,
    Position.cam: 0.76, Position.lb: 0.74, Position.rw: 0.7,
    Position.cdm: 0.62, Position.rb: 0.55, Position.st: 0.62,
    Position.cb: 0.5, Position.gk: 0.05,
  },
  Position.rm: {
    Position.rm: 1.0,
    Position.rw: 0.9, Position.lm: 0.85, Position.cm: 0.82,
    Position.cam: 0.76, Position.rb: 0.74, Position.lw: 0.7,
    Position.cdm: 0.62, Position.lb: 0.55, Position.st: 0.62,
    Position.cb: 0.5, Position.gk: 0.05,
  },
  Position.cm: {
    Position.cm: 1.0,
    Position.cdm: 0.9, Position.cam: 0.86, Position.lm: 0.8, Position.rm: 0.8,
    Position.st: 0.6, Position.lw: 0.6, Position.rw: 0.6,
    Position.cb: 0.58, Position.rb: 0.58, Position.lb: 0.58,
    Position.gk: 0.05,
  },
  Position.cdm: {
    Position.cdm: 1.0,
    Position.cm: 0.9, Position.cb: 0.76, Position.rb: 0.62, Position.lb: 0.62,
    Position.lm: 0.68, Position.rm: 0.68, Position.cam: 0.64,
    Position.st: 0.5, Position.lw: 0.5, Position.rw: 0.5,
    Position.gk: 0.05,
  },
  Position.cb: {
    Position.cb: 1.0,
    Position.rb: 0.72, Position.lb: 0.72, Position.cdm: 0.7,
    Position.cm: 0.55, Position.rm: 0.45, Position.lm: 0.45,
    Position.st: 0.4, Position.lw: 0.4, Position.rw: 0.4,
    Position.cam: 0.4, Position.gk: 0.05,
  },
  Position.rb: {
    Position.rb: 1.0,
    Position.lb: 0.72, Position.cb: 0.7, Position.rm: 0.74,
    Position.rw: 0.7, Position.cdm: 0.6, Position.cm: 0.6,
    Position.lm: 0.45, Position.lw: 0.45, Position.st: 0.4,
    Position.cam: 0.4, Position.gk: 0.05,
  },
  Position.lb: {
    Position.lb: 1.0,
    Position.rb: 0.72, Position.cb: 0.7, Position.lm: 0.74,
    Position.lw: 0.7, Position.cdm: 0.6, Position.cm: 0.6,
    Position.rm: 0.45, Position.rw: 0.45, Position.st: 0.4,
    Position.cam: 0.4, Position.gk: 0.05,
  },
};

/// Squad selection and rating logic.
class SquadEngine {
  const SquadEngine();

  /// Compatibility factor of playing [player] in [slot] (0..1).
  double compatibilityOf(Position player, Position slot) =>
      _compatibility[player]![slot]!;

  /// Position-sensitive slot rating (GDD 7.2): the player's attributes
  /// weighted by the SLOT's position weights, scaled by compatibility.
  /// Returns 0 for effectively incompatible placements.
  double slotRatingOf(PlayerCard player, FormationSlot slot) {
    final factor = compatibilityOf(player.position, slot.position);
    if (factor <= 0.1) return 0;
    final weights = positionWeights[slot.position]!;
    var total = 0.0;
    for (final e in weights.entries) {
      total += player.attribute(e.key) * e.value;
    }
    // Goalkeepers are rated on their goalkeeping attribute in the GK slot.
    return total * factor;
  }

  /// Rating used to rank bench/reserves candidates: the player's own
  /// position rating, scaled by remaining stamina (GDD 6.3 sorting).
  double benchRatingOf(PlayerCard player) =>
      player.positionRating() * (player.staminaPercent / 100);

  /// Auto Pick (GDD 6.3): fills starting XI, then bench, then reserves.
  ///
  /// Rules: position compatibility, highest suitable rating first, no
  /// duplicate assignments, and no incompatible positions while a suitable
  /// alternative exists (slots are processed rarest-first so specialist
  /// positions are secured before generic ones).
  ///
  /// Returns slotIndex → ownedId for every assignable slot (XI 0..10,
  /// bench 11..17, reserves 18..22). Fewer than 23 players simply leaves
  /// later slots unassigned.
  Map<int, int> autoPick(List<PlayerCard> players, Formation formation) {
    final assignment = <int, int>{};
    final available = {for (final p in players) p.ownedId};
    final byId = {for (final p in players) p.ownedId: p};

    // Pass 1 — XI, rarest slot first (fewest compatible candidates in the
    // pool; GK is always rarest). Only compatible candidates (rating > 0)
    // are considered, so specialists stay available for their own slots.
    for (final slotIndex in _rarestFirstSlots(players, formation)) {
      final slot = formation.slots[slotIndex];
      int? bestId;
      var bestRating = 0.0;
      for (final id in available) {
        final rating = slotRatingOf(byId[id]!, slot);
        if (rating > bestRating) {
          bestRating = rating;
          bestId = id;
        }
      }
      if (bestId != null) {
        assignment[slotIndex] = bestId;
        available.remove(bestId);
      }
    }

    // Pass 2 — degenerate pools: XI slots with no compatible candidate get
    // the least-damaging remaining player (better than an empty slot).
    for (var slotIndex = 0; slotIndex < formation.slots.length; slotIndex++) {
      if (assignment.containsKey(slotIndex) || available.isEmpty) continue;
      final slot = formation.slots[slotIndex];
      int? bestId;
      var bestRating = -1.0;
      for (final id in available) {
        final rating = slotRatingOf(byId[id]!, slot);
        if (rating > bestRating) {
          bestRating = rating;
          bestId = id;
        }
      }
      if (bestId != null) {
        assignment[slotIndex] = bestId;
        available.remove(bestId);
      }
    }

    // Bench then reserves: best remaining by own-position rating (GDD 6.3:
    // reserves sorted by rating).
    final remaining = available
        .map((id) => byId[id]!)
        .toList()
      ..sort((a, b) => benchRatingOf(b).compareTo(benchRatingOf(a)));
    var next = 0;
    for (var slot = Formation.startingXiSize;
        slot < Formation.squadSize && next < remaining.length;
        slot++) {
      assignment[slot] = remaining[next++].ownedId;
    }
    return assignment;
  }

  /// Orders XI slots by scarcity: slots whose required position has the
  /// fewest compatible candidates are filled first (GK always first).
  List<int> _rarestFirstSlots(List<PlayerCard> players, Formation formation) {
    final slots = <int>[];
    for (var i = 0; i < formation.slots.length; i++) {
      slots.add(i);
    }
    int candidatesFor(FormationSlot slot) => players
        .where((p) => compatibilityOf(p.position, slot.position) > 0.5)
        .length;
    slots.sort((a, b) {
      final ca = candidatesFor(formation.slots[a]);
      final cb = candidatesFor(formation.slots[b]);
      if (ca != cb) return ca.compareTo(cb);
      return a.compareTo(b);
    });
    return slots;
  }

  /// Squad validity (GDD 6.1): complete XI, a goalkeeper in goal, all
  /// distinct, bench and reserves within capacity.
  List<String> validateSquad(
      Formation formation, Map<int, PlayerCard> slotAssignments) {
    final problems = <String>[];
    final xi = {
      for (final e in slotAssignments.entries)
        if (e.key < Formation.startingXiSize) e.key: e.value,
    };
    if (xi.length < Formation.startingXiSize) {
      problems.add('Starting XI is incomplete (${xi.length}/11)');
    }
    if (xi.isNotEmpty && xi[0]?.position != Position.gk) {
      problems.add('No goalkeeper in the starting XI');
    }
    final ids = slotAssignments.values.map((p) => p.ownedId).toSet();
    if (ids.length != slotAssignments.length) {
      problems.add('A player is assigned to multiple slots');
    }
    return problems;
  }
}
