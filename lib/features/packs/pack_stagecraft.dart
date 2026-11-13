/// FCM Rivals — pack opening stagecraft.
///
/// The extra layers that give every pack opening its own character on top
/// of the shared reveal timeline:
///
/// * [chargeGlowColor] — the pack's glow CLIMBS a colour ladder while it
///   charges (amethyst → sapphire → gold → crimson) and stops on the rung
///   of the card inside. Lower pulls also flash the NEXT rung for a beat (a
///   near miss) before settling — the "was that gold?!" moment.
/// * [AmbientPainter] — rarity-flavoured particles drifting around the
///   finished card (soft motes, rising crystals, falling gold dust,
///   crimson embers), so a great pull keeps glittering after the reveal.
/// * [LightningPainter] — the crimson 90+ pull's forked lightning.
///
/// Presentation only: nothing here touches the draw, the timelines or the
/// haptic marks.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';

/// The colour rungs of the charge ladder, lowest first: rare, epic,
/// legendary, premium (90+). Same jewels as the cards and shelves.
List<Color> chargeLadder() => [
  CardRarity.rare.accent,
  CardRarity.epic.accent,
  CardRarity.legendary.accent,
  CardClass.premium.accent,
];

/// Which ladder rung a pull stops on: 0 rare, 1 epic, 2 legendary,
/// 3 premium (90+).
int revealRank(CardRarity rarity, CardClass cardClass) =>
    cardClass == CardClass.premium ? 3 : rarity.index;

/// The pack's charge glow colour at [charge] (0..1) for a pull of [rank].
///
/// The first 70% of the charge climbs from rung 0 up to the pull's own
/// rung; a pull that is not already on the top rung also leans toward the
/// next rung between 55% and 88% of the charge (the near miss) and is back
/// on its own colour by the time the pack bursts (charge 1 → exactly the
/// pull's rung).
Color chargeGlowColor({
  required double charge,
  required int rank,
  List<Color>? ladder,
}) {
  final rungs = ladder ?? chargeLadder();
  final top = rungs.length - 1;
  final r = math.max(0, math.min(rank, top));
  final c = charge.clamp(0.0, 1.0).toDouble();
  // The burst: exactly the pull's own rung, no float residue from the tease.
  if (c >= 1.0) return rungs[r];
  final climb = const Interval(0.0, 0.7).transform(c) * r;
  final lo = math.max(0, math.min(climb.floor(), r));
  final hi = math.min(lo + 1, r);
  var color = Color.lerp(rungs[lo], rungs[hi], climb - lo)!;
  if (r < top) {
    final tease = math.sin(math.pi * const Interval(0.55, 0.88).transform(c));
    color = Color.lerp(color, rungs[r + 1], 0.55 * tease)!;
  }
  return color;
}

/// Deterministic 0..1 pseudo-random from [x] (no RNG state to carry).
double _hash(double x) {
  final s = math.sin(x * 12.9898) * 43758.5453;
  return s - s.floorToDouble();
}

/// How the ambient particles of a finished card behave.
enum AmbientStyle {
  /// Rare: a few soft motes drifting up.
  motes,

  /// Epic: small crystal shards rising and turning.
  crystals,

  /// Legendary: gold dust falling with the odd sparkle.
  goldDust,

  /// Premium 90+: hot crimson embers rising fast.
  embers,
}

/// Rarity-flavoured particles around the revealed card.
class AmbientPainter extends CustomPainter {
  AmbientPainter({
    required this.time,
    required this.style,
    required this.color,
    required this.strength,
    this.count = 24,
  });

  /// Looping 0..1 clock (the screen's 30s spin controller): each particle
  /// completes a whole number of laps per loop, so it never jumps.
  final double time;
  final AmbientStyle style;
  final Color color;

  /// 0..1 overall opacity; 0 draws nothing.
  final double strength;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final r1 = _hash(i * 1.0 + 1);
      final r2 = _hash(i * 7.0 + 3);
      final r3 = _hash(i * 13.0 + 5);
      final laps = 3 + (r2 * 5).floor();
      final prog = (time * laps + r3) % 1.0;
      final fadeInOut = math.sin(math.pi * prog);
      final x = r1 * size.width;
      switch (style) {
        case AmbientStyle.motes:
          {
          paint.color = Colors.white.withValues(
            alpha: (0.30 * strength * fadeInOut).clamp(0.0, 1.0),
          );
          canvas.drawCircle(
            Offset(x + math.sin((prog + r1) * 2 * math.pi) * 8,
                size.height * (1 - prog)),
            1.2 + 2.0 * r2,
            paint,
          );
          }
        case AmbientStyle.crystals:
          {
          final y = size.height * (1 - prog);
          final s = 3.0 + 4.0 * r2;
          final spin = prog * 2 * math.pi * (r3 > 0.5 ? 1 : -1);
          paint.color = Color.lerp(color, Colors.white, 0.45)!.withValues(
            alpha: (0.55 * strength * fadeInOut).clamp(0.0, 1.0),
          );
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(spin);
          canvas.drawPath(
            Path()
              ..moveTo(0, -s)
              ..lineTo(s * 0.6, 0)
              ..lineTo(0, s)
              ..lineTo(-s * 0.6, 0)
              ..close(),
            paint,
          );
          canvas.restore();
          }
        case AmbientStyle.goldDust:
          {
          final y = size.height * prog;
          final sway = math.sin((prog * 2 + r1) * 2 * math.pi) * 12;
          paint.color = Color.lerp(color, Colors.white, 0.35 * r3)!.withValues(
            alpha: (0.70 * strength * fadeInOut).clamp(0.0, 1.0),
          );
          final p = Offset(x + sway, y);
          if (i % 5 == 0) {
            final s = 3.5 + 3.0 * r2;
            canvas.drawPath(
              Path()
                ..moveTo(p.dx, p.dy - s)
                ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
                ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
                ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
                ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s)
                ..close(),
              paint,
            );
          } else {
            canvas.drawCircle(p, 1.5 + 2.5 * r2, paint);
          }
          }
        case AmbientStyle.embers:
          {
          final y = size.height * (1 - prog);
          final sway = math.sin((prog * 3 + r1) * 2 * math.pi) * 14;
          final flicker = 0.6 + 0.4 * math.sin((prog * 9 + r2) * 2 * math.pi);
          paint
            ..color = Color.lerp(color, Colors.white, 0.4 * r3)!.withValues(
              alpha: (0.80 * strength * fadeInOut * flicker).clamp(0.0, 1.0),
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
          canvas.drawCircle(Offset(x + sway, y), 1.6 + 3.0 * r2, paint);
          paint.maskFilter = null;
          }
      }
    }
  }

  @override
  bool shouldRepaint(AmbientPainter old) =>
      old.time != time ||
      old.strength != strength ||
      old.style != style ||
      old.color != color ||
      old.count != count;
}

/// Forked lightning for the crimson 90+ pull: bolts re-roll roughly every
/// 0.2s of a 20s timeline so they crackle instead of sliding.
class LightningPainter extends CustomPainter {
  LightningPainter({
    required this.strength,
    required this.time,
    required this.color,
    this.bolts = 7,
  });

  /// 0..1 overall intensity; 0 draws nothing.
  final double strength;

  /// The reveal timeline fraction (0..1); the bolt layout re-rolls with it.
  final double time;
  final Color color;
  final int bolts;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    final reach = size.shortestSide * 0.85;
    final tick = (time * 90).floor();
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < bolts; i++) {
      final seed = i * 31.0 + tick * 7.0;
      // Some bolts blink out between re-rolls — the crackle.
      if (_hash(seed + 99) < 0.35) continue;
      final angle = _hash(seed) * 2 * math.pi;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final perp = Offset(-dir.dy, dir.dx);
      final len = reach * (0.5 + 0.6 * _hash(seed + 1));
      const segs = 7;
      final path = Path()..moveTo(c.dx + dir.dx * 44, c.dy + dir.dy * 44);
      for (var s = 1; s <= segs; s++) {
        final along = s / segs;
        final jitter = (_hash(seed + s * 3.7) - 0.5) * 64;
        final p = c + dir * (44 + (len - 44) * along) + perp * jitter;
        path.lineTo(p.dx, p.dy);
      }
      glow.color = color.withValues(
        alpha: (0.45 * strength).clamp(0.0, 1.0),
      );
      core.color = Colors.white.withValues(
        alpha: (0.9 * strength).clamp(0.0, 1.0),
      );
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  @override
  bool shouldRepaint(LightningPainter old) =>
      old.strength != strength ||
      old.time != time ||
      old.color != color ||
      old.bolts != bolts;
}
