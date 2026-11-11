/// FCM Rivals — rarity-specific card face artwork.
///
/// Every rarity gets its own *design language*, not just its own colour, so
/// a card is recognisable from across the room:
///
/// * RARE (amethyst) — clean holo foil: concentric ripples, diagonal gloss
///   bands and faint scan lines.
/// * EPIC (sapphire) — cut gemstone: a faceted crystal behind the player,
///   angular shards and twinkling glints.
/// * LEGENDARY (gold) — royal crest: a slowly turning double sunburst,
///   laurel wings hugging both sides and drifting golden sparkles.
/// * PREMIUM 90+ (oxblood) — the regalia line over the legendary crest:
///   a gold guilloché weave, a double silhouette keyline crowned with
///   diamond studs, gold lightning veins crawling the edges and rising
///   gold embers.
///
/// Everything is drawn in proportion to the card size (it is used from the
/// 56px pitch shield up to the 320px reveal) and stays cheap: strokes and
/// fills only, no blur. [phase] (0..1, looping) animates the twinkles, the
/// turning rays and the lightning; null renders a calm static frame.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fcm_style.dart';

/// Paints the rarity artwork. The canvas is already inset and clipped to
/// the card outline by the caller; [size] is the full card size.
void paintRarityArt(
  Canvas canvas,
  Size size, {
  required CardRarity rarity,
  required CardClass cardClass,
  required Color accent,
  required List<Color> gradient,
  double? phase,
}) {
  final premium = cardClass == CardClass.premium;
  if (premium) {
    _premiumPattern(canvas, size, cardClass);
    _legendaryArt(canvas, size, accent, gradient, phase);
    _premiumFrame(canvas, size, cardClass);
    _premiumVeins(canvas, size, accent, cardClass, phase);
    return;
  }
  switch (rarity) {
    case CardRarity.rare:
      _rareArt(canvas, size, phase);
    case CardRarity.epic:
      _epicArt(canvas, size, accent, phase);
    case CardRarity.legendary:
      _legendaryArt(canvas, size, accent, gradient, phase);
  }
}

/// 0..1 looping pulse; a calm constant when [phase] is null.
double _pulse(double? phase, {double cycles = 1, double offset = 0}) {
  if (phase == null) return 0.5;
  return 0.5 + 0.5 * math.sin(2 * math.pi * (phase * cycles + offset));
}

/// Twinkle alpha of sparkle [i]: sharp peaks, long dark gaps.
double _twinkle(double? phase, int i) {
  if (phase == null) return 0.55;
  final s = 0.5 + 0.5 * math.sin(2 * math.pi * (phase * 2 + i * 0.37));
  return 0.18 + 0.82 * s * s * s;
}

/// Four-point sparkle star.
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
    Paint()..color = color.withValues(alpha: alpha.clamp(0.0, 1.0).toDouble()),
  );
}

/// Tapered rays fanning out of [c], optionally turned by [turn] radians.
void _rays(
  Canvas canvas,
  Offset c,
  double radius,
  Color color,
  double alpha,
  int rays,
  double turn,
) {
  final slice = 2 * math.pi / rays;
  final paint = Paint()
    ..shader = RadialGradient(
      colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0.0)],
    ).createShader(Rect.fromCircle(center: c, radius: radius));
  for (var i = 0; i < rays; i++) {
    final a = turn + i * slice;
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

// ---------------------------------------------------------------- RARE ---

void _rareArt(Canvas canvas, Size size, double? phase) {
  final w = size.width, h = size.height;
  final hair = math.max(0.5, w * 0.006);
  final mc = Offset(w * 0.56, h * 0.29);

  // Ripples radiating from behind the player.
  final arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = hair * 1.4
    ..color = Colors.white.withValues(alpha: 0.11);
  for (var i = 1; i <= 5; i++) {
    canvas.drawCircle(mc, w * 0.12 * i, arc);
  }

  // Diagonal gloss bands (holo foil).
  void band(double x0, double bandW, double alpha) {
    canvas.drawPath(
      Path()
        ..moveTo(w * x0, 0)
        ..lineTo(w * (x0 + bandW), 0)
        ..lineTo(w * (x0 + bandW - 0.55), h * 0.6)
        ..lineTo(w * (x0 - 0.55), h * 0.6)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
  }

  final drift = phase == null ? 0.0 : 0.04 * math.sin(2 * math.pi * phase);
  band(0.72 + drift, 0.12, 0.07);
  band(0.92 + drift, 0.05, 0.05);

  // Fine scan lines.
  final scan = Paint()
    ..strokeWidth = hair
    ..color = Colors.white.withValues(alpha: 0.03);
  for (var y = h * 0.02; y < h * 0.54; y += w * 0.04) {
    canvas.drawLine(Offset(0, y), Offset(w, y), scan);
  }
}

// ---------------------------------------------------------------- EPIC ---

void _epicArt(Canvas canvas, Size size, Color accent, double? phase) {
  final w = size.width, h = size.height;
  final hair = math.max(0.5, w * 0.006);

  // Angular shards across the face.
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

  // The cut gem behind the player: four facets around the table.
  final mc = Offset(w * 0.56, h * 0.29);
  final r = h * 0.30;
  final top = Offset(mc.dx, mc.dy - r);
  final right = Offset(mc.dx + r * 0.72, mc.dy);
  final bottom = Offset(mc.dx, mc.dy + r * 1.1);
  final left = Offset(mc.dx - r * 0.72, mc.dy);
  void facet(Offset a, Offset b, double alpha, {bool dark = false}) {
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(mc.dx, mc.dy)
        ..close(),
      Paint()
        ..color = (dark ? Colors.black : Colors.white).withValues(
          alpha: alpha,
        ),
    );
  }

  facet(top, right, 0.16);
  facet(right, bottom, 0.10, dark: true);
  facet(bottom, left, 0.12);
  facet(left, top, 0.09, dark: true);
  canvas.drawPath(
    Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close(),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair * 1.2
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.28),
  );
  canvas.drawLine(
    left,
    right,
    Paint()
      ..strokeWidth = hair
      ..color = Colors.white.withValues(alpha: 0.18),
  );

  // Glints that catch the light in turn.
  final glints = <(Offset, double)>[
    (Offset(w * 0.19, h * 0.13), w * 0.040),
    (Offset(w * 0.87, h * 0.19), w * 0.032),
    (Offset(w * 0.74, h * 0.46), w * 0.026),
    (Offset(mc.dx - r * 0.2, mc.dy - r * 0.45), w * 0.030),
  ];
  for (var i = 0; i < glints.length; i++) {
    _sparkle(
      canvas,
      glints[i].$1,
      glints[i].$2,
      Colors.white,
      _twinkle(phase, i) * 0.9,
    );
  }
}

// ----------------------------------------------------------- LEGENDARY ---

void _legendaryArt(
  Canvas canvas,
  Size size,
  Color accent,
  List<Color> g,
  double? phase,
) {
  final w = size.width, h = size.height;
  final hair = math.max(0.5, w * 0.006);
  final mc = Offset(w * 0.56, h * 0.29);

  // Double sunburst, counter-rotating a single slice per loop so the
  // animation is seamless.
  const n = 24;
  const slice = 2 * math.pi / n;
  final turn = phase == null ? 0.0 : phase * slice;
  _rays(canvas, mc, h * 0.66, Colors.white, 0.26, n, turn);
  _rays(canvas, mc, h * 0.50, accent, 0.22, n, slice / 2 - turn);

  // Laurel wings hugging both edges of the face.
  final leaf = Paint()..color = g[0].withValues(alpha: 0.42);
  final vein = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = hair
    ..color = g[2].withValues(alpha: 0.30);
  for (final side in const [-1.0, 1.0]) {
    double px(double fx) => side < 0 ? w * fx : w * (1 - fx);
    final p0 = Offset(px(0.045), h * 0.53);
    final p1 = Offset(px(-0.03), h * 0.30);
    final p2 = Offset(px(0.16), h * 0.075);
    const leaves = 7;
    for (var i = 0; i < leaves; i++) {
      final t = i / (leaves - 1);
      final mt = 1 - t;
      final pt = Offset(
        mt * mt * p0.dx + 2 * mt * t * p1.dx + t * t * p2.dx,
        mt * mt * p0.dy + 2 * mt * t * p1.dy + t * t * p2.dy,
      );
      final tx = 2 * mt * (p1.dx - p0.dx) + 2 * t * (p2.dx - p1.dx);
      final ty = 2 * mt * (p1.dy - p0.dy) + 2 * t * (p2.dy - p1.dy);
      final ang = math.atan2(ty, tx);
      final len = w * (0.085 - 0.03 * t);
      final wid = w * (0.036 - 0.012 * t);
      for (final flip in const [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(pt.dx, pt.dy);
        canvas.rotate(ang + flip * 0.9);
        final rect = Rect.fromCenter(
          center: Offset(len / 2, 0),
          width: len,
          height: wid,
        );
        canvas.drawOval(rect, leaf);
        canvas.drawOval(rect, vein);
        canvas.restore();
      }
    }
  }

  // Sparkles drifting across the crest.
  final glints = <(Offset, double)>[
    (Offset(w * 0.22, h * 0.11), w * 0.042),
    (Offset(w * 0.84, h * 0.15), w * 0.036),
    (Offset(w * 0.30, h * 0.40), w * 0.028),
    (Offset(w * 0.80, h * 0.43), w * 0.032),
    (Offset(w * 0.58, h * 0.06), w * 0.026),
  ];
  for (var i = 0; i < glints.length; i++) {
    _sparkle(
      canvas,
      glints[i].$1,
      glints[i].$2,
      Colors.white,
      _twinkle(phase, i + 3),
    );
  }
}

// ------------------------------------------------------------- PREMIUM ---

/// The card outline scaled [inset] px inside [s] — mirrors cardPath so
/// the regalia frame can follow the silhouette without importing the
/// painters file (they import this one).
Path _regaliaOutline(Size s, double inset) {
  final dx = inset, dy = inset;
  final w = s.width - inset * 2, h = s.height - inset * 2;
  final c = w * 0.12;
  return Path()
    ..moveTo(dx + c, dy)
    ..lineTo(dx + w - c, dy)
    ..lineTo(dx + w, dy + c)
    ..lineTo(dx + w, dy + h * 0.865)
    ..quadraticBezierTo(dx + w, dy + h * 0.935, dx + w * 0.5, dy + h)
    ..quadraticBezierTo(dx, dy + h * 0.935, dx, dy + h * 0.865)
    ..lineTo(dx, dy + c)
    ..close();
}

/// The guilloché weave: two counter-diagonal line families — gold over
/// shade — finer than the face lattice, so the premium face reads as
/// championship banknote stock even between the sunburst rays.
void _premiumPattern(Canvas canvas, Size size, CardClass cardClass) {
  final w = size.width, h = size.height;
  final hair = math.max(0.5, w * 0.006);
  final gold = Paint()
    ..strokeWidth = hair
    ..color = cardClass.frameGold.withValues(alpha: 0.10);
  final shade = Paint()
    ..strokeWidth = hair
    ..color = Colors.black.withValues(alpha: 0.10);
  final step = w * 0.085;
  for (var x = -h; x < w + h; x += step) {
    canvas.drawLine(Offset(x, h), Offset(x + h, 0), gold);
    canvas.drawLine(Offset(x, 0), Offset(x + h, h), shade);
  }
}

/// The regalia frame: a double gold keyline following the card
/// silhouette, crowned by diamond studs — a larger one on each top
/// chamfer corner and a pair flanking the bezel gem along the top
/// edge (the gem itself keeps the crown's centre).
void _premiumFrame(Canvas canvas, Size size, CardClass cardClass) {
  final w = size.width;
  final hair = math.max(0.5, w * 0.006);
  final gold = cardClass.frameGold;

  canvas.drawPath(
    _regaliaOutline(size, w * 0.016),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, w * 0.010)
      ..strokeJoin = StrokeJoin.round
      ..color = gold.withValues(alpha: 0.85),
  );
  canvas.drawPath(
    _regaliaOutline(size, w * 0.034),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = hair
      ..color = gold.withValues(alpha: 0.30),
  );

  void stud(Offset c, double r) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(p, Paint()..color = gold.withValues(alpha: 0.95));
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hair
        ..color = Colors.black.withValues(alpha: 0.35),
    );
  }

  // The chamfer corners of the outline (inset w*0.016): each stud sits
  // on the diagonal edge's midpoint.
  stud(Offset(w * 0.074, w * 0.074), w * 0.016);
  stud(Offset(w * 0.926, w * 0.074), w * 0.016);
  stud(Offset(w * 0.33, w * 0.016), w * 0.011);
  stud(Offset(w * 0.67, w * 0.016), w * 0.011);
}

void _premiumVeins(
  Canvas canvas,
  Size size,
  Color accent,
  CardClass cardClass,
  double? phase,
) {
  final w = size.width, h = size.height;
  final hair = math.max(0.5, w * 0.006);

  // Branching lightning veins climbing both edges; flicker with the
  // phase. Crimson aura under a regalia-gold core.
  const bolt = <(double, double)>[
    (0.05, 0.54),
    (0.14, 0.44),
    (0.08, 0.36),
    (0.20, 0.25),
    (0.13, 0.17),
    (0.27, 0.05),
  ];
  const branch = <(double, double)>[
    (0.14, 0.44),
    (0.26, 0.41),
    (0.31, 0.33),
  ];
  Path build(List<(double, double)> pts, bool mirror) {
    final p = Path();
    for (var i = 0; i < pts.length; i++) {
      final x = mirror ? w * (1 - pts[i].$1) : w * pts[i].$1;
      final y = h * pts[i].$2;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p;
  }

  final flick = phase == null
      ? 0.8
      : 0.45 + 0.55 * math.pow(math.sin(2 * math.pi * phase * 3), 2);
  for (final mirror in const [false, true]) {
    for (final pts in const [bolt, branch]) {
      final path = build(pts, mirror);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hair * 4.5
          ..strokeJoin = StrokeJoin.round
          ..color = accent.withValues(alpha: 0.28 * flick),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = hair * 1.4
          ..strokeJoin = StrokeJoin.round
          ..color = cardClass.frameGold.withValues(alpha: 0.85 * flick),
      );
    }
  }

  // Gold embers rising off the base of the crest.
  final ember = Paint();
  for (var i = 0; i < 9; i++) {
    final seed = i * 0.6180339;
    final x = w * (0.10 + 0.80 * (seed - seed.floorToDouble()));
    final base = (i * 0.173) % 1.0;
    final prog = phase == null ? base : (base + phase) % 1.0;
    final y = h * (0.54 - 0.50 * prog);
    ember.color = cardClass.frameGold.withValues(
      alpha: 0.60 * math.sin(math.pi * prog),
    );
    canvas.drawCircle(Offset(x, y), w * (0.006 + 0.006 * (i % 3)), ember);
  }
}

/// Pulsing outer glow on the rim for epic and above. Skipped on the tiny
/// pitch shields (no blur on a 56px card) and on rare cards.
void paintRimPulse(
  Canvas canvas,
  Size size,
  Path path, {
  required CardRarity rarity,
  required CardClass cardClass,
  required Color accent,
  double? phase,
}) {
  final premium = cardClass == CardClass.premium;
  if (rarity == CardRarity.rare && !premium) return;
  final w = size.width;
  if (w < 90) return;
  final weight = premium ? 1.0 : (rarity == CardRarity.legendary ? 0.8 : 0.5);
  final pulse = _pulse(phase);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeJoin = StrokeJoin.round
      ..color = accent.withValues(
        alpha: ((0.14 + 0.36 * pulse) * weight).clamp(0.0, 1.0).toDouble(),
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.02),
  );
}
