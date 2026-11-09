/// FCM Rivals — mini player card family (extracted from
/// `player_card.dart`, app-structure review task
/// `2026-11-05_app-structure_split-player-card`): the compact
/// squad-list card with its ghost/stat/stamina/warn widgets.
/// Pure relocation — widget trees unchanged.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fcm_style.dart';
import 'fcm_widgets.dart' show ratingColor, staminaColor;
import 'injury_badge.dart';
import 'player_card_painters.dart';

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
    this.flag,
    this.warn = false,
    this.stamina,
    this.stats,
    this.ghost = false,
    this.injuryMatchesOut,
  });

  final int overall;
  final String position;
  final String name;
  final CardRarity rarity;
  final double width;

  /// Country flag emoji under the position code (T-0066), mirroring the
  /// big card's OVR → position → flag order. Null renders nothing — the
  /// layout stays byte-identical for unset callers and ghosts.
  final String? flag;

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

  /// Matches the player still misses (T-0056); null or ≤ 0 hides the
  /// injury badge.
  final int? injuryMatchesOut;

  @override
  Widget build(BuildContext context) {
    final h = width / kPlayerCardAspect;
    // The premium class derives from the same deterministic overall the
    // caller used for the rarity (T-0049): 90+ reads red in every surface.
    final cardClass = CardClass.fromOverall(overall);
    final premium = cardClass == CardClass.premium;
    final ink = premium ? cardClass.ink : rarity.ink;
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
                      painter: CardFacePainter(
                        rarity: rarity,
                        cardClass: cardClass,
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
                  // The injury badge rides the shield's corner (T-0056):
                  // red cross + matches-out count, pinned over the face
                  // so it reads on every rarity ink.
                  if (!ghost &&
                      injuryMatchesOut != null &&
                      injuryMatchesOut! > 0)
                    PositionedDirectional(
                      top: 2,
                      start: 2,
                      child: InjuryBadge(
                        matchesOut: injuryMatchesOut!,
                        size: math.max(10, width * 0.18),
                      ),
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
                          if (flag != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              flag!,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(fontSize: width * 0.20),
                            ),
                          ],
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
