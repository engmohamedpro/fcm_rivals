/// FCM Rivals — FIFA-style player card (GDD 5.6 / 7.1).
///
/// Drawn with [CustomPainter] so the card has a real shield silhouette, a
/// rarity gradient, a foil light sweep and a player silhouette, with the
/// rating and attributes laid on top. Stats count up from zero driven by
/// [statProgress] so the reveal can animate them.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/players.dart';
import 'country_flag.dart';
import 'fcm_style.dart';

/// Width : height ratio of the card.
const double kPlayerCardAspect = 0.70;

class PlayerCard extends StatelessWidget {
  const PlayerCard({
    super.key,
    required this.player,
    required this.rarity,
    this.width = 260,
    this.shine,
    this.statProgress = 1.0,
    this.glow = 0.0,
  });

  final BasePlayer player;
  final CardRarity rarity;

  /// Card width; height follows [kPlayerCardAspect].
  final double width;

  /// Foil sweep position, 0..1 across the card. `null` hides the sweep.
  final double? shine;

  /// 0..1 — how far the rating and attribute numbers have counted up.
  final double statProgress;

  /// 0..1 — outer glow strength behind the card.
  final double glow;

  /// The attributes worth showing: outfield players hide their goalkeeping
  /// score, goalkeepers hide ATT, so every card shows meaningful numbers.
  static List<({String label, int value})> statsFor(BasePlayer p) {
    final s = p.baseStats;
    if (p.position.isGoalkeeper) {
      return [
        (label: 'GK', value: s.goalkeeping),
        (label: 'DEF', value: s.defence),
        (label: 'SUP', value: s.support),
      ];
    }
    return [
      (label: 'ATT', value: s.attack),
      (label: 'SUP', value: s.support),
      (label: 'DEF', value: s.defence),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final w = width;
    final h = width / kPlayerCardAspect;
    final ink = rarity.ink;
    final p = statProgress.clamp(0.0, 1.0);
    final ovr = (player.baseStats.overall * p).round();
    final stats = statsFor(player);

    return SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            if (glow > 0)
              BoxShadow(
                color: rarity.accent.withValues(alpha: 0.65 * glow),
                blurRadius: 50 * glow,
                spreadRadius: 6 * glow,
              ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CardFacePainter(rarity: rarity, shine: shine),
              ),
            ),
            // Rating, position, flag.
            Positioned(
              left: w * 0.11,
              top: h * 0.105,
              width: w * 0.24,
              child: Column(
                children: [
                  Text(
                    '$ovr',
                    style: TextStyle(
                      color: ink,
                      fontSize: w * 0.20,
                      fontWeight: FontWeight.w900,
                      height: 0.95,
                    ),
                  ),
                  Text(
                    player.position.code,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.92),
                      fontSize: w * 0.085,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: h * 0.012),
                    height: 2,
                    width: w * 0.12,
                    color: ink.withValues(alpha: 0.4),
                  ),
                  Text(flagEmojiFor(player.nationality),
                      style: TextStyle(fontSize: w * 0.095)),
                ],
              ),
            ),
            // Tier ribbon, top-right.
            Positioned(
              right: w * 0.10,
              top: h * 0.085,
              child: Text(
                rarity.label,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.75),
                  fontSize: w * 0.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            // Name plate.
            Positioned(
              left: w * 0.07,
              right: w * 0.07,
              top: h * 0.565,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  player.name.toUpperCase(),
                  maxLines: 1,
                  style: TextStyle(
                    color: ink,
                    fontSize: w * 0.092,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            Positioned(
              left: w * 0.07,
              right: w * 0.07,
              top: h * 0.64,
              child: Text(
                '${player.club} · ${player.age}y',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.78),
                  fontSize: w * 0.046,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Attribute row.
            Positioned(
              left: w * 0.12,
              right: w * 0.12,
              top: h * 0.705,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final s in stats)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(s.value * p).round()}',
                          style: TextStyle(
                            color: ink,
                            fontSize: w * 0.105,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        Text(
                          s.label,
                          style: TextStyle(
                            color: ink.withValues(alpha: 0.75),
                            fontSize: w * 0.048,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card back shown before the flip.
class PlayerCardBack extends StatelessWidget {
  const PlayerCardBack({super.key, required this.rarity, this.width = 260});

  final CardRarity rarity;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width / kPlayerCardAspect;
    return SizedBox(
      width: width,
      height: h,
      child: CustomPaint(painter: _CardBackPainter(rarity: rarity)),
    );
  }
}

/// Shield-shaped card outline.
Path cardPath(Size s) {
  final w = s.width, h = s.height;
  return Path()
    ..moveTo(0, h * 0.06)
    ..quadraticBezierTo(w * 0.5, -h * 0.012, w, h * 0.06)
    ..lineTo(w, h * 0.87)
    ..quadraticBezierTo(w, h * 0.94, w * 0.5, h)
    ..quadraticBezierTo(0, h * 0.94, 0, h * 0.87)
    ..close();
}

class _CardFacePainter extends CustomPainter {
  _CardFacePainter({required this.rarity, required this.shine});

  final CardRarity rarity;
  final double? shine;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = cardPath(size);

    // Base gradient.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: rarity.faceGradient,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(path);

    // Diagonal foil stripes.
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = size.width * 0.05;
    for (var x = -size.height; x < size.width + size.height; x += size.width * 0.16) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }

    // Soft top light.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.8),
          radius: 0.9,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    // Player silhouette (head + shoulders), right of centre.
    final sil = Paint()..color = Colors.black.withValues(alpha: 0.22);
    final cx = size.width * 0.62;
    final headR = size.width * 0.13;
    final headY = size.height * 0.26;
    canvas.drawCircle(Offset(cx, headY), headR, sil);
    final shoulders = Path()
      ..moveTo(cx - size.width * 0.30, size.height * 0.56)
      ..quadraticBezierTo(
          cx - size.width * 0.28, headY + headR * 1.25, cx, headY + headR * 1.2)
      ..quadraticBezierTo(cx + size.width * 0.28, headY + headR * 1.25,
          cx + size.width * 0.30, size.height * 0.56)
      ..close();
    canvas.drawPath(shoulders, sil);

    // Bottom darkening so the stats read well.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.28),
          ],
        ).createShader(
            Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5)),
    );

    // Foil sweep.
    final s = shine;
    if (s != null) {
      final cxs = -size.width * 0.4 + s * size.width * 1.8;
      final sweep = Path()
        ..moveTo(cxs - size.width * 0.18, size.height)
        ..lineTo(cxs + size.width * 0.05, size.height)
        ..lineTo(cxs + size.width * 0.5, 0)
        ..lineTo(cxs + size.width * 0.27, 0)
        ..close();
      canvas.drawPath(
        sweep,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.55),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(
              cxs - size.width * 0.18, 0, size.width * 0.7, size.height)),
      );
    }
    canvas.restore();

    // Inner and outer borders.
    canvas.drawPath(
      path.shift(Offset.zero),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.save();
    canvas.translate(size.width * 0.03, size.height * 0.02);
    canvas.scale(0.94, 0.96);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.006
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardFacePainter old) =>
      old.rarity != rarity || old.shine != shine;
}

class _CardBackPainter extends CustomPainter {
  _CardBackPainter({required this.rarity});

  final CardRarity rarity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = cardPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF16307A), Color(0xFF071236)],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipPath(path);
    // Concentric rings + crest in the rarity colour.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = rarity.accent.withValues(alpha: 0.35);
    final c = Offset(size.width / 2, size.height / 2);
    for (var i = 1; i <= 5; i++) {
      canvas.drawCircle(c, size.width * 0.1 * i, ring);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: 'FCM',
        style: TextStyle(
          color: rarity.accent,
          fontSize: size.width * 0.26,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.014
        ..color = rarity.accent,
    );
  }

  @override
  bool shouldRepaint(_CardBackPainter old) => old.rarity != rarity;
}

/// Convenience: sin-based 0..1 pulse for idle glows.
double pulse(double t, {double cycles = 1}) =>
    0.5 + 0.5 * math.sin(t * 2 * math.pi * cycles);
