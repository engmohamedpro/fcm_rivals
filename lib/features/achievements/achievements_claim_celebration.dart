/// FCM Rivals — the achievement claim celebration (premium redesign,
/// owner request 2026-11-13).
///
/// THE MOMENT (the research's core finding: "a dedicated unlocked
/// component marks the moment cleanly — celebratory but never a
/// roadblock"): a full-screen dismissible overlay that plays ONE
/// choreographed beat, ~1.6s:
///
///   0ms    the scrim darkens (220ms);
///   60ms   the shockwave ring expands from centre (500ms, easeOut);
///   80ms   the badge scales in on an easeOutBack overshoot (450ms)
///          with the metal's rays sweeping behind it;
///   200ms  the title rises + fades in below the badge (350ms);
///   260ms  the coin payout chip pops in (250ms, easeOutBack);
///   300ms  coin rain — 14 painter-drawn coins fall with rotation
///          and staggered delays (900ms);
///   1500ms everything fades out together (300ms) and the overlay
///          pops itself.
///
/// A tap ANYWHERE skips straight to the fade — the celebration never
/// blocks a player in a hurry. `barrierDismissible` semantics without
/// a dialog: a GestureDetector over the scrim.
///
/// All painting is CustomPainter (the codebase's craft — no image
/// assets, no Lottie dependency), reusing [FcmBadgePainter] for the
/// badge itself so the celebration shows EXACTLY the metal the card
/// wore.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_coin.dart';
import '../../core/ui/fcm_style.dart';
import 'achievement_catalog.dart' show BadgeMetal;
import 'achievements_badge_painter.dart' show FcmBadgePainter;

/// Plays the celebration and returns when it has fully dismissed.
Future<void> showAchievementClaimCelebration(
  BuildContext context, {
  required BadgeMetal metal,
  required String title,
  required int coins,
}) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => _ClaimCelebrationOverlay(
      metal: metal,
      title: title,
      coins: coins,
    ),
  ));
}

class _ClaimCelebrationOverlay extends StatefulWidget {
  const _ClaimCelebrationOverlay({
    required this.metal,
    required this.title,
    required this.coins,
  });

  final BadgeMetal metal;
  final String title;
  final int coins;

  @override
  State<_ClaimCelebrationOverlay> createState() =>
      _ClaimCelebrationOverlayState();
}

class _ClaimCelebrationOverlayState extends State<_ClaimCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    // Self-dismiss when the beat completes.
    _c.whenComplete(() => _dismiss());
  }

  void _dismiss() {
    if (!mounted || _skipped) return;
    _skipped = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The choreography timeline (fractions of the 1600ms beat).
    final scrim = Tween(begin: 0.0, end: 0.78).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
      ),
    );
    final ring = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.04, 0.35, curve: Curves.easeOutCubic),
    );
    final badge = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.05, 0.33, curve: Curves.easeOutBack),
    );
    final titleIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.125, 0.34, curve: Curves.easeOutCubic),
    );
    final chipIn = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.16, 0.32, curve: Curves.easeOutBack),
    );
    final coins = CurvedAnimation(parent: _c, curve: Curves.linear);
    final outro = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
    );

    return GestureDetector(
      onTap: _dismiss,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Material(
          type: MaterialType.transparency,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The scrim.
              Container(color: FcmColors.night.withValues(alpha: scrim.value)),
              // The coin rain, behind the badge.
              IgnorePointer(
                child: CustomPaint(
                  painter: _CoinRainPainter(progress: coins.value),
                ),
              ),
              // The composed moment.
              IgnorePointer(
                child: Opacity(
                  opacity: 1.0 - outro.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: CustomPaint(
                          painter: _BurstPainter(
                            ring: ring.value,
                            badge: badge.value.clamp(0.0, 1.0),
                            metal: widget.metal,
                            phase: _c.value,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(0, 26 * (1 - titleIn.value)),
                        child: Opacity(
                          opacity: titleIn.value,
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FcmColors.goldSoft,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Transform.scale(
                        scale: chipIn.value.clamp(0.0, 1.0),
                        child: Opacity(
                          opacity: chipIn.value.clamp(0.0, 1.0),
                          child: FcmCoinChip(coins: widget.coins),
                        ),
                      ),
                    ],
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

/// The composed badge moment: the expanding shockwave rings, the
/// metal's ray sweep, and the badge itself scaling in.
class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.ring,
    required this.badge,
    required this.metal,
    required this.phase,
  });

  /// 0..1 — the shockwave expansion.
  final double ring;

  /// 0..1 — the badge's easeOutBack scale-in.
  final double badge;

  final BadgeMetal metal;

  /// The controller's raw value, drives the ray sweep.
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final tint = switch (metal) {
      BadgeMetal.bronze => const Color(0xFFB08D5C),
      BadgeMetal.silver => FcmColors.silver,
      BadgeMetal.gold => FcmColors.gold,
      BadgeMetal.platinum => const Color(0xFFDCE6EE),
      BadgeMetal.legend => FcmColors.goldSoft,
    };

    // Two shockwave rings: an outer hairline and an inner glow band,
    // both expanding and fading with [ring].
    for (final (radius, width, alpha) in [
      (ring * 105.0, 2.0, 0.55 * (1 - ring)),
      (ring * 72.0, 8.0, 0.22 * (1 - ring)),
    ]) {
      if (alpha <= 0) continue;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = tint.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }

    // The ray sweep behind the badge: 12 tapered rays rotating slowly
    // while the badge is on screen.
    if (badge > 0.02) {
      final spin = 0.30 * phase;
      for (var i = 0; i < 12; i++) {
        final a = spin + i * math.pi / 6;
        final len = 88.0 * badge;
        final ray = Path()
          ..moveTo(cx + math.cos(a - 0.09) * 34, cy + math.sin(a - 0.09) * 34)
          ..lineTo(cx + math.cos(a) * len, cy + math.sin(a) * len)
          ..lineTo(cx + math.cos(a + 0.09) * 34, cy + math.sin(a + 0.09) * 34)
          ..close();
        canvas.drawPath(
          ray,
          Paint()
            ..color = tint.withValues(alpha: 0.16 * badge)
            ..blendMode = BlendMode.plus,
        );
      }
    }

    // The badge itself, scaled about its centre with the overshoot.
    final s = badge.clamp(0.0, 1.15);
    if (s > 0.01) {
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(s);
      canvas.translate(-cx, -cy);
      // The stage plate behind the badge: a rounded square tinted
      // with the metal, matching the cards' badge stages.
      const cell = 120.0;
      final stage = Rect.fromCenter(
        center: Offset(cx, cy),
        width: cell,
        height: cell,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(stage, const Radius.circular(30)),
        Paint()
          ..shader = _stageGradient(tint).createShader(stage),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(stage, const Radius.circular(30)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = tint.withValues(alpha: 0.55),
      );
      // THE badge — the same painter the card wore, so the metal the
      // player claimed is the metal that celebrates.
      canvas.save();
      canvas.translate(cx - cell / 2, cy - cell / 2);
      FcmBadgePainter(metal: metal, phase: phase).paint(canvas, const Size(cell, cell));
      canvas.restore();
      canvas.restore();
    }
  }

  LinearGradient _stageGradient(Color tint) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          tint.withValues(alpha: 0.30),
          FcmColors.surfaceHigh,
          tint.withValues(alpha: 0.12),
        ],
      );

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.ring != ring || old.badge != badge || old.phase != phase;
}

/// The coin rain: 14 gold coins falling from above the fold with
/// staggered starts, each rotating; painter-drawn discs with the
/// house coin face (a ring + a star), the codebase's no-asset craft.
class _CoinRainPainter extends CustomPainter {
  _CoinRainPainter({required this.progress});

  /// 0..1 over the whole beat.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rng = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final x0 = w * (0.06 + 0.88 * rng.nextDouble());
      final delay = 0.18 + 0.30 * rng.nextDouble();
      final speed = 0.55 + 0.45 * rng.nextDouble();
      final r = 7.0 + 5.0 * rng.nextDouble();
      // Each coin's own local progress.
      final t = ((progress - delay) / (0.62 * speed)).clamp(-1.0, 1.0);
      if (t < 0) continue;
      final y = -40 + t * (h * 0.62);
      final spin = t * 6 + i * 1.3;
      final alpha = (1 - t).clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      canvas.save();
      canvas.translate(x0, y);
      canvas.rotate(spin);
      // The disc.
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = FcmColors.goldGradient.createShader(
            Rect.fromCircle(center: Offset.zero, radius: r),
          ),
      );
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = FcmColors.goldSoft.withValues(alpha: 0.8),
      );
      // The face: a small five-point star in ink.
      _star(canvas, Offset.zero, r * 0.45, alpha);
      canvas.restore();
    }
  }

  void _star(Canvas canvas, Offset o, double r, double alpha) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.42;
      final a = -math.pi / 2 + i * math.pi / 5;
      final x = o.dx + rr * math.cos(a);
      final y = o.dy + rr * math.sin(a);
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    p.close();
    canvas.drawPath(
      p,
      Paint()..color = FcmColors.ink.withValues(alpha: 0.85 * alpha),
    );
  }

  @override
  bool shouldRepaint(_CoinRainPainter old) => old.progress != progress;
}
