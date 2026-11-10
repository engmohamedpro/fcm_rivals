/// FCM Rivals — the crest renderer (T-0097, redesigned).
///
/// [FcmCrest] paints a [CrestSpec] via [CustomPaint] as a small piece of
/// badge art rather than a flat sticker:
///
///  - a soft drop shadow under the silhouette,
///  - a metallic rim in the secondary colour,
///  - a graded primary field carrying the spec's [CrestPattern] in the
///    secondary colour,
///  - a glossy highlight across the top of the field,
///  - a solid, haloed glyph (cream or ink, whichever reads against the
///    field) so the icon is legible over any pattern and any colour pair.
///
/// Everything derives from the canvas size (no absolute dimensions), so
/// the same spec scales cleanly from 28px list chips to 96px headers.
/// [FcmCrestGlyph] and [FcmCrestPatternChip] expose the glyph and the
/// pattern on their own for the club builder's pickers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/crest.dart';

/// Renders one [spec] at [width] logical pixels (square aspect).
class FcmCrest extends StatelessWidget {
  const FcmCrest({super.key, required this.spec, this.width = 48});

  final CrestSpec spec;

  /// Logical pixel width (and height — the crest is square).
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width,
      child: CustomPaint(painter: _CrestPainter(spec)),
    );
  }
}

/// One crest icon on its own, in [color] with an automatic contrast
/// halo — the builder's icon swatches use it so the picker shows the real
/// artwork that lands on the crest.
class FcmCrestGlyph extends StatelessWidget {
  const FcmCrestGlyph({
    super.key,
    required this.icon,
    required this.color,
    this.size = 28,
  });

  final CrestIcon icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(icon, color)),
    );
  }
}

/// One pattern on its own: a rounded swatch of [primary] carrying the
/// [pattern] in [secondary] — the builder's pattern picker.
class FcmCrestPatternChip extends StatelessWidget {
  const FcmCrestPatternChip({
    super.key,
    required this.pattern,
    required this.primary,
    required this.secondary,
    this.size = 34,
  });

  final CrestPattern pattern;
  final Color primary;
  final Color secondary;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PatternChipPainter(pattern, primary, secondary)),
    );
  }
}

Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

/// The silhouette of [shape] drawn inside [r] — symmetric about the
/// vertical axis for every shape.
Path _shapePath(CrestShape shape, Rect r) {
  Offset u(double x, double y) =>
      Offset(r.left + x * r.width, r.top + y * r.height);
  final p = Path();
  switch (shape) {
    case CrestShape.shield:
      p.moveTo(u(0.10, 0.06).dx, u(0.10, 0.06).dy);
      p.lineTo(u(0.90, 0.06).dx, u(0.90, 0.06).dy);
      p.cubicTo(
        u(0.90, 0.56).dx, u(0.90, 0.56).dy,
        u(0.70, 0.82).dx, u(0.70, 0.82).dy,
        u(0.50, 0.97).dx, u(0.50, 0.97).dy,
      );
      p.cubicTo(
        u(0.30, 0.82).dx, u(0.30, 0.82).dy,
        u(0.10, 0.56).dx, u(0.10, 0.56).dy,
        u(0.10, 0.06).dx, u(0.10, 0.06).dy,
      );
      p.close();
    case CrestShape.heater:
      p.moveTo(u(0.10, 0.06).dx, u(0.10, 0.06).dy);
      p.lineTo(u(0.90, 0.06).dx, u(0.90, 0.06).dy);
      p.lineTo(u(0.90, 0.48).dx, u(0.90, 0.48).dy);
      p.cubicTo(
        u(0.90, 0.80).dx, u(0.90, 0.80).dy,
        u(0.70, 0.94).dx, u(0.70, 0.94).dy,
        u(0.50, 0.97).dx, u(0.50, 0.97).dy,
      );
      p.cubicTo(
        u(0.30, 0.94).dx, u(0.30, 0.94).dy,
        u(0.10, 0.80).dx, u(0.10, 0.80).dy,
        u(0.10, 0.48).dx, u(0.10, 0.48).dy,
      );
      p.close();
    case CrestShape.round:
      p.addOval(Rect.fromLTRB(
        r.left + r.width * 0.05,
        r.top + r.height * 0.05,
        r.right - r.width * 0.05,
        r.bottom - r.height * 0.05,
      ));
    case CrestShape.pennant:
      p.moveTo(u(0.10, 0.06).dx, u(0.10, 0.06).dy);
      p.lineTo(u(0.90, 0.06).dx, u(0.90, 0.06).dy);
      p.lineTo(u(0.90, 0.92).dx, u(0.90, 0.92).dy);
      p.lineTo(u(0.50, 0.74).dx, u(0.50, 0.74).dy);
      p.lineTo(u(0.10, 0.92).dx, u(0.10, 0.92).dy);
      p.close();
    case CrestShape.diamond:
      p.moveTo(u(0.50, 0.03).dx, u(0.50, 0.03).dy);
      p.lineTo(u(0.97, 0.50).dx, u(0.97, 0.50).dy);
      p.lineTo(u(0.50, 0.97).dx, u(0.50, 0.97).dy);
      p.lineTo(u(0.03, 0.50).dx, u(0.03, 0.50).dy);
      p.close();
    case CrestShape.hexagon:
      p.moveTo(u(0.50, 0.03).dx, u(0.50, 0.03).dy);
      p.lineTo(u(0.94, 0.27).dx, u(0.94, 0.27).dy);
      p.lineTo(u(0.94, 0.73).dx, u(0.94, 0.73).dy);
      p.lineTo(u(0.50, 0.97).dx, u(0.50, 0.97).dy);
      p.lineTo(u(0.06, 0.73).dx, u(0.06, 0.73).dy);
      p.lineTo(u(0.06, 0.27).dx, u(0.06, 0.27).dy);
      p.close();
  }
  return p;
}

/// Where the glyph's centre sits inside the field, as a fraction of the
/// field's height — pointed shapes carry it a touch high.
double _glyphCentreY(CrestShape shape) => switch (shape) {
  CrestShape.shield => 0.42,
  CrestShape.heater => 0.44,
  CrestShape.pennant => 0.42,
  CrestShape.round => 0.50,
  CrestShape.diamond => 0.50,
  CrestShape.hexagon => 0.50,
};

/// Glyph size as a fraction of the field width.
double _glyphScale(CrestShape shape) => switch (shape) {
  CrestShape.diamond => 0.34,
  CrestShape.pennant => 0.40,
  CrestShape.shield => 0.44,
  _ => 0.46,
};

/// Paints [pattern] in [color] over [r] (the caller has clipped to the
/// field).
void _paintPattern(Canvas canvas, Rect r, CrestPattern pattern, Color color) {
  final paint = Paint()..color = color;
  final w = r.width;
  final h = r.height;
  switch (pattern) {
    case CrestPattern.plain:
      break;
    case CrestPattern.halves:
      canvas.drawRect(
        Rect.fromCenter(center: r.center, width: w * 0.32, height: h),
        paint,
      );
    case CrestPattern.stripes:
      final sw = w / 5;
      for (final i in const [1, 3]) {
        canvas.drawRect(
          Rect.fromLTWH(r.left + sw * i, r.top, sw, h),
          paint,
        );
      }
    case CrestPattern.hoops:
      final sh = h / 5;
      for (final i in const [1, 3]) {
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.top + sh * i, w, sh),
          paint,
        );
      }
    case CrestPattern.diagonal:
      canvas.drawPath(
        Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.left + w * 0.36, r.top)
          ..lineTo(r.right, r.bottom - h * 0.36)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.right - w * 0.36, r.bottom)
          ..lineTo(r.left, r.top + h * 0.36)
          ..close(),
        paint,
      );
    case CrestPattern.chevron:
      canvas.drawPath(
        Path()
          ..moveTo(r.left, r.top + h * 0.26)
          ..lineTo(r.center.dx, r.top + h * 0.66)
          ..lineTo(r.right, r.top + h * 0.26)
          ..lineTo(r.right, r.top + h * 0.50)
          ..lineTo(r.center.dx, r.top + h * 0.90)
          ..lineTo(r.left, r.top + h * 0.50)
          ..close(),
        paint,
      );
    case CrestPattern.cross:
      canvas.drawRect(
        Rect.fromCenter(center: r.center, width: w * 0.24, height: h),
        paint,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(r.center.dx, r.top + h * 0.42),
          width: w,
          height: h * 0.24,
        ),
        paint,
      );
    case CrestPattern.quarters:
      canvas.drawRect(Rect.fromLTRB(r.left, r.top, r.center.dx, r.center.dy), paint);
      canvas.drawRect(Rect.fromLTRB(r.center.dx, r.center.dy, r.right, r.bottom), paint);
  }
}

/// The single painter behind every crest — one canvas pass, no
/// late-bound state, so a grid of crests repaints cheaply.
class _CrestPainter extends CustomPainter {
  _CrestPainter(this.spec);

  final CrestSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final primary = spec.primaryColor;
    final secondary = spec.secondaryColor;
    final bounds = Offset.zero & size;

    final outer = _shapePath(spec.shape, bounds);
    final rimWidth = w * 0.075;
    final fieldRect = bounds.deflate(rimWidth);
    final field = _shapePath(spec.shape, fieldRect);

    // 1. Soft drop shadow (skipped on tiny chips where it only muddies).
    if (w >= 34) {
      canvas.drawPath(
        outer.shift(Offset(0, w * 0.03)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.38)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.04),
      );
    }

    // 2. Metallic rim: the outer silhouette in a light-to-dark ramp of
    //    the secondary colour.
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _lighten(secondary, 0.45),
            secondary,
            _darken(secondary, 0.35),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
    );

    // 3. The field: graded primary, the pattern in the secondary, and a
    //    gloss across the top.
    canvas.save();
    canvas.clipPath(field);
    canvas.drawRect(
      fieldRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lighten(primary, 0.16), primary, _darken(primary, 0.28)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(fieldRect),
    );
    canvas.saveLayer(fieldRect, Paint());
    _paintPattern(canvas, fieldRect, spec.pattern, secondary);
    // Shade the pattern the same way as the field so it sits ON the
    // cloth rather than floating above it.
    canvas.drawRect(
      fieldRect,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.26),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(fieldRect),
    );
    canvas.restore();
    // Gloss.
    canvas.drawRect(
      Rect.fromLTWH(
        fieldRect.left,
        fieldRect.top,
        fieldRect.width,
        fieldRect.height * 0.46,
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(fieldRect),
    );
    canvas.restore();

    // 4. Edge definition: a dark hairline on the rim and the field.
    canvas.drawPath(
      field,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.016)
        ..color = Colors.black.withValues(alpha: 0.38),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.018)
        ..color = _darken(secondary, 0.62).withValues(alpha: 0.9),
    );

    // 5. The glyph — solid, haloed, cream or ink by the field's tone.
    final lum = (primary.computeLuminance() + secondary.computeLuminance()) / 2;
    final fill = lum > 0.55 ? const Color(0xFF1A1612) : const Color(0xFFF8F3E6);
    final side = fieldRect.width * _glyphScale(spec.shape);
    final cell = Rect.fromCenter(
      center: Offset(
        w / 2,
        fieldRect.top + fieldRect.height * _glyphCentreY(spec.shape),
      ),
      width: side,
      height: side,
    );
    _paintGlyph(canvas, spec.icon, cell, fill);
  }

  @override
  bool shouldRepaint(_CrestPainter old) => old.spec != spec;
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.icon, this.color);

  final CrestIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGlyph(canvas, icon, Offset.zero & size, color);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.icon != icon || old.color != color;
}

class _PatternChipPainter extends CustomPainter {
  _PatternChipPainter(this.pattern, this.primary, this.secondary);

  final CrestPattern pattern;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(r, Radius.circular(size.width * 0.22));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lighten(primary, 0.14), _darken(primary, 0.22)],
        ).createShader(r),
    );
    _paintPattern(canvas, r, pattern, secondary);
    canvas.restore();
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_PatternChipPainter old) =>
      old.pattern != pattern ||
      old.primary != primary ||
      old.secondary != secondary;
}

/// One glyph's geometry: a filled [body] and optional [detail] strokes /
/// fills drawn in the contrast colour on top of it.
class _Glyph {
  const _Glyph(this.body, [this.detail]);

  final Path body;
  final Path? detail;
}

Path _poly(Rect c, List<List<double>> pts) {
  final path = Path();
  for (var i = 0; i < pts.length; i++) {
    final x = c.left + pts[i][0] * c.width;
    final y = c.top + pts[i][1] * c.height;
    if (i == 0) {
      path.moveTo(x, y);
    } else {
      path.lineTo(x, y);
    }
  }
  return path..close();
}

Path _disc(Rect c, double cx, double cy, double r) => Path()
  ..addOval(Rect.fromCircle(
    center: Offset(c.left + cx * c.width, c.top + cy * c.height),
    radius: r * c.width,
  ));

/// A cubic path through unit-space control triples (start + [x1,y1,x2,y2,x,y]).
Path _cubics(Rect c, List<double> start, List<List<double>> segs) {
  Offset u(double x, double y) =>
      Offset(c.left + x * c.width, c.top + y * c.height);
  final path = Path();
  final s = u(start[0], start[1]);
  path.moveTo(s.dx, s.dy);
  for (final g in segs) {
    final a = u(g[0], g[1]);
    final b = u(g[2], g[3]);
    final e = u(g[4], g[5]);
    path.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
  }
  return path..close();
}

_Glyph _glyphFor(CrestIcon icon, Rect c) {
  Offset polar(double cx, double cy, double r, double a) => Offset(
    c.left + (cx + r * math.cos(a)) * c.width,
    c.top + (cy + r * math.sin(a)) * c.height,
  );
  switch (icon) {
    case CrestIcon.star:
      final pts = <Offset>[
        for (var i = 0; i < 10; i++)
          polar(0.5, 0.54, i.isEven ? 0.52 : 0.21, -math.pi / 2 + i * math.pi / 5),
      ];
      return _Glyph(Path()..addPolygon(pts, true));
    case CrestIcon.ball:
      final detail = Path();
      final pent = <Offset>[
        for (var i = 0; i < 5; i++)
          polar(0.5, 0.5, 0.17, -math.pi / 2 + i * 2 * math.pi / 5),
      ];
      detail.addPolygon(pent, true);
      for (final p in pent) {
        final a = math.atan2(p.dy - (c.top + c.height / 2), p.dx - (c.left + c.width / 2));
        final from = p;
        final to = polar(0.5, 0.5, 0.40, a);
        detail.moveTo(from.dx, from.dy);
        detail.lineTo(to.dx, to.dy);
      }
      return _Glyph(_disc(c, 0.5, 0.5, 0.46), detail);
    case CrestIcon.crown:
      final body = _poly(c, const [
        [0.02, 0.94],
        [0.02, 0.32],
        [0.26, 0.58],
        [0.50, 0.16],
        [0.74, 0.58],
        [0.98, 0.32],
        [0.98, 0.94],
      ]);
      body.addPath(_disc(c, 0.02, 0.26, 0.07), Offset.zero);
      body.addPath(_disc(c, 0.50, 0.10, 0.07), Offset.zero);
      body.addPath(_disc(c, 0.98, 0.26, 0.07), Offset.zero);
      final band = Path()
        ..moveTo(c.left + c.width * 0.02, c.top + c.height * 0.80)
        ..lineTo(c.left + c.width * 0.98, c.top + c.height * 0.80);
      return _Glyph(body, band);
    case CrestIcon.lion:
      final mane = <Offset>[
        for (var i = 0; i < 20; i++)
          polar(0.5, 0.5, i.isEven ? 0.52 : 0.40, i * math.pi / 10),
      ];
      final face = Path.combine(
        PathOperation.difference,
        _disc(c, 0.5, 0.5, 0.29),
        Path.combine(
          PathOperation.union,
          Path.combine(
            PathOperation.union,
            _disc(c, 0.40, 0.45, 0.045),
            _disc(c, 0.60, 0.45, 0.045),
          ),
          _poly(c, const [
            [0.44, 0.57],
            [0.56, 0.57],
            [0.50, 0.66],
          ]),
        ),
      );
      return _Glyph(Path()..addPolygon(mane, true), face);
    case CrestIcon.flame:
      final outer = _cubics(c, const [0.50, 0.0], const [
        [0.62, 0.18, 0.92, 0.34, 0.90, 0.64],
        [0.88, 0.88, 0.70, 1.0, 0.50, 1.0],
        [0.30, 1.0, 0.12, 0.88, 0.10, 0.64],
        [0.09, 0.50, 0.20, 0.40, 0.30, 0.30],
        [0.32, 0.42, 0.38, 0.46, 0.42, 0.46],
        [0.40, 0.30, 0.42, 0.14, 0.50, 0.0],
      ]);
      final inner = _cubics(c, const [0.50, 0.58], const [
        [0.62, 0.70, 0.70, 0.78, 0.62, 0.90],
        [0.58, 0.96, 0.42, 0.96, 0.38, 0.90],
        [0.30, 0.78, 0.40, 0.68, 0.50, 0.58],
      ]);
      return _Glyph(Path.combine(PathOperation.difference, outer, inner));
    case CrestIcon.bolt:
      return _Glyph(_poly(c, const [
        [0.55, 0.0],
        [0.10, 0.55],
        [0.42, 0.55],
        [0.32, 1.0],
        [0.90, 0.40],
        [0.57, 0.40],
        [0.80, 0.0],
      ]));
    case CrestIcon.sun:
      final body = _disc(c, 0.5, 0.5, 0.25);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final tri = <Offset>[
          polar(0.5, 0.5, 0.33, a - 0.24),
          polar(0.5, 0.5, 0.52, a),
          polar(0.5, 0.5, 0.33, a + 0.24),
        ];
        body.addPolygon(tri, true);
      }
      return _Glyph(body);
    case CrestIcon.tower:
      final tower = _poly(c, const [
        [0.14, 1.0],
        [0.14, 0.04],
        [0.30, 0.04],
        [0.30, 0.18],
        [0.42, 0.18],
        [0.42, 0.04],
        [0.58, 0.04],
        [0.58, 0.18],
        [0.70, 0.18],
        [0.70, 0.04],
        [0.86, 0.04],
        [0.86, 1.0],
      ]);
      final door = _cubics(c, const [0.42, 1.0], const [
        [0.42, 0.90, 0.42, 0.80, 0.42, 0.74],
        [0.42, 0.60, 0.58, 0.60, 0.58, 0.74],
        [0.58, 0.80, 0.58, 0.90, 0.58, 1.0],
      ]);
      final slit = _poly(c, const [
        [0.47, 0.34],
        [0.53, 0.34],
        [0.53, 0.50],
        [0.47, 0.50],
      ]);
      return _Glyph(
        Path.combine(
          PathOperation.difference,
          Path.combine(PathOperation.difference, tower, door),
          slit,
        ),
      );
    case CrestIcon.sword:
      final body = _poly(c, const [
        [0.50, 0.0],
        [0.60, 0.12],
        [0.60, 0.68],
        [0.40, 0.68],
        [0.40, 0.12],
      ]);
      body.addPath(
        _poly(c, const [
          [0.18, 0.68],
          [0.82, 0.68],
          [0.82, 0.77],
          [0.18, 0.77],
        ]),
        Offset.zero,
      );
      body.addPath(
        _poly(c, const [
          [0.45, 0.77],
          [0.55, 0.77],
          [0.55, 0.92],
          [0.45, 0.92],
        ]),
        Offset.zero,
      );
      body.addPath(_disc(c, 0.5, 0.94, 0.07), Offset.zero);
      final fuller = Path()
        ..moveTo(c.left + c.width * 0.5, c.top + c.height * 0.12)
        ..lineTo(c.left + c.width * 0.5, c.top + c.height * 0.60);
      return _Glyph(body, fuller);
    case CrestIcon.moon:
      return _Glyph(
        Path.combine(
          PathOperation.difference,
          _disc(c, 0.46, 0.5, 0.46),
          _disc(c, 0.68, 0.40, 0.38),
        ),
      );
  }
}

/// Paints [icon] filled in [fill] inside [cell], over a halo of the
/// opposite tone so it reads on any pattern and any colour pair.
void _paintGlyph(Canvas canvas, CrestIcon icon, Rect cell, Color fill) {
  final g = _glyphFor(icon, cell);
  final dark = fill.computeLuminance() > 0.5;
  final halo = dark ? const Color(0xFF14110E) : const Color(0xFFFFFFFF);
  final contrast = halo;
  // Halo: a round-joined stroke behind the fill.
  canvas.drawPath(
    g.body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, cell.width * 0.13)
      ..strokeJoin = StrokeJoin.round
      ..color = halo.withValues(alpha: 0.55),
  );
  canvas.drawPath(g.body, Paint()..color = fill);
  final detail = g.detail;
  if (detail != null) {
    canvas.drawPath(detail, Paint()..color = contrast);
    canvas.drawPath(
      detail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, cell.width * 0.06)
        ..strokeCap = StrokeCap.round
        ..color = contrast,
    );
  }
}
