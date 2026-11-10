/// FCM Rivals — the GOAL announcement moment (T-0116).
///
/// A goal is the loudest thing that happens on the pitch, and before
/// this widget the screen said so with a quiet border glow on the
/// 76px commentary card at the BOTTOM of the viewport. This banner is
/// the loud channel: a full-width "GOAL!" wordmark bursts over the
/// pitch area for ~1.6 seconds — scale-in with a light sweep across
/// the wordmark, a hold with the scorer's name and the new score, a
/// fade-and-rise exit — while the scoreboard's digits pulse. The
/// commentary card stays exactly as it is (the informative channel);
/// this is the celebration channel.
///
/// Discipline:
///
/// - NEVER interrupts the match: [IgnorePointer], no tap targets, the
///   clock keeps running. A celebration, not a modal.
/// - One controller, created in initState, disposed in dispose — the
///   screen's own controller-dispose rules apply unchanged.
/// - A second goal RESTARTS the animation from the top (goals near the
///   kick-off never queue two banners).
/// - Never stacks with the half-time or recovery cards: the host only
///   mounts this widget when no touchline card is up, and a goal
///   cannot land while the half-time card holds the clock anyway.
/// - Team colour drives the glow ring; the user's own goals get the
///   full treatment, an opponent's the same mechanics at reduced
///   intensity (the audio mirrors this asymmetry already).
/// - RepaintBoundary + no shaders, no per-frame allocations: plain
///   transforms and gradients only.
///
/// RTL-safe: no directional paddings or alignment — the banner is
/// centred and mirrors trivially.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';

/// The one number the host can bump to re-run the banner.
class GoalBanner extends StatefulWidget {
  const GoalBanner({
    super.key,
    required this.scorerName,
    required this.scoreline,
    required this.color,
    this.isUserGoal = true,
    this.onFinished,
  });

  /// The scorer's display name ("P 9" style — resolved by the host).
  final String scorerName;

  /// The new running score, e.g. "2 - 1".
  final String scoreline;

  /// The scoring side's colour — drives the glow ring.
  final Color color;

  /// False for an opponent's goal: the same mechanics at reduced
  /// intensity, so a conceded goal still reads but does not party.
  final bool isUserGoal;

  /// Fired once when the animation completes — the host unmounts the
  /// banner. The banner never removes itself: the host owns the state.
  final VoidCallback? onFinished;

  @override
  State<GoalBanner> createState() => _GoalBannerState();
}

class _GoalBannerState extends State<GoalBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
  }

  @override
  void didUpdateWidget(GoalBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A second goal while the banner is still up: restart, never queue.
    if (oldWidget.scorerName != widget.scorerName ||
        oldWidget.scoreline != widget.scoreline) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Phase 1: entrance (0 - 0.19) — scale 0.86 -> 1 + fade in.
    // Phase 2: hold (0.19 - 0.69) — full banner, sweep rides across.
    // Phase 3: exit (0.69 - 1) — fade out and rise 18px.
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    final entrance = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.19, curve: Curves.easeOutBack),
    );
    final exit = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.69, 1, curve: Curves.easeIn),
    );
    final sweep = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.1, 0.55, curve: Curves.easeOutCubic),
    );
    final intensity = widget.isUserGoal ? 1.0 : 0.55;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isAnimating && _controller.value >= 1) {
              return const SizedBox.shrink();
            }
            return FadeTransition(
              opacity: entrance,
              child: FadeTransition(
                opacity: ReverseAnimation(exit),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.12),
                    end: Offset.zero,
                  ).animate(entrance),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset.zero,
                      end: const Offset(0, -0.35),
                    ).animate(exit),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.86,
                        end: 1,
                      ).animate(entrance),
                      child: _banner(context, curved, sweep, intensity),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _banner(
    BuildContext context,
    Animation<double> curved,
    Animation<double> sweep,
    double intensity,
  ) {
    final color = widget.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.82),
            Colors.black.withValues(alpha: 0.62),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withValues(alpha: 0.55 * intensity),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35 * intensity),
            blurRadius: 34,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The wordmark — the whole point of the moment.
              _wordmark(curved, color, intensity),
              const SizedBox(height: 6),
              Text(
                widget.scorerName,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 15,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // The new score in the side's colour — the number that
              // changed lives at a glance.
              Text(
                widget.scoreline,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
          // The light sweep rides across the wordmark once during the
          // hold — the celebration's shine.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.55 * intensity,
                child: CustomPaint(
                  painter: _GoalSweepPainter(progress: sweep.value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wordmark(
    Animation<double> curved,
    Color color,
    double intensity,
  ) {
    final pulse = 1 + 0.05 * math.sin(curved.value * math.pi * 6);
    return Transform.scale(
      scale: pulse * (widget.isUserGoal ? 1 : 0.92),
      child: Text(
        'GOAL!',
        maxLines: 1,
        style: TextStyle(
          // Bigger than everything else on the live screen: this is
          // the announcement, not a label.
          fontSize: 46,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 8,
          color: Colors.white,
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.9 * intensity),
              blurRadius: 24 * intensity,
            ),
            const Shadow(color: Colors.black87, blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

/// The celebration's light band: a soft white-gold sweep across the
/// banner, once per goal. A physical light sweep, not text — travels
/// start-to-end in both locales.
class _GoalSweepPainter extends CustomPainter {
  const _GoalSweepPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final cx = (progress * 1.5 - 0.25) * size.width;
    final rect = Rect.fromCenter(
      center: Offset(cx, size.height / 2),
      width: size.width * 0.38,
      height: size.height * 1.4,
    );
    final edge = progress < 0.2
        ? progress / 0.2
        : progress > 0.8
        ? (1 - progress) / 0.2
        : 1.0;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Color.lerp(Colors.white, FcmColors.gold, 0.35)!
              .withValues(alpha: 0.38 * edge),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GoalSweepPainter old) => old.progress != progress;
}
