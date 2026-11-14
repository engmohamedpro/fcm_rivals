/// FCM Rivals — squad drag-and-drop widgets (Team tab).
///
/// Hold a player, drag him onto another player (or onto an empty place)
/// and drop: the two swap. It works across the pitch, the bench and the
/// reserves; the rules live in `squad_swap.dart`.
///
/// Opt-in by composition: [SquadDragHost] wraps the pitch and the strips
/// and publishes a [SquadDragScope]; [SquadDraggable] and [SquadDropZone]
/// turn into plain pass-throughs when no scope is above them, so every
/// surface that does not enable swapping (pre-match, live tactics) is
/// untouched.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import 'formations.dart' show GridCell;
import 'squad_engine.dart' show PlayerCard;
import 'squad_swap.dart';

/// What the owner of the squad supplies to enable swapping.
class SquadSwapping {
  const SquadSwapping({
    required this.rejection,
    required this.onSwap,
    this.slotRejection,
    this.onMoveSlot,
  });

  /// Null when dropping [dragged] on [target] is allowed, otherwise the
  /// reason it is not (drives the green / red hover feedback).
  final String? Function(PlayerCard dragged, SquadDropTarget target) rejection;

  /// Performs the drop (validates again, persists, explains refusals).
  final void Function(PlayerCard dragged, SquadDropTarget target) onSwap;

  /// Null when moving the empty formation place [slot] to [cell] is
  /// allowed, otherwise the reason. Null callback: empty places are not
  /// draggable.
  final String? Function(int slot, GridCell cell)? slotRejection;

  /// Performs the move of the empty place [slot] to [cell] (validates
  /// again, persists the new formation, explains refusals).
  final void Function(int slot, GridCell cell)? onMoveSlot;
}

/// Published by [SquadDragHost] to the draggable cards and drop zones
/// beneath it.
class SquadDragScope extends InheritedWidget {
  const SquadDragScope({
    super.key,
    required this.swapping,
    required this.dragging,
    required this.slotDragging,
    required this.begin,
    required this.beginSlot,
    required this.update,
    required this.end,
    required super.child,
  });

  final SquadSwapping swapping;

  /// The player currently held, or null.
  final ValueNotifier<PlayerCard?> dragging;

  /// The empty formation place currently held (its slot index), or null.
  final ValueNotifier<int?> slotDragging;

  final void Function(PlayerCard card) begin;
  final void Function(int slot) beginSlot;
  final void Function(Offset globalPosition) update;
  final VoidCallback end;

  static SquadDragScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SquadDragScope>();

  // The owner's validation closure captures the current squad, so it must
  // reach the cards on every rebuild.
  @override
  bool updateShouldNotify(SquadDragScope oldWidget) => true;
}

/// Owns the drag state and scrolls the page while a card is held near its
/// top or bottom edge — the pitch is taller than the screen, so dragging
/// a bench player onto the pitch needs the page to move under the finger.
class SquadDragHost extends StatefulWidget {
  const SquadDragHost({super.key, required this.swapping, required this.child});

  final SquadSwapping swapping;
  final Widget child;

  @override
  State<SquadDragHost> createState() => _SquadDragHostState();
}

class _SquadDragHostState extends State<SquadDragHost> {
  final ValueNotifier<PlayerCard?> _dragging = ValueNotifier(null);
  final ValueNotifier<int?> _slotDragging = ValueNotifier(null);
  Offset? _pointer;
  Timer? _scrollTimer;

  /// How close to the viewport edge (logical px) the page starts to scroll.
  static const double _edge = 96;

  /// Fastest scroll, in logical px per 16ms tick.
  static const double _maxStep = 14;

  void _begin(PlayerCard card) {
    _dragging.value = card;
  }

  void _beginSlot(int slot) {
    _slotDragging.value = slot;
  }

  void _update(Offset globalPosition) {
    _pointer = globalPosition;
    _scrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _scrollTick(),
    );
  }

  void _end() {
    _dragging.value = null;
    _slotDragging.value = null;
    _pointer = null;
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _scrollTick() {
    final p = _pointer;
    if (p == null || !mounted) return;
    final scrollable = Scrollable.maybeOf(context);
    final box = scrollable?.context.findRenderObject();
    if (scrollable == null || box is! RenderBox || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    var step = 0.0;
    if (p.dy < top + _edge) {
      step = -_maxStep * (1 - ((p.dy - top) / _edge).clamp(0.0, 1.0));
    } else if (p.dy > bottom - _edge) {
      step = _maxStep * (1 - ((bottom - p.dy) / _edge).clamp(0.0, 1.0));
    }
    if (step == 0) return;
    final pos = scrollable.position;
    final next = (pos.pixels + step)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent)
        .toDouble();
    if (next != pos.pixels) pos.jumpTo(next);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _dragging.dispose();
    _slotDragging.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SquadDragScope(
      swapping: widget.swapping,
      dragging: _dragging,
      slotDragging: _slotDragging,
      begin: _begin,
      beginSlot: _beginSlot,
      update: _update,
      end: _end,
      child: widget.child,
    );
  }
}

/// Makes [child] hold-and-drag-able as [card]. A plain pass-through when
/// no [SquadDragScope] is above. A long press starts the drag, so taps
/// (the card showcase) and the strips' horizontal scrolling keep working.
class SquadDraggable extends StatelessWidget {
  const SquadDraggable({
    super.key,
    required this.card,
    required this.feedback,
    required this.feedbackSize,
    required this.child,
  });

  final PlayerCard card;

  /// What follows the finger (a mini card).
  final Widget feedback;
  final Size feedbackSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = SquadDragScope.maybeOf(context);
    if (scope == null) return child;
    return LongPressDraggable<PlayerCard>(
      data: card,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: (draggable, context, position) =>
          Offset(feedbackSize.width / 2, feedbackSize.height * 0.55),
      onDragStarted: () => scope.begin(card),
      onDragUpdate: (details) => scope.update(details.globalPosition),
      onDragEnd: (_) => scope.end(),
      feedback: Material(
        type: MaterialType.transparency,
        // Perf pass 2026-11-12: the 0.95 Opacity forced a saveLayer every
        // drag frame for an imperceptible tint; the scale reads the same
        // without it.
        child: Transform.scale(scale: 1.15, child: feedback),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      child: child,
    );
  }
}

/// Makes [child] a place a held player can be dropped. While a card is
/// held, every EMPTY place that would refuse him is hidden, a player's
/// card that would refuse him dims (it never vanishes), and the places
/// that accept him stay as they are; under the finger the ring turns
/// gold (will swap). A plain pass-through when no [SquadDragScope] is above.
class SquadDropZone extends StatelessWidget {
  const SquadDropZone({
    super.key,
    required this.target,
    required this.child,
    this.radius = 12,
  });

  final SquadDropTarget target;
  final Widget child;
  final double radius;

  bool _isSelf(PlayerCard dragged) =>
      target.card != null && target.card!.ownedId == dragged.ownedId;

  @override
  Widget build(BuildContext context) {
    final scope = SquadDragScope.maybeOf(context);
    if (scope == null) return child;
    return ValueListenableBuilder<PlayerCard?>(
      valueListenable: scope.dragging,
      child: child,
      builder: (context, dragged, child) => DragTarget<PlayerCard>(
        onWillAcceptWithDetails: (details) => !_isSelf(details.data),
        onAcceptWithDetails: (details) =>
            scope.swapping.onSwap(details.data, target),
        builder: (context, candidates, _) {
          final hovering = candidates.isNotEmpty;
          Color? ring;
          var ringWidth = 0.0;
          var fade = 1.0;
          if (dragged != null && !_isSelf(dragged)) {
            final ok = scope.swapping.rejection(dragged, target) == null;
            if (ok) {
              // No ring on the places he can go to — only the gold ring
              // on the one under the finger.
              if (hovering) {
                ring = FcmColors.gold;
                ringWidth = 2.5;
              }
            } else if (target.zone != SquadZone.reserves) {
              // A PLACE he cannot take (an empty placeholder) disappears
              // while he is held — but a PLAYER's card never does: it
              // only dims. Hiding the cards made the keeper vanish
              // whenever an outfield man was held, and the WHOLE outfield
              // vanish whenever a keeper was held.
              // (The pool strip is exempt: it is also where the held
              // card may come from, and hiding it would hide the source.)
              fade = target.card != null
                  ? 0.45
                  : (target.cell != null ? 0.25 : 0.0);
            }
          }
          return AnimatedOpacity(
            opacity: fade,
            duration: const Duration(milliseconds: 120),
            child: Container(
              foregroundDecoration: ring == null
                  ? null
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(color: ring, width: ringWidth),
                    ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

/// Makes [child] (an EMPTY formation place's cell) hold-and-drag-able: drag
/// it onto a free cell to move the place and reshape the formation. A plain
/// pass-through when no [SquadDragScope] is above or the owner did not
/// enable slot moves.
class SquadSlotDraggable extends StatelessWidget {
  const SquadSlotDraggable({
    super.key,
    required this.slot,
    required this.feedback,
    required this.feedbackSize,
    required this.child,
  });

  final int slot;

  /// What follows the finger (the ghost card).
  final Widget feedback;
  final Size feedbackSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = SquadDragScope.maybeOf(context);
    if (scope == null || scope.swapping.onMoveSlot == null) return child;
    return LongPressDraggable<int>(
      data: slot,
      maxSimultaneousDrags: 1,
      dragAnchorStrategy: (draggable, context, position) =>
          Offset(feedbackSize.width / 2, feedbackSize.height * 0.55),
      onDragStarted: () => scope.beginSlot(slot),
      onDragUpdate: (details) => scope.update(details.globalPosition),
      onDragEnd: (_) => scope.end(),
      feedback: Material(
        type: MaterialType.transparency,
        child: Transform.scale(scale: 1.15, child: feedback),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      child: child,
    );
  }
}

/// Makes [child] a FREE cell an empty formation place can be dropped on
/// (see [SquadSlotDraggable]). Gold ring under the finger when allowed.
class SquadSlotDropZone extends StatelessWidget {
  const SquadSlotDropZone({
    super.key,
    required this.cell,
    required this.child,
    this.radius = 8,
  });

  final GridCell cell;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scope = SquadDragScope.maybeOf(context);
    final move = scope?.swapping.onMoveSlot;
    if (scope == null || move == null) return child;
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) =>
          scope.swapping.slotRejection?.call(details.data, cell) == null,
      onAcceptWithDetails: (details) => move(details.data, cell),
      builder: (context, candidates, _) => Container(
        foregroundDecoration: candidates.isEmpty
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: FcmColors.gold, width: 2.5),
              ),
        child: child,
      ),
    );
  }
}
