/// FCM Rivals — pack burst particle painters.
///
/// Light rays, sparks, the particle burst and the shockwave rings
/// behind the reveal, split verbatim out of `pack_effects.dart`
/// (T-0040).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';

/// Rotating light beams from the centre — the stadium floodlight look.
class LightRaysPainter extends CustomPainter {
  LightRaysPainter({
    required this.rotation,
    required this.color,
    required this.strength,
    this.rays = 14,
  });

  /// Rotation in turns (0..1 is a full revolution).
  final double rotation;
  final Color color;

  /// 0..1 overall opacity.
  final double strength;
  final int rays;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    final radius = size.longestSide;
    final slice = 2 * math.pi / rays;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.55 * strength),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: c, radius: radius));
    for (var i = 0; i < rays; i++) {
      final a = rotation * 2 * math.pi + i * slice;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a) * radius, c.dy + math.sin(a) * radius)
        ..lineTo(
          c.dx + math.cos(a + slice * 0.42) * radius,
          c.dy + math.sin(a + slice * 0.42) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(LightRaysPainter old) =>
      old.rotation != rotation ||
      old.strength != strength ||
      old.color != color;
}

/// One spark of the burst; all values are fixed at creation.
class Spark {
  Spark(math.Random r)
    : angle = r.nextDouble() * 2 * math.pi,
      speed = 0.35 + r.nextDouble() * 0.85,
      size = 2 + r.nextDouble() * 5,
      delay = r.nextDouble() * 0.15,
      gold = r.nextBool();

  final double angle;
  final double speed;
  final double size;
  final double delay;
  final bool gold;
}

/// Sparks flying outward from the pack with a little gravity.
class ParticleBurstPainter extends CustomPainter {
  ParticleBurstPainter({
    required this.progress,
    required this.sparks,
    required this.color,
  });

  /// 0..1 since the burst began; 0 draws nothing.
  final double progress;
  final List<Spark> sparks;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    final reach = size.shortestSide * 0.95;
    for (final s in sparks) {
      final t = ((progress - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final eased = 1 - math.pow(1 - t, 3).toDouble();
      final pos =
          c +
          Offset(math.cos(s.angle), math.sin(s.angle)) *
              (reach * s.speed * eased) +
          Offset(0, 90 * t * t);
      final alpha = (1 - t).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        s.size * (1 - 0.5 * t),
        Paint()
          ..color = (s.gold ? FcmColors.gold : color).withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(ParticleBurstPainter old) => old.progress != progress;
}

/// Expanding golden shock rings — the pressure wave of a legendary burst.
class ShockwavePainter extends CustomPainter {
  ShockwavePainter({
    required this.progress,
    required this.color,
    this.rings = 3,
  });

  /// 0..1 since the wave began; 0 draws nothing.
  final double progress;
  final Color color;
  final int rings;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    final reach = size.longestSide * 0.75;
    for (var i = 0; i < rings; i++) {
      final delay = i * 0.14;
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0).toDouble();
      if (t <= 0) continue;
      final eased = 1 - math.pow(1 - t, 2.2).toDouble();
      canvas.drawCircle(
        c,
        reach * eased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10.0 * (1 - t) + 1.0
          ..color = color.withValues(alpha: (1 - t) * 0.75)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  @override
  bool shouldRepaint(ShockwavePainter old) =>
      old.progress != progress || old.color != color;
}
