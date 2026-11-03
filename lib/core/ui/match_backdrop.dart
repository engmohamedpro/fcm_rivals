/// FCM Rivals — stadium backdrop for the live match screen.
///
/// The uploaded match-day photo as the base layer with a very slow Ken
/// Burns drift (zoom + pan breathing, mirrored each half-cycle so it
/// never snaps back), a legibility scrim on top (the scoreboard and the
/// commentary feed read directly on this background), and the app's
/// signature ambient light over everything: the same drifting orbs and
/// faint stadium-light diagonals as [FcmBackdrop], plus one slowly
/// sweeping floodlight beam for the big-match feel. The photo therefore
/// reads as a live scene, not a static wallpaper, while every panel on
/// top stays readable.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fcm_style.dart';

/// The stadium photo shipped with the app (assets/images/match_bg.jpg).
const String kMatchBackgroundAsset = 'assets/images/match_bg.jpg';

class FcmMatchBackdrop extends StatefulWidget {
  const FcmMatchBackdrop({super.key, this.child, this.tint});

  final Widget? child;

  /// Optional accent that colours one of the ambient orbs.
  final Color? tint;

  @override
  State<FcmMatchBackdrop> createState() => _FcmMatchBackdropState();
}

class _FcmMatchBackdropState extends State<FcmMatchBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 34),
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
        // Photo layer: Ken Burns drift around a slowly moving anchor
        // point. Scaling around an off-centre alignment pans the image,
        // so one sinusoidal transform gives zoom + drift with no snap.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value * 2 * math.pi;
              final zoom = 1.07 + 0.06 * math.sin(t);
              final ax = 0.5 + 0.055 * math.sin(t + 1.2);
              final ay = 0.5 + 0.04 * math.cos(t * 0.5 + 0.7);
              return Transform(
                alignment: Alignment(-1 + 2 * ax, -1 + 2 * ay),
                transform: Matrix4.identity()
                  ..scaleByDouble(zoom, zoom, zoom, 1),
                child: Image.asset(
                  kMatchBackgroundAsset,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              );
            },
          ),
        ),
        // Scrim + ambient light layer.
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MatchScrimPainter(_c, widget.tint ?? FcmColors.gold),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

/// Paints everything between the photo and the UI: a vertical scrim
/// (darkest behind the scoreboard and the commentary feed, where text
/// sits directly on the background), the app's drifting orbs and faint
/// light diagonals, and one wide floodlight beam that sweeps across the
/// pitch once per cycle.
class _MatchScrimPainter extends CustomPainter {
  _MatchScrimPainter(this.anim, this.tint) : super(repaint: anim);

  final Animation<double> anim;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width, h = size.height;
    final base = math.max(w, h);
    final t = anim.value * 2 * math.pi;

    // Legibility scrim: strong at the very top (scoreboard) and along
    // the bottom (commentary), lighter across the middle so the stadium
    // itself stays visible.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xCC0B0A0E),
            Color(0x8C0B0A0E),
            Color(0x660B0A0E),
            Color(0xB30B0A0E),
          ],
          stops: [0.0, 0.22, 0.55, 1.0],
        ).createShader(rect),
    );

    // Ambient orbs — same motion language as FcmBackdrop.
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

    orb(
      Offset(w * (0.2 + 0.1 * math.sin(t)), h * (0.12 + 0.05 * math.cos(t))),
      base * 0.55,
      FcmColors.gold,
      0.10,
    );
    orb(
      Offset(
        w * (0.85 + 0.08 * math.cos(t * 2)),
        h * (0.35 + 0.06 * math.sin(t)),
      ),
      base * 0.42,
      tint,
      0.06,
    );
    orb(
      Offset(
        w * (0.5 + 0.12 * math.sin(t * 1.5)),
        h * (1.0 + 0.03 * math.cos(t)),
      ),
      base * 0.55,
      FcmColors.pitch,
      0.09,
    );

    // Faint stadium-light diagonals.
    final line = Paint()
      ..color = FcmColors.goldSoft.withValues(alpha: 0.015)
      ..strokeWidth = 26;
    for (var i = -3; i < 8; i++) {
      final x = w * i / 5 + math.sin(t) * 14;
      canvas.drawLine(Offset(x, 0), Offset(x + h * 0.6, h), line);
    }

    // The floodlight sweep: one wide soft beam that travels across the
    // stadium once per cycle. Alpha breathes with the sweep so the beam
    // fades in from the left and out to the right.
    final sweep = (math.sin(t) + 1) / 2; // 0..1 across the cycle
    final beamAlpha = 0.075 * math.sin(math.pi * sweep);
    if (beamAlpha > 0.002) {
      final cx = w * (-0.2 + 1.4 * sweep);
      canvas.save();
      canvas.translate(cx, h * 0.5);
      canvas.rotate(-0.38);
      final beamW = w * 0.34;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: beamW, height: h * 1.8),
        Paint()
          ..shader =
              LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  FcmColors.goldSoft.withValues(alpha: 0),
                  FcmColors.goldSoft.withValues(alpha: beamAlpha),
                  FcmColors.goldSoft.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: beamW,
                  height: h * 1.8,
                ),
              ),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MatchScrimPainter old) => old.tint != tint;
}
