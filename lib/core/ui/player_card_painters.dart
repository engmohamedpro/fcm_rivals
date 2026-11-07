/// FCM Rivals — player card painters and drawing primitives
/// (extracted from `player_card.dart`, app-structure review task
/// `2026-11-05_app-structure_split-player-card`): the card outline
/// path, canvas helpers, the card-face and card-back CustomPainters.
/// Pure relocation — painting code unchanged.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fcm_style.dart';

/// Width : height ratio of the card.
const double kPlayerCardAspect = 0.70;

/// Premium card outline: chamfered top corners over a curved, tapering
/// base — the silhouette every card, ghost slot and warning ring shares.
Path cardPath(Size s) {
  final w = s.width, h = s.height;
  final c = w * 0.12;
  return Path()
    ..moveTo(c, 0)
    ..lineTo(w - c, 0)
    ..lineTo(w, c)
    ..lineTo(w, h * 0.865)
    ..quadraticBezierTo(w, h * 0.935, w * 0.5, h)
    ..quadraticBezierTo(0, h * 0.935, 0, h * 0.865)
    ..lineTo(0, c)
    ..close();
}

/// Scales the canvas about its centre so a [cardPath] drawn afterwards
/// lands [inset] pixels inside the full outline on every side.
void _insetCanvas(Canvas canvas, Size size, double inset) {
  canvas.translate(size.width / 2, size.height / 2);
  canvas.scale(
    (size.width - 2 * inset) / size.width,
    (size.height - 2 * inset) / size.height,
  );
  canvas.translate(-size.width / 2, -size.height / 2);
}

/// Tapered rays fanning out of [c] — the legendary face's sunburst.
void _paintRays(
  Canvas canvas,
  Offset c,
  double radius,
  Color color,
  double alpha,
  int rays,
) {
  final slice = 2 * math.pi / rays;
  final paint = Paint()
    ..shader = RadialGradient(
      colors: [
        color.withValues(alpha: alpha),
        color.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: c, radius: radius));
  for (var i = 0; i < rays; i++) {
    final a = i * slice;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a) * radius, c.dy + math.sin(a) * radius)
        ..lineTo(
          c.dx + math.cos(a + slice * 0.45) * radius,
          c.dy + math.sin(a + slice * 0.45) * radius,
        )
        ..close(),
      paint,
    );
  }
}

/// Small five-point star path for the card back's rarity row.
Path _cardStarPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final rad = i.isEven ? r : r * 0.45;
    final x = c.dx + math.cos(a) * rad;
    final y = c.dy + math.sin(a) * rad;
    if (i == 0) {
      p.moveTo(x, y);
    } else {
      p.lineTo(x, y);
    }
  }
  p.close();
  return p;
}

class CardFacePainter extends CustomPainter {
  CardFacePainter({
    required this.rarity,
    required this.shine,
    this.cardClass = CardClass.standard,
    this.glow = 0.0,
    this.glowColor,
  });

  final CardRarity rarity;
  final double? shine;

  /// The presentation-level class axis (T-0049): premium paints the red
  /// escalation above gold while the rarity stays legendary underneath.
  final CardClass cardClass;

  /// 0..1 aura strength following the card silhouette.
  final double glow;

  /// Aura colour; the rarity accent when null.
  final Color? glowColor;

  /// Effective palette: the red premium family overrides the legendary
  /// gold for 90+ players (the class rides on top of the rarity).
  List<Color> get _faceGradient =>
      cardClass == CardClass.premium
      ? cardClass.faceGradient
      : rarity.faceGradient;

  Color get _accent =>
      cardClass == CardClass.premium ? cardClass.accent : rarity.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final path = cardPath(size);
    final g = _faceGradient;
    final hair = math.max(0.5, w * 0.006);

    // Aura: a soft halo hugging the silhouette (not a square box).
    if (glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = (glowColor ?? _accent).withValues(
            alpha: (0.65 * glow).clamp(0.0, 1.0),
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10 * glow + 2),
      );
    }

    // Bezel: polished metal, white-hot top-left into the deep tone.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, g[0], g[1], g[2], g[1]],
          stops: const [0.0, 0.22, 0.5, 0.82, 1.0],
        ).createShader(rect),
    );

    // Face, inset inside the bezel.
    canvas.save();
    _insetCanvas(canvas, size, w * 0.034);
    canvas.clipPath(path);

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect),
    );

    // Diamond lattice.
    final lattice = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair
      ..color = Colors.white.withValues(alpha: 0.055);
    final step = w * 0.12;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), lattice);
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
    }

    // Rarity motif behind the player.
    final mc = Offset(w * 0.56, h * 0.29);
    switch (rarity) {
      case CardRarity.legendary:
        _paintRays(canvas, mc, h * 0.62, Colors.white, 0.26, 22);
      case CardRarity.epic:
        void tri(
          double x1,
          double y1,
          double x2,
          double y2,
          double x3,
          double y3,
          Color color,
        ) {
          canvas.drawPath(
            Path()
              ..moveTo(w * x1, h * y1)
              ..lineTo(w * x2, h * y2)
              ..lineTo(w * x3, h * y3)
              ..close(),
            Paint()..color = color,
          );
        }
        final lightShard = Colors.white.withValues(alpha: 0.10);
        final darkShard = Colors.black.withValues(alpha: 0.08);
        tri(0, 0, 0.64, 0, 0, 0.52, lightShard);
        tri(1, 0, 0.42, 0, 1, 0.58, darkShard);
        tri(0, 0.30, 0.55, 0.56, 0, 0.60, darkShard);
        tri(1, 0.36, 0.45, 0.56, 1, 0.62, lightShard);
      case CardRarity.rare:
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hair * 1.4
          ..color = Colors.white.withValues(alpha: 0.11);
        for (var i = 1; i <= 5; i++) {
          canvas.drawCircle(mc, w * 0.12 * i, arc);
        }
    }

    // Soft top light.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.75),
          radius: 0.95,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    // Player silhouette (head + shoulders), right of centre.
    final cx = w * 0.60;
    final headR = w * 0.125;
    final headY = h * 0.255;
    final silRect = Rect.fromLTWH(0, h * 0.1, w, h * 0.5);
    final sil = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.34),
          Colors.black.withValues(alpha: 0.10),
        ],
      ).createShader(silRect);
    canvas.drawCircle(Offset(cx, headY), headR, sil);
    canvas.drawPath(
      Path()
        ..moveTo(cx - w * 0.32, h * 0.57)
        ..quadraticBezierTo(
          cx - w * 0.30,
          headY + headR * 1.25,
          cx,
          headY + headR * 1.2,
        )
        ..quadraticBezierTo(
          cx + w * 0.30,
          headY + headR * 1.25,
          cx + w * 0.32,
          h * 0.57,
        )
        ..close(),
      sil,
    );

    // Dark glass information panel for name and attributes.
    final panelTop = h * 0.545;
    final panel = Rect.fromLTWH(0, panelTop, w, h - panelTop);
    canvas.drawRect(
      panel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.50),
            Colors.black.withValues(alpha: 0.84),
          ],
        ).createShader(panel),
    );
    final edge = Rect.fromLTWH(0, panelTop - hair, w, hair * 2);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = LinearGradient(
          colors: [
            g[0].withValues(alpha: 0.0),
            g[0],
            g[0].withValues(alpha: 0.0),
          ],
        ).createShader(edge),
    );

    // Name bar and the three attribute cells.
    final nameBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.07, h * 0.553, w * 0.86, h * 0.088),
      Radius.circular(h * 0.012),
    );
    canvas.drawRRect(
      nameBar,
      Paint()..color = Colors.white.withValues(alpha: 0.07),
    );
    canvas.drawRRect(
      nameBar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = g[0].withValues(alpha: 0.45),
    );
    final cellW = w * 0.84 / 3;
    for (var i = 0; i < 3; i++) {
      final cell = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          w * 0.08 + i * cellW + w * 0.012,
          h * 0.70,
          cellW - w * 0.024,
          h * 0.125,
        ),
        Radius.circular(h * 0.014),
      );
      canvas.drawRRect(
        cell,
        Paint()..color = Colors.white.withValues(alpha: 0.06),
      );
      canvas.drawRRect(
        cell,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hair
          ..color = g[0].withValues(alpha: 0.28),
      );
    }

    // Top gem and the brand mark at the foot.
    final gem = Offset(w / 2, h * 0.032);
    final gr = w * 0.024;
    final gemPath = Path()
      ..moveTo(gem.dx, gem.dy - gr)
      ..lineTo(gem.dx + gr, gem.dy)
      ..lineTo(gem.dx, gem.dy + gr)
      ..lineTo(gem.dx - gr, gem.dy)
      ..close();
    canvas.drawPath(
      gemPath,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawPath(
      gemPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = g[2].withValues(alpha: 0.8),
    );
    final brand = TextPainter(
      text: TextSpan(
        text: 'FCM',
        style: TextStyle(
          color: g[0].withValues(alpha: 0.85),
          fontSize: w * 0.06,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: w * 0.012,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    brand.paint(
      canvas,
      Offset(w / 2 - brand.width / 2, h * 0.915 - brand.height / 2),
    );

    // Foil sweep.
    final s = shine;
    if (s != null) {
      final cxs = -w * 0.4 + s * w * 1.8;
      final sweep = Path()
        ..moveTo(cxs - w * 0.18, h)
        ..lineTo(cxs + w * 0.05, h)
        ..lineTo(cxs + w * 0.5, 0)
        ..lineTo(cxs + w * 0.27, 0)
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
          ).createShader(Rect.fromLTWH(cxs - w * 0.18, 0, w * 0.7, h)),
      );
    }
    canvas.restore();

    // Face edge and a fine inner keyline, then the bright outer rim.
    canvas.save();
    _insetCanvas(canvas, size, w * 0.034);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = Colors.black.withValues(alpha: 0.4),
    );
    canvas.restore();
    canvas.save();
    _insetCanvas(canvas, size, w * 0.058);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = Colors.white.withValues(alpha: 0.30),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.012)
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(CardFacePainter old) =>
      old.rarity != rarity ||
      old.cardClass != cardClass ||
      old.shine != shine ||
      old.glow != glow ||
      old.glowColor != glowColor;
}

class CardBackPainter extends CustomPainter {
  CardBackPainter({required this.rarity, this.cardClass = CardClass.standard});

  final CardRarity rarity;

  /// The presentation-level class axis (T-0049): premium paints the red
  /// bezel/glow escalation above gold; the rarity stays legendary.
  final CardClass cardClass;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final path = cardPath(size);
    final g = cardClass == CardClass.premium
        ? cardClass.faceGradient
        : rarity.faceGradient;
    final accent = cardClass == CardClass.premium
        ? cardClass.accent
        : rarity.accent;
    final hair = math.max(0.5, w * 0.006);

    // Bezel in the rarity's metal.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [g[0], accent, g[2], accent],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ).createShader(rect),
    );

    // Carbon-black face.
    canvas.save();
    _insetCanvas(canvas, size, w * 0.034);
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2731), Color(0xFF121014), Color(0xFF0B0A0E)],
        ).createShader(rect),
    );
    final lattice = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair
      ..color = accent.withValues(alpha: 0.14);
    final step = w * 0.10;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), lattice);
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
    }
    // Warm glow behind the wordmark.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.7,
          colors: [
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );
    // Rarity stars along the foot: 3 rare, 4 epic, 5 legendary.
    final n = switch (rarity) {
      CardRarity.rare => 3,
      CardRarity.epic => 4,
      CardRarity.legendary => 5,
    };
    final starR = w * 0.042;
    for (var i = 0; i < n; i++) {
      final c = Offset(w / 2 + (i - (n - 1) / 2) * starR * 2.5, h * 0.80);
      canvas.drawPath(_cardStarPath(c, starR), Paint()..color = g[0]);
    }
    canvas.restore();

    // Frames: a fine keyline inside the face and the bright outer rim.
    canvas.save();
    _insetCanvas(canvas, size, w * 0.075);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = accent.withValues(alpha: 0.65),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.012)
        ..strokeJoin = StrokeJoin.round
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(CardBackPainter old) =>
      old.rarity != rarity || old.cardClass != cardClass;
}

/// Compact card for the pitch and bench: rating, position, surname, an
/// optional three-column stat row and a colour-coded stamina bar.
/// [width] is the shield width; everything else stacks under it.
