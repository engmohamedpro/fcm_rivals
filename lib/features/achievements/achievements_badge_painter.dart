/// FCM Rivals — badge art per tier metal (T-0110).
///
/// A CustomPainter in the `card_rarity_art.dart` craft: strokes and
/// fills only, no blur, drawn in proportion to the badge size, the
/// premium visual language the rest of the game already speaks. The
/// laurel-and-star emblem reads tier metal from across the room:
///
/// * BRONZE — warm matte, a single low star.
/// * SILVER — cool sheen, two stars.
/// * GOLD — the house gold, three stars, a turning glint.
/// * PLATINUM — pale ice shine, four stars, sharper facets.
/// * LEGEND — the double sunburst, five stars, drifting sparkles.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'achievement_catalog.dart' show BadgeMetal;
import '../../core/ui/fcm_style.dart';

/// Paints one badge. The canvas is the caller's clip; [size] is the
/// full badge cell.
class FcmBadgePainter extends CustomPainter {
  FcmBadgePainter({required this.metal, this.phase});

  /// The tier's metal (T-0105).
  final BadgeMetal metal;

  /// 0..1 looping animation phase; null renders a calm static frame
  /// (the always-on ambient screens pass a phase; statics pass null).
  final double? phase;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.62;

    // Metal palette: rim, fill, sheen, glow — the house tokens for
    // bronze/silver/gold, cooler ice for platinum, and the legend's
    // royal gold pair.
    final (rim, fill, sheen, glow) = switch (metal) {
      BadgeMetal.bronze => (
        const Color(0xFF8A6E42),
        const Color(0xFF4A3A22),
        const Color(0xFFB08D5C),
        const Color(0x668A6E42),
      ),
      BadgeMetal.silver => (
        FcmColors.silver,
        const Color(0xFF565463),
        Colors.white.withValues(alpha: 0.75),
        const Color(0x66C9C4B8),
      ),
      BadgeMetal.gold => (
        FcmColors.gold,
        FcmColors.goldDeep,
        FcmColors.goldSoft,
        FcmColors.gold.withValues(alpha: 0.5),
      ),
      BadgeMetal.platinum => (
        const Color(0xFFDCE6EE),
        const Color(0xFF6B7B88),
        Colors.white.withValues(alpha: 0.85),
        const Color(0x66AFC4D4),
      ),
      BadgeMetal.legend => (
        FcmColors.goldSoft,
        const Color(0xFF3E2E10),
        FcmColors.gold,
        FcmColors.gold.withValues(alpha: 0.6),
      ),
    };

    // Legend: the turning double sunburst behind the emblem.
    if (metal == BadgeMetal.legend) {
      final spin = phase == null ? 0.12 : 0.12 + 0.25 * phase!;
      for (var ring = 0; ring < 2; ring++) {
        final rays = 12 + ring * 6;
        final rr = w * (0.52 - ring * 0.14);
        final sweep = math.pi / rays;
        for (var i = 0; i < rays; i++) {
          final a = spin + ring * 0.26 + i * 2 * math.pi / rays;
          final p = Path()
            ..moveTo(cx, cy)
            ..lineTo(cx + rr * math.cos(a - sweep), cy + rr * math.sin(a - sweep))
            ..lineTo(cx + rr * 0.86 * math.cos(a), cy + rr * 0.86 * math.sin(a))
            ..close();
          canvas.drawPath(
            p,
            Paint()
              ..color = glow.withValues(
                alpha: 0.28 + 0.12 * (ring == 0 ? 1 : 0),
              ),
          );
        }
      }
    }

    // The shield silhouette: a rounded shield with a notched base —
    // the identity shape, scaled to the cell.
    final s = math.min(w, h) * 0.92;
    final shield = Path()
      ..moveTo(cx - s * 0.38, cy - s * 0.42)
      ..quadraticBezierTo(cx, cy - s * 0.52, cx + s * 0.38, cy - s * 0.42)
      ..lineTo(cx + s * 0.38, cy + s * 0.16)
      ..quadraticBezierTo(cx + s * 0.30, cy + s * 0.42, cx, cy + s * 0.48)
      ..quadraticBezierTo(cx - s * 0.30, cy + s * 0.42, cx - s * 0.38, cy + s * 0.16)
      ..close();

    // Fill: metal body + rim.
    canvas.drawPath(
      shield,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fill, rim.withValues(alpha: 0.55), fill],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, s * 0.035)
        ..color = rim,
    );

    // The diagonal sheen band — the foil gloss pass, metal-scaled.
    final gloss = Path()
      ..moveTo(cx - s * 0.38, cy - s * 0.10)
      ..lineTo(cx - s * 0.05, cy - s * 0.42)
      ..lineTo(cx + s * 0.10, cy - s * 0.42)
      ..lineTo(cx - s * 0.22, cy - s * 0.02)
      ..close();
    canvas.drawPath(
      gloss,
      Paint()
        ..color = sheen.withValues(alpha: 0.16)
        ..blendMode = BlendMode.plus,
    );

    // Stars: the tier-meatl count, centred rows on the shield face.
    final starCount = switch (metal) {
      BadgeMetal.bronze => 1,
      BadgeMetal.silver => 2,
      BadgeMetal.gold => 3,
      BadgeMetal.platinum => 4,
      BadgeMetal.legend => 5,
    };
    final starR = s * 0.075;
    for (var i = 0; i < starCount; i++) {
      final row = i ~/ 3;
      final inRow = math.min(3, starCount - row * 3);
      final sx = cx + (i % 3 - (inRow - 1) / 2) * starR * 2.6;
      final sy = cy - s * 0.10 + row * starR * 2.4;
      final twinkle = phase == null
          ? 0.85
          : 0.55 + 0.45 *
                math.sin(2 * math.pi * (phase! * 1.4 + i * 0.31));
      _star(canvas, Offset(sx, sy), starR, sheen, 0.55 + 0.45 * twinkle);
    }

    // Legend: the drifting sparkles, phase-animated.
    if (metal == BadgeMetal.legend && phase != null) {
      final seeds = const [7, 19, 31, 47];
      for (var i = 0; i < seeds.length; i++) {
        final a = seeds[i].toDouble();
        final ox = cx + (w * 0.42) * math.cos(a + phase! * 1.9);
        final oy = cy - h * 0.36 + (h * 0.16) * math.sin(a * 3 + phase! * 2.3);
        final sparkle = 0.18 + 0.82 *
            math.pow(
              0.5 + 0.5 * math.sin(2 * math.pi * (phase! * 2 + i * 0.37)),
              3,
            );
        _sparkle(canvas, Offset(ox, oy), w * 0.03, FcmColors.goldSoft, sparkle);
      }
    }
  }

  /// Five-point star.
  void _star(Canvas canvas, Offset o, double r, Color color, double alpha) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.42;
      final a = -math.pi / 2 + i * math.pi / 5;
      final x = o.dx + rr * math.cos(a);
      final y = o.dy + rr * math.sin(a);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    p.close();
    canvas.drawPath(
      p,
      Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  /// Four-point sparkle (the rarity-art craft's shape).
  void _sparkle(Canvas canvas, Offset o, double r, Color color, double alpha) {
    if (alpha <= 0 || r <= 0) return;
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    canvas.drawPath(
      p,
      Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  @override
  bool shouldRepaint(FcmBadgePainter old) =>
      old.metal != metal || old.phase != phase;
}
