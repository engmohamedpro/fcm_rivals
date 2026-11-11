/// FCM Rivals — player card painters and drawing primitives
/// (extracted from `player_card.dart`, app-structure review task
/// `2026-11-05_app-structure_split-player-card`): the card outline
/// path, canvas helpers and the card-face CustomPainter.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card_rarity_art.dart';
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

/// Clips any widget to the card outline — the card back's full-bleed
/// art gets the same chamfered silhouette as the painted faces.
class CardPathClipper extends CustomClipper<Path> {
  const CardPathClipper();

  @override
  Path getClip(Size size) => cardPath(size);

  @override
  bool shouldReclip(CardPathClipper oldClipper) => false;
}

class CardFacePainter extends CustomPainter {
  CardFacePainter({
    required this.rarity,
    required this.shine,
    this.cardClass = CardClass.standard,
    this.glow = 0.0,
    this.glowColor,
    this.phase,
  });

  final CardRarity rarity;
  final double? shine;

  /// 0..1 looping phase of the rarity artwork's idle animation (turning
  /// sunburst, twinkles, lightning, rim pulse). Null paints a static frame
  /// — the collection grid and pitch shields never animate.
  final double? phase;

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
    final premium = cardClass == CardClass.premium;

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

    // Milled bezel: a catch-light band sweeping the metal.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.34, 0.44, 0.60],
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

    // Rarity artwork behind the player: each rarity has its own design
    // language (holo foil / cut gem / royal crest / lightning crest).
    paintRarityArt(
      canvas,
      size,
      rarity: rarity,
      cardClass: cardClass,
      accent: _accent,
      gradient: g,
      phase: phase,
    );

    // Bottom vignette: grounds the glass panel in the face's depth.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, 1.7),
          radius: 1.2,
          colors: [
            Colors.black.withValues(alpha: 0.32),
            Colors.black.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

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

    // Security-print chevrons under the top edge.
    final chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair
      ..color = Colors.white.withValues(alpha: 0.07);
    final chevStep = w * 0.05;
    for (var x = -chevStep; x < w + chevStep; x += chevStep) {
      canvas.drawLine(
        Offset(x, h * 0.030),
        Offset(x + chevStep * 0.5, h * 0.018),
        chevron,
      );
    }

    // Portrait window: the plate the player stands on — dark glass in
    // a chamfered metal frame echoing the card's own silhouette. The
    // portrait widget (and the placeholder silhouette, clipped to the
    // same path below) lives inside it; the big card and the mini share
    // the zone (mini column ends where the window begins, at 0.37w).
    final winL = w * 0.37, winT = h * 0.095;
    final winR = w * 0.95, winB = h * 0.545;
    Path windowPath(double inset) {
      final c = math.max(0.0, w * 0.045 - inset);
      final r = math.max(0.0, w * 0.030 - inset);
      final l = winL + inset, t = winT + inset;
      final rr = winR - inset, b = winB - inset;
      return Path()
        ..moveTo(l + c, t)
        ..lineTo(rr - c, t)
        ..lineTo(rr, t + c)
        ..lineTo(rr, b - r)
        ..quadraticBezierTo(rr, b, rr - r, b)
        ..lineTo(l + r, b)
        ..quadraticBezierTo(l, b, l, b - r)
        ..lineTo(l, t + c)
        ..close();
    }

    final win = windowPath(0);
    final winRect = Rect.fromLTRB(winL, winT, winR, winB);
    // Recessed glass — darker than the face, a touch lighter than the
    // panel below, so it reads as its own depth layer.
    canvas.drawPath(
      win,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.35),
            Colors.black.withValues(alpha: 0.66),
          ],
        ).createShader(winRect),
    );
    // A catch-light sweeping down the glass, like the milled bezel.
    canvas.drawPath(
      win,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55],
        ).createShader(winRect),
    );

    // Player silhouette (head + shoulders), right of centre — the
    // photo's permanent placeholder, clipped to the window so the bust
    // reads as framed portraiture (and never washes over the rails).
    canvas.save();
    canvas.clipPath(win);
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
    canvas.restore();

    // Metal rails over the glass edge — the bezel language in
    // miniature, with the premium regalia gold on 90+ faces. The
    // bottom rail meets the panel's lit edge and merges into it.
    final frameColor = premium ? cardClass.frameGold : g[0];
    canvas.drawPath(
      win,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.010)
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, frameColor, g[2]],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(winRect),
    );
    // Fine inner keyline, like the face's own.
    canvas.drawPath(
      windowPath(w * 0.018),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = Colors.white.withValues(alpha: 0.25),
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
    // Premium regalia: the panel's light edge carries the frame's gold.
    final edgeColor = premium ? cardClass.frameGold : g[0];
    canvas.drawRect(
      edge,
      Paint()
        ..shader = LinearGradient(
          colors: [
            edgeColor.withValues(alpha: 0.0),
            edgeColor,
            edgeColor.withValues(alpha: 0.0),
          ],
        ).createShader(edge),
    );

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
          // Premium regalia: the inner keyline carries the frame's gold.
          ..color = premium
              ? cardClass.frameGold.withValues(alpha: 0.60)
              : Colors.white.withValues(alpha: 0.30),
    );
    canvas.restore();
    paintRimPulse(
      canvas,
      size,
      path,
      rarity: rarity,
      cardClass: cardClass,
      accent: _accent,
      phase: phase,
    );
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
      old.glowColor != glowColor ||
      old.phase != phase;
}

/// Compact card for the pitch and bench: rating, position, surname, an
/// optional three-column stat row and a colour-coded stamina bar.
/// [width] is the shield width; everything else stacks under it.
