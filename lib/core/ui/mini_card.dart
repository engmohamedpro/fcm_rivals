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

/// Compact card for the pitch and bench: the face mirrors the big
/// card — the rating column (OVR → position) down the left with the
/// player portrait beside it, and the identity pair (flag + crest)
/// centred on the glass panel, the band the big card gives to the name
/// and attributes the mini never shows — then under the shield:
/// surname, an optional three-column stat row and a colour-coded
/// stamina bar. [width] is the shield width; everything else stacks
/// under it.
class FcmMiniCard extends StatelessWidget {
  const FcmMiniCard({
    super.key,
    required this.overall,
    required this.position,
    required this.name,
    required this.rarity,
    this.width = 56,
    this.flag,
    this.imageUrl,
    this.clubCrestUrl,
    this.warn = false,
    this.stamina,
    this.stats,
    this.ghost = false,
    this.injuryMatchesOut,
    this.upgradable = false,
  });

  final int overall;
  final String position;
  final String name;
  final CardRarity rarity;
  final double width;

  /// Country flag emoji (T-0066) — beside the crest in the centred
  /// identity pair on the glass panel. Null renders the pair without
  /// it; ghosts never show one at all.
  final String? flag;

  /// Player portrait (dataset v3): the network photo fills the band
  /// beside the rating column, over the painted silhouette — the same
  /// treatment as the big card, scaled down. Null or empty keeps the
  /// silhouette; ghosts never pass one.
  final String? imageUrl;

  /// Club crest (dataset v3) — beside the flag in the centred identity
  /// pair on the glass panel. Null or empty renders nothing.
  final String? clubCrestUrl;

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

  /// A duplicate is owned, so this card can merge a level up
  /// (T-0089): a small gold up-arrow pill rides the bottom-start
  /// corner — opposite the injury badge, clear of the name slot.
  /// Visual only; default false keeps every other consumer unchanged.
  final bool upgradable;

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
                  // The upgradable mark (T-0089): gold up-arrow pill on
                  // the bottom-START corner — the injury badge owns the
                  // top-start, so the two never collide. Icon-only: no
                  // text, no l10n surface. Bottom-start keeps it inside
                  // the card face in both text directions.
                  if (!ghost && upgradable)
                    PositionedDirectional(
                      bottom: 2,
                      start: 2,
                      child: _UpgradableMark(size: math.max(11, width * 0.21)),
                    ),
                  // The face mirrors the big card, mini-sized: the rating
                  // column (OVR → position) down the left with the
                  // portrait filling the band beside it, and the identity
                  // pair (flag + crest) centred in the glass panel — the
                  // band where the big card carries the name and
                  // attributes. The mini never shows those, so the pair
                  // works that space instead of leaving it empty. The
                  // column ends exactly where the painted portrait
                  // window begins (0.37w), aligning the mini's photo
                  // band with the big card's frame.
                  if (!ghost) ...[
                    Positioned(
                      left: 0,
                      right: width * 0.05,
                      top: h * 0.10,
                      bottom: h * 0.46,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: width * 0.05),
                            child: SizedBox(
                              width: width * 0.32,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '$overall',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: width * 0.26,
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
                                        fontSize: width * 0.115,
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // The portrait band: the photo over the painted
                          // silhouette, fading in when it loads. An empty
                          // URL or a failed download keeps the silhouette.
                          Expanded(
                            child: (imageUrl != null &&
                                    imageUrl!.isNotEmpty)
                                ? Image.network(
                                    imageUrl!,
                                    fit: BoxFit.contain,
                                    alignment: const Alignment(0.2, 1),
                                    filterQuality: FilterQuality.medium,
                                    gaplessPlayback: true,
                                    frameBuilder: (
                                      context,
                                      child,
                                      frame,
                                      wasSynchronouslyLoaded,
                                    ) {
                                      if (wasSynchronouslyLoaded) {
                                        return child;
                                      }
                                      return AnimatedOpacity(
                                        opacity: frame == null ? 0.0 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child: child,
                                      );
                                    },
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox.shrink(),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                    // The identity pair rides the glass panel, centred:
                    // the flag beside the crest, both at sizes the pitch
                    // can actually resolve. Only what exists renders —
                    // one of the pair, or nothing at all.
                    if (flag != null ||
                        (clubCrestUrl != null && clubCrestUrl!.isNotEmpty))
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * 0.645,
                        height: h * 0.16,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (flag != null)
                                Text(
                                  flag!,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(fontSize: width * 0.14),
                                ),
                              if (flag != null &&
                                  clubCrestUrl != null &&
                                  clubCrestUrl!.isNotEmpty)
                                SizedBox(width: width * 0.06),
                              if (clubCrestUrl != null &&
                                  clubCrestUrl!.isNotEmpty)
                                Image.network(
                                  clubCrestUrl!,
                                  height: width * 0.15,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
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

/// The gold up-arrow pill (T-0089): "a duplicate exists — this card
/// can merge a level up". Icon-only so it stays l10n-free; the pill
/// reads on every rarity ink exactly like the injury badge does.
class _UpgradableMark extends StatelessWidget {
  const _UpgradableMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Upgradable',
      child: Container(
        padding: EdgeInsets.all(size * 0.16),
        decoration: BoxDecoration(
          color: FcmColors.gold,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          Icons.upload_rounded,
          size: size,
          color: FcmColors.ink,
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
