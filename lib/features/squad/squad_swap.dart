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

/// The drag layout the pitch renders while a player is held (owner
/// request 2026-11-13): the shape the drop builds, decomposed into the
/// PLACES it stands at — every position's player-count spread by the
/// anchor rules (see `formations.dart`), the GK fixed in goal.
///
/// A drop never adds a player: the held man LEAVES his place (dragged
/// off the pitch, the bench or the pool) and re-enters at one of the
/// [slots]. So [count] of the held player's own position is the LIVE
/// mix minus him; every other position keeps its live count. The
/// [slots] are ordered slot-index-wise (GK first) exactly like a
/// [Formation.slots] list, so the pitch can lay them out with the
/// same solver it already uses.
class SquadDragLayout {
  const SquadDragLayout({required this.slots, required this.problem});

  /// The places the pitch renders while a drag is live: the shape's
  /// own 11 places (GK first, slot order) plus every ADDITIONAL spare
  /// place the drop may fill (positions the shape does not field —
  /// the RB of a 3-4-3 — appended after the XI, back line → attack).
  final List<DragSlot> slots;

  /// Why the held player may not enter any place — the cap his
  /// position is at. Null when the drop may proceed.
  final String? problem;

  bool get isLegal => problem == null;
}

/// One place of a [SquadDragLayout]: what it asks for and where it
/// stands (x/y percent of the pitch, like [FormationSlot]).
class DragSlot {
  const DragSlot(this.position, this.x, this.y, {required this.isHeld});

  final Position position;

  /// Pitch coordinates for rendering (percent of width/height).
  final double x;
  final double y;

  /// True when this place is the one the held player would take on
  /// entry — the pitch highlights it.
  final bool isHeld;
}

/// The LIVE position mix of the XI: a slot's ask is its occupant's
/// position when it has one (an out-of-position player redefines the
/// place he stands on — the custom-formation rule), otherwise the
/// formation's ask.
List<Position> _livePositions(Formation formation, Map<int, PlayerCard> live) => [
  for (var slot = 0; slot < Formation.startingXiSize; slot++)
    live[slot]?.position ?? formation.slots[slot].position,
];

/// Computes the [SquadDragLayout] the pitch shows while [dragged] is
/// held: the shape as it stands without him, so the empty places the
/// drop could fill are the empty positions of that shape, and every
/// occupied place keeps its anchor in the RE-SPREAD formation (two CMs
/// whose third man just got picked up close ranks to a pair).
SquadDragLayout squadDragLayout({
  required Formation formation,
  required Map<int, PlayerCard> squad,
  required PlayerCard dragged,
}) {
  const firstPoolSlot = Formation.startingXiSize + Formation.benchSize;
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

  final from = slotOf(dragged);
  final positions = _livePositions(formation, live);
  // The held man leaves his place first: the layout below is the shape
  // WITHOUT him — his slot renders as a free place.
  final heldSlot = (from != null && from < Formation.startingXiSize)
      ? from
      : -1;

  // Count the mix without the held man.
  final counts = <Position, int>{};
  for (var i = 0; i < positions.length; i++) {
    if (i == heldSlot) continue;
    counts.update(positions[i], (n) => n + 1, ifAbsent: () => 1);
  }

  // Where the held man may re-enter: his own position when it has a
  // free place under the caps, or any position short of its cap. A
  // keeper re-enters only in goal (his slot's occupant is always
  // there, so he can never re-enter — dropping him anywhere else is
  // refused as ever).
  final cap = positionCaps[dragged.position]!;
  String? problem;
  if (dragged.position == Position.gk) {
    problem = 'The goalkeeper keeps his slot — drag him nowhere.';
  } else if ((counts[dragged.position] ?? 0) + 1 > cap.$2) {
    problem = 'Too many ${dragged.position.code}s — a custom formation '
        'fields at most ${cap.$2}.';
  }

  // Build the layout places: the live mix WITHOUT the held man — his
  // own slot renders as a free placeholder dead-centre of his
  // position's home (his natural drop-back home), and the REMAINING
  // men of his position re-spread to their true count (a lone CM
  // centres, a pair halves). Plus ONE spare place for every position
  // the mix does not field AT ALL and that is not the held man's own
  // (owner request 2026-11-13: a 3-4-3 with no RB still shows the RB
  // place, so a dragged ST may take it). Positions the mix already
  // fields do NOT grow extra placeholders: their spare capacity is
  // reached by redefining an empty slot, not by stacking invitations.
  final layoutPositions = <Position>[];
  var heldIndex = -1;
  for (var i = 0; i < positions.length; i++) {
    if (i == heldSlot) {
      layoutPositions.add(dragged.position);
      heldIndex = layoutPositions.length - 1;
    } else {
      layoutPositions.add(positions[i]);
    }
  }
  // The absent positions: one place each, ordered back line →
  // midfield → attack so the pitch reads top to bottom. GK never
  // appears (its slot never opens), and the held man's own position
  // never doubles up — his vacated place already invites him back.
  final order = [
    Position.rb, Position.lb,
    Position.cdm, Position.cm, Position.cam, Position.lm, Position.rm,
    Position.lw, Position.rw, Position.st,
  ];
  // A spare place is only offered when the drop can really fill it: the
  // held man vacates a place of his own (heldSlot >= 0), or the XI has
  // an empty outfield place to turn into it. A bench / pool man facing
  // a full XI brings no place — offering spares then made the drop
  // refuse (or, worse, land on somebody) — and the keeper never takes
  // an outfield place at all.
  var hasEmptyOutfieldSlot = false;
  for (var s = 1; s < Formation.startingXiSize; s++) {
    if (!live.containsKey(s)) {
      hasEmptyOutfieldSlot = true;
      break;
    }
  }
  final offersSpares =
      dragged.position != Position.gk &&
      (heldSlot >= 0 || hasEmptyOutfieldSlot);
  for (final p in order) {
    if (!offersSpares) break;
    if (p == dragged.position && heldSlot >= 0) continue;
    if ((counts[p] ?? 0) == 0) {
      layoutPositions.add(p);
    }
  }
  // The anchor spread counts only the OCCUPIED places: the held man's
  // placeholder and the spare places anchor ALONE (dead centre / their
  // wing), so the remaining men of a position close ranks to their
  // true count — the remaining CM of a picked-apart pair centres.
  final totals = <Position, int>{};
  for (var i = 0; i < layoutPositions.length; i++) {
    if (i >= Formation.startingXiSize) continue; // spare places
    if (i == heldSlot) continue; // the held man's placeholder
    totals.update(layoutPositions[i], (n) => n + 1, ifAbsent: () => 1);
  }
  // The occurrence index of each OCCUPIED place, numbered left to
  // right by where the current formation stands them: a pair reads
  // 32/68 whatever order its slots carried.
  final occurrence = <int, int>{};
  for (final e in totals.entries) {
    final indices = <int>[
      for (var i = 0; i < Formation.startingXiSize; i++)
        if (i != heldSlot && layoutPositions[i] == e.key) i,
    ];
    if (indices.isEmpty) continue;
    final byX = [
      for (final i in indices) (i, formation.slots[i].x),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (var n = 0; n < byX.length; n++) {
      occurrence[byX[n].$1] = n;
    }
  }
  final slots = <DragSlot>[
    for (var i = 0; i < layoutPositions.length; i++)
      () {
        final p = layoutPositions[i];
        final inXi = i < Formation.startingXiSize;
        final occupied = inXi && i != heldSlot;
        final (x, y) = customAnchors(
          p,
          occupied ? (occurrence[i] ?? 0) : 0,
          occupied ? (totals[p] ?? 1) : 1,
        );
        return DragSlot(p, x, y, isHeld: i == heldIndex);
      }(),
  ];
  return SquadDragLayout(slots: slots, problem: problem);
}

/// Which XI slot a placeholder drop redefines (owner request
/// 2026-11-13). The drag layout shows COUNT-AWARE places, not one
/// placeholder per static slot, so the finger lands on a PLACE (a
/// position) rather than a slot index; this maps it back to the slot
/// whose redefinition reproduces exactly that place:
///
///  * the dragged man's own slot, when the place asks for his
///    position — dropping a ST back on a ST place puts him home and
///    the shape keeps his old slot asking for ST (no change at all);
///  * else the EMPTY slot whose live position already asks for the
///    place's position (a 3-4-3's RB-less slot at the RB place) —
///    redefining it is a no-op that simply fills it;
///  * else the dragged man's vacated slot (the place is a NEW
///    position for the shape — his old place is the one that morphs).
///
/// Falls back to [targetSlot] when [targetPosition] is null (the
/// legacy static-slot drops and the tests).
///
/// Never returns a slot another man stands on, and never a slot outside
/// the outfield XI (1..10): a drop that has nowhere legal to land
/// returns null and the caller refuses it with a reason. (Before this
/// guard the fallback returned the spare place's stand-in slot — an
/// OCCUPIED slot — and the drop silently overwrote its occupant, and a
/// bench man's own bench slot came back as the "XI slot", so the drop
/// was refused with the keeper message.)
int? _resolveDropSlot({
  required Formation formation,
  required Map<int, PlayerCard> live,
  required PlayerCard dragged,
  required int targetSlot,
  Position? targetPosition,
}) {
  final ask = targetPosition;
  if (ask == null) return targetSlot;
  int? from;
  for (final e in live.entries) {
    if (e.value.ownedId == dragged.ownedId) {
      from = e.key;
      break;
    }
  }
  // Only a man standing in the OUTFIELD XI vacates a pitch place; a
  // bench man (slot 11..17) or a pool man (null) brings no place with
  // him, and the keeper's place never moves.
  final fromXi =
      (from != null && from > 0 && from < Formation.startingXiSize)
      ? from
      : null;
  // The empty outfield places, in slot order.
  final empty = <int>[
    for (var s = 1; s < Formation.startingXiSize; s++)
      if (!live.containsKey(s)) s,
  ];
  Position askOf(int s) =>
      live[s]?.position ?? formation.slots[s].position;

  // 1. The empty place the finger rested on, when it already asks for
  //    the place's position: the man simply moves THERE (a CM dropped
  //    on the empty CM place beside him changes sides instead of the
  //    drop silently doing nothing).
  if (empty.contains(targetSlot) && askOf(targetSlot) == ask) {
    return targetSlot;
  }
  // 2. His own slot when the place asks for his position (dropped
  //    straight back home — no change).
  if (fromXi != null && ask == dragged.position) return fromXi;
  // 3. Another empty slot that already asks for the place's position.
  for (final s in empty) {
    if (askOf(s) == ask) return s;
  }
  // 4. His vacated slot: the place is a new position for the shape.
  if (fromXi != null) return fromXi;
  // 5. A bench / pool man on a fresh position: the empty place under
  //    his finger, else the first empty place there is.
  if (empty.contains(targetSlot)) return targetSlot;
  if (empty.isNotEmpty) return empty.first;
  // 6. The XI is full and he brings no place: nowhere legal to land.
  return null;
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

  // A drop on an EMPTY XI place: the place BECOMES the dragged
  // player's position (custom formation building). Applies from the
  // squad or from the pool alike; the GK slot is untouchable (its
  // occupant is always there, so it is never empty in practice).
  //
  // [SquadDropTarget.slotPosition] (owner request 2026-11-13): the
  // placeholder's POSITION the finger rested on, as the drag layout
  // computed it — the drop then redefines THIS player's slot to that
  // position, not merely the slot index under the finger. It picks
  // the dragged man's own slot when the position matches his (a drop
  // back home), otherwise the OCCUPANT-less slot whose live position
  // already asks for it, and otherwise the held man's vacated slot.
  if (target.slot != null && targetCardSlot == null && !toPool) {
    // The keeper never takes an outfield place — dropping him on an
    // empty place (or a spare one) used to move him out of goal and
    // leave the goal empty.
    if (dragged.position == Position.gk) {
      return const SquadSwapOutcome.rejected(
        'The goalkeeper keeps his slot — only a goalkeeper stands in goal.',
      );
    }
    if (target.slot == 0) {
      return const SquadSwapOutcome.rejected(
        'Only the goalkeeper stands in goal — his slot cannot change.',
      );
    }
    final slot = _resolveDropSlot(
      formation: formation,
      live: live,
      dragged: dragged,
      targetSlot: target.slot!,
      targetPosition: target.slotPosition,
    );
    if (slot == null) {
      return const SquadSwapOutcome.rejected(
        'The starting XI is full — drop him on a player to swap, or move '
        'a starter out first.',
      );
    }
    if (slot <= 0 || slot >= Formation.startingXiSize) {
      return const SquadSwapOutcome.rejected(
        'Only the goalkeeper stands in goal — his slot cannot change.',
      );
    }
    // Never overwrite a man who stands on the resolved place: the only
    // occupied place the drop may take is the one the held man himself
    // leaves (his own slot).
    final occupant = live[slot];
    if (occupant != null && occupant.ownedId != dragged.ownedId) {
      return const SquadSwapOutcome.rejected(
        'That place is taken — drop him on the player to swap them.',
      );
    }
    // WHAT the redefined slot asks for: the PLACE's position when the
    // finger rested on a drag-layout placeholder (dropping a ST on the
    // spare RB place turns the slot into an RB slot), otherwise the
    // dragged man's own position (the legacy slot drops).
    final ask = target.slotPosition ?? dragged.position;
    final positions = _slotPositionsAfter(formation, live, slot, ask);
    if (positions == null) {
      return SquadSwapOutcome.rejected(
        customFormationProblem([
          for (var s = 0; s < Formation.startingXiSize; s++)
            s == slot
                ? ask
                : (live[s]?.position ?? formation.slots[s].position),
        ])!,
      );
    }
    final newFormation = customFormation(positions)!;
    final assignment = ids()..[slot] = dragged.ownedId;
    // His old place frees up when he came from the XI; a bench man
    // frees his bench slot instead. A drop that lands the man BACK on
    // his own slot (slot == from) keeps the assignment tight — the
    // remove-then-settle order below handles it by re-adding him.
    if (from != null && from != slot) {
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
