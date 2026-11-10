/// FCM Rivals — the crest renderer (T-0097).
///
/// [FcmCrest] paints a [CrestSpec] via [CustomPaint]: the shape's
/// outline in the secondary colour over a primary-coloured field with
/// the halves pattern (a secondary vertical band through the middle),
/// the icon glyph centered. The design is symmetric — the same spec
/// reads identically LTR and RTL — and scales from 28px list chips to
/// 96px headers without clipping (everything derives from the canvas
/// size; there are no absolute dimensions).
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
    final outline = secondary.withValues(alpha: 0.9);

    // 1. The shape's path.
    final path = _shapePath(spec.shape, w, h);

    // 2. The field: primary fill clipped to the shape, with the halves
    //    pattern — a secondary vertical band through the middle third.
    canvas.save();
    canvas.clipPath(path);
    final fieldPaint = Paint()..color = primary;
    canvas.drawRect(Offset.zero & size, fieldPaint);
    final bandPaint = Paint()..color = secondary.withValues(alpha: 0.55);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(w / 2, h / 2),
        width: w * 0.30,
        height: h,
      ),
      bandPaint,
    );
    canvas.restore();

    // 3. The outline over the field's edge.
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.06).clamp(1.5, 4.0)
      ..color = outline;
    canvas.drawPath(path, outlinePaint);

    // 4. The icon glyph, centered — drawn with the icon's own painter
    //    inside a square cell sized off the canvas.
    final glyphSize = w * 0.5;
    final glyphCell = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: glyphSize,
      height: glyphSize,
    );
    _paintIcon(canvas, glyphCell, secondary);
  }

  /// The shape's outline path, symmetric about the vertical axis.
  Path _shapePath(CrestShape shape, double w, double h) {
    switch (shape) {
      case CrestShape.shield:
        // Flat top, sides that taper, pointed bottom — symmetric.
        return Path()
          ..moveTo(w * 0.12, h * 0.08)
          ..lineTo(w * 0.88, h * 0.08)
          ..quadraticBezierTo(w * 0.88, h * 0.52, w * 0.5, h * 0.94)
          ..quadraticBezierTo(w * 0.12, h * 0.52, w * 0.12, h * 0.08)
          ..close();
      case CrestShape.round:
        return Path()
          ..addOval(Rect.fromCenter(
            center: Offset(w / 2, h / 2),
            width: w * 0.86,
            height: h * 0.86,
          ));
      case CrestShape.pennant:
        // Broad top edge, swallow-tailed bottom — symmetric.
        return Path()
          ..moveTo(w * 0.10, h * 0.08)
          ..lineTo(w * 0.90, h * 0.08)
          ..lineTo(w * 0.90, h * 0.86)
          ..lineTo(w * 0.5, h * 0.70)
          ..lineTo(w * 0.10, h * 0.86)
            ..close();
      case CrestShape.diamond:
        return Path()
          ..moveTo(w / 2, h * 0.06)
          ..lineTo(w * 0.94, h / 2)
          ..lineTo(w / 2, h * 0.94)
          ..lineTo(w * 0.06, h / 2)
          ..close();
    }
  }

  /// The icon glyph inside [cell], stroked in [color] — symmetric
  /// geometry per icon, drawn with primitives (no font, no asset).
  void _paintIcon(Canvas canvas, Rect cell, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (cell.width * 0.10).clamp(1.2, 3.5)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: 0.95);
    final cx = cell.center.dx;
    final cy = cell.center.dy;
    final r = cell.width / 2;

    switch (spec.icon) {
      case CrestIcon.star:
        // Five-point star outline from polar points.
        final points = <Offset>[];
        for (var i = 0; i < 10; i++) {
          final radius = i.isEven ? r : r * 0.44;
          final angle = -math.pi / 2 + i * math.pi / 5;
          points.add(Offset(
            cx + radius * math.cos(angle),
            cy + radius * math.sin(angle),
          ));
        }
        canvas.drawPath(Path()..addPolygon(points, true), paint);
      case CrestIcon.ball:
        // Circle with the classic pentagon seam hint: center dot.
        canvas.drawCircle(cell.center, r * 0.9, paint);
        final dot = Paint()..color = color.withValues(alpha: 0.95);
        canvas.drawCircle(cell.center, r * 0.22, dot);
      case CrestIcon.crown:
        // Three peaks over a base band — symmetric.
        canvas.drawPath(
          Path()
            ..moveTo(cell.left, cell.bottom)
            ..lineTo(cell.left, cell.top + cell.height * 0.30)
            ..lineTo(
                cell.left + cell.width * 0.25, cell.top + cell.height * 0.62)
            ..lineTo(cx, cell.top)
            ..lineTo(
                cell.right - cell.width * 0.25, cell.top + cell.height * 0.62)
            ..lineTo(cell.right, cell.top + cell.height * 0.30)
            ..lineTo(cell.right, cell.bottom)
            ..close(),
          paint,
        );
      case CrestIcon.lion:
        // Mane as a spiked ring + face circle — symmetric.
        final mane = <Offset>[];
        for (var i = 0; i < 12; i++) {
          final radius = i.isEven ? r : r * 0.62;
          final angle = i * math.pi / 6;
          mane.add(Offset(
            cx + radius * math.cos(angle),
            cy + radius * math.sin(angle),
          ));
        }
        canvas.drawPath(Path()..addPolygon(mane, true), paint);
        canvas.drawCircle(cell.center, r * 0.34, paint);
      case CrestIcon.flame:
        // Two mirrored curves meeting at a rounded base.
        canvas.drawPath(
          Path()
            ..moveTo(cx, cell.top)
            ..quadraticBezierTo(
              cell.right,
              cell.top + cell.height * 0.34,
              cx,
              cell.bottom - cell.height * 0.10,
            )
            ..quadraticBezierTo(
              cell.left,
              cell.top + cell.height * 0.34,
              cx,
              cell.top,
            )
            ..close(),
          paint,
        );
      case CrestIcon.bolt:
        // Classic zigzag bolt — mirrored about the center axis.
        canvas.drawPath(
          Path()
            ..moveTo(cx + cell.width * 0.16, cell.top)
            ..lineTo(cx - cell.width * 0.20, cy)
            ..lineTo(cx + cell.width * 0.02, cy)
            ..lineTo(cx - cell.width * 0.16, cell.bottom)
            ..lineTo(cx + cell.width * 0.24, cy + cell.height * 0.10)
            ..lineTo(cx + cell.width * 0.02, cy + cell.height * 0.10)
            ..close(),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_CrestPainter old) => old.spec != spec;
}
