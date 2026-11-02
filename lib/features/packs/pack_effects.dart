/// FCM Rivals — pack opening visual effects (CustomPainter based).
///
/// * [FoilPackPainter]  — the sealed foil pack with crimped edges, shimmer
///   and a light crack that grows while the pack charges.
/// * [LightRaysPainter] — rotating stadium-light beams behind the reveal.
/// * [ParticleBurstPainter] — sparks thrown out when the pack bursts.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';

/// Pack width : height.
const double kPackAspect = 0.62;

Path _packPath(Size s) {
  final w = s.width, h = s.height;
  const tooth = 9.0;
  const crimp = 16.0;
  final p = Path()..moveTo(0, crimp);
  // Top crimp (zig-zag), left → right.
  var x = 0.0;
  var up = true;
  p.lineTo(0, crimp);
  while (x < w) {
    final nx = math.min(x + tooth, w);
    p.lineTo(nx, up ? 0 : crimp);
    x = nx;
    up = !up;
  }
  p.lineTo(w, h - crimp);
  // Bottom crimp, right → left.
  x = w;
  up = true;
  while (x > 0) {
    final nx = math.max(x - tooth, 0.0);
    p.lineTo(nx, up ? h : h - crimp);
    x = nx;
    up = !up;
  }
  p.close();
  return p;
}

class FoilPackPainter extends CustomPainter {
  FoilPackPainter({
    required this.shimmer,
    required this.charge,
    required this.glowColor,
    this.tint,
  });

  /// 0..1 loop position of the idle foil shimmer.
  final double shimmer;

  /// 0..1 — how charged the pack is (grows the crack and hot glow).
  final double charge;

  /// Colour the pack's inner light turns toward while charging.
  final Color glowColor;

  /// Solid tier metal the whole foil is painted in — bronze / silver /
  /// gold at full strength, never a translucent wash. Null keeps the
  /// untinted charcoal leather — the classic sealed look.
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _packPath(size);

    // Foil palette: the brand charcoal, or the tier's own metallic ramp.
    final shades = tint == null ? null : _foilShades(tint!);

    // Drop shadow.
    canvas.drawShadow(path, Colors.black, 18, true);

    // Foil body: sheen at the top-left, tier metal across the middle,
    // deep shade at the bottom-right — the pack reads as a solid bronze
    // / silver / gold wrapper, not a dark one with a hint of colour.
    final bodyColors = shades == null
        ? const [Color(0xFF3A342C), Color(0xFF17161A), Color(0xFF0B0A0E)]
        : [shades[0], shades[1], shades[3]];
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bodyColors,
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(path);

    // Metal band across the middle — embossed dark edges, bright centre.
    final bandTop = size.height * 0.40;
    final bandRect =
        Rect.fromLTWH(0, bandTop, size.width, size.height * 0.20);
    final bandColors = shades == null
        ? const [Color(0xFF8A6E42), Color(0xFFF5E3B0), Color(0xFF8A6E42)]
        : [shades[2], shades[0], shades[2]];
    canvas.drawRect(
      bandRect,
      Paint()
        ..shader = LinearGradient(colors: bandColors)
            .createShader(bandRect),
    );

    // Wordmark.
    _text(canvas, 'FCM', size.width * 0.24, FcmColors.night,
        Offset(size.width / 2, bandRect.center.dy - size.height * 0.015),
        italic: true, spacing: -1);
    _text(canvas, 'RIVALS', size.width * 0.115, FcmColors.night,
        Offset(size.width / 2, bandRect.center.dy + size.height * 0.062),
        italic: true, spacing: 3);

    // Crown + stars above the band: bright tier metal when tinted.
    _text(canvas, '★  ★  ★', size.width * 0.07,
        shades == null ? FcmColors.gold : shades[0],
        Offset(size.width / 2, size.height * 0.30));
    _text(canvas, 'PLAYER PACK', size.width * 0.075,
        shades == null ? FcmColors.goldSoft : shades[0],
        Offset(size.width / 2, size.height * 0.76),
        spacing: 3);

    // Idle foil shimmer: warm champagne sweep.
    final sx = -size.width * 0.5 + shimmer * size.width * 2.2;
    final sweep = Path()
      ..moveTo(sx, size.height)
      ..lineTo(sx + size.width * 0.18, size.height)
      ..lineTo(sx + size.width * 0.18 + size.height * 0.45, 0)
      ..lineTo(sx + size.height * 0.45, 0)
      ..close();
    canvas.drawPath(
      sweep,
      Paint()
        ..shader = LinearGradient(colors: [
          FcmColors.goldSoft.withValues(alpha: 0.0),
          FcmColors.goldSoft.withValues(alpha: 0.30),
          FcmColors.goldSoft.withValues(alpha: 0.0),
        ]).createShader(
            Rect.fromLTWH(sx, 0, size.width * 0.7, size.height)),
    );

    // Charging: inner light bleeding through a growing crack.
    if (charge > 0) {
      final c = charge.clamp(0.0, 1.0);
      final mid = size.height * 0.5;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.2 + 0.9 * c,
            colors: [
              Color.lerp(Colors.white, glowColor, 0.5)!
                  .withValues(alpha: 0.85 * c),
              glowColor.withValues(alpha: 0.0),
            ],
          ).createShader(rect),
      );
      final crack = Path()..moveTo(size.width * 0.5, mid);
      final rnd = math.Random(7);
      for (final dir in [-1.0, 1.0]) {
        var x = size.width * 0.5;
        var y = mid;
        final reach = size.width * 0.55 * c;
        var travelled = 0.0;
        crack.moveTo(x, y);
        while (travelled < reach) {
          final step = size.width * 0.06;
          x += dir * step;
          y += (rnd.nextDouble() - 0.5) * size.height * 0.05;
          crack.lineTo(x, y);
          travelled += step;
        }
      }
      canvas.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.white.withValues(alpha: 0.35 * c)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: c),
      );
    }
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = shades == null
            ? FcmColors.gold.withValues(alpha: 0.45)
            : shades[0],
    );
  }

  /// Metallic ramp of a tier colour: [light, base, dark, deep]. Derived
  /// by shifting lightness only, so hue and saturation survive at full
  /// strength — bronze looks like bronze, silver like silver.
  static List<Color> _foilShades(Color base) {
    final hsl = HSLColor.fromColor(base);
    final l = hsl.lightness;
    Color shade(double lightness) =>
        hsl.withLightness(lightness.clamp(0.0, 0.92)).toColor();
    return [
      shade(l + 0.22), // sheen — top-left highlight and band centre
      base,            // the tier metal itself
      shade(l * 0.45 + 0.07), // embossed band edges
      shade(l * 0.25 + 0.04), // deep bottom-right of the foil
    ];
  }

  void _text(Canvas canvas, String text, double size, Color color,
      Offset center,
      {bool italic = false, double spacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w900,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          letterSpacing: spacing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(FoilPackPainter old) =>
      old.shimmer != shimmer ||
      old.charge != charge ||
      old.glowColor != glowColor;
}

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
        ..lineTo(c.dx + math.cos(a + slice * 0.42) * radius,
            c.dy + math.sin(a + slice * 0.42) * radius)
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
      final pos = c +
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
