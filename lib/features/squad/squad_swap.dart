/// FCM Rivals — squad drag-and-drop rules (Team tab).
///
/// Pure Dart, UI-independent (SRS 21.1): decides whether a dragged
/// player may take a place in the 23-man squad and, when he may, what
/// the whole assignment looks like afterwards.
///
/// The rules:
///  * any two players can be swapped across the formation (slots 0..10),
///    the bench (11..17) and the reserves (18..22);
///  * the ONLY restriction: a player landing in a STARTING slot must have
///    that slot's position — a CB cannot take a ST slot, an LB cannot
///    take an RB slot. Moving a starter OUT (to the bench or reserves) is
///    always allowed, as long as the player coming in fits his slot;
///  * the starting XI can never be left with a hole: a starter cannot be
///    moved onto an EMPTY bench or reserves place — swap him with a
///    player instead.
library;

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
            Formation.benchSize, (i) => Formation.startingXiSize + i);
      case SquadZone.reserves:
        return List<int>.generate(
            Formation.reservesSize,
            (i) => Formation.startingXiSize + Formation.benchSize + i);
    }
  }
}

/// Where a dragged player was dropped: ON a player, on an EMPTY
/// formation slot, or on an empty place of the bench / reserves.
class SquadDropTarget {
  const SquadDropTarget.player(PlayerCard this.card)
      : slot = null,
        zone = null;

  const SquadDropTarget.xiSlot(int this.slot)
      : card = null,
        zone = null;

  const SquadDropTarget.emptyIn(SquadZone this.zone)
      : card = null,
        slot = null;

  /// The player dropped on, when the target is a player.
  final PlayerCard? card;

  /// The empty formation slot, when the target is one.
  final int? slot;

  /// The zone whose first free place is meant (empty bench / reserves).
  final SquadZone? zone;
}

/// The verdict on a drop: either the full new assignment (slot → owned
/// player id, ready for the store) or a human-readable reason.
class SquadSwapOutcome {
  const SquadSwapOutcome.accepted(Map<int, int> this.assignment)
      : rejection = null;

  const SquadSwapOutcome.rejected(String this.rejection) : assignment = null;

  /// The new squad (slot → owned id) when accepted.
  final Map<int, int>? assignment;

  /// Why the drop is refused, when it is.
  final String? rejection;

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

  // A starter must never be left without a replacement: the XI has to
  // stay full.
  if (other == null &&
      fromSlot < Formation.startingXiSize &&
      toSlot >= Formation.startingXiSize) {
    return const SquadSwapOutcome.rejected(
        'The starting XI must stay full — drop a bench player on him '
        'instead.');
  }

  // The one real restriction: whoever lands in a starting slot must have
  // that slot's position.
  String? misfit(PlayerCard p, int slot) {
    if (slot >= Formation.startingXiSize) return null;
    final need = formation.slots[slot].position;
    if (p.position == need) return null;
    return '${_surname(p)} is a ${p.position.code} — a starting '
        '${need.code} place needs a ${need.code}.';
  }

  final bad = misfit(mover, toSlot) ??
      (other == null ? null : misfit(other, fromSlot));
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

/// Resolves a UI drop ([dragged] onto [target]) into slot indices and
/// applies [swapSquadSlots]. [squad] is the persisted slot → card map.
SquadSwapOutcome planSquadDrop({
  required Formation formation,
  required Map<int, PlayerCard> squad,
  required PlayerCard dragged,
  required SquadDropTarget target,
}) {
  int? slotOf(PlayerCard c) {
    for (final e in squad.entries) {
      if (e.value.ownedId == c.ownedId) return e.key;
    }
    return null;
  }

  final from = slotOf(dragged);
  if (from == null) {
    return const SquadSwapOutcome.rejected('He is not in your squad.');
  }
  final int? to;
  if (target.card != null) {
    to = slotOf(target.card!);
  } else if (target.slot != null) {
    to = target.slot;
  } else if (target.zone != null) {
    to = firstFreeSlot(squad, target.zone!);
  } else {
    to = null;
  }
  if (to == null) {
    return const SquadSwapOutcome.rejected('There is no free place there.');
  }
  return swapSquadSlots(
      formation: formation, squad: squad, fromSlot: from, toSlot: to);
}
