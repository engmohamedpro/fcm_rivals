/// FCM Rivals — shared premium UI kit: {title}.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'fcm_widgets_helpers.dart';

// -----------------------------------------------------------------------------
// Motion helpers
// -----------------------------------------------------------------------------

/// Fade + slide-in with a stagger by [index]. Plays once when first built.
/// Uses a single controller with an [Interval] delay (no timers).
class FcmEntrance extends StatefulWidget {
  const FcmEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.dx = 0,
    this.dy = 22,
    this.duration = const Duration(milliseconds: 480),
    this.stagger = const Duration(milliseconds: 60),
    this.maxStaggered = 10,
  });

  final Widget child;
  final int index;
  final double dx;
  final double dy;
  final Duration duration;
  final Duration stagger;
  final int maxStaggered;

  @override
  State<FcmEntrance> createState() => _FcmEntranceState();
}

class _FcmEntranceState extends State<FcmEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.stagger * math.min(widget.index, widget.maxStaggered);
    final total = widget.duration + delay;
    _c = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _c,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - v) * widget.dx, (1 - v) * widget.dy),
            child: child,
          ),
        );
      },
    );
  }
}

/// Press-scale feedback with a haptic tick. Pass `onTap: null` to disable.
class FcmPressable extends StatefulWidget {
  const FcmPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<FcmPressable> createState() => _FcmPressableState();
}

class _FcmPressableState extends State<FcmPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        if (widget.haptic) fcmTick();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Number that rolls to its new value whenever [value] changes.
class FcmCountUp extends StatelessWidget {
  const FcmCountUp({
    super.key,
    required this.value,
    this.style,
    this.format,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final TextStyle? style;
  final String Function(int)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return Text(
          format != null ? format!(n) : '$n',
          maxLines: 1,
          softWrap: false,
          style: style,
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Text
// -----------------------------------------------------------------------------

/// Single-line text that scales down to fit its box instead of wrapping,
/// clipping or overflowing — the default for numbers, labels and names.
class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    this.style,
    this.align = Alignment.centerLeft,
  });

  final String text;
  final TextStyle? style;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}

