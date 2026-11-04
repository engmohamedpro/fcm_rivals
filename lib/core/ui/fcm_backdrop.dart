/// FCM Rivals — shared premium UI kit: {title}.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'fcm_style.dart';

// -----------------------------------------------------------------------------
// Backdrop
// -----------------------------------------------------------------------------

/// Animated stadium-night background. Honours the system "reduce motion"
/// setting by freezing the drift.
class FcmBackdrop extends StatefulWidget {
  const FcmBackdrop({super.key, this.child, this.tint});

  final Widget? child;

  /// Optional accent that colours one of the light orbs.
  final Color? tint;

  @override
  State<FcmBackdrop> createState() => _FcmBackdropState();
}

class _FcmBackdropState extends State<FcmBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 26),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BackdropPainter(_c, widget.tint ?? FcmColors.gold),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.anim, this.tint) : super(repaint: anim);

  final Animation<double> anim;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = anim.value * 2 * math.pi;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151318), FcmColors.night, Color(0xFF09080C)],
        ).createShader(rect),
    );

    void orb(Offset c, double r, Color color, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final w = size.width, h = size.height;
    final base = math.max(w, h);
    orb(
      Offset(w * (0.2 + 0.1 * math.sin(t)), h * (0.12 + 0.05 * math.cos(t))),
      base * 0.55,
      FcmColors.gold,
      0.11,
    );
    orb(
      Offset(
        w * (0.85 + 0.08 * math.cos(t * 2)),
        h * (0.35 + 0.06 * math.sin(t)),
      ),
      base * 0.42,
      tint,
      0.07,
    );
    orb(
      Offset(
        w * (0.5 + 0.12 * math.sin(t * 1.5)),
        h * (1.0 + 0.03 * math.cos(t)),
      ),
      base * 0.55,
      FcmColors.pitch,
      0.12,
    );

    // Faint stadium-light diagonals.
    final line = Paint()
      ..color = FcmColors.goldSoft.withValues(alpha: 0.016)
      ..strokeWidth = 26;
    for (var i = -3; i < 8; i++) {
      final x = w * i / 5 + math.sin(t) * 14;
      canvas.drawLine(Offset(x, 0), Offset(x + h * 0.6, h), line);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.tint != tint;
}

