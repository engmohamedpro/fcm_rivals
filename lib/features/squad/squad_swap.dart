/// FCM Rivals — squad drag-and-drop rules (Team tab).
///
/// Pure Dart, UI-independent (SRS 21.1): decides whether a dragged
/// player may take a place in the 23-man squad and, when he may, what
/// the whole assignment looks like afterwards.
///
/// The rules (custom formations, owner request 2026-11-12):
///  * the pitch has 11 FIXED PLACES. Dragging a player ONTO ANOTHER
///    player swaps the two — the XI keeps its shape, each man takes
///    the other's place (out-of-position placement is allowed and
///    simply shows the compatibility warn mark; the keeper's slot is
///    the one exception — only a goalkeeper may stand in goal);
///  * dragging a player ONTO AN EMPTY pitch place REDEFINES that
///    place: it becomes his position (a striker dropped on an empty
///    CM place turns it into a ST place), as long as the resulting
///    position mix stays within [positionCaps] — otherwise the drop
///    is refused with the reason. This is how a custom formation is
///    built: the owner's exact ladder (ST 0-2, LW/RW/LB/RB 0-1, CAM
///    0-2, CM/CDM/CB 0-3, GK 1) is the law;
///  * bench (11..17) and reserves/pool (18..22) swap freely with
///    anything, exactly as before — dropping a starter there simply
///    moves him out, leaving an empty pitch place behind.
library;

import '../../core/domain/players.dart' show Position;
import 'formations.dart';
import 'squad_engine.dart' show PlayerCard;

/// The three areas of the 23-man squad.
enum SquadZone {
  xi,
  bench,
  reserves;

  /// The zone a squad slot index belongs to.
  static SquadZone ofSlot(int slot) {
    if (slot < Formation.startingXiSize) return SquadZone.xi;
    if (slot < Formation.startingXiSize + Formation.benchSize) {
      return SquadZone.bench;
    }
    return SquadZone.reserves;
  }

  /// Every slot index of this zone, in order.
  List<int> get slots {
    switch (this) {
      case SquadZone.xi:
        return List<int>.generate(Formation.startingXiSize, (i) => i);
      case SquadZone.bench:
        return List<int>.generate(
          Formation.benchSize,
          (i) => Formation.startingXiSize + i,
        );
      case SquadZone.reserves:
        return List<int>.generate(
          Formation.reservesSize,
          (i) => Formation.startingXiSize + Formation.benchSize + i,
        );
    }
  }
}

/// Where a dragged player was dropped: ON a player, on an EMPTY
/// formation slot (carrying the slot's current position so the planner
/// can decide the redefinition), or on an empty place of the bench /
/// reserves.
class SquadDropTarget {
  const SquadDropTarget.player(PlayerCard this.card)
    : slot = null,
      zone = null,
      slotPosition = null;

  const SquadDropTarget.xiSlot(int this.slot, {Position? position})
    : card = null,
      zone = null,
      slotPosition = position;

  const SquadDropTarget.emptyIn(SquadZone this.zone)
    : card = null,
      slot = null,
      slotPosition = null;

  /// The player dropped on, when the target is a player.
  final PlayerCard? card;

  /// The empty formation slot, when the target is one.
  final int? slot;

  /// The zone whose first free place is meant (empty bench / reserves).
  final SquadZone? zone;

  /// The empty slot's CURRENT position — what the place asks for
  /// before the drop redefines it. Null on non-slot targets.
  final Position? slotPosition;
}

/// The verdict on a drop: either the full new assignment (slot → owned
/// player id, ready for the store) plus the formation that result
/// produces, or a human-readable reason.
class SquadSwapOutcome {
  const SquadSwapOutcome.accepted(
    Map<int, int> this.assignment, {
    Formation? formation,
  }) : rejection = null,
       formation = formation;

  const SquadSwapOutcome.rejected(String this.rejection)
    : assignment = null,
       formation = null;

  /// The new squad (slot → owned id) when accepted.
  final Map<int, int>? assignment;

  /// Why the drop is refused, when it is.
  final String? rejection;

  /// When the drop redefined an empty slot's position (custom
  /// formation building): the new formation to persist ALONGSIDE the
  /// assignment. Null when the shape is unchanged.
  final Formation? formation;

  bool get isAccepted => assignment != null;
}

String _surname(PlayerCard p) => p.base.name.split(' ').last;

/// First empty place of [zone] in [squad], or null when the zone is full.
int? firstFreeSlot(Map<int, PlayerCard> squad, SquadZone zone) {
  for (final slot in zone.slots) {
    if (!squad.containsKey(slot)) return slot;
  }
  return null;
}

/// The keeper's law: the man in goal must be a goalkeeper. Every other
/// position placement is a manager's choice — the pitch shows the
/// compatibility warn mark, the match engine applies its factor, but
/// the drag planner does not refuse it.
String? _misfit(Formation formation, PlayerCard p, int slot) {
  if (slot >= Formation.startingXiSize) return null;
  if (p.isInjured) {
    return '${_surname(p)} is injured and cannot play in the starting XI.';
  }
  final need = formation.slots[slot].position;
  if (need == Position.gk) {
    if (p.position == Position.gk) return null;
    return '${_surname(p)} is a ${p.position.code} — only a goalkeeper '
        'stands in goal.';
  }
  if (p.position == Position.gk) {
    return '${_surname(p)} is a goalkeeper — he only plays in goal.';
  }
  return null;
}

/// Moves the player in [fromSlot] to [toSlot], swapping with whoever is
/// there (an empty [toSlot] is a plain move). See the library rules.
SquadSwapOutcome swapSquadSlots({
  required Formation formation,
  required Map<int, PlayerCard> squad,
  required int fromSlot,
  required int toSlot,
}) {
  final mover = squad[fromSlot];
  if (mover == null) {
    return const SquadSwapOutcome.rejected('There is nobody to move.');
  }
  if (toSlot < 0 || toSlot >= Formation.squadSize || toSlot == fromSlot) {
    return const SquadSwapOutcome.rejected('Pick another place for him.');
  }
  final other = squad[toSlot];

  final bad =
      _misfit(formation, mover, toSlot) ??
      (other == null ? null : _misfit(formation, other, fromSlot));
  if (bad != null) return SquadSwapOutcome.rejected(bad);

  final assignment = <int, int>{
    for (final e in squad.entries) e.key: e.value.ownedId,
  };
  assignment[toSlot] = mover.ownedId;
  if (other != null) {
    assignment[fromSlot] = other.ownedId;
  } else {
    assignment.remove(fromSlot);
  }
  return SquadSwapOutcome.accepted(assignment);
}

/// The position each XI slot asks for after this drop: a drop on an
/// EMPTY slot redefines that slot to the dragged player's position;
/// every other slot keeps the formation's ask. Null when the redefined
/// mix is illegal (returned as the rejection instead).
List<Position>? _slotPositionsAfter(
  Formation formation,
  Map<int, PlayerCard> live,
  int redefinedSlot,
  Position newPosition,
) {
  final positions = [
    for (var slot = 0; slot < Formation.startingXiSize; slot++)
      slot == redefinedSlot
          ? newPosition
          : (live[slot]?.position ?? formation.slots[slot].position),
  ];
  if (customFormationProblem(positions) != null) return null;
  return positions;
}

/// Resolves a UI drop ([dragged] onto [target]) into the new squad.
/// [squad] is the persisted slot → card map.
///
/// The Team tab's lower strip is the POOL — every owned card that is not
/// in the XI or on the bench — so a drop can also come FROM the pool
/// (onto a pitch slot, a bench place or a placed player, who then goes
/// back to the pool) or go TO the pool (the strip's [SquadZone.reserves]
/// zone, or a pool card, which takes the dragged player's place). Cards
/// parked in the legacy reserve slots count as pool cards.
///
/// Dropping on an EMPTY pitch slot builds the CUSTOM FORMATION: the
/// slot becomes the dragged player's position (see the library rules),
/// the outcome carries the new [SquadSwapOutcome.formation] to persist
/// beside the assignment. Drops on occupied slots keep the shape and
/// simply swap the two men.
SquadSwapOutcome planSquadDrop({
  required Formation formation,
  required Map<int, PlayerCard> squad,
  required PlayerCard dragged,
  required SquadDropTarget target,
}) {
  const firstPoolSlot = Formation.startingXiSize + Formation.benchSize;
  // The squad that counts: XI + bench.
  final live = <int, PlayerCard>{
    for (final e in squad.entries)
      if (e.key < firstPoolSlot) e.key: e.value,
  };
  int? slotOf(PlayerCard c) {
    for (final e in live.entries) {
      if (e.value.ownedId == c.ownedId) return e.key;
    }
    return null;
  }

  Map<int, int> ids() => {
    for (final e in live.entries) e.key: e.value.ownedId,
  };

  final from = slotOf(dragged);
  final targetCardSlot = target.card == null ? null : slotOf(target.card!);
  final toPool =
      target.zone == SquadZone.reserves ||
      (target.card != null && targetCardSlot == null);

  // A drop on an EMPTY XI slot: the slot BECOMES the dragged player's
  // position (custom formation building). Applies from the squad or
  // from the pool alike; the GK slot is untouchable (its occupant is
  // always there, so it is never empty in practice).
  if (target.slot != null && targetCardSlot == null && !toPool) {
    final slot = target.slot!;
    if (slot <= 0 || slot >= Formation.startingXiSize) {
      return const SquadSwapOutcome.rejected(
        'Only the goalkeeper stands in goal — his slot cannot change.',
      );
    }
    final positions = _slotPositionsAfter(
      formation,
      live,
      slot,
      dragged.position,
    );
    if (positions == null) {
      return SquadSwapOutcome.rejected(
        customFormationProblem([
          for (var s = 0; s < Formation.startingXiSize; s++)
            s == slot
                ? dragged.position
                : (live[s]?.position ?? formation.slots[s].position),
        ])!,
      );
    }
    final newFormation = customFormation(positions)!;
    final assignment = ids()..[slot] = dragged.ownedId;
    if (from != null && from < Formation.startingXiSize) {
      assignment.remove(from);
    } else if (from != null) {
      assignment.remove(from);
    }
    // An injured player cannot hold a starting place at all.
    if (dragged.isInjured) {
      return SquadSwapOutcome.rejected(
        '${_surname(dragged)} is injured and cannot play in the starting XI.',
      );
    }
    return SquadSwapOutcome.accepted(assignment, formation: newFormation);
  }

  // From the pool onto the pitch / bench.
  if (from == null) {
    if (toPool) {
      return const SquadSwapOutcome.rejected(
        'He is already in the pool — drop him on the pitch or the bench.',
      );
    }
    final int? to;
    if (target.card != null) {
      to = targetCardSlot;
    } else if (target.zone != null) {
      to = firstFreeSlot(live, target.zone!);
    } else {
      to = null;
    }
    if (to == null || to < 0 || to >= firstPoolSlot) {
      return const SquadSwapOutcome.rejected('There is no free place there.');
    }
    final bad = _misfit(formation, dragged, to);
    if (bad != null) return SquadSwapOutcome.rejected(bad);
    // Whoever held the place simply goes back to the pool.
    return SquadSwapOutcome.accepted(ids()..[to] = dragged.ownedId);
  }

  // From the squad to the pool.
  if (toPool) {
    final assignment = ids();
    final back = target.card;
    if (back != null) {
      final bad = _misfit(formation, back, from);
      if (bad != null) return SquadSwapOutcome.rejected(bad);
      assignment[from] = back.ownedId;
    } else {
      assignment.remove(from);
    }
    return SquadSwapOutcome.accepted(assignment);
  }

  // Within the squad.
  final int? to;
  if (target.card != null) {
    to = targetCardSlot;
  } else if (target.slot != null) {
    // Unreachable for empty slots (handled above); a squad player
    // dropped on an empty XI slot redefines it, so this branch only
    // catches inconsistent input.
    to = target.slot;
  } else if (target.zone != null) {
    to = firstFreeSlot(live, target.zone!);
  } else {
    to = null;
  }
  if (to == null) {
    return const SquadSwapOutcome.rejected('There is no free place there.');
  }
  return swapSquadSlots(
    formation: formation,
    squad: live,
    fromSlot: from,
    toSlot: to,
  );
}
