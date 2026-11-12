/// FCM Rivals — the GOAL announcement moment (T-0116, redesigned).
///
/// A goal is the loudest thing that happens on the pitch. This moment
/// says WHO scored for WHOM at a glance, in three beats over ~2.6 s:
///
/// 1. The scoring team's CREST pops in with an elastic bounce and a
///    shockwave ring in the team colour, its NAME tracking in beneath.
/// 2. The scorer's small player CARD flips over from its back, rising
///    into place with a burst of sparks and a shimmer sweep across the
///    card face — the same premium card the player has everywhere else
///    in the app (portrait, rating, position, flag, club crest).
/// 3. The new score lands in the team colour, the whole composition
///    holds a beat, then fades and rises out.
///
/// The commentary card at the bottom stays exactly as it is (the
/// informative channel); this is the celebration channel, and the
/// scoreboard's digits still pulse.
///
/// Discipline (unchanged from the first version):
///
/// - NEVER interrupts the match: [IgnorePointer], no tap targets, the
///   clock keeps running. A celebration, not a modal.
/// - One controller, created in initState, disposed in dispose — the
///   screen's own controller-dispose rules apply unchanged.
/// - A second goal RESTARTS the animation from the top (goals near the
///   kick-off never queue two banners).
/// - Never stacks with the half-time or recovery cards: the host only
///   mounts this widget when no touchline card is up.
/// - The user's own goals get the full treatment, an opponent's the same
///   mechanics at reduced intensity (smaller card, softer glow, fewer
///   sparks) — the audio mirrors this asymmetry already.
/// - RepaintBoundary, one reused [Paint] per painter, no shaders beyond
///   the plain gradients the card itself already uses.
///
/// Every piece of the new content is optional: a host without a crest, a
/// team name or a scorer card still gets the wordmark, scorer name and
/// score (friendly previews, tests).
///
/// RTL-safe: everything is centred; the only directional motion is the
/// light sweep and the sparks, which are physical effects, not text.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/crest.dart' show CrestSpec;
import '../../core/ui/fcm_crest.dart';
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
  });

  /// Overall rating shown top-left on the card (also picks the rarity).
  final int rating;

  /// Position code, e.g. "ST".
  final String position;

  /// Nationality flag emoji.
  final String flag;

  /// Portrait link ('' → the card's own silhouette fallback).
  final String imageUrl;

  /// Real-world club crest link ('' → the FCM logo).
  final String clubCrestUrl;
}

/// Same thresholds as the mini cards on the pitch and bench.
PlayerCardRarity _rarityOf(int overall) {
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
    this.teamName,
    this.crest,
    this.scorerCard,
    this.onFinished,
  });

  /// The scorer's display name — shown under the card.
  final String scorerName;

  /// The new running score, e.g. "2 - 1".
  final String scoreline;

  /// The scoring side's colour — drives the glow, ring and sparks.
  final Color color;

  /// False for an opponent's goal: the same mechanics at reduced
  /// intensity, so a conceded goal still reads but does not party.
  final bool isUserGoal;

  /// The scoring team's name, under the crest. Null hides the line.
  final String? teamName;

  /// The scoring team's crest. Null hides the badge.
  final CrestSpec? crest;

  /// The scorer's small player card. Null hides the card (the scorer name
  /// still shows).
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
    duration: const Duration(milliseconds: 2600),
  );

  // Timeline (fractions of the 2.6 s run):
  //   0.00-0.28  crest elastic pop-in      0.02-0.50  shockwave ring
  //   0.10-0.30  team name tracks in       0.22-0.52  card flip + rise
  //   0.46-0.84  sparks                    0.50-0.80  card shimmer
  //   0.40-0.56  score lands               0.82-1.00  fade + rise out
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.1, curve: Curves.easeOut),
  );
  late final Animation<double> _exit = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.82, 1, curve: Curves.easeIn),
  );
  late final Animation<double> _crestPop = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.28, curve: Curves.elasticOut),
  );
  late final Animation<double> _ring = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.02, 0.5, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _name = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 0.3, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _flip = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.22, 0.52, curve: Curves.easeOutBack),
  );
  late final Animation<double> _sparks = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.46, 0.84, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _shimmer = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 0.8, curve: Curves.easeInOut),
  );
  late final Animation<double> _score = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.4, 0.56, curve: Curves.easeOutBack),
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
                // Short phones: the whole composition scales down rather
                // than overflowing the pitch area.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _composition(context, intensity),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _composition(BuildContext context, double intensity) {
    final color = widget.color;
    final crest = widget.crest;
    final teamName = widget.teamName;
    final card = widget.scorerCard;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: BoxDecoration(
        // A soft dark scrim in the team colour's shadow: the composition
        // reads over any pitch without a hard-edged box.
        gradient: RadialGradient(
          radius: 0.95,
          colors: [
            Colors.black.withValues(alpha: 0.80),
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0),
          ],
          stops: const [0, 0.62, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (crest != null) _crestBadge(crest, color, intensity),
          if (teamName != null && teamName.isNotEmpty) ...[
            const SizedBox(height: 8),
            _teamName(teamName, color, intensity),
          ],
          const SizedBox(height: 8),
          _wordmark(color, intensity),
          if (card != null) ...[
            const SizedBox(height: 10),
            _scorerCard(card, color, intensity),
          ],
          const SizedBox(height: 8),
          Text(
            widget.scorerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 15,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 8),
          _scoreline(color),
        ],
      ),
    );
  }

  /// Beat 1a — the crest: elastic pop, a glow behind it, and one
  /// shockwave ring racing outward in the team colour.
  Widget _crestBadge(CrestSpec crest, Color color, double intensity) {
    const size = 68.0;
    return SizedBox(
      width: size * 2.2,
      height: size * 1.4,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                progress: _ring.value,
                color: color,
                crestSize: size,
                intensity: intensity,
              ),
            ),
          ),
          Transform.scale(
            scale: (0.2 + 0.8 * _crestPop.value).clamp(0.0, 1.35),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.55 * intensity),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: FcmCrest(spec: crest, width: size),
            ),
          ),
        ],
      ),
    );
  }

  /// Beat 1b — the team name tracks in: scales down from 1.3x while it
  /// fades up, settling on a wide-tracked all-caps line.
  Widget _teamName(String name, Color color, double intensity) {
    final t = _name.value;
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 1.3 - 0.3 * t,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                shadows: [
                  Shadow(
                    color: color.withValues(alpha: 0.9 * intensity),
                    blurRadius: 16,
                  ),
                  const Shadow(color: Colors.black87, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The small "GOAL!" tag — the wordmark's job shrank to a label now
  /// that the crest and card carry the moment.
  Widget _wordmark(Color color, double intensity) {
    final pulse = 1 + 0.05 * math.sin(_controller.value * math.pi * 8);
    return Transform.scale(
      scale: pulse,
      child: Text(
        'GOAL!',
        maxLines: 1,
        style: TextStyle(
          fontSize: 20,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 6,
          color: FcmColors.gold,
          shadows: [
            Shadow(
              color: color.withValues(alpha: 0.9 * intensity),
              blurRadius: 14 * intensity,
            ),
            const Shadow(color: Colors.black87, blurRadius: 6),
          ],
        ),
      ),
    );
  }

  /// Beat 2 — the scorer's card flips over from its back (3D rotateY,
  /// overshooting into place), rising 36px as it lands. Sparks burst from
  /// behind it at the flip's end and a shimmer sweeps the face after.
  Widget _scorerCard(GoalScorerCard card, Color color, double intensity) {
    final cardW = widget.isUserGoal ? 96.0 : 84.0;
    final cardH = cardW / kPlayerCardAspect;
    final rarity = _rarityOf(card.rating);
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
      width: cardW + 120,
      height: cardH + 28,
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

  /// Beat 3 — the new score lands in the team colour with a small
  /// overshoot, the number that changed lives at a glance.
  Widget _scoreline(Color color) {
    final t = _score.value;
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.6 + 0.4 * t.clamp(0.0, 1.2),
        child: Text(
          widget.scoreline,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: 28,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}

/// One shockwave ring leaving the crest: starts at the badge's edge,
/// grows to ~1.9x, thinning and fading as it goes.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.crestSize,
    required this.intensity,
  });

  final double progress;
  final Color color;
  final double crestSize;
  final double intensity;

  final Paint _paint = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final radius = crestSize / 2 * (1 + 0.9 * progress);
    _paint
      ..color = color.withValues(alpha: 0.85 * (1 - progress) * intensity)
      ..strokeWidth = 5 * (1 - progress) + 0.8;
    canvas.drawCircle(size.center(Offset.zero), radius, _paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.intensity != intensity;
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
