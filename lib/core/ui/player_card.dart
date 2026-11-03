/// FCM Rivals — premium player card (GDD 5.6 / 7.1).
///
/// One card design for every size in the game — the pack reveal, the
/// collection grid, the detail sheet, the pitch and bench. Everything is
/// drawn with [CustomPainter] in proportion to the card's width, so the
/// card looks identical at 56px and at 320px: a bright metal bezel, a
/// rarity-coloured face with its own motif (legendary sunburst, epic
/// crystal shards, rare arcs), a dark glass information panel, a foil
/// light sweep and a player silhouette, with the rating and attributes
/// laid on top. Stats count up from zero driven by [statProgress] so the
/// reveal can animate them.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/players.dart';
import 'country_flag.dart';
import 'fcm_logo.dart' show kFcmWordmarkAsset;
import 'fcm_style.dart';
import 'fcm_widgets.dart' show ratingColor, staminaColor;

/// Width : height ratio of the card.
const double kPlayerCardAspect = 0.70;

class FcmPlayerCard extends StatelessWidget {
  const FcmPlayerCard({
    super.key,
    required this.player,
    required this.rarity,
    this.width = 260,
    this.shine,
    this.statProgress = 1.0,
    this.nameProgress = 1.0,
    this.glow = 0.0,
    this.overall,
    this.stats,
    this.upgradeLevel = 0,
    this.nameLetters,
    this.maskName = false,
    this.maskPulse = 0.0,
  });

  final BasePlayer player;

  /// Rating to show instead of the base overall (owned, upgraded copies).
  final int? overall;

  /// Attribute values to show instead of the base ones.
  final List<({String label, int value})>? stats;

  /// Merge/upgrade level; shows a +N badge when above zero.
  final int upgradeLevel;
  final CardRarity rarity;

  /// Card width; height follows [kPlayerCardAspect].
  final double width;

  /// Foil sweep position, 0..1 across the card. `null` hides the sweep.
  final double? shine;

  /// 0..1 — how far the rating and attribute numbers have counted up.
  final double statProgress;

  /// 0..1 — the name's reveal (0 renders no text at all). The pack
  /// opening keeps the identity hidden until the stats have landed.
  final double nameProgress;

  /// 0..1 — outer glow strength behind the card.
  final double glow;

  /// Typewriter name reveal (the legendary walkout): 0..1 is the share of
  /// the name's letters on show, the rest holds its space invisibly so the
  /// name never shifts as it lands. Null uses the plain [nameProgress] fade.
  final double? nameLetters;

  /// Draws a breathing redacted bar where the name will land — the
  /// legendary walkout's "who is it?" slot. Only while the name is hidden.
  final bool maskName;

  /// 0..1 breathing phase of the redacted bar.
  final double maskPulse;

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
    final light = rarity.faceGradient.first;
    final p = statProgress.clamp(0.0, 1.0).toDouble();
    final ovr = ((overall ?? player.baseStats.overall) * p).round();
    final shownStats = stats ?? statsFor(player);
    final letters = nameLetters;
    final nameHidden = letters == null ? nameProgress <= 0.01 : letters <= 0;

    // Engraved look for the dark ink on the bright metal: a faint light
    // edge just below each glyph.
    final engrave = [
      Shadow(
        color: Colors.white.withValues(alpha: 0.45),
        offset: Offset(0, w * 0.006),
      ),
    ];

    final nameStyle = TextStyle(
      color: Colors.white,
      fontSize: w * 0.088,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
      shadows: [
        const Shadow(color: Colors.black, blurRadius: 6),
        if (letters != null)
          Shadow(
            color: rarity.accent.withValues(alpha: 0.9),
            blurRadius: w * 0.05,
          ),
      ],
    );

    Widget nameWidget() {
      final full = player.name.toUpperCase();
      if (letters == null) {
        return Text(nameHidden ? '' : full, maxLines: 1, style: nameStyle);
      }
      // Nothing at all (not even an invisible name) until the first
      // letter lands — the identity must not leak to screen readers.
      if (nameHidden) return Text('', maxLines: 1, style: nameStyle);
      final shown = math.min(
        full.length,
        math.max(0, (full.length * letters).ceil()),
      );
      return Text.rich(
        TextSpan(
          style: nameStyle,
          children: [
            TextSpan(text: full.substring(0, shown)),
            TextSpan(
              text: full.substring(shown),
              style: const TextStyle(
                color: Colors.transparent,
                shadows: <Shadow>[],
              ),
            ),
          ],
        ),
        maxLines: 1,
      );
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CardFacePainter(
                  rarity: rarity,
                  shine: shine,
                  glow: glow,
                ),
              ),
            ),
            // Rating, position, flag.
            Positioned(
              left: w * 0.075,
              top: h * 0.10,
              width: w * 0.30,
              child: Column(
                children: [
                  SizedBox(
                    width: w * 0.30,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$ovr',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: ink,
                          fontSize: w * 0.20,
                          fontWeight: FontWeight.w900,
                          height: 0.95,
                          shadows: engrave,
                        ),
                      ),
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      player.position.code,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.92),
                        fontSize: w * 0.085,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        shadows: engrave,
                      ),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(vertical: h * 0.012),
                    height: math.max(1.0, w * 0.008),
                    width: w * 0.12,
                    color: ink.withValues(alpha: 0.4),
                  ),
                  Text(
                    flagEmojiFor(player.nationality),
                    style: TextStyle(fontSize: w * 0.095),
                  ),
                  SizedBox(height: w * 0.015),
                  // Nationality name under the flag — always visible like
                  // the flag itself (the walkout already told the country).
                  SizedBox(
                    width: w * 0.30,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        player.nationality.toUpperCase(),
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.92),
                          fontSize: w * 0.045,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tier ribbon, top-right.
            Positioned(
              right: w * 0.10,
              top: h * 0.085,
              child: Text(
                rarity.label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: ink.withValues(alpha: 0.78),
                  fontSize: w * 0.04,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
            if (upgradeLevel > 0)
              Positioned(
                right: w * 0.09,
                top: h * 0.125,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.03,
                    vertical: w * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(w * 0.03),
                    border: Border.all(
                      color: FcmColors.gold.withValues(alpha: 0.7),
                      width: math.max(0.5, w * 0.004),
                    ),
                  ),
                  child: Text(
                    '+$upgradeLevel',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: FcmColors.gold,
                      fontSize: w * 0.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            // Redacted name slot: a breathing bar where the identity will
            // land — shown only by the legendary walkout, while it waits.
            if (maskName && nameHidden)
              Positioned(
                left: w * 0.20,
                right: w * 0.20,
                top: h * 0.585,
                height: h * 0.034,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: light.withValues(
                      alpha: 0.14 + 0.20 * maskPulse.clamp(0.0, 1.0),
                    ),
                    borderRadius: BorderRadius.circular(h * 0.017),
                  ),
                ),
              ),
            // Name plate — nothing at all renders until the reveal lifts
            // it: the pack reveal lands the identity only after the stats
            // have counted up (no placeholder text).
            Positioned(
              left: w * 0.07,
              right: w * 0.07,
              top: h * 0.568,
              height: h * 0.07,
              child: Opacity(
                opacity: letters != null
                    ? (nameHidden ? 0.0 : 1.0)
                    : nameProgress.clamp(0.0, 1.0),
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: nameWidget()),
                ),
              ),
            ),
            // Attribute row — equal cells, each shrinks to fit.
            Positioned(
              left: w * 0.08,
              right: w * 0.08,
              top: h * 0.705,
              child: Row(
                children: [
                  for (final s in shownStats)
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(s.value * p).round()}',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w * 0.105,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                            Text(
                              s.label,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: light.withValues(alpha: 0.9),
                                fontSize: w * 0.048,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// The card back shown before the flip: carbon-black face, the rarity's
/// metal bezel and frames, the brand wordmark and the rarity stars.
class FcmPlayerCardBack extends StatelessWidget {
  const FcmPlayerCardBack({super.key, required this.rarity, this.width = 260});

  final CardRarity rarity;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width / kPlayerCardAspect;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CardBackPainter(rarity: rarity)),
          ),
          Image.asset(
            kFcmWordmarkAsset,
            width: width * 0.72,
            cacheWidth: 480,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            // The back is still a card without its wordmark.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

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

class _CardFacePainter extends CustomPainter {
  _CardFacePainter({
    required this.rarity,
    required this.shine,
    this.glow = 0.0,
    this.glowColor,
  });

  final CardRarity rarity;
  final double? shine;

  /// 0..1 aura strength following the card silhouette.
  final double glow;

  /// Aura colour; the rarity accent when null.
  final Color? glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final path = cardPath(size);
    final g = rarity.faceGradient;
    final hair = math.max(0.5, w * 0.006);

    // Aura: a soft halo hugging the silhouette (not a square box).
    if (glow > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = (glowColor ?? rarity.accent).withValues(
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
  bool shouldRepaint(_CardFacePainter old) =>
      old.rarity != rarity ||
      old.shine != shine ||
      old.glow != glow ||
      old.glowColor != glowColor;
}

class _CardBackPainter extends CustomPainter {
  _CardBackPainter({required this.rarity});

  final CardRarity rarity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final path = cardPath(size);
    final g = rarity.faceGradient;
    final accent = rarity.accent;
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
  bool shouldRepaint(_CardBackPainter old) => old.rarity != rarity;
}

/// Compact card for the pitch and bench: rating, position, surname, an
/// optional three-column stat row and a colour-coded stamina bar.
/// [width] is the shield width; everything else stacks under it.
class FcmMiniCard extends StatelessWidget {
  const FcmMiniCard({
    super.key,
    required this.overall,
    required this.position,
    required this.name,
    required this.rarity,
    this.width = 56,
    this.warn = false,
    this.stamina,
    this.stats,
    this.ghost = false,
  });

  final int overall;
  final String position;
  final String name;
  final CardRarity rarity;
  final double width;

  /// Red outline when the player is out of position.
  final bool warn;

  /// Stamina percent 0..100; null hides the bar.
  final int? stamina;

  /// The player's attributes (label + value), rendered as a three-column
  /// stat row under the name — outfield ATT/SUP/DEF, keepers GK/DEF/SUP.
  final List<({String label, int value})>? stats;

  /// Renders the card as an empty slot placeholder: same silhouette,
  /// proportions and text slots as a filled card, but dimmed (charcoal
  /// face, no glow) with no overall, position or name — the formation
  /// and bench read as a grid of same-shaped cards where the unassigned
  /// ones are simply see-through.
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final h = width / kPlayerCardAspect;
    final ink = rarity.ink;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: width + 12,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CardFacePainter(
                        rarity: rarity,
                        shine: null,
                        glow: ghost ? 0.0 : 0.8,
                        glowColor: warn ? FcmColors.danger : null,
                      ),
                      foregroundPainter: ghost ? _GhostPainter() : null,
                    ),
                  ),
                  if (warn)
                    Positioned.fill(
                      child: CustomPaint(painter: _WarnPainter()),
                    ),
                  // The ghost draws no overall and no position — the card
                  // keeps the text slots' footprint but stays wordless.
                  if (!ghost)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: h * 0.17,
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$overall',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: ink,
                                fontSize: width * 0.36,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              position,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: ink.withValues(alpha: 0.9),
                                fontSize: width * 0.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            // Ghost keeps the surname slot's footprint without text: a
            // fixed-height box the size of one name line.
            if (ghost)
              SizedBox(height: math.max(9, width * 0.19) * 1.0)
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name.toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: math.max(9, width * 0.19),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
            if (stats != null && stats!.isNotEmpty) ...[
              const SizedBox(height: 2),
              _StatRow(stats: stats!, width: width),
            ],
            if (stamina != null) ...[
              const SizedBox(height: 3),
              _StaminaBar(percent: stamina!, width: width),
            ],
          ],
        ),
      ),
    );
  }
}

/// Overlay for ghost mini cards: washes the card face to a translucent
/// charcoal and adds the same borders as a live card, so an empty slot
/// keeps the silhouette of a filled one at reduced opacity.
class _GhostPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = cardPath(size);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF121014).withValues(alpha: 0.82),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.012
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.save();
    canvas.translate(size.width * 0.03, size.height * 0.02);
    canvas.scale(0.94, 0.96);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.006
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Three label-over-value stat columns under the card; values are coloured
/// by rating so strengths read at a glance.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.stats, required this.width});

  final List<({String label, int value})> stats;
  final double width;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in stats)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.06),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.label,
                    style: TextStyle(
                      color: FcmColors.goldSoft.withValues(alpha: 0.8),
                      fontSize: math.max(6.5, width * 0.115),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    '${s.value}',
                    style: TextStyle(
                      color: ratingColor(s.value),
                      fontSize: math.max(9, width * 0.17),
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Colour-coded stamina strip under a mini card: the fill length is the
/// percent and the colour grades green → gold → amber → red as it drops.
/// The fill is pinned with [Positioned] inside a fixed-height track so it
/// always renders with real height (a FractionallySizedBox with only a
/// width factor collapses its child to zero height).
class _StaminaBar extends StatelessWidget {
  const _StaminaBar({required this.percent, required this.width});

  final int percent;
  final double width;

  static const double trackHeight = 5;

  @override
  Widget build(BuildContext context) {
    final color = staminaColor(percent);
    final fill = (percent / 100).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fill),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, f, _) => Container(
        width: width,
        height: trackHeight,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(trackHeight / 2),
          border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(trackHeight / 2),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: width * f,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.75), color],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarnPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      cardPath(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.06
        ..color = FcmColors.danger,
    );
  }

  @override
  bool shouldRepaint(_WarnPainter old) => false;
}

/// Convenience: sin-based 0..1 pulse for idle glows.
double pulse(double t, {double cycles = 1}) =>
    0.5 + 0.5 * math.sin(t * 2 * math.pi * cycles);
