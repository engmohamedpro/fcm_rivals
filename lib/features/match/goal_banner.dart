/// FCM Rivals — the GOAL announcement moment (T-0116, redesigned).
///
/// Deliberately minimal: the word "GOAL!" and the scorer's small player
/// card — portrait, nationality flag and club logo — and nothing else.
/// Over ~2.4 s the wordmark pops in, then the card flips over from its
/// back and rises into place with a burst of sparks and a shimmer sweep,
/// holds a beat, and fades out.
///
/// The commentary card at the bottom stays exactly as it is (the
/// informative channel, with the scorer and score); this is the
/// celebration channel, and the scoreboard's digits still pulse.
///
/// Discipline:
///
/// - NEVER interrupts the match: [IgnorePointer], no tap targets, the
///   clock keeps running. A celebration, not a modal.
/// - One controller, created in initState, disposed in dispose.
/// - A second goal RESTARTS the animation from the top (goals near the
///   kick-off never queue two banners).
/// - Never stacks with the half-time or recovery cards: the host only
///   mounts this widget when no touchline card is up.
/// - The user's own goals get the full treatment, an opponent's the same
///   mechanics at reduced intensity (smaller card, softer glow, fewer
///   sparks).
/// - RepaintBoundary, one reused [Paint] per painter.
///
/// [scorerName] and [scoreline] are NOT drawn; they identify the goal so
/// a second goal restarts the run while the late portrait lookup for the
/// SAME goal does not.
///
/// RTL-safe: everything is centred.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/player_card.dart';

/// What the scorer's small card shows. Plain data so the host (which owns
/// the lookup) stays decoupled from the card widget.
class GoalScorerCard {
  const GoalScorerCard({
    required this.rating,
    required this.position,
    this.flag = '⚽',
    this.imageUrl = '',
    this.clubCrestUrl = '',
    this.isIcon = false,
  });

  /// Overall rating shown top-left on the card (also picks the rarity).
  final int rating;

  /// Position code, e.g. "ST".
  final String position;

  /// Nationality flag emoji.
  final String flag;

  /// Portrait link ('' → the card's own silhouette fallback).
  final String imageUrl;

  /// Real-world club logo link ('' → the FCM logo).
  final String clubCrestUrl;

  /// Icon players (owner request 2026-11-12): the scorer card paints the
  /// holo icon treatment regardless of the rating band.
  final bool isIcon;
}

/// Same thresholds as the mini cards on the pitch and bench. An icon
/// scorer (owner request 2026-11-12) reads holo white-silver-gold.
PlayerCardRarity _rarityOf(int overall, {bool isIcon = false}) {
  if (isIcon) return PlayerCardRarity.icon;
  if (overall >= 90) return PlayerCardRarity.premium;
  if (overall >= 80) return PlayerCardRarity.legendary;
  if (overall >= 70) return PlayerCardRarity.epic;
  return PlayerCardRarity.rare;
}

/// The one number the host can bump to re-run the banner.
class GoalBanner extends StatefulWidget {
  const GoalBanner({
    super.key,
    required this.scorerName,
    required this.scoreline,
    required this.color,
    this.isUserGoal = true,
    this.scorerCard,
    this.onFinished,
  });

  /// Identifies the goal (with [scoreline]); not drawn.
  final String scorerName;

  /// Identifies the goal (with [scorerName]); not drawn.
  final String scoreline;

  /// The scoring side's colour — drives the glow and sparks.
  final Color color;

  /// False for an opponent's goal: the same mechanics at reduced
  /// intensity, so a conceded goal still reads but does not party.
  final bool isUserGoal;

  /// The scorer's small player card. Null shows the wordmark alone.
  final GoalScorerCard? scorerCard;

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
    duration: const Duration(milliseconds: 2400),
  );

  // Timeline (fractions of the 2.4 s run):
  //   0.00-0.22  wordmark pop-in           0.16-0.46  card flip + rise
  //   0.40-0.80  sparks                    0.46-0.76  card shimmer
  //   0.80-1.00  fade + rise out
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.1, curve: Curves.easeOut),
  );
  late final Animation<double> _exit = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.8, 1, curve: Curves.easeIn),
  );
  late final Animation<double> _wordPop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.22, curve: Curves.easeOutBack),
  );
  late final Animation<double> _flip = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.16, 0.46, curve: Curves.easeOutBack),
  );
  late final Animation<double> _sparks = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.4, 0.8, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _shimmer = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.46, 0.76, curve: Curves.easeInOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
    _controller.forward();
  }

  @override
  void didUpdateWidget(GoalBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A second goal while the banner is still up: restart, never queue.
    // (Enrichment of the SAME goal — portrait arriving late — keeps the
    // scorer and score, so it never restarts the run.)
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
    final intensity = widget.isUserGoal ? 1.0 : 0.55;
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            if (!_controller.isAnimating && _controller.value >= 1) {
              return const SizedBox.shrink();
            }
            // Exit: fade out while rising 28px.
            final exit = _exit.value;
            return Opacity(
              opacity: (_fadeIn.value * (1 - exit)).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -28 * exit),
                // Short phones: the composition scales down rather than
                // overflowing the pitch area.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _composition(intensity),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _composition(double intensity) {
    final color = widget.color;
    final card = widget.scorerCard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        // A soft dark scrim so the composition reads over any pitch
        // without a hard-edged box.
        gradient: RadialGradient(
          radius: 0.95,
          colors: [
            Colors.black.withValues(alpha: 0.78),
            Colors.black.withValues(alpha: 0.5),
            Colors.black.withValues(alpha: 0),
          ],
          stops: const [0, 0.62, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _wordmark(color, intensity),
          if (card != null) ...[
            const SizedBox(height: 6),
            _scorerCard(card, color, intensity),
          ],
        ],
      ),
    );
  }

  /// The wordmark: pops in with an overshoot, then breathes.
  Widget _wordmark(Color color, double intensity) {
    final pop = (0.5 + 0.5 * _wordPop.value).clamp(0.0, 1.2);
    final pulse = 1 + 0.04 * math.sin(_controller.value * math.pi * 8);
    return Transform.scale(
      scale: pop * pulse * (widget.isUserGoal ? 1 : 0.92),
      child: Text(
        'GOAL!',
        maxLines: 1,
        style: TextStyle(
          fontSize: 44,
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

  /// The scorer's card flips over from its back (3D rotateY, overshooting
  /// into place), rising 36px as it lands. Sparks burst from behind it at
  /// the flip's end and a shimmer sweeps the face after.
  Widget _scorerCard(GoalScorerCard card, Color color, double intensity) {
    final cardW = widget.isUserGoal ? 120.0 : 100.0;
    final cardH = cardW / kPlayerCardAspect;
    final rarity = _rarityOf(card.rating, isIcon: card.isIcon);
    final flip = _flip.value;
    // 1 → 0: back-facing at the start (rotateY pi), front at the end.
    final angle = math.pi * (1 - flip.clamp(0.0, 1.2));
    final showBack = angle > math.pi / 2;
    final face = showBack
        ? Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: PlayerCardBackWidget(rarity: rarity, width: cardW),
          )
        : PlayerCardWidget(
            rarity: rarity,
            rating: card.rating,
            position: card.position,
            flag: card.flag,
            teamLogo: card.clubCrestUrl.isNotEmpty
                ? NetworkImage(card.clubCrestUrl)
                : const AssetImage('assets/images/logo_full.webp'),
            playerImage: card.imageUrl.isNotEmpty
                ? NetworkImage(card.imageUrl)
                : null,
            size: CardSize.small,
            width: cardW,
            // The shimmer band sweeps the face once, after the flip.
            shimmer: _shimmer.value,
          );
    return SizedBox(
      width: cardW + 140,
      height: cardH + 36,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SparkPainter(
                progress: _sparks.value,
                color: color,
                intensity: intensity,
              ),
            ),
          ),
          Opacity(
            opacity: (flip * 3).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 36 * (1 - flip.clamp(0.0, 1.0))),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateY(angle),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5 * intensity),
                        blurRadius: 26,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: face,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A deterministic burst of sparks leaving the card: team colour, gold
/// and white, arcing outward and drooping under a little gravity. Fixed
/// angles and speeds (no Random) so the burst is identical every goal and
/// the painter allocates nothing per frame beyond the offsets it draws.
class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.progress,
    required this.color,
    required this.intensity,
  });

  final double progress;
  final Color color;
  final double intensity;

  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final count = intensity >= 1 ? 26 : 14;
    final reach = math.min(size.width, size.height) * 0.62;
    for (var i = 0; i < count; i++) {
      final angle = i / count * 2 * math.pi + i * 0.37;
      final speed = 0.55 + (i % 5) * 0.11;
      final dist = reach * speed * progress;
      final droop = 26 * progress * progress;
      final pos =
          center + Offset(math.cos(angle) * dist, math.sin(angle) * dist + droop);
      final base = switch (i % 3) {
        0 => color,
        1 => FcmColors.gold,
        _ => Colors.white,
      };
      _paint.color = base.withValues(alpha: (1 - progress) * intensity);
      canvas.drawCircle(pos, 3.2 - 2.0 * progress, _paint);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.intensity != intensity;
}
