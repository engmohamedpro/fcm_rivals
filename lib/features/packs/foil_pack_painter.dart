/// FCM Rivals — the sealed booster foil painter.
///
/// [FoilPackPainter] and its private drawing helpers (card fan,
/// sunburst, star path), split verbatim out of `pack_effects.dart`
/// (T-0040).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/player_card.dart' show cardPath;
import 'pack_effect_palette.dart';

/// The sealed booster: a trading-card foil pack. Brushed tier-metal foil
/// with a diamond lattice, crimped ridged seals, a chamfered print frame
/// holding a fan of three player cards over a sunburst, the brand
/// wordmark on a dark glass band, rarity stars, a tier-name plate and a
/// prismatic holographic sheen that sweeps across the wrapper.
class FoilPackPainter extends CustomPainter {
  FoilPackPainter({
    required this.shimmer,
    required this.charge,
    required this.glowColor,
    this.tint,
    this.stars = 3,
  });

  /// 0..1 loop position of the idle foil shimmer.
  final double shimmer;

  /// 0..1 — how charged the pack is (grows the crack and hot glow).
  final double charge;

  /// Colour the pack's inner light turns toward while charging.
  final Color glowColor;

  /// Solid tier metal the whole foil is painted in — amethyst / sapphire /
  /// gold at full strength, never a translucent wash. Null keeps the
  /// untinted charcoal leather — the classic sealed look.
  final Color? tint;

  /// Rarity stars stamped above the card fan: 3 rare, 4 epic, 5 legendary
  /// — the pack's grade must read at a glance on the shelf.
  final int stars;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final path = packPath(size);
    final crimpH = w * 0.075;

    // Palette: the tier's metallic ramp, or the brand charcoal + gold.
    final shades = tint == null ? null : _foilShades(tint!);
    final Color light, base, dark, deep, trim;
    if (shades != null) {
      light = shades[0];
      base = shades[1];
      dark = shades[2];
      deep = shades[3];
      trim = shades[0];
    } else {
      light = const Color(0xFF4A4338);
      base = const Color(0xFF211F24);
      dark = const Color(0xFF121014);
      deep = const Color(0xFF0B0A0E);
      trim = FcmColors.gold;
    }
    final ramp = [light, base, dark, deep];

    // Drop shadow.
    canvas.drawShadow(path, Colors.black, 14, true);

    // Foil body: brushed-metal streaks — deep edges, a bright reflection
    // band top-left, a darker one low-right — so the wrapper reads as one
    // sheet of curved foil, not a flat fill.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [deep, base, light, base, dark, base, deep],
          stops: const [0.0, 0.16, 0.30, 0.46, 0.64, 0.82, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(path);

    // Diamond lattice texture across the whole wrapper.
    final lattice = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, w * 0.006)
      ..color = Colors.white.withValues(alpha: 0.045);
    final step = w * 0.11;
    for (var x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + h, h), lattice);
      canvas.drawLine(Offset(x, h), Offset(x + h, 0), lattice);
    }

    // Crimped seals: vertical ridges, each a dark groove with a lit edge.
    final grooveW = math.max(0.6, w * 0.007);
    final groove = Paint()
      ..strokeWidth = grooveW
      ..color = Colors.black.withValues(alpha: 0.20);
    final lit = Paint()
      ..strokeWidth = grooveW
      ..color = Colors.white.withValues(alpha: 0.18);
    for (var x = w * 0.025; x < w; x += w * 0.05) {
      canvas.drawLine(Offset(x, 0), Offset(x, crimpH), groove);
      canvas.drawLine(
        Offset(x + w * 0.012, 0),
        Offset(x + w * 0.012, crimpH),
        lit,
      );
      canvas.drawLine(Offset(x, h - crimpH), Offset(x, h), groove);
      canvas.drawLine(
        Offset(x + w * 0.012, h - crimpH),
        Offset(x + w * 0.012, h),
        lit,
      );
    }
    // Seal shading: the crimp folds away from the flat body.
    for (final top in [true, false]) {
      final seal = top
          ? Rect.fromLTWH(0, 0, w, crimpH * 1.6)
          : Rect.fromLTWH(0, h - crimpH * 1.6, w, crimpH * 1.6);
      canvas.drawRect(
        seal,
        Paint()
          ..shader = LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.30),
              Colors.black.withValues(alpha: 0.0),
            ],
          ).createShader(seal),
      );
    }

    // Print frame: a chamfered badge outline in tier metal, the inside
    // darkened like tinted glass so the artwork pops off the foil.
    final inset = w * 0.07;
    final frame = Rect.fromLTRB(
      inset,
      crimpH * 1.45,
      w - inset,
      h - crimpH * 1.45,
    );
    final framePath = chamfered(frame, w * 0.075);
    canvas.drawPath(
      framePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            deep.withValues(alpha: 0.62),
            dark.withValues(alpha: 0.30),
            deep.withValues(alpha: 0.66),
          ],
        ).createShader(frame),
    );

    // Sunburst behind the card fan — only the rarer grades get one.
    canvas.save();
    canvas.clipPath(framePath);
    final fanCenter = Offset(w / 2, h * 0.315);
    if (stars >= 4) {
      _paintSunburst(
        canvas,
        fanCenter,
        h * 0.5,
        light,
        stars >= 5 ? 0.34 : 0.20,
        stars >= 5 ? 20 : 14,
      );
    }
    // Soft radial glow behind the fan.
    canvas.drawCircle(
      fanCenter,
      w * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [light.withValues(alpha: 0.38), light.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: fanCenter, radius: w * 0.42)),
    );
    canvas.restore();

    // Three player cards fanned out — the promise of the pack.
    _paintCardFan(canvas, size, fanCenter, ramp, trim);

    // Frame strokes drawn after the art so the rim sits on top of it.
    canvas.drawPath(
      framePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.014)
        ..strokeJoin = StrokeJoin.round
        ..color = trim.withValues(alpha: 0.92),
    );
    canvas.drawPath(
      chamfered(frame.deflate(w * 0.022), w * 0.055),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, w * 0.005)
        ..color = trim.withValues(alpha: 0.38),
    );

    // Rarity stars above the card fan: drawn five-point stars in bright
    // tier metal with a dark rim and a soft shadow — they read from
    // across the shelf. Count is the pack's grade: 3 / 4 / 5.
    final metal = trim;
    final starFill = Color.lerp(metal, Colors.white, 0.28)!;
    final starRim = shades == null
        ? const Color(0xFF0B0A0E)
        : deep.withValues(alpha: 0.9);
    final starR = w * 0.05;
    final rowY = h * 0.118;
    final starGap = starR * 2.42;
    final n = stars.clamp(1, 5);
    for (var i = 0; i < n; i++) {
      final c = Offset(w / 2 + (i - (n - 1) / 2) * starGap, rowY);
      final sp = _starPath(c, starR);
      canvas.drawPath(
        sp,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(sp, Paint()..color = starFill);
      canvas.drawPath(
        sp,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, starR * 0.14)
          ..strokeJoin = StrokeJoin.round
          ..color = starRim,
      );
    }

    // Wordmark band: dark glass between two metal hairlines, the
    // transparent brand logo large on it with a warm glow behind.
    final band = Rect.fromLTRB(
      frame.left + w * 0.012,
      h * 0.465,
      frame.right - w * 0.012,
      h * 0.725,
    );
    final bandPath = chamfered(band, w * 0.04);
    canvas.drawPath(
      bandPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            deep.withValues(alpha: 0.96),
            const Color(0xFF15130F).withValues(alpha: 0.98),
            deep.withValues(alpha: 0.96),
          ],
        ).createShader(band),
    );
    canvas.drawRect(
      band,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [trim.withValues(alpha: 0.30), trim.withValues(alpha: 0.0)],
        ).createShader(band),
    );
    canvas.drawPath(
      bandPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.01)
        ..strokeJoin = StrokeJoin.round
        ..color = trim.withValues(alpha: 0.9),
    );

    // Wordmark: the transparent logo art, full colour. Until the async
    // decode lands, the metal text mark stands in.
    final logo = packLogo;
    _paintedWithLogo = logo != null;
    if (logo != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        logo.width.toDouble(),
        logo.height.toDouble(),
      );
      final aspect = src.width / src.height;
      var dstH = band.height * 0.96;
      if (dstH * aspect > band.width * 0.96) {
        dstH = band.width * 0.96 / aspect;
      }
      final dst = Rect.fromCenter(
        center: band.center,
        width: dstH * aspect,
        height: dstH,
      );
      canvas.drawImageRect(
        logo,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      _text(
        canvas,
        'FCM',
        w * 0.24,
        FcmColors.silver,
        Offset(w / 2, band.center.dy - h * 0.025),
        italic: true,
        spacing: -1,
      );
      _text(
        canvas,
        'RIVALS',
        w * 0.115,
        FcmColors.gold,
        Offset(w / 2, band.center.dy + h * 0.06),
        italic: true,
        spacing: 3,
      );
    }

    // The tier's name on a deep plate with a tier-metal hairline: the
    // plate guarantees contrast on every metal, and the pack's grade
    // reads at a glance without a label under the cell.
    final plateText = switch (stars) {
      4 => 'EPIC',
      >= 5 => 'LEGENDARY',
      _ => 'RARE',
    };
    final plateFont = w * 0.082;
    final plateTp = _layoutText(plateText, plateFont, starFill, spacing: 2.5);
    final plateCenter = Offset(w / 2, h * 0.805);
    final plate = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: plateCenter,
        width: plateTp.width + w * 0.16,
        height: plateTp.height + w * 0.10,
      ),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF15130F).withValues(alpha: 0.94),
            const Color(0xFF0B0A0E).withValues(alpha: 0.98),
          ],
        ).createShader(plate.outerRect),
    );
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.008)
        ..color = metal.withValues(alpha: 0.85),
    );
    plateTp.paint(
      canvas,
      plateCenter - Offset(plateTp.width / 2, plateTp.height / 2),
    );

    // Ornament under the plate: hairline with a centre diamond.
    final orn = h * 0.885;
    final ornPaint = Paint()
      ..strokeWidth = math.max(0.8, w * 0.006)
      ..color = trim.withValues(alpha: 0.6);
    canvas.drawLine(Offset(w * 0.22, orn), Offset(w * 0.45, orn), ornPaint);
    canvas.drawLine(Offset(w * 0.55, orn), Offset(w * 0.78, orn), ornPaint);
    final dm = w * 0.022;
    canvas.drawPath(
      Path()
        ..moveTo(w / 2, orn - dm)
        ..lineTo(w / 2 + dm, orn)
        ..lineTo(w / 2, orn + dm)
        ..lineTo(w / 2 - dm, orn)
        ..close(),
      Paint()..color = trim.withValues(alpha: 0.9),
    );

    // Top gloss: the upper half catches the light.
    final gloss = Rect.fromLTWH(0, 0, w, h * 0.55);
    canvas.drawRect(
      gloss,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(gloss),
    );
    // Left rim light.
    final rim = Rect.fromLTWH(0, 0, w * 0.05, h);
    canvas.drawRect(
      rim,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(rim),
    );

    // Holographic sheen: a prismatic band sweeping across the foil as
    // [shimmer] loops, screened over the art like real holo stock.
    final hx = -w * 0.7 + shimmer * w * 2.5;
    final holoW = w * 0.38;
    final holo = Path()
      ..moveTo(hx, h)
      ..lineTo(hx + holoW, h)
      ..lineTo(hx + holoW + h * 0.45, 0)
      ..lineTo(hx + h * 0.45, 0)
      ..close();
    canvas.drawPath(
      holo,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const LinearGradient(
          colors: [
            Color(0x0000E5FF),
            Color(0x4400E5FF),
            Color(0x44FF4DD2),
            Color(0x44FFE14D),
            Color(0x00FFE14D),
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromLTWH(hx, 0, holoW + h * 0.45, h)),
    );

    // Idle foil shimmer: warm champagne sweep.
    final sx = -w * 0.5 + shimmer * w * 2.2;
    final sweep = Path()
      ..moveTo(sx, h)
      ..lineTo(sx + w * 0.16, h)
      ..lineTo(sx + w * 0.16 + h * 0.45, 0)
      ..lineTo(sx + h * 0.45, 0)
      ..close();
    canvas.drawPath(
      sweep,
      Paint()
        ..shader = LinearGradient(
          colors: [
            FcmColors.goldSoft.withValues(alpha: 0.0),
            FcmColors.goldSoft.withValues(alpha: 0.32),
            FcmColors.goldSoft.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(sx, 0, w * 0.7, h)),
    );

    // Charging: inner light bleeding through a growing crack.
    if (charge > 0) {
      final c = charge.clamp(0.0, 1.0);
      final mid = h * 0.5;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.2 + 0.9 * c,
            colors: [
              Color.lerp(
                Colors.white,
                glowColor,
                0.5,
              )!.withValues(alpha: 0.85 * c),
              glowColor.withValues(alpha: 0.0),
            ],
          ).createShader(rect),
      );
      final crack = Path()..moveTo(w * 0.5, mid);
      final rnd = math.Random(7);
      for (final dir in [-1.0, 1.0]) {
        var x = w * 0.5;
        var y = mid;
        final reach = w * 0.55 * c;
        var travelled = 0.0;
        crack.moveTo(x, y);
        while (travelled < reach) {
          final step = w * 0.06;
          x += dir * step;
          y += (rnd.nextDouble() - 0.5) * h * 0.05;
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

    // Wrapper rim.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, w * 0.012)
        ..color = shades == null
            ? FcmColors.gold.withValues(alpha: 0.5)
            : shades[0],
    );
  }

  /// Metallic ramp of a tier colour: [light, base, dark, deep]. Derived
  /// by shifting lightness only, so hue and saturation survive at full
  /// strength — amethyst reads as amethyst, sapphire as sapphire.
  static List<Color> _foilShades(Color base) {
    final hsl = HSLColor.fromColor(base);
    final l = hsl.lightness;
    Color shade(double lightness) =>
        hsl.withLightness(lightness.clamp(0.0, 0.92)).toColor();
    return [
      shade(l + 0.22), // sheen — top-left highlight and band centre
      base, // the tier metal itself
      shade(l * 0.45 + 0.07), // embossed band edges
      shade(l * 0.25 + 0.04), // deep bottom-right of the foil
    ];
  }

  void _text(
    Canvas canvas,
    String text,
    double size,
    Color color,
    Offset center, {
    bool italic = false,
    double spacing = 0,
  }) {
    final tp = _layoutText(text, size, color, italic: italic, spacing: spacing);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Lays one stamped wordmark line out — [_text] paints it centred,
  /// the label plate measures it first.
  TextPainter _layoutText(
    String text,
    double size,
    Color color, {
    bool italic = false,
    double spacing = 0,
  }) {
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
    return tp;
  }

  /// Whether the last paint stamped the decoded logo (vs the text
  /// fallback) — flips the repaint when the decode lands late.
  bool _paintedWithLogo = false;

  @override
  bool shouldRepaint(FoilPackPainter old) =>
      old.shimmer != shimmer ||
      old.charge != charge ||
      old.glowColor != glowColor ||
      old.tint != tint ||
      old.stars != stars ||
      old._paintedWithLogo != (packLogo != null);
}

/// Three player cards fanned out around [center]: two angled side cards
/// in the deeper tier metal, the hero card in the middle, larger and
/// bright, each wearing the same silhouette-and-stat-bars hint as the
/// real card face.
void _paintCardFan(
  Canvas canvas,
  Size size,
  Offset center,
  List<Color> ramp,
  Color trim,
) {
  final w = size.width;
  final cw = w * 0.30;
  final ch = cw / 0.70;

  void card(
    double dx,
    double dy,
    double angle,
    double scale, {
    required bool hero,
  }) {
    canvas.save();
    canvas.translate(center.dx + dx, center.dy + dy);
    canvas.rotate(angle);
    canvas.scale(scale, scale);
    canvas.translate(-cw / 2, -ch / 2);
    final cs = Size(cw, ch);
    final p = cardPath(cs);
    canvas.drawShadow(p, Colors.black, 6, true);
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hero
              ? [ramp[0], ramp[1], ramp[2]]
              : [ramp[1], ramp[2], ramp[3]],
        ).createShader(Offset.zero & cs),
    );
    canvas.save();
    canvas.clipPath(p);
    final ink = Paint()
      ..color = Colors.black.withValues(alpha: hero ? 0.30 : 0.22);
    // Player silhouette: head and shoulders.
    final hx = cw * 0.5;
    final hy = ch * 0.34;
    final hr = cw * 0.15;
    canvas.drawCircle(Offset(hx, hy), hr, ink);
    canvas.drawPath(
      Path()
        ..moveTo(hx - cw * 0.34, ch * 0.70)
        ..quadraticBezierTo(hx - cw * 0.32, hy + hr * 1.25, hx, hy + hr * 1.2)
        ..quadraticBezierTo(
          hx + cw * 0.32,
          hy + hr * 1.25,
          hx + cw * 0.34,
          ch * 0.70,
        )
        ..close(),
      ink,
    );
    // Rating chip and two stat bars.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cw * 0.12, ch * 0.09, cw * 0.24, cw * 0.14),
        Radius.circular(cw * 0.03),
      ),
      ink,
    );
    for (var i = 0; i < 2; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cw * 0.16,
            ch * (0.76 + i * 0.08),
            cw * 0.68,
            ch * 0.035,
          ),
          Radius.circular(cw * 0.02),
        ),
        ink,
      );
    }
    canvas.restore();
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cw * 0.035
        ..strokeJoin = StrokeJoin.round
        ..color = hero
            ? Colors.white.withValues(alpha: 0.9)
            : trim.withValues(alpha: 0.7),
    );
    canvas.restore();
  }

  card(-w * 0.19, w * 0.025, -0.22, 0.92, hero: false);
  card(w * 0.19, w * 0.025, 0.22, 0.92, hero: false);
  card(0, -w * 0.018, 0, 1.12, hero: true);
}

/// Thin tapered rays fanning out of [c] — the sunburst behind the cards.
void _paintSunburst(
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

/// A five-point star centred on [c] with outer radius [r], first point
/// straight up — drawn as a path so each star gets its own fill, rim
/// and drop shadow (a text glyph can only be one flat colour).
Path _starPath(Offset c, double r) {
  const points = 5;
  const inner = 0.45;
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / points;
    final rad = i.isEven ? r : r * inner;
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
