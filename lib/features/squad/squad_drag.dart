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
import 'squad_engine.dart' show PlayerCard;
import 'squad_swap.dart';

/// What the owner of the squad supplies to enable swapping.
class SquadSwapping {
  const SquadSwapping({required this.rejection, required this.onSwap});

  /// Null when dropping [dragged] on [target] is allowed, otherwise the
  /// reason it is not (drives the green / red hover feedback).
  final String? Function(PlayerCard dragged, SquadDropTarget target)
      rejection;

  /// Performs the drop (validates again, persists, explains refusals).
  final void Function(PlayerCard dragged, SquadDropTarget target) onSwap;
}

/// Published by [SquadDragHost] to the draggable cards and drop zones
/// beneath it.
class SquadDragScope extends InheritedWidget {
  const SquadDragScope({
    super.key,
    required this.swapping,
    required this.dragging,
    required this.begin,
    required this.update,
    required this.end,
    required super.child,
  });

  final SquadSwapping swapping;

  /// The player currently held, or null.
  final ValueNotifier<PlayerCard?> dragging;

  final void Function(PlayerCard card) begin;
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
  const SquadDragHost({
    super.key,
    required this.swapping,
    required this.child,
  });

  final SquadSwapping swapping;
  final Widget child;

  @override
  State<SquadDragHost> createState() => _SquadDragHostState();
}

class _SquadDragHostState extends State<SquadDragHost> {
  final ValueNotifier<PlayerCard?> _dragging = ValueNotifier(null);
  Offset? _pointer;
  Timer? _scrollTimer;

  /// How close to the viewport edge (logical px) the page starts to scroll.
  static const double _edge = 96;

  /// Fastest scroll, in logical px per 16ms tick.
  static const double _maxStep = 14;

  void _begin(PlayerCard card) {
    _dragging.value = card;
  }

  void _update(Offset globalPosition) {
    _pointer = globalPosition;
    _scrollTimer ??=
        Timer.periodic(const Duration(milliseconds: 16), (_) => _scrollTick());
  }

  void _end() {
    _dragging.value = null;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SquadDragScope(
      swapping: widget.swapping,
      dragging: _dragging,
      begin: _begin,
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
        child: Transform.scale(
          scale: 1.15,
          child: Opacity(opacity: 0.95, child: feedback),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      child: child,
    );
  }
}

/// Makes [child] a place a held player can be dropped. While a card is
/// held, every place that would accept him glows green and every refused
/// one dims; under the finger the ring turns gold (will swap) or red
/// (refused — the drop then explains why). A plain pass-through when no
/// [SquadDragScope] is above.
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
              ring = hovering
                  ? FcmColors.gold
                  : FcmColors.success.withValues(alpha: 0.6);
              ringWidth = hovering ? 2.5 : 1.5;
            } else {
              ring = hovering ? FcmColors.danger : null;
              ringWidth = 2.5;
              fade = hovering ? 1.0 : 0.55;
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

/// The one-line instruction shown above the pitch when swapping is on.
class SquadSwapHint extends StatelessWidget {
  const SquadSwapHint({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 16, color: FcmColors.textDim),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Hold a player and drop him on another to swap',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FcmColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
