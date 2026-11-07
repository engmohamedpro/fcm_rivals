/// FCM Rivals — squad pitch family (GDD 6.2).
///
/// The pitch, the bench/reserves card rows and the pitch painter,
/// split verbatim out of `squad_view.dart` (T-0042); the setup column
/// lives in `tactics_setup_view.dart` and `squad_view.dart` re-exports
/// both.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart' show Position, PlayerAttribute;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../collection/player_detail_sheet.dart' show rarityOf;
import 'formations.dart';
import 'pitch_layout.dart';
import 'squad_drag.dart';
import 'squad_engine.dart';
import 'squad_swap.dart' show SquadDropTarget, SquadZone;

/// The visible stat triple of a squad card: outfield players show
/// ATT / SUP / DEF, keepers GK / DEF / SUP — upgraded values included.
List<({String label, int value})> statsOf(PlayerCard c) =>
    c.position.isGoalkeeper
    ? [
        (label: 'GK', value: c.attribute(PlayerAttribute.goalkeeping)),
        (label: 'DEF', value: c.attribute(PlayerAttribute.defence)),
        (label: 'SUP', value: c.attribute(PlayerAttribute.support)),
      ]
    : [
        (label: 'ATT', value: c.attribute(PlayerAttribute.attack)),
        (label: 'SUP', value: c.attribute(PlayerAttribute.support)),
        (label: 'DEF', value: c.attribute(PlayerAttribute.defence)),
      ];

/// Renders the pitch with player cards at formation coordinates (GDD 6.2).
/// Card size adapts to the formation: the widest line and the number of
/// lines bound the shield size, so every card gets the most space the
/// shape allows without neighbours overlapping. Cards glide to their new
/// spots when the formation changes. Each card carries its stats and,
/// when [showStamina] is set, a colour-coded stamina bar.
class SquadPitch extends StatelessWidget {
  const SquadPitch({
    super.key,
    required this.formation,
    required this.assignments,
    this.showStamina = true,
    this.showStats = true,
    this.onPlayerTap,
  });

  final Formation formation;

  /// Slot index → card for the starting XI.
  final Map<int, PlayerCard> assignments;

  /// Whether cards carry their stamina bar (hidden in the Team tab).
  final bool showStamina;

  /// Whether cards carry their stat row (hidden in the Team tab).
  final bool showStats;

  /// Optional card tap (player detail sheet).
  final void Function(PlayerCard card)? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.66,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final pw = constraints.maxWidth;
              final ph = constraints.maxHeight;

              // The layout solver (pitch_layout.dart) sizes the cards as big
              // as the pitch allows and places every slot by its role — keeper
              // at the bottom, back line, midfield, attack at the top, each
              // line in the formation's left-to-right order — with air
              // between all cards and names, whatever the formation or the
              // screen.
              final layout = computePitchLayout(
                formation: formation,
                width: pw,
                height: ph,
                showStats: showStats,
                showStamina: showStamina,
              );
              final cardW = layout.cardWidth;
              final slotW = layout.slotWidth;

              return Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _PitchPainter()),
                  ),
                  for (var slot = 0; slot < formation.slots.length; slot++)
                    () {
                      final fs = formation.slots[slot];
                      final card = assignments[slot];
                      final box = layout.boxes[slot];
                      return AnimatedPositioned(
                        key: ValueKey('slot-$slot'),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        left: box.left,
                        top: box.top,
                        width: box.width,
                        // A held player can be dropped on any slot: onto a
                        // player (swap) or onto an empty slot (move).
                        child: SquadDropZone(
                          target: card == null
                              ? SquadDropTarget.xiSlot(slot)
                              : SquadDropTarget.player(card),
                          child: card == null
                              ? _EmptySlot(position: fs.position, width: cardW)
                              : SquadDraggable(
                                  card: card,
                                  feedbackSize: Size(
                                    slotW,
                                    cardW / kPlayerCardAspect + 20,
                                  ),
                                  feedback: _dragFeedback(card, cardW),
                                  child: FcmPressable(
                                    onTap: onPlayerTap == null
                                        ? null
                                        : () => onPlayerTap!(card),
                                    child: FcmMiniCard(
                                      overall: card.overall,
                                      position: card.position.code,
                                      name: card.base.name.split(' ').last,
                                      rarity: rarityOf(card),
                                      width: cardW,
                                      warn: fs.position != card.position,
                                      stamina: showStamina
                                          ? card.staminaPercent
                                          : null,
                                      stats: showStats ? statsOf(card) : null,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    }(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of mini cards (bench / reserves): the surname under
/// each shield, the stat row and — when [showStamina] is set — the
/// stamina bar.
/// Horizontal strip of mini cards (bench / reserves): the surname under
/// each shield, the stat row and — when [showStamina] is set — the
/// stamina bar. [emptySlots] pads the strip with placeholder cards, so
/// an un-filled bench or reserves still shows its full quota of slots.
class SquadCardRow extends StatelessWidget {
  const SquadCardRow({
    super.key,
    required this.cards,
    this.emptySlots = 0,
    this.zone,
    this.showStamina = true,
    this.showStats = true,
    this.onPlayerTap,
  });

  final List<PlayerCard> cards;

  /// Which part of the squad this strip is — lets a held player be dropped
  /// on its empty places. Null makes the empty places plain placeholders.
  final SquadZone? zone;

  /// Placeholder cards appended after the real ones (quota minus the
  /// assigned players).
  final int emptySlots;

  /// Whether cards carry their stamina bar (hidden in the Team tab).
  final bool showStamina;

  /// Whether cards carry their stat row (hidden in the Team tab).
  final bool showStats;

  /// Optional card tap (player detail sheet).
  final void Function(PlayerCard card)? onPlayerTap;

  static const double cardWidth = 64;

  @override
  Widget build(BuildContext context) {
    // Shield + surname, plus the optional stat row and stamina bar
    // (20 + 22 + 8 = the flat 50 the full strip always used).
    final stripHeight =
        cardWidth / kPlayerCardAspect +
        20 +
        (showStats ? 22 : 0) +
        (showStamina ? 8 : 0);
    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length + emptySlots,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i >= cards.length) {
            final z = zone;
            return z == null
                ? const _EmptyBenchCard()
                : SquadDropZone(
                    target: SquadDropTarget.emptyIn(z),
                    child: const _EmptyBenchCard(),
                  );
          }
          final c = cards[i];
          return FcmEntrance(
            index: i,
            dx: 20,
            dy: 0,
            child: SquadDropZone(
              target: SquadDropTarget.player(c),
              child: SquadDraggable(
                card: c,
                feedbackSize: Size(
                  cardWidth + 12,
                  cardWidth / kPlayerCardAspect + 20,
                ),
                feedback: _dragFeedback(c, cardWidth),
                child: FcmPressable(
                  onTap: onPlayerTap == null ? null : () => onPlayerTap!(c),
                  child: FcmMiniCard(
                    overall: c.overall,
                    position: c.position.code,
                    name: c.base.name.split(' ').last,
                    rarity: rarityOf(c),
                    width: cardWidth,
                    stamina: showStamina ? c.staminaPercent : null,
                    stats: showStats ? statsOf(c) : null,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The card that follows the finger while a player is dragged: the plain
/// mini card (no stamina bar or stat row), the same size as on the page.
Widget _dragFeedback(PlayerCard card, double width) => FcmMiniCard(
  overall: card.overall,
  position: card.position.code,
  name: card.base.name.split(' ').last,
  rarity: rarityOf(card),
  width: width,
);

/// An unassigned formation slot: a ghost mini card — the exact shape,
/// size and layout of a filled one (same painter silhouette, same text
/// slots) rendered see-through with no overall, position or name, so the
/// pitch reads as a full formation with the empty places still holding
/// their card footprints.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.position, required this.width});

  final Position position;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: FcmMiniCard(
        overall: 0,
        position: '',
        name: '',
        rarity: CardRarity.rare,
        width: width,
        ghost: true,
      ),
    );
  }
}

/// Placeholder for an unassigned bench / reserves slot: a ghost mini
/// card — same footprint and style as the real ones beside it, dimmed
/// and wordless (no overall, position or name).
class _EmptyBenchCard extends StatelessWidget {
  const _EmptyBenchCard();

  static const double width = SquadCardRow.cardWidth;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: FcmMiniCard(
        overall: 0,
        position: '',
        name: '',
        rarity: CardRarity.rare,
        width: width,
        ghost: true,
      ),
    );
  }
}

/// Mown-grass stripes, white markings and a soft floodlight vignette.
class _PitchPainter extends CustomPainter {
  const _PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;

    // Grass with alternating mown bands.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF41502F), Color(0xFF57683F)],
        ).createShader(rect),
    );
    const bands = 10;
    for (var i = 0; i < bands; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, h / bands * i, w, h / bands),
        Paint()..color = Colors.white.withValues(alpha: 0.045),
      );
    }

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.6);
    final m = w * 0.05;
    final field = Rect.fromLTRB(m, m, w - m, h - m);
    canvas.drawRect(field, line);
    canvas.drawLine(Offset(m, h / 2), Offset(w - m, h / 2), line);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.14, line);
    canvas.drawCircle(Offset(w / 2, h / 2), 3, Paint()..color = line.color);

    // Penalty and goal areas, top and bottom.
    final boxW = w * 0.56, boxH = h * 0.14;
    final goalW = w * 0.28, goalH = h * 0.055;
    for (final top in [true, false]) {
      final y0 = top ? m : h - m - boxH;
      canvas.drawRect(Rect.fromLTWH((w - boxW) / 2, y0, boxW, boxH), line);
      final gy = top ? m : h - m - goalH;
      canvas.drawRect(Rect.fromLTWH((w - goalW) / 2, gy, goalW, goalH), line);
      // penalty arc
      final arcCenter = Offset(
        w / 2,
        top ? m + boxH * 0.72 : h - m - boxH * 0.72,
      );
      final arcRect = Rect.fromCircle(center: arcCenter, radius: w * 0.11);
      canvas.drawArc(
        arcRect,
        top ? 0.45 : math.pi + 0.45,
        math.pi - 0.9,
        false,
        line,
      );
    }

    // Floodlight vignette.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          stops: const [0.55, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_PitchPainter old) => false;
}
