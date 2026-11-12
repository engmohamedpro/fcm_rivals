/// FCM Rivals — premium player card (GDD 5.6 / 7.1).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../domain/players.dart';
import 'card_rarity.dart' as domain;
import 'country_flag.dart';
import 'fcm_logo.dart' show kFcmWordmarkAsset;

export 'card_rarity.dart';
export 'mini_card.dart';
export 'player_card_painters.dart';

/// Constant aspect ratio used across the app for player cards.
const double kPlayerCardAspect = 0.70;

enum PlayerCardRarity { rare, epic, legendary, premium, icon }

enum CardSize { big, small }

class PlayerStat {
  const PlayerStat(this.title, this.value);
  final String title;
  final int value;
}

// ───────────────────────────── Palettes ─────────────────────────────

class _Palette {
  const _Palette({
    required this.light,
    required this.base,
    required this.deep,
    required this.edgeLight,
    required this.edgeDark,
    required this.glow,
    required this.accent,
    required this.text,
    required this.panel,
    required this.panelAlpha,
    this.holo = false,
  });

  final Color light, base, deep;
  final Color edgeLight, edgeDark;
  final Color glow, accent, text;
  final Color panel;
  final double panelAlpha;
  final bool holo;

  bool get darkText => text.computeLuminance() < 0.4;
}

_Palette _paletteOf(PlayerCardRarity r) {
  switch (r) {
    case PlayerCardRarity.rare:
      return const _Palette(
        light: Color(0xFF9B6BFF),
        base: Color(0xFF4B2A8C),
        deep: Color(0xFF1A0B33),
        edgeLight: Color(0xFFE0CCFF),
        edgeDark: Color(0xFF3A1D73),
        glow: Color(0xFF8A4DFF),
        accent: Color(0xFFD2B8FF),
        text: Color(0xFFF7F1FF),
        panel: Color(0xFF12061F),
        panelAlpha: .78,
      );
    case PlayerCardRarity.epic:
      return const _Palette(
        light: Color(0xFF5BB6FF),
        base: Color(0xFF1456B8),
        deep: Color(0xFF061A3A),
        edgeLight: Color(0xFFCDEBFF),
        edgeDark: Color(0xFF0B3170),
        glow: Color(0xFF2E9BFF),
        accent: Color(0xFF9AD6FF),
        text: Color(0xFFF2F9FF),
        panel: Color(0xFF04112A),
        panelAlpha: .78,
      );
    case PlayerCardRarity.legendary:
      return const _Palette(
        light: Color(0xFFFFE08A),
        base: Color(0xFFC48A1E),
        deep: Color(0xFF6B4508),
        edgeLight: Color(0xFFFFF4C9),
        edgeDark: Color(0xFF7A4F0A),
        glow: Color(0xFFFFC53D),
        accent: Color(0xFF5E3C06),
        text: Color(0xFF2B1B05),
        panel: Color(0xFFFFE9A6),
        panelAlpha: .32,
      );
    case PlayerCardRarity.premium:
      return const _Palette(
        light: Color(0xFFFF5A5F),
        base: Color(0xFFB0121F),
        deep: Color(0xFF2A0508),
        edgeLight: Color(0xFFFFD0C7),
        edgeDark: Color(0xFF5E0A12),
        glow: Color(0xFFFF2E3B),
        accent: Color(0xFFFFA79D),
        text: Color(0xFFFFF4F2),
        panel: Color(0xFF1E0306),
        panelAlpha: .8,
      );
    case PlayerCardRarity.icon:
      return const _Palette(
        light: Color(0xFFFFFFFF),
        base: Color(0xFFDDE4EF),
        deep: Color(0xFF8C9AB4),
        edgeLight: Color(0xFFFFFBEA),
        edgeDark: Color(0xFFA8842F),
        glow: Color(0xFFBFE6FF),
        accent: Color(0xFF9C7A28),
        text: Color(0xFF101A2C),
        panel: Color(0xFFFFFFFF),
        panelAlpha: .5,
        holo: true,
      );
  }
}

// ───────────────────────────── Geometry ─────────────────────────────

Path _roundedPolygon(List<Offset> pts, double r) {
  final path = Path();
  final n = pts.length;
  for (int i = 0; i < n; i++) {
    final prev = pts[(i - 1 + n) % n];
    final cur = pts[i];
    final next = pts[(i + 1) % n];
    final v1 = prev - cur;
    final v2 = next - cur;
    final d1 = math.min(r, v1.distance / 2);
    final d2 = math.min(r, v2.distance / 2);
    final start = cur + v1 / v1.distance * d1;
    final end = cur + v2 / v2.distance * d2;
    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(cur.dx, cur.dy, end.dx, end.dy);
  }
  path.close();
  return path;
}

Path buildCardPath(Size s, {double inset = 0}) {
  final w = s.width, h = s.height;
  final pts = <Offset>[
    Offset(0, h * .065),
    Offset(w * .5, 0),
    Offset(w, h * .065),
    Offset(w, h * .885),
    Offset(w * .5, h),
    Offset(0, h * .885),
  ];
  final path = _roundedPolygon(pts, w * .045);
  if (inset <= 0) return path;
  final sx = (w - 2 * inset) / w;
  final sy = (h - 2 * inset) / h;
  final m = Matrix4(
    sx, 0, 0, 0,
    0, sy, 0, 0,
    0, 0, 1, 0,
    w / 2 * (1 - sx), h / 2 * (1 - sy), 0, 1,
  );
  return path.transform(m.storage);
}

class _CardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => buildCardPath(size);
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ───────────────────────────── Painter ─────────────────────────────

class PlayerCardPainter extends CustomPainter {
  PlayerCardPainter({
    required this.rarity,
    this.shimmer = .35,
    this.showDetails = true,
    this.isBack = false,
  });

  final PlayerCardRarity rarity;
  final double shimmer;
  final bool showDetails;
  final bool isBack;

  @override
  void paint(Canvas canvas, Size size) {
    final pal = _paletteOf(rarity);
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    final path = buildCardPath(size);
    final k = w / 260;

    canvas.drawShadow(path.shift(Offset(0, h * .012)), Colors.black, w * .04, true);
    canvas.drawPath(
      path.shift(Offset(0, h * .008)),
      Paint()
        ..color = pal.glow.withValues(alpha: .38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * .05),
    );

    canvas.save();
    canvas.clipPath(path);

    final Color c0, c1, c2;
    if (isBack) {
      c0 = Color.lerp(pal.deep, Colors.black, .35)!;
      c1 = Color.lerp(pal.deep, Colors.black, .65)!;
      c2 = Color.lerp(pal.deep, Colors.black, .88)!;
    } else {
      c0 = pal.light;
      c1 = pal.base;
      c2 = pal.deep;
    }
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c0, c1, c2],
          stops: const [0, .52, 1],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(.25, -.45),
          radius: .85,
          colors: [
            (isBack ? pal.glow : pal.light).withValues(alpha: isBack ? .30 : .55),
            Colors.transparent,
          ],
        ).createShader(rect),
    );

    _facets(canvas, size);

    // Fine speckle (brushed-metal grain)
    final rnd = math.Random(11);
    for (int i = 0; i < 170; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
        (.25 + rnd.nextDouble() * .55) * k,
        Paint()..color = Colors.white.withValues(alpha: .04 + rnd.nextDouble() * .12),
      );
    }

    if (isBack) {
      _backOrnament(canvas, size, pal);
    } else {
      final panelRect = Rect.fromLTWH(0, h * .56, w, h * .44);
      canvas.drawRect(
        panelRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              pal.panel.withValues(alpha: 0),
              pal.panel.withValues(alpha: pal.panelAlpha),
            ],
            stops: const [0, .55],
          ).createShader(panelRect),
      );
    }

    if (pal.holo) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            transform: GradientRotation(shimmer * .9),
            colors: [
              const Color(0xFF6FE7FF).withValues(alpha: .30),
              const Color(0xFFFF8AD8).withValues(alpha: .22),
              const Color(0xFFFFE27A).withValues(alpha: .28),
              const Color(0xFF8FA8FF).withValues(alpha: .24),
              const Color(0xFF6FE7FF).withValues(alpha: .30),
            ],
            stops: const [0, .28, .52, .76, 1],
          ).createShader(rect),
      );
    }

    final t = -.25 + 1.5 * shimmer;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0x00FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
          stops: [
            (t - .13).clamp(0.0, 1.0),
            t.clamp(0.0, 1.0),
            (t + .13).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
    );

    canvas.restore();

    final fw = w * .022;
    canvas.drawPath(
      buildCardPath(size, inset: fw / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fw
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [pal.edgeLight, pal.edgeDark, pal.edgeLight, pal.edgeDark],
          stops: const [0, .38, .62, 1],
        ).createShader(rect),
    );
    canvas.drawPath(
      buildCardPath(size, inset: w * .042),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.8, 1.1 * k)
        ..color = pal.edgeLight.withValues(alpha: .55),
    );
    canvas.drawPath(
      buildCardPath(size, inset: w * .054),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.5, .6 * k)
        ..color = pal.edgeLight.withValues(alpha: .22),
    );
    canvas.drawPath(
      buildCardPath(size, inset: .4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .85),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: .45),
          ],
          stops: const [0, .5, 1],
        ).createShader(rect),
    );

    if (showDetails && !isBack) {
      final y = h * .722;
      final line = Rect.fromLTWH(w * .12, y - 1, w * .76, 2);
      canvas.drawLine(
        Offset(w * .12, y),
        Offset(w * .88, y),
        Paint()
          ..strokeWidth = math.max(.8, 1.2 * k)
          ..shader = LinearGradient(colors: [
            pal.accent.withValues(alpha: 0),
            pal.accent.withValues(alpha: .85),
            pal.accent.withValues(alpha: 0),
          ]).createShader(line),
      );
      final d = w * .012;
      canvas.drawPath(
        Path()
          ..moveTo(w / 2, y - d)
          ..lineTo(w / 2 + d, y)
          ..lineTo(w / 2, y + d)
          ..lineTo(w / 2 - d, y)
          ..close(),
        Paint()..color = pal.accent,
      );
    }
  }

  void _facets(Canvas canvas, Size s) {
    Offset o(double x, double y) => Offset(x * s.width, y * s.height);
    final facets = <(List<Offset>, bool, double)>[
      ([o(0, 0), o(.55, 0), o(0, .5)], true, .12),
      ([o(.55, 0), o(1, 0), o(1, .40)], false, .12),
      ([o(0, .5), o(.55, 0), o(1, .40)], true, .07),
      ([o(0, .5), o(1, .40), o(1, 1), o(0, 1)], false, .14),
      ([o(0, .70), o(.60, .58), o(.35, 1), o(0, 1)], true, .08),
      ([o(.60, .58), o(1, .62), o(1, 1), o(.35, 1)], false, .12),
    ];
    for (final (pts, light, op) in facets) {
      final p = Path()..addPolygon(pts, true);
      final col = light ? Colors.white : Colors.black;
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [col.withValues(alpha: op), col.withValues(alpha: op * .25)],
          ).createShader(p.getBounds()),
      );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .6
          ..color = Colors.white.withValues(alpha: .07),
      );
    }
  }

  void _backOrnament(Canvas canvas, Size s, _Palette pal) {
    final w = s.width, h = s.height;
    final c = Offset(w / 2, h / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = pal.edgeLight.withValues(alpha: .13);
    for (int i = 1; i <= 7; i++) {
      final dx = w * .085 * i, dy = h * .065 * i;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - dy)
          ..lineTo(c.dx + dx, c.dy)
          ..lineTo(c.dx, c.dy + dy)
          ..lineTo(c.dx - dx, c.dy)
          ..close(),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PlayerCardPainter old) =>
      old.rarity != rarity ||
      old.shimmer != shimmer ||
      old.showDetails != showDetails ||
      old.isBack != isBack;
}

// ───────────────────────────── Front widget ─────────────────────────────

class PlayerCardWidget extends StatelessWidget {
  const PlayerCardWidget({
    super.key,
    required this.rarity,
    required this.rating,
    required this.position,
    required this.flag,
    required this.teamLogo,
    this.playerImage,
    this.imageHasBackground,
    this.size = CardSize.big,
    this.name,
    this.nameLetters,
    this.nationalityFallbackText,
    this.upgradeLevel = 0,
    this.stats = const [],
    this.width,
    this.fontFamily,
    this.shimmer = .35,
  });

  final PlayerCardRarity rarity;
  final int rating;
  final String position;
  final dynamic flag; // ImageProvider or String
  final ImageProvider teamLogo;
  final ImageProvider? playerImage;
  final bool? imageHasBackground;
  final CardSize size;
  final String? name;
  final double? nameLetters;
  final String? nationalityFallbackText;
  final int upgradeLevel;
  final List<PlayerStat> stats;
  final double? width;
  final String? fontFamily;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    final big = size == CardSize.big;
    final w = width ?? (big ? 260.0 : 120.0);
    final h = w / kPlayerCardAspect;
    final pal = _paletteOf(rarity);

    TextStyle ts(double fs, FontWeight fw,
        {double ls = 0, Color? color, double? height}) {
      final dark = pal.darkText;
      return TextStyle(
        fontFamily: fontFamily,
        fontSize: fs,
        fontWeight: fw,
        letterSpacing: ls,
        height: height,
        color: color ?? pal.text,
        fontFeatures: const [ui.FontFeature.tabularFigures()],
        shadows: [
          Shadow(
            color: dark
                ? Colors.white.withValues(alpha: .35)
                : Colors.black.withValues(alpha: .55),
            offset: Offset(0, math.max(.8, w * .006)),
            blurRadius: w * .012,
          ),
        ],
      );
    }

    Widget buildNameWidget() {
      final full = (name ?? '').toUpperCase();
      final letters = nameLetters;
      if (letters == null) {
        if (full.isEmpty) return const SizedBox.shrink();
        return Text(full, maxLines: 1, style: ts(w * .10, FontWeight.w900, ls: w * .004));
      }
      if (letters <= 0) return const SizedBox.shrink();
      final shown = math.min(full.length, math.max(0, (full.length * letters).ceil()));
      return Text.rich(
        TextSpan(
          style: ts(w * .10, FontWeight.w900, ls: w * .004),
          children: [
            TextSpan(text: full.substring(0, shown)),
            TextSpan(
              text: full.substring(shown),
              style: const TextStyle(color: Colors.transparent),
            ),
          ],
        ),
        maxLines: 1,
      );
    }

    Widget buildUpgradeBadge(double fontSize, double paddingH, double paddingV) {
      if (upgradeLevel <= 0) return const SizedBox.shrink();
      return Container(
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3D2F10), Color(0xFF1F1705)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(fontSize * 0.4),
          border: Border.all(
            color: const Color(0xFFFFC53D),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC53D).withValues(alpha: 0.5),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '+$upgradeLevel',
          style: TextStyle(
            color: const Color(0xFFFFC53D),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
      );
    }

    final nationalityFallback = nationalityFallbackText != null
        ? Center(
            child: Text(
              nationalityFallbackText!.toUpperCase(),
              style: ts(w * .05, FontWeight.w800),
            ),
          )
        : const SizedBox.shrink();

    // Small card layout
    if (!big) {
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: PlayerCardPainter(
                    rarity: rarity, shimmer: shimmer, showDetails: false),
              ),
            ),
            // Premium floating upgrade badge above small cards too
            if (upgradeLevel > 0)
              Positioned(
                top: -10,
                right: -4,
                child: buildUpgradeBadge(10, 7, 2.5),
              ),
            Positioned.fill(
              child: ClipPath(
                clipper: _CardClipper(),
                child: Stack(
                  children: [
                    // Top-left: Rating & bigger Position
                    Positioned(
                      left: w * .08,
                      top: h * .08,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Opacity(
                                  opacity: 0.0,
                                  child: Text(
                                    rating == 99 ? '98' : '99',
                                    style: ts(w * .34, FontWeight.w900, ls: -1, height: 1),
                                  ),
                                ),
                                Text(
                                  '$rating',
                                  style: ts(w * .34, FontWeight.w900, ls: -1, height: 1),
                                ),
                              ],
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              position.toUpperCase(),
                              style: ts(w * .15, FontWeight.w800, ls: .5, height: 1.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Top-right: Smaller player image beside overall
                    Positioned(
                      right: w * .04,
                      top: h * .06,
                      width: w * .42,
                      height: h * .50,
                      child: _PlayerImage(
                          image: playerImage, hasBackground: imageHasBackground, pal: pal, isSmall: true),
                    ),
                    // Bottom: Flag and team logo side by side, moved up a bit (top: h * .52), with identical equal box sizing
                    Positioned(
                      left: w * .08,
                      right: w * .08,
                      top: h * .52,
                      height: h * .36,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Flag (equal box, no border)
                          SizedBox(
                            width: w * .36,
                            height: h * .28,
                            child: Center(
                              child: flag is ImageProvider
                                  ? Image(
                                      image: flag as ImageProvider,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    )
                                  : Text(
                                      flag.toString(),
                                      style: TextStyle(fontSize: w * .24),
                                    ),
                            ),
                          ),
                          SizedBox(width: w * .06),
                          // Team Logo (equal box matching flag)
                          SizedBox(
                            width: w * .36,
                            height: h * .28,
                            child: Center(
                              child: Image(
                                image: teamLogo,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, _, _) => nationalityFallback,
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
          ],
        ),
      );
    }

    // Big card layout (with nationality flag and team logo on the left)
    final flagW = w * .115;
    final logoS = w * .135;

    final left = Positioned(
      left: w * .06,
      top: h * .12,
      width: w * .2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Opacity(
                  opacity: 0.0,
                  child: Text(
                    rating == 99 ? '98' : '99',
                    style: ts(w * .185, FontWeight.w900, ls: -1, height: 1),
                  ),
                ),
                Text(
                  '$rating',
                  style: ts(w * .185, FontWeight.w900, ls: -1, height: 1),
                ),
              ],
            ),
          ),
          Text(position.toUpperCase(),
              style: ts(w * .075, FontWeight.w800, ls: .5, height: 1.15)),
          SizedBox(height: w * .02),
          Container(
              width: w * .11, height: 1, color: pal.accent.withValues(alpha: .7)),
          SizedBox(height: w * .035),
          // Nationality flag (no border)
          Container(
            width: flagW,
            height: flagW * .68,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              image: flag is ImageProvider
                  ? DecorationImage(image: flag as ImageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: flag is String
                ? Text(flag as String, style: TextStyle(fontSize: flagW * 0.7))
                : null,
          ),
          SizedBox(height: w * .035),
          Image(
            image: teamLogo,
            width: logoS,
            height: logoS,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => nationalityFallback,
          ),
        ],
      ),
    );

    final image = Positioned(
      left: w * .30,
      right: w * .03,
      top: h * .055,
      height: h * .575,
      child: _PlayerImage(
          image: playerImage, hasBackground: imageHasBackground, pal: pal, isSmall: false),
    );

    final shownStats = stats.take(3).toList();

    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: PlayerCardPainter(
                  rarity: rarity, shimmer: shimmer, showDetails: true),
            ),
          ),
          // Premium floating upgrade badge above the card for big cards
          if (upgradeLevel > 0)
            Positioned(
              top: -14,
              right: -6,
              child: buildUpgradeBadge(13, 10, 4),
            ),
          Positioned.fill(
            child: ClipPath(
              clipper: _CardClipper(),
              child: Stack(
                children: [
                  image,
                  left,
                  if (name != null)
                    Positioned(
                      left: w * .08,
                      right: w * .08,
                      top: h * .645,
                      height: h * .07,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: buildNameWidget(),
                      ),
                    ),
                  if (shownStats.isNotEmpty)
                    Positioned(
                      left: w * .09,
                      right: w * .09,
                      top: h * .745,
                      height: h * .13,
                      child: Row(
                        children: [
                          for (int i = 0; i < shownStats.length; i++)
                            Expanded(
                              child: Container(
                                decoration: i == 0
                                    ? null
                                    : BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: pal.accent
                                                .withValues(alpha: .45),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${shownStats[i].value}',
                                          style: ts(w * .105, FontWeight.w900,
                                              height: 1.05)),
                                      Text(shownStats[i].title.toUpperCase(),
                                          style: ts(w * .045, FontWeight.w700,
                                              ls: 1,
                                              color: pal.text
                                                  .withValues(alpha: .85))),
                                    ],
                                  ),
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
        ],
      ),
    );
  }
}

// ───────────────────────────── Player image ─────────────────────────────

final Map<Object, bool> _bgCache = {};

Future<bool> _detectBackground(ImageProvider provider) async {
  final completer = Completer<ui.Image>();
  final stream =
      ResizeImage(provider, width: 96).resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
      stream.removeListener(listener);
    },
    onError: (e, st) {
      if (!completer.isCompleted) completer.completeError(e, st);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);

  final img = await completer.future;
  final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
  final w = img.width, h = img.height;
  img.dispose();
  if (data == null || w < 4 || h < 4) return false;

  int total = 0, opaque = 0;
  const t = 2;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (x < t || y < t || x >= w - t || y >= h - t) {
        total++;
        if (data.getUint8((y * w + x) * 4 + 3) > 200) opaque++;
      }
    }
  }
  return total > 0 && opaque / total > .5;
}

class _PlayerImage extends StatefulWidget {
  const _PlayerImage({
    required this.image,
    required this.hasBackground,
    required this.pal,
    this.isSmall = false,
  });

  final ImageProvider? image;
  final bool? hasBackground;
  final _Palette pal;
  final bool isSmall;

  @override
  State<_PlayerImage> createState() => _PlayerImageState();
}

class _PlayerImageState extends State<_PlayerImage> {
  bool? _bg;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _PlayerImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image || old.hasBackground != widget.hasBackground) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final p = widget.image;
    if (p == null) {
      _bg = null;
      return;
    }
    if (widget.hasBackground != null) {
      _bg = widget.hasBackground;
      return;
    }
    final cached = _bgCache[p];
    if (cached != null) {
      _bg = cached;
      return;
    }
    _bg = null;
    bool result;
    try {
      result = await _detectBackground(p);
    } catch (_) {
      result = false;
    }
    _bgCache[p] = result;
    if (mounted && widget.image == p) setState(() => _bg = result);
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    Widget playerPng() => LayoutBuilder(
          builder: (context, constraints) {
            final shift = constraints.maxHeight * (widget.isSmall ? 0.35 : 0.22);
            return Transform.translate(
              offset: Offset(0, -shift),
              child: Image.asset(
                'assets/images/player.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) =>
                    CustomPaint(painter: _SilhouettePainter(pal)),
              ),
            );
          },
        );

    final fallback = SizedBox.expand(child: playerPng());
    if (widget.image == null) return fallback;
    final hasBg = _bg;
    if (hasBg == null) return const SizedBox.expand();

    final img = Image(
      image: widget.image!,
      fit: hasBg ? BoxFit.cover : BoxFit.contain,
      alignment: hasBg ? Alignment.topCenter : Alignment.bottomCenter,
      filterQuality: FilterQuality.high,
      color: hasBg ? pal.base.withValues(alpha: .18) : null,
      colorBlendMode: hasBg ? BlendMode.softLight : null,
      errorBuilder: (_, _, _) => playerPng(),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: ShaderMask(
        key: ValueKey(hasBg),
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => hasBg
            ? const RadialGradient(
                center: Alignment(0, -.1),
                radius: .78,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, .62, 1],
              ).createShader(r)
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, .82, 1],
              ).createShader(r),
        child: img,
      ),
    );
  }
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.pal);
  final _Palette pal;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final rect = Offset.zero & s;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          pal.deep.withValues(alpha: .70),
          pal.deep.withValues(alpha: .0),
        ],
        stops: const [.2, 1],
      ).createShader(rect);

    canvas.drawCircle(Offset(w * .5, h * .34), w * .20, paint);
    canvas.drawPath(
      Path()
        ..moveTo(w * .06, h)
        ..cubicTo(w * .06, h * .72, w * .28, h * .62, w * .5, h * .62)
        ..cubicTo(w * .72, h * .62, w * .94, h * .72, w * .94, h)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) => old.pal != pal;
}

// ───────────────────────────── Back ─────────────────────────────

class PlayerCardBackWidget extends StatelessWidget {
  const PlayerCardBackWidget({
    super.key,
    required this.rarity,
    this.size = CardSize.big,
    this.width,
    this.logoAsset = kFcmWordmarkAsset,
    this.shimmer = .35,
  });

  final PlayerCardRarity rarity;
  final CardSize size;
  final double? width;
  final String logoAsset;
  final double shimmer;

  @override
  Widget build(BuildContext context) {
    final w = width ?? (size == CardSize.big ? 260.0 : 120.0);
    final h = w / kPlayerCardAspect;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: PlayerCardPainter(
                rarity: rarity,
                shimmer: shimmer,
                showDetails: false,
                isBack: true,
              ),
            ),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: _CardClipper(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(w * .14, h * .12, w * .14, h * .1),
                child: Image.asset(
                  logoAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Flip animation ─────────────────────────────

class FlippablePlayerCard extends StatefulWidget {
  const FlippablePlayerCard({
    super.key,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 600),
  });

  final Widget front;
  final Widget back;
  final Duration duration;

  @override
  State<FlippablePlayerCard> createState() => _FlippablePlayerCardState();
}

class _FlippablePlayerCardState extends State<FlippablePlayerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);

  void _toggle() => _c.isCompleted || _c.velocity > 0 ? _c.reverse() : _c.forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (_, _) {
          final angle = _curve.value * math.pi;
          final showBack = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0012)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}

// ───────────────────────────── FCM Integration Adapters ─────────────────────────────

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
    this.phase,
  });

  final BasePlayer player;
  final domain.CardRarity rarity;
  final double width;
  final double? shine;
  final double statProgress;
  final double nameProgress;
  final double glow;
  final int? overall;
  final List<({String label, int value})>? stats;
  final int upgradeLevel;
  final double? nameLetters;
  final bool maskName;
  final double maskPulse;
  final double? phase;

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

  PlayerCardRarity _mapRarity(domain.CardRarity rarity, int overall) {
    // Icons (owner request 2026-11-12) render the holo icon treatment
    // FIRST: a legend card reads white-silver-gold everywhere, whatever
    // band its OVR would otherwise paint.
    if (player.isIcon) return PlayerCardRarity.icon;
    if (overall >= 90) return PlayerCardRarity.premium;
    if (overall >= 80 || rarity == domain.CardRarity.legendary) return PlayerCardRarity.legendary;
    if (overall >= 70 || rarity == domain.CardRarity.epic) return PlayerCardRarity.epic;
    return PlayerCardRarity.rare;
  }

  @override
  Widget build(BuildContext context) {
    final ovr = overall ?? player.baseStats.overall;
    final r = _mapRarity(rarity, ovr);

    final ratingVal = (ovr * statProgress.clamp(0.0, 1.0)).round();
    final List<({String label, int value})> rawStats = stats ?? statsFor(player);
    final pStats = rawStats
        .map((s) => PlayerStat(s.label, (s.value * statProgress.clamp(0.0, 1.0)).round()))
        .toList();

    return PlayerCardWidget(
      rarity: r,
      rating: ratingVal,
      position: player.position.code,
      flag: flagEmojiFor(player.nationality),
      teamLogo: player.clubCrestUrl.isNotEmpty
          ? NetworkImage(player.clubCrestUrl)
          : const AssetImage('assets/images/logo_full.webp'),
      playerImage: player.imageUrl.isNotEmpty ? NetworkImage(player.imageUrl) : null,
      size: CardSize.big,
      name: player.name,
      nameLetters: nameLetters ?? (nameProgress <= 0.01 ? 0.0 : 1.0),
      nationalityFallbackText: player.nationality,
      upgradeLevel: upgradeLevel,
      stats: pStats,
      width: width,
      shimmer: shine ?? .35,
    );
  }
}

class FcmPlayerCardBack extends StatelessWidget {
  const FcmPlayerCardBack({super.key, this.width = 260});

  final double width;

  @override
  Widget build(BuildContext context) {
    return PlayerCardBackWidget(
      rarity: PlayerCardRarity.legendary,
      width: width,
      logoAsset: kFcmWordmarkAsset,
    );
  }
}
