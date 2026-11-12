/// FCM Rivals — the scene-loading transition (visuals).
///
/// A full-screen, dismissable overlay that plays the brand logo in a
/// premium infinite loop while the next scene loads — the way a console
/// football game shows its animated league crest between scenes. It is
/// what makes a load read as a *game* beat instead of an app spinner.
///
/// This file is only the picture. WHEN it shows (above any loading
/// screen, with a debounce so fast loads never flash it) is owned by
/// `scene_loading.dart`; the pieces are split so the visual can be
/// previewed and tested on its own.
///
/// Layers, back to front (every layer is periodic in the loop, so the
/// animation never visibly restarts):
///  1. a breathing champagne glow behind the crest,
///  2. slowly rotating light rays,
///  3. shock-wave rings that expand off the logo and fade,
///  4. orbiting sparks on the far side of the logo,
///  5. the logo itself — breathing, floating, with a light sweep,
///  6. orbiting sparks on the near side (depth),
///  7. a gold progress shimmer under the crest, and a quiet close button.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fcm_logo.dart';
import 'fcm_style.dart';

const double _tau = math.pi * 2;

/// The full-screen scene-loading overlay.
///
/// Tapping anywhere, or the close button, calls [onDismiss]. With
/// `MediaQuery.disableAnimations` (reduce motion) the logo is shown
/// still, with no looping layers.
class SceneLoadingTransition extends StatefulWidget {
  const SceneLoadingTransition({
    super.key,
    this.onDismiss,
    this.loopDuration = const Duration(milliseconds: 6000),
  });

  /// Called when the person dismisses the overlay (tap or close button).
  /// Null makes the overlay non-dismissable and hides the close button.
  final VoidCallback? onDismiss;

  /// One full loop of every layer. Faster layers run an integer number of
  /// cycles per loop, so the seam is invisible.
  final Duration loopDuration;

  @override
  State<SceneLoadingTransition> createState() => _SceneLoadingTransitionState();
}

class _SceneLoadingTransitionState extends State<SceneLoadingTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.loopDuration,
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _c
        ..stop()
        ..value = 0.25;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final logoWidth = math.min(size.width * 0.74, 420.0);

    // The logo art is decoded once and handed to the builder as a child,
    // so each animation frame only re-applies transforms and the shader.
    final logo = Image.asset(
      kFcmWordmarkAsset,
      width: logoWidth,
      cacheWidth: 900,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => FcmWordmark(size: logoWidth * 0.22),
    );

    return Material(
      color: FcmColors.night,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: SizedBox.expand(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              child: logo,
              builder: (context, art) {
                final t = _c.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ExcludeSemantics(
                      child: CustomPaint(
                        painter: _BackdropPainter(t, logoWidth),
                      ),
                    ),
                    if (!_reduceMotion)
                      ExcludeSemantics(
                        child: CustomPaint(
                          painter: _SparkPainter(t, logoWidth, front: false),
                        ),
                      ),
                    Center(child: _AnimatedLogo(t: t, child: art!)),
                    if (!_reduceMotion)
                      ExcludeSemantics(
                        child: CustomPaint(
                          painter: _SparkPainter(t, logoWidth, front: true),
                        ),
                      ),
                    Align(
                      alignment: const Alignment(0, 0.42),
                      child: ExcludeSemantics(
                        child: SizedBox(
                          width: math.min(logoWidth * 0.5, 190),
                          height: 4,
                          child: CustomPaint(painter: _BarPainter(t)),
                        ),
                      ),
                    ),
                    if (widget.onDismiss != null)
                      SafeArea(
                        child: Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _CloseButton(onTap: widget.onDismiss!),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Logo: breathe, float, light sweep
// -----------------------------------------------------------------------------

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Two breaths per loop (3 s each).
    final breathe = math.sin(t * _tau * 2);
    final scale = 1.0 + 0.035 * breathe;
    final bob = math.sin(t * _tau * 2 + 1.2) * 5.0;

    // The light sweep crosses the logo once every 3 s, then rests.
    final cycle = (t * 2) % 1.0;
    final sweep = Curves.easeInOutCubic.transform((cycle / 0.55).clamp(0.0, 1.0));

    return Transform.translate(
      offset: Offset(0, bob),
      child: Transform.scale(
        scale: scale,
        child: DecoratedBox(
          // A soft gold bloom hugging the art — lifts it off the night.
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: FcmColors.gold.withValues(alpha: 0.16 + 0.08 * breathe),
                blurRadius: 60,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: const Alignment(-1, -0.45),
              end: const Alignment(1, 0.45),
              colors: const [
                Color(0x00FFF3CF),
                Color(0xB3FFF3CF),
                Color(0x00FFF3CF),
              ],
              stops: const [0.38, 0.5, 0.62],
              transform: _SlideGradient(sweep * 2 - 1),
            ).createShader(bounds),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Slides a gradient horizontally by [dx] × the bounds' width.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * dx, 0, 0);
}

// -----------------------------------------------------------------------------
// Backdrop: glow, rays, rings, vignette
// -----------------------------------------------------------------------------

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.t, this.logoWidth);

  final double t;
  final double logoWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final shortest = size.shortestSide;
    final diagonal = size.longestSide * 1.1;

    // 1. Breathing glow.
    final breathe = math.sin(t * _tau * 2);
    final glowR = shortest * (0.62 + 0.05 * breathe);
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            FcmColors.gold.withValues(alpha: 0.26 + 0.06 * breathe),
            FcmColors.bronze.withValues(alpha: 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );

    // 2. Slowly rotating light rays (one revolution per loop).
    const rays = 14;
    final rayPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          FcmColors.goldSoft.withValues(alpha: 0.13),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: diagonal * 0.62));
    for (var i = 0; i < rays; i++) {
      final a = t * _tau + i * _tau / rays;
      final half = i.isEven ? 0.060 : 0.030;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(
          c.dx + math.cos(a - half) * diagonal,
          c.dy + math.sin(a - half) * diagonal,
        )
        ..lineTo(
          c.dx + math.cos(a + half) * diagonal,
          c.dy + math.sin(a + half) * diagonal,
        )
        ..close();
      canvas.drawPath(path, rayPaint);
    }

    // 3. Shock-wave rings: three staggered, one launched per second.
    for (var i = 0; i < 3; i++) {
      final phase = (t * 2 + i / 3) % 1.0;
      final eased = Curves.easeOutCubic.transform(phase);
      final radius = logoWidth * 0.30 + (shortest * 0.95 - logoWidth * 0.30) * eased;
      final fade = math.pow(1 - phase, 1.6).toDouble();
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 + 2.6 * (1 - phase)
          ..color = FcmColors.gold.withValues(alpha: 0.34 * fade),
      );
    }

    // 4. Vignette keeps the eye on the crest and the edges quiet.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            Colors.transparent,
            FcmColors.night.withValues(alpha: 0.78),
          ],
          stops: const [0.45, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.t != t || old.logoWidth != logoWidth;
}

// -----------------------------------------------------------------------------
// Orbiting sparks (split front/back for depth)
// -----------------------------------------------------------------------------

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.t, this.logoWidth, {required this.front});

  final double t;
  final double logoWidth;

  /// True paints the near half of every orbit (over the logo), false the
  /// far half (behind it).
  final bool front;

  static const int _count = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    final core = Paint();

    for (var i = 0; i < _count; i++) {
      // Whole revolutions per loop (±1..3) keep the loop seamless.
      final dir = i.isEven ? 1 : -1;
      final revs = 1 + (i % 3);
      final angle = i * _tau / _count + dir * t * _tau * revs;
      final s = math.sin(angle);
      if ((s >= 0) != front) continue;

      final rx = logoWidth * 0.50 + (i % 4) * 16.0;
      final ry = rx * 0.40;
      final pos = Offset(c.dx + math.cos(angle) * rx, c.dy + s * ry);

      final twinkle = 0.5 + 0.5 * math.sin((t * (2 + i % 3) + i * 0.37) * _tau);
      final r = 1.1 + 2.2 * twinkle;
      final color = Color.lerp(FcmColors.gold, FcmColors.goldSoft, twinkle)!;
      canvas.drawCircle(pos, r * 2.2, glow..color = color.withValues(alpha: 0.5 * twinkle));
      canvas.drawCircle(pos, r, core..color = color.withValues(alpha: 0.35 + 0.65 * twinkle));
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.t != t || old.logoWidth != logoWidth || old.front != front;
}

// -----------------------------------------------------------------------------
// Progress shimmer + close button
// -----------------------------------------------------------------------------

/// An indeterminate gold shimmer sliding along a faint track.
class _BarPainter extends CustomPainter {
  _BarPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    final segW = size.width * 0.42;
    final p = (t * 3) % 1.0; // three passes per loop
    final x = -segW + (size.width + segW) * Curves.easeInOut.transform(p);
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRect(
      Rect.fromLTWH(x, 0, segW, size.height),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            FcmColors.goldSoft,
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(x, 0, segW, size.height)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.t != t;
}

/// Quiet, always-reachable dismiss control. Fades in a moment after the
/// overlay so it never competes with the logo's entrance.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1400),
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      builder: (context, v, child) => Opacity(opacity: v, child: child),
      child: Semantics(
        button: true,
        label: MaterialLocalizations.of(context).closeButtonLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: FcmColors.silver.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
