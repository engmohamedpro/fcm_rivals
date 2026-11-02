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
    final ovr = ((overall ?? player.baseStats.overall) * p).round();
    final shownStats = stats ?? statsFor(player);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
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
                      ),
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
                  color: ink.withValues(alpha: 0.75),
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
                      horizontal: w * 0.03, vertical: w * 0.008),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(w * 0.03),
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
            // Name plate — nothing at all renders until nameProgress
            // lifts it: the pack reveal lands the identity only after
            // the stats have counted up (no placeholder text).
            Positioned(
              left: w * 0.07,
              right: w * 0.07,
              top: h * 0.565,
              child: Opacity(
                opacity: nameProgress.clamp(0.0, 1.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    nameProgress <= 0.01 ? '' : player.name.toUpperCase(),
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
                                color: ink,
                                fontSize: w * 0.105,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            Text(
                              s.label,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: ink.withValues(alpha: 0.75),
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
    ),
    );
  }
}

/// The card back shown before the flip.
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
          colors: [Color(0xFF2A2731), Color(0xFF121014)],
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
            Container(
              width: width,
              height: h,
              decoration: BoxDecoration(
                boxShadow: [
                  if (!ghost)
                    BoxShadow(
                      color: (warn ? FcmColors.danger : rarity.accent)
                          .withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CardFacePainter(rarity: rarity, shine: null),
                      foregroundPainter:
                          ghost ? _GhostPainter() : null,
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
                            child: Text('$overall',
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                    color: ink,
                                    fontSize: width * 0.36,
                                    fontWeight: FontWeight.w900,
                                    height: 1)),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(position,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                    color: ink.withValues(alpha: 0.9),
                                    fontSize: width * 0.2,
                                    fontWeight: FontWeight.w800)),
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
