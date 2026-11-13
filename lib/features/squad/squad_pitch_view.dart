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
import '../../core/ui/country_flag.dart' show flagEmojiFor;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../collection/player_detail_sheet.dart' show rarityOf;
import '../match/chemistry.dart' show clubChemistryKeyOf;
import '../match/chemistry_links.dart';
import 'formations.dart';
import 'pitch_layout.dart';
import 'squad_drag.dart';
import 'squad_engine.dart';
import 'squad_swap.dart'
    show DragSlot, SquadDropTarget, SquadZone, squadDragLayout;

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
    this.showChemistryLinks = false,
    this.showStamina = true,
    this.showStats = true,
    this.showCondition = true,
    this.onPlayerTap,
    this.upgradable,
  });

  final Formation formation;

  /// Slot index → card for the starting XI.
  final Map<int, PlayerCard> assignments;

  /// Draws a line between players sharing a nationality or a club
  /// (owner request 2026-11-11): white when the pair shares ONE
  /// chemistry type, golden when it shares both. The chemistry reading
  /// itself lives on the control card above the pitch.
  final bool showChemistryLinks;

  /// Whether cards carry their stamina bar (hidden in the Team tab).
  final bool showStamina;

  /// Whether cards carry their stat row (hidden in the Team tab).
  final bool showStats;

  /// Optional card tap (player detail sheet).
  /// Whether cards carry MATCH-DAY CONDITION chrome (T-0117): the
  /// injury badge and the injured card's frozen/inert treatment.
  /// The Team tab — the pure management surface — passes false:
  /// the saved XI is the club's identity eleven on merit, and
  /// fitness is a matchday concern that belongs to the pre-match
  /// duplicate (and the kick-off session guard), never here.
  /// Pre-match/live keep the true value.
  final bool showCondition;

  final void Function(PlayerCard card)? onPlayerTap;

  /// Upgradable marks (T-0089): true when a duplicate of the base
  /// player is owned. Null shows no mark (non-team surfaces).
  final bool Function(int playerId)? upgradable;

  @override
  Widget build(BuildContext context) {
    // The live drag (custom-formation preview, owner request
    // 2026-11-13): while a player is held, the pitch re-spreads the
    // WHOLE shape — his old place opens, every position's anchors
    // re-take their count-aware spread (a lone CAM centres, a pair
    // halves, a trio lines up), and every place the drop may fill
    // shows its position placeholder, including positions the current
    // shape does not field at all (a 3-4-3 with no RB still shows the
    // RB place — a dragged ST may take it). Read straight from the
    // drag scope, so the preview lives only on surfaces that enable
    // swapping.
    final dragScope = SquadDragScope.maybeOf(context);
    return ValueListenableBuilder<PlayerCard?>(
      valueListenable: dragScope?.dragging ?? _noDrag,
      builder: (context, held, _) => AspectRatio(
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

                // The drag layout: the shape re-spread as it stands
                // without the held man, his own place marked. Null
                // when nobody is held (or the surface has no swapping)
                // — the pitch then renders the plain formation.
                final dragLayout = held == null
                    ? null
                    : squadDragLayout(
                        formation: formation,
                        squad: assignments,
                        dragged: held,
                      );

                // The layout solver (pitch_layout.dart) sizes the cards as big
                // as the pitch allows and places every slot by its role — keeper
                // at the bottom, back line, midfield, attack at the top, each
                // line in the formation's left-to-right order — with air
                // between all cards and names, whatever the formation or the
                // screen. A live drag re-solves on the PREVIEW formation (the
                // re-spread shape's own 11 places), so the cards glide to the
                // places the drop builds and the placeholders sit exactly
                // where the new shape stands. The EXTRA spare places (positions
                // the shape does not field — the RB of a 3-4-3) render from
                // the SAME drag layout, offset alongside their line's depth.
                final effectiveFormation = dragLayout == null
                    ? formation
                    : Formation(
                        formation.code,
                        formation.name,
                        [
                          for (final s in dragLayout.slots.take(11))
                            FormationSlot(s.position, s.x, s.y),
                        ],
                      );
                final layout = computePitchLayout(
                  formation: effectiveFormation,
                  width: pw,
                  height: ph,
                  showStats: showStats,
                  showStamina: showStamina,
                );
                final cardW = layout.cardWidth;
                final slotW = layout.slotWidth;
                // The spare places beyond the XI (owner request
                // 2026-11-13): every position the mix may still take
                // that the shape does not field, each rendered as a
                // placeholder at its own anchor, pushed to the pitch
                // edge of its line so it never fights the shape's own
                // cards for space.
                final extraPlaces = dragLayout == null
                    ? const <DragSlot>[]
                    : dragLayout.slots.skip(11).toList();
                // Where each spare stands: beside the line of its own
                // depth, on a free spot — never on top of a card.
                final extraBoxes = placeSparePlaces(
                  layout: layout,
                  formation: effectiveFormation,
                  width: pw,
                  height: ph,
                  requests: [
                    for (final extra in extraPlaces)
                      SparePlaceRequest(
                        y: extra.y,
                        leftSide: switch (extra.position) {
                          Position.lb ||
                          Position.lw ||
                          Position.lm => true,
                          Position.rb ||
                          Position.rw ||
                          Position.rm => false,
                          _ => extra.x < 50,
                        },
                      ),
                  ],
                );

                return Stack(
                  children: [
                  const Positioned.fill(
                    // Perf pass 2026-11-12: the pitch painter is static
                    // (shouldRepaint: false) but the 11 slot cards'
                    // AnimatedPositioned glides used to re-record it every
                    // frame — its own boundary keeps it rasterized.
                    child: RepaintBoundary(child: CustomPaint(painter: _PitchPainter())),
                  ),
                  // Chemistry links: a line between players sharing a
                  // nationality or a club, drawn UNDER the cards so
                  // they read as threads running from card to card.
                  // Only on surfaces that show the chemistry reading.
                  if (showChemistryLinks)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: _ChemistryLinksLayer(
                          nationalities: {
                            for (final e in assignments.entries)
                              if (e.key < formation.slots.length)
                                e.key: e.value.base.nationality,
                          },
                          clubs: {
                            for (final e in assignments.entries)
                              if (e.key < formation.slots.length)
                                e.key: clubChemistryKeyOf(
                                  e.value.base.clubId,
                                  e.value.base.clubName,
                                ),
                          },
                          icons: {
                            for (final e in assignments.entries)
                              if (e.key < formation.slots.length)
                                e.key: e.value.base.isIcon,
                          },
                          centres: {
                            for (final e in assignments.entries)
                              if (e.key < formation.slots.length)
                                e.key: Offset(
                                  layout.boxes[e.key].left +
                                      layout.boxes[e.key].width / 2,
                                  layout.boxes[e.key].top +
                                      cardW / kPlayerCardAspect / 2,
                                ),
                          },
                        ),
                      ),
                    ),
                  for (var slot = 0; slot < formation.slots.length; slot++)
                    () {
                      // The DRAG view (owner request 2026-11-13): while a
                      // player is held, every place renders from the
                      // re-spread layout — his own place shows his
                      // position's placeholder (he may drop back there),
                      // every OTHER empty position of the new shape shows
                      // its placeholder too, and the occupied places
                      // carry their cards wherever the new spread put
                      // them. With nobody held this is the plain slot.
                      final fs = effectiveFormation.slots[slot];
                      final card = assignments[slot];
                      final box = layout.boxes[slot];
                      final dragSlot = dragLayout?.slots[slot];
                      final heldHere = dragSlot?.isHeld ?? false;
                      // During a drag the occupied cards keep their men;
                      // the held man's own slot and every place the shape
                      // now asks for and nobody fills render a
                      // placeholder naming the position.
                      final showCard = card != null && !heldHere;
                      return AnimatedPositioned(
                        key: ValueKey('slot-$slot'),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        left: box.left,
                        top: box.top,
                        width: box.width,
                        // A held player can be dropped on any place: onto a
                        // player (swap) or onto an empty place (which
                        // redefines the slot — custom formation).
                        child: !showCard
                            ? SquadDropZone(
                                target: SquadDropTarget.xiSlot(
                                  slot,
                                  position: dragSlot?.position ?? fs.position,
                                ),
                                child: _EmptySlot(
                                  position: dragSlot?.position ?? fs.position,
                                  width: cardW,
                                  heldPosition: held != null &&
                                      dragLayout!.isLegal
                                  ? held.position
                                  : null,
                                  heldProblem: held == null
                                      ? null
                                      : dragLayout!.problem,
                                  highlighted: heldHere,
                                ),
                              )
                            : showCondition && card.injuryMatchesRemaining > 0
                            ? // Injured (T-0056): visually marked and fully
                              // inert — no pickup, no drop target, no swap.
                              // The store refuses any squad save
                              // referencing him (T-0055 backstop), so the
                              // frozen slot is the honest rendering until
                              // he recovers. Detail tap still works.
                              FcmPressable(
                                onTap: onPlayerTap == null
                                    ? null
                                    : () => onPlayerTap!(card),
                                child: FcmMiniCard(
                                  overall: card.overall,
                                  position: card.position.code,
                                  flag: flagEmojiFor(card.base.nationality),
                                  imageUrl: card.base.imageUrl,
                                  clubCrestUrl: card.base.clubCrestUrl,
                                  name: card.base.name,
                                  rarity: rarityOf(card),
                                  isIcon: card.base.isIcon,
                                  width: cardW,
                                  warn: fs.position != card.position,
                                  stamina: showStamina
                                      ? card.staminaPercent
                                      : null,
                                  stats: showStats ? statsOf(card) : null,
                                  injuryMatchesOut: showCondition
                                      ? card.injuryMatchesRemaining
                                      : null,
                                  upgradeLevel: card.upgradeLevel,
                                  upgradable: upgradable?.call(
                                        card.base.playerId,
                                      ) ??
                                      false,
                                ),
                              )
                            : SquadDropZone(
                                target: SquadDropTarget.player(card),
                                child: SquadDraggable(
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
                                      flag: flagEmojiFor(card.base.nationality),
                                      imageUrl: card.base.imageUrl,
                                      clubCrestUrl: card.base.clubCrestUrl,
                                      name: card.base.name,
                                      rarity: rarityOf(card),
                                      isIcon: card.base.isIcon,
                                      width: cardW,
                                      warn: fs.position != card.position,
                                      stamina: showStamina
                                          ? card.staminaPercent
                                          : null,
                                      stats: showStats ? statsOf(card) : null,
                                      injuryMatchesOut: showCondition
                                          ? card.injuryMatchesRemaining
                                          : null,
                                      upgradeLevel: card.upgradeLevel,
                                      upgradable: upgradable?.call(
                                            card.base.playerId,
                                          ) ??
                                          false,
                                    ),
                                  ),
                                ),
                              ),
                      );
                    }(),
                  // The SPARE places (owner request 2026-11-13): the
                  // positions the mix may still take that the shape
                  // does not field — the RB of a 3-4-3, a second ST
                  // of a one-striker shape. Each renders as a
                  // placeholder at its own anchor, pushed to the
                  // EDGE of its line (left edge for left-side
                  // positions, right for right, centre positions sit
                  // just outside the widest card of their line) so it
                  // never fights the shape's own cards for space.
                  for (var e = 0; e < extraPlaces.length; e++)
                    () {
                      final extra = extraPlaces[e];
                      final box = extraBoxes[e];
                      return Positioned(
                        key: ValueKey('extra-${extra.position.code}'),
                        left: box.left,
                        top: box.top,
                        width: box.width,
                        height: box.height,
                        child: SquadDropZone(
                          target: SquadDropTarget.xiSlot(
                            // The slot index is a placeholder — the
                            // resolver in squad_swap.dart maps the
                            // POSITION to the real slot; 1 is a safe
                            // non-GK stand-in.
                            1,
                            position: extra.position,
                          ),
                          child: _EmptySlot(
                            position: extra.position,
                            width: cardW,
                            heldPosition: held != null && dragLayout!.isLegal
                                ? held.position
                                : null,
                            heldProblem: held == null
                                ? null
                                : dragLayout!.problem,
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
      ),
    );
  }
}

/// A never-firing stand-in for the drag notifier on surfaces without a
/// [SquadDragHost] (pre-match, live tactics): the pitch then renders no
/// drag preview at all.
final ValueNotifier<PlayerCard?> _noDrag = ValueNotifier<PlayerCard?>(null);

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
    this.showCondition = true,
    this.onPlayerTap,
    this.upgradable,
    this.wrap = false,
    this.selectedIds = const {},
  });

  /// Owned ids already placed in the XI / bench: drawn faded with a
  /// check so the all-players pool still lists them, visibly chosen.
  final Set<int> selectedIds;

  /// Lays the cards out as a wrapping grid instead of a one-line strip
  /// (the Team tab's all-players pool).
  final bool wrap;

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
  /// Whether cards carry MATCH-DAY CONDITION chrome (T-0117) — the
  /// injury badge and the injured card's inert treatment. False on
  /// the Team tab's strips: management shows the squad on merit.
  final bool showCondition;

  final void Function(PlayerCard card)? onPlayerTap;

  /// Upgradable marks (T-0089): true when a duplicate of the base
  /// player is owned. Null shows no mark.
  final bool Function(int playerId)? upgradable;

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
    Widget itemAt(BuildContext context, int i) {
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
          final injured = showCondition && c.injuryMatchesRemaining > 0;
          // Already placed in the XI / bench (drawn faded with the gold
          // check): it cannot be picked up again from this strip — move
          // him from the pitch or the bench instead.
          final picked = selectedIds.contains(c.ownedId);
          final item = FcmEntrance(
            index: wrap ? 0 : i,
            dx: 20,
            dy: 0,
            child: injured
                ? // Injured (T-0056): marked and inert in the strips too —
                  // no pickup, no drop target.
                  FcmPressable(
                    onTap: onPlayerTap == null ? null : () => onPlayerTap!(c),
                    child: FcmMiniCard(
                      overall: c.overall,
                      position: c.position.code,
                      flag: flagEmojiFor(c.base.nationality),
                      imageUrl: c.base.imageUrl,
                      clubCrestUrl: c.base.clubCrestUrl,
                      name: c.base.name,
                      rarity: rarityOf(c),
                      width: cardWidth,
                      stamina: showStamina ? c.staminaPercent : null,
                      stats: showStats ? statsOf(c) : null,
                      injuryMatchesOut: showCondition
                          ? c.injuryMatchesRemaining
                          : null,
                      upgradeLevel: c.upgradeLevel,
                      upgradable: upgradable?.call(c.base.playerId) ?? false,
                    ),
                  )
                : SquadDropZone(
                    target: SquadDropTarget.player(c),
                    child: () {
                      final tappable = FcmPressable(
                        onTap: onPlayerTap == null
                            ? null
                            : () => onPlayerTap!(c),
                        child: FcmMiniCard(
                          overall: c.overall,
                          position: c.position.code,
                          flag: flagEmojiFor(c.base.nationality),
                          imageUrl: c.base.imageUrl,
                          clubCrestUrl: c.base.clubCrestUrl,
                          name: c.base.name,
                          rarity: rarityOf(c),
                          isIcon: c.base.isIcon,
                          width: cardWidth,
                          stamina: showStamina ? c.staminaPercent : null,
                          stats: showStats ? statsOf(c) : null,
                          injuryMatchesOut: showCondition
                              ? c.injuryMatchesRemaining
                              : null,
                          upgradeLevel: c.upgradeLevel,
                          upgradable: upgradable?.call(c.base.playerId) ??
                              false,
                        ),
                      );
                      // A picked card keeps its tap (detail sheet) but has
                      // no pickup.
                      if (picked) return tappable;
                      return SquadDraggable(
                        card: c,
                        feedbackSize: Size(
                          cardWidth + 12,
                          cardWidth / kPlayerCardAspect + 20,
                        ),
                        feedback: _dragFeedback(c, cardWidth),
                        child: tappable,
                      );
                    }(),
                  ),
          );
          return picked ? _selectedMark(item) : item;
    }

    final count = cards.length + emptySlots;
    if (wrap) {
      return Wrap(
        spacing: 6,
        runSpacing: 8,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(
              width: cardWidth,
              height: stripHeight,
              child: itemAt(context, i),
            ),
        ],
      );
    }
    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: itemAt,
      ),
    );
  }
}

/// Fades a card and pins a gold check on it: "already picked".
Widget _selectedMark(Widget card) => Stack(
  clipBehavior: Clip.none,
  children: [
    Opacity(opacity: 0.4, child: card),
    Positioned(
      top: 2,
      right: 2,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(1),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: FcmColors.gold,
          ),
          child: const Icon(Icons.check_rounded, size: 12, color: FcmColors.ink),
        ),
      ),
    ),
  ],
);

/// The card that follows the finger while a player is dragged: the plain
/// mini card (no stamina bar or stat row), the same size as on the page.
Widget _dragFeedback(PlayerCard card, double width) => FcmMiniCard(
  overall: card.overall,
  position: card.position.code,
  flag: flagEmojiFor(card.base.nationality),
  imageUrl: card.base.imageUrl,
  clubCrestUrl: card.base.clubCrestUrl,
  name: card.base.name,
  rarity: rarityOf(card),
  isIcon: card.base.isIcon,
  width: width,
  upgradeLevel: card.upgradeLevel,
);

/// An unassigned formation place: a ghost mini card — the exact shape,
/// size and layout of a filled one (same painter silhouette, same text
/// slots) rendered see-through with no overall or name, so the pitch
/// reads as a full formation with the empty places still holding
/// their card footprints.
///
/// Custom formations (owner request 2026-11-13): while a player is
/// held, the whole shape re-spreads and EVERY free place of the new
/// mix shows its position placeholder (not just the starting XI's own
/// empty slots) — positions the current shape does not field at all
/// included. The [heldPosition] preview applies to all of them: the
/// drop fills the place with that position when the caps allow it,
/// [heldProblem] names the reason when they do not, and [highlighted]
/// marks the held man's OWN place (the natural drop-back spot).
class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.position,
    required this.width,
    this.heldPosition,
    this.heldProblem,
    this.highlighted = false,
  });

  /// What the place asks for right now.
  final Position position;

  final double width;

  /// The held player's position while a drag is live, else null.
  final Position? heldPosition;

  /// Why the held player may NOT take this place (caps / keeper law),
  /// or null when he may.
  final String? heldProblem;

  /// True for the held man's own place while his drag is live — the
  /// place he came from, the natural spot to drop him back.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    // The chip names the PLACE's own position — the position a drop on
    // it builds — so the RB / LB / CDM / CAM spares read differently.
    // (It used to print the HELD man's position on every placeholder,
    // so every spare place of a drag read the same.)
    final ask = position;
    return Opacity(
      opacity: highlighted ? 0.9 : 0.45,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FcmMiniCard(
            overall: 0,
            position: '',
            name: '',
            rarity: CardRarity.rare,
            width: width,
            ghost: true,
          ),
          // The position chip floating over the ghost: the place's ask
          // (or the held player's position while a drag is live and
          // legal — the "what this drop builds" preview).
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: heldProblem != null
                        ? const Color(0x99B3261E)
                        : highlighted
                        ? Colors.white.withValues(alpha: 0.92)
                        : heldPosition != null
                        ? FcmColors.gold.withValues(alpha: 0.92)
                        : Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: heldProblem != null
                          ? Colors.white.withValues(alpha: 0.8)
                          : highlighted
                          ? FcmColors.gold
                          : Colors.white.withValues(alpha: 0.25),
                      width: highlighted ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    heldProblem != null
                        ? (heldProblem!.length > 22
                              ? '${heldProblem!.substring(0, 21)}…'
                              : heldProblem!)
                        : ask.code,
                    maxLines: 1,
                    style: TextStyle(
                      color: heldProblem != null || highlighted
                          ? FcmColors.ink
                          : FcmColors.gold,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

/// Palette for the chemistry lines (owner request 2026-11-11): a pair
/// sharing ONE chemistry type (nationality or club) is joined by a
/// white line, a pair sharing BOTH by a golden line. The dark grass
/// bands keep both readable with the shared dark under-stroke.
const Color _kSingleTypeLinkColor = Color(0xFFFFFFFF);
const Color _kDoubleTypeLinkColor = Color(0xFFFFD54F);

/// Draws the chemistry lines (same-nationality / same-club links) under
/// the cards. When the formation changes the cards glide to their new
/// spots, and the line ends follow them with the same curve and
/// duration.
class _ChemistryLinksLayer extends StatefulWidget {
  const _ChemistryLinksLayer({
    required this.nationalities,
    required this.clubs,
    required this.centres,
    this.icons = const {},
  });

  final Map<int, String?> nationalities;
  final Map<int, String?> clubs;
  final Map<int, Offset> centres;

  /// Icon-player slots (owner request 2026-11-12): wildcards linking to
  /// every other slot in BOTH chemistry kinds.
  final Map<int, bool> icons;

  @override
  State<_ChemistryLinksLayer> createState() => _ChemistryLinksLayerState();
}

class _ChemistryLinksLayerState extends State<_ChemistryLinksLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late Map<int, Offset> _from = widget.centres;
  late Map<int, Offset> _to = widget.centres;

  static bool _sameCentres(Map<int, Offset> a, Map<int, Offset> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  Map<int, Offset> _current() {
    final t = Curves.easeOutCubic.transform(_glide.value);
    return {
      for (final e in _to.entries)
        e.key: Offset.lerp(_from[e.key] ?? e.value, e.value, t)!,
    };
  }

  @override
  void didUpdateWidget(_ChemistryLinksLayer old) {
    super.didUpdateWidget(old);
    if (!_sameCentres(_to, widget.centres)) {
      _from = _current();
      _to = widget.centres;
      _glide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final links = chemistryLinks(
      nationalities: widget.nationalities,
      clubs: widget.clubs,
      centres: {
        for (final e in _to.entries) e.key: (x: e.value.dx, y: e.value.dy),
      },
      icons: widget.icons,
    );
    return AnimatedBuilder(
      animation: _glide,
      builder: (context, _) => CustomPaint(
        painter: _ChemistryLinksPainter(
          links: links,
          centres: _current(),
        ),
      ),
    );
  }
}

class _ChemistryLinksPainter extends CustomPainter {
  const _ChemistryLinksPainter({required this.links, required this.centres});

  final List<ChemistryLink> links;
  final Map<int, Offset> centres;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      final a = centres[link.a];
      final b = centres[link.b];
      if (a == null || b == null) continue;
      // Owner request 2026-11-11: one shared chemistry type → white,
      // both types (nationality AND club) → golden. The kind set is
      // the pair's relationship, so the colour is stable even when
      // only one dimension's tree drew the edge.
      final baseColor = link.kinds.length >= 2
          ? _kDoubleTypeLinkColor
          : _kSingleTypeLinkColor;
      final color = baseColor.withValues(alpha: 0.7);
      // A dark under-stroke keeps the colour legible on the grass bands.
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 5.5
          ..strokeCap = StrokeCap.round
          ..color = Colors.black.withValues(alpha: 0.35),
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ChemistryLinksPainter old) => true;
}

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
