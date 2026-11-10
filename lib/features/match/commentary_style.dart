/// FCM Rivals — the shared visual language of commentary moments
/// (T-0115).
///
/// ONE dressing table for every surface that renders a live
/// commentary moment — the featured feed card, the timeline rows and
/// the compact ticker. Before this file the two consumers each carried
/// their own private copy of the map, and both copies shared icons
/// across kinds (both cards wore `Icons.style_rounded`, foul and
/// kick-off both wore `Icons.sports_rounded`) and took the featured
/// colour from the TEAM side — so every moment of one team looked
/// identical regardless of what happened on the pitch.
///
/// The contract this table locks (two channels, two questions):
///
/// - EVENT identity — icon, small-caps label, accent colour — is
///   per-kind, never the team colour, and every kind's icon is
///   UNIQUE (an iteration test pins this: no two kinds may share an
///   icon again). A yellow card reads as a literal small YELLOW
///   card, a red card a literal RED one: the two card kinds render a
///   tilted rounded rectangle ([CardChip], `cardYellow`/`cardRed`)
///   instead of a generic icon — shape + hue + label, three signals,
///   so colour-blind users still read the kind at a glance.
/// - SIDE identity — WHICH team the moment belongs to — stays on the
///   surface's own team-coloured chrome: the featured card's wash
///   gradient, its border and its minute badge; the ticker's bar
///   tint; the timeline row's dot. The event accent never bleeds into
///   that channel and vice versa.
///
/// Consumers import `momentStyleOf`; nothing outside this library may
/// reach into the table directly.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import 'match_report.dart' show CommentaryKind;

/// The dressing of one event kind: badge icon, small-caps label and
/// the kind's own accent colour. [card] marks the two booking kinds,
/// which render a literal card chip ([CardChip]) instead of an icon.
class MomentStyle {
  const MomentStyle({
    required this.icon,
    required this.label,
    required this.accent,
    this.card,
  });

  /// This kind's unique badge icon (null only for the two card kinds,
  /// which carry [card] instead).
  final IconData? icon;

  /// Small-caps label shown next to the badge.
  final String label;

  /// This kind's accent — the event-identity colour.
  final Color accent;

  /// The literal card colour for the booking kinds, else null.
  final Color? card;

  /// The width/height of a literal booking card chip, tilted ~8°.
  static const double cardChipWidth = 10;
  static const double cardChipHeight = 14;
}

/// The ONE dressing table. Accents are pairwise distinct by design:
/// goal gold burst, penalty champagne, yellow card = real saturated
/// football yellow, red card = decisive red, saves the keeper green,
/// injuries the medical red, subs and tactical the steel tones, the
/// manager's megaphone gold, kick-off and the break bronze, the final
/// whistle gold, and the quiet possession moments stay dim.
const Map<CommentaryKind, MomentStyle> momentStyles = {
  CommentaryKind.goal: MomentStyle(
    icon: Icons.sports_soccer_rounded,
    label: 'GOAL',
    accent: FcmColors.gold,
  ),
  CommentaryKind.penalty: MomentStyle(
    icon: Icons.adjust_rounded,
    label: 'PENALTY',
    accent: FcmColors.goldSoft,
  ),
  CommentaryKind.redCard: MomentStyle(
    icon: null,
    label: 'RED CARD',
    accent: FcmColors.cardRed,
    card: FcmColors.cardRed,
  ),
  CommentaryKind.yellowCard: MomentStyle(
    icon: null,
    label: 'YELLOW CARD',
    accent: FcmColors.cardYellow,
    card: FcmColors.cardYellow,
  ),
  CommentaryKind.save: MomentStyle(
    icon: Icons.sports_handball_rounded,
    label: 'SAVE',
    accent: FcmColors.success,
  ),
  CommentaryKind.injury: MomentStyle(
    icon: Icons.medical_services_outlined,
    label: 'INJURY',
    accent: FcmColors.danger,
  ),
  CommentaryKind.substitution: MomentStyle(
    icon: Icons.swap_horiz_rounded,
    label: 'SUBSTITUTION',
    accent: FcmColors.silver,
  ),
  CommentaryKind.tactical: MomentStyle(
    icon: Icons.tune_rounded,
    label: 'TACTICAL CHANGE',
    accent: FcmColors.silver,
  ),
  CommentaryKind.order: MomentStyle(
    icon: Icons.campaign_rounded,
    label: 'MANAGER ORDER',
    accent: FcmColors.gold,
  ),
  CommentaryKind.kickoff: MomentStyle(
    icon: Icons.sports_rounded,
    label: 'KICK-OFF',
    accent: FcmColors.bronze,
  ),
  CommentaryKind.halfTime: MomentStyle(
    icon: Icons.pause_rounded,
    label: 'THE BREAK',
    accent: FcmColors.bronze,
  ),
  CommentaryKind.fullTime: MomentStyle(
    icon: Icons.flag_rounded,
    label: 'THE FINAL WHISTLE',
    accent: FcmColors.gold,
  ),
  CommentaryKind.foul: MomentStyle(
    icon: Icons.block_rounded,
    label: 'FOUL',
    accent: FcmColors.textDim,
  ),
  CommentaryKind.offside: MomentStyle(
    icon: Icons.flag_outlined,
    label: 'OFFSIDE',
    accent: FcmColors.bronze,
  ),
  CommentaryKind.corner: MomentStyle(
    icon: Icons.crop_free_rounded,
    label: 'CORNER',
    accent: FcmColors.pitch,
  ),
  CommentaryKind.none: MomentStyle(
    icon: Icons.circle_rounded,
    label: 'UPDATE',
    accent: FcmColors.textDim,
  ),
};

/// The dressing of [kind]; unknown kinds fall back to the generic
/// update moment so a new engine kind never renders bare.
MomentStyle momentStyleOf(CommentaryKind kind) =>
    momentStyles[kind] ?? momentStyles[CommentaryKind.none]!;

/// A literal booking card: the small tilted rounded rectangle a referee
/// holds up. Rendered INSTEAD OF an icon for the yellow/red card kinds
/// on every commentary surface — the shape is the strongest
/// "card = card" read and it survives colour blindness.
class CardChip extends StatelessWidget {
  const CardChip({super.key, required this.color, this.size = 15});

  /// The card's own colour — `FcmColors.cardYellow` or `cardRed`.
  final Color color;

  /// The chip's target height; width follows the card ratio.
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = MomentStyle.cardChipWidth *
        (size / MomentStyle.cardChipHeight);
    final h = size;
    return SizedBox(
      width: w + 1, // +1: the tilt's bounding box is slightly wider.
      height: h + 1,
      child: Transform.rotate(
        angle: 8 * math.pi / 180,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 5,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: SizedBox(width: w, height: h),
        ),
      ),
    );
  }
}
