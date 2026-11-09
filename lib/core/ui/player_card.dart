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
import 'player_card_painters.dart';

export 'mini_card.dart';
export 'player_card_painters.dart';


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

  /// 0..1 looping phase that animates the rarity artwork (turning
  /// sunburst, twinkles, lightning veins, rim pulse). Null keeps the face
  /// static — grids, sheets and the pitch never animate.
  final double? phase;

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
    // The premium class derives from the same deterministic overall the
    // rarity call sites use (T-0049): 90+ reads red in every surface.
    final cardClass = CardClass.fromOverall(
      overall ?? player.baseStats.overall,
    );
    final premium = cardClass == CardClass.premium;
    final ink = premium ? cardClass.ink : rarity.ink;
    final light = premium
        ? cardClass.faceGradient.first
        : rarity.faceGradient.first;
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
            color: (premium ? cardClass.accent : rarity.accent)
                .withValues(alpha: 0.9),
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
                painter: CardFacePainter(
                  rarity: rarity,
                  cardClass: cardClass,
                  shine: shine,
                  glow: glow,
                  phase: phase,
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
                premium ? cardClass.label : rarity.label,
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
  const FcmPlayerCardBack({
    super.key,
    required this.rarity,
    this.cardClass = CardClass.standard,
    this.width = 260,
  });

  final CardRarity rarity;

  /// The premium class axis (T-0049): the pre-flip back paints the red
  /// bezel for 90+ players.
  final CardClass cardClass;
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
            child: CustomPaint(
              painter: CardBackPainter(rarity: rarity, cardClass: cardClass),
            ),
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


