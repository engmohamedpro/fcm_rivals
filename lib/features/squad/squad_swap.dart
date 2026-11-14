/// FCM Rivals — squad drag-and-drop rules (Team tab).
///
/// Pure Dart, UI-independent (SRS 21.1): decides whether a dragged
/// player may take a place in the 23-man squad and, when he may, what
/// the whole assignment looks like afterwards.
///
/// The rules (the chess GRID, owner request 2026-11-13 — "like FM 26"):
///  * the Team-tab pitch is a fixed grid of cells ([kGridCols] ×
///    [kGridRows]); every XI slot stands on ONE cell and nothing moves
///    unless the user moves it — no re-spreading, no placeholders;
///  * dragging a player ONTO ANOTHER player swaps the two (each man takes
///    the other's cell; out-of-position placement is allowed and shows
///    the compatibility warn mark; the keeper's slot is the one
///    exception — only a goalkeeper may stand in goal);
///  * dragging a player onto an EMPTY slot's cell (a starter he replaced
///    went to the bench) simply fills it;
///  * dragging a player onto a FREE cell (no slot there) moves a slot
///    there: an XI man moves his own slot, a bench / pool man takes an
///    empty slot's place. What the slot asks for becomes the position
///    the cell stands for ([positionOfCell]); the result must stay within
///    the per-position maximums ([positionCaps]) or the drop is refused
///    with the reason. This is how a custom formation is built;
///  * bench (11..17) and reserves/pool (18..22) swap freely with
///    anything — dropping a starter there leaves an empty slot (a ghost
///    on its cell) behind.
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

/// Where a dragged player was dropped: ON a player, on an EMPTY formation
/// slot, on a pitch CELL (free, or the cell of an empty slot) or on an
/// empty place of the bench / reserves.
class SquadDropTarget {
  const SquadDropTarget.player(PlayerCard this.card)
    : slot = null,
      zone = null,
      cell = null;

  const SquadDropTarget.xiSlot(int this.slot)
    : card = null,
      zone = null,
      cell = null;

  const SquadDropTarget.emptyIn(SquadZone this.zone)
    : card = null,
      slot = null,
      cell = null;

  const SquadDropTarget.cell(GridCell this.cell)
    : card = null,
      slot = null,
      zone = null;

  /// The player dropped on, when the target is a player.
  final PlayerCard? card;

  /// The empty formation slot, when the target is one (used as is).
  final int? slot;

  /// The zone whose first free place is meant (empty bench / reserves).
  final SquadZone? zone;

  /// The pitch grid cell, when the target is one.
  final GridCell? cell;
}

/// The verdict on a drop: either the full new assignment (slot → owned
/// player id, ready for the store) plus the formation that result
/// produces, or a human-readable reason.
class SquadSwapOutcome {
  const SquadSwapOutcome.accepted(
    this.assignment, {
    this.formation,
  }) : rejection = null;

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

/// The formation with [slot] moved to [cell]; what the slot asks for becomes
/// the position of that cell. Null when the mix is illegal ([problem] then
/// says why).
({Formation? formation, String? problem}) _formationWithSlotAt(
  Formation formation,
  int slot,
  GridCell cell,
) {
  final cells = [...gridCellsOf(formation)];
  final positions = [for (final s in formation.slots) s.position];
  cells[slot] = cell;
  positions[slot] = positionOfCell(cell.col, cell.row);
  final problem = gridFormationProblem(positions, cells);
  if (problem != null) return (formation: null, problem: problem);
  return (formation: customGridFormation(positions, cells), problem: null);
}

/// A drop on a pitch CELL (see the library rules).
SquadSwapOutcome _planCellDrop({
  required Formation formation,
  required Map<int, PlayerCard> live,
  required Map<int, int> Function() ids,
  required PlayerCard dragged,
  required int? from,
  required GridCell cell,
}) {
  if (!isGridCellAllowed(cell.col, cell.row)) {
    return const SquadSwapOutcome.rejected('That is not a place on the pitch.');
  }
  final cells = gridCellsOf(formation);
  final slotHere = cells.indexOf(cell);

  // The cell of an existing slot: swap with its occupant, or fill it.
  if (slotHere >= 0) {
    if (from != null) {
      return swapSquadSlots(
        formation: formation,
        squad: live,
        fromSlot: from,
        toSlot: slotHere,
      );
    }
    final bad = _misfit(formation, dragged, slotHere);
    if (bad != null) return SquadSwapOutcome.rejected(bad);
    // A pool man replaces whoever stands there (he goes back to the pool).
    return SquadSwapOutcome.accepted(
      ids()..[slotHere] = dragged.ownedId,
    );
  }

  // A FREE cell: a slot moves there.
  if (dragged.position == Position.gk) {
    return const SquadSwapOutcome.rejected(
      'The goalkeeper keeps his slot — only a goalkeeper stands in goal.',
    );
  }
  if (dragged.isInjured) {
    return SquadSwapOutcome.rejected(
      '${_surname(dragged)} is injured and cannot play in the starting XI.',
    );
  }
  int? slot;
  if (from != null && from > 0 && from < Formation.startingXiSize) {
    slot = from; // an XI man carries his own place with him
  } else {
    for (var s = 1; s < Formation.startingXiSize; s++) {
      if (!live.containsKey(s)) {
        slot = s; // a bench / pool man takes an empty place
        break;
      }
    }
  }
  if (slot == null) {
    return const SquadSwapOutcome.rejected(
      'The starting XI is full — drop him on a player to swap, or move a '
      'starter out first.',
    );
  }
  final moved = _formationWithSlotAt(formation, slot, cell);
  if (moved.formation == null) {
    return SquadSwapOutcome.rejected(moved.problem!);
  }
  final assignment = ids();
  if (from != null && from != slot) assignment.remove(from);
  assignment[slot] = dragged.ownedId;
  return SquadSwapOutcome.accepted(assignment, formation: moved.formation);
}

/// Moves the formation place [slot] (a ghost standing empty, or a card's
/// own place) to the FREE cell [cell] — how an empty position is dragged
/// to reshape the formation (owner request 2026-11-14). The men stay on
/// their slots; only the slot's cell, and so what it asks for
/// ([positionOfCell]), changes. Refused with the reason when the cell is
/// off the pitch or taken, the keeper's slot is involved, or the move
/// breaks the per-position maximums.
SquadSwapOutcome planSlotMove({
  required Formation formation,
  required Map<int, PlayerCard> squad,
  required int slot,
  required GridCell cell,
}) {
  if (slot <= 0 || slot >= Formation.startingXiSize) {
    return const SquadSwapOutcome.rejected(
      'The goalkeeper keeps his slot — only a goalkeeper stands in goal.',
    );
  }
  if (!isGridCellAllowed(cell.col, cell.row)) {
    return const SquadSwapOutcome.rejected('That is not a place on the pitch.');
  }
  if (gridCellsOf(formation).contains(cell)) {
    return const SquadSwapOutcome.rejected('That place is taken.');
  }
  final moved = _formationWithSlotAt(formation, slot, cell);
  if (moved.formation == null) {
    return SquadSwapOutcome.rejected(moved.problem!);
  }
  return SquadSwapOutcome.accepted({
    for (final e in squad.entries) e.key: e.value.ownedId,
  }, formation: moved.formation);
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
/// Dropping on a FREE pitch cell builds the CUSTOM FORMATION: a slot moves
/// there (see the library rules) and the outcome carries the new
/// [SquadSwapOutcome.formation] to persist beside the assignment. Drops on
/// occupied slots keep the shape and simply swap the two men.
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

  // A drop on a pitch CELL (the chess grid).
  if (target.cell != null) {
    return _planCellDrop(
      formation: formation,
      live: live,
      ids: ids,
      dragged: dragged,
      from: from,
      cell: target.cell!,
    );
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
    } else if (target.slot != null && !live.containsKey(target.slot)) {
      to = target.slot;
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
    // An empty XI slot: a plain move onto it, the shape unchanged.
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
