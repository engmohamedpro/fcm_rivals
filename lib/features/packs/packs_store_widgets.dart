/// FCM Rivals — pack store grid widgets.
///
/// The store grid family (scope sections, tier cells and the scope-key
/// helper), split verbatim out of `packs_screen.dart` (T-0041). The
/// screen shell lives on `packs_screen.dart`.
library;

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart' show Pack;
import '../../core/ui/fcm_widgets.dart';
import '../../features/collection/collection_store.dart'
    show StorePackOffer;
import 'pack_engine.dart' show PackTier;
import 'pack_effects.dart' show FoilPackPainter, kPackAspect;
import 'pack_price_widgets.dart';
import 'pack_tier_colors.dart';

/// Scope key shared by owned packs and store offers, e.g.
/// 'global:bronze' or 'position:ST:gold' — the join between inventory
/// and grid cell: owned starting packs are bronze, so they stack under
/// the bronze cells only.
String _scopeKey(String category, String? scopeValue, String tier) =>
    '$category:${scopeValue ?? 'ANY'}:$tier';

/// The store: one section per scope — global first, then every position —
/// each grouping its three tier offers under a shared header.
class StoreGrid extends StatelessWidget {
  const StoreGrid({
  super.key,
    required this.packs,
    required this.offers,
    required this.coins,
    required this.opening,
    required this.onOpen,
    required this.onBuy,
    required this.onInfo,
  });

  final List<Pack> packs;
  final List<StorePackOffer> offers;
  final int? coins;
  final bool opening;
  final void Function(int packId, PackTier tier) onOpen;
  final void Function(StorePackOffer offer) onBuy;
  final void Function(StorePackOffer offer) onInfo;

  @override
  Widget build(BuildContext context) {
    // Owned unopened packs grouped by scope+tier: their count replaces the
    // price on the matching cell (free packs, GDD 5.8).
    final owned = <String, List<Pack>>{};
    for (final p in packs) {
      owned
          .putIfAbsent(_scopeKey(p.category, p.scopeValue, p.tier), () => [])
          .add(p);
    }

    // Group the offers into scope sections, keeping store order (global
    // first, then positions).
    final sectionOrder = <String>[];
    final sections = <String, List<StorePackOffer>>{};
    for (final offer in offers) {
      final key = '${offer.category.name}:${offer.scopeValue ?? 'ANY'}';
      sections
          .putIfAbsent(key, () {
            sectionOrder.add(key);
            return <StorePackOffer>[];
          })
          .add(offer);
    }

    // The whole store in one eagerly-built column: every section renders
    // once (same cost as the old shrink-wrapped grid) and stays findable
    // for tests; the RefreshIndicator still has its scrollable. The same
    // 14px rhythm runs on all four sides and between sections, so the
    // shelves read as one evenly padded board.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var i = 0; i < sectionOrder.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _ScopeSection(
              key: ValueKey('store-section-${sectionOrder[i]}'),
              offers: sections[sectionOrder[i]]!,
              owned: owned,
              coins: coins,
              opening: opening,
              onOpen: onOpen,
              onBuy: onBuy,
              onInfo: onInfo,
            ),
          ],
        ],
      ),
    );
  }
}

/// One scope group: shared title — 'ST Pack', 'LM Pack', ... — with a
/// compact players icon button at the end of the title row, and the
/// row of the tier cells side by side (two cells when the pool holds no
/// player of the missing rarity). All rarities of one scope draw from
/// the exact same pool; the contents list behind that one button is the
/// single place that pool is shown.
class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    super.key,
    required this.offers,
    required this.owned,
    required this.coins,
    required this.opening,
    required this.onOpen,
    required this.onBuy,
    required this.onInfo,
  });

  final List<StorePackOffer> offers;
  final Map<String, List<Pack>> owned;
  final int? coins;
  final bool opening;
  final void Function(int packId, PackTier tier) onOpen;
  final void Function(StorePackOffer offer) onBuy;
  final void Function(StorePackOffer offer) onInfo;

  @override
  Widget build(BuildContext context) {
    // Sort the section's tiers into store order: rare, epic, legendary.
    final byTier = {for (final o in offers) o.tier: o};
    final ordered = [
      for (final t in PackTier.values)
        if (byTier.containsKey(t)) byTier[t]!,
    ];
    final head = ordered.first;
    final scopeLabel = '${head.scopeValue} Pack';

    // One visual group: title, players icon entry and the tier cells
    // share a single raised surface, so what belongs together reads as
    // together at a glance — sections are separated by the grid's even
    // 14px rhythm, not by a gap of their own.
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shared title with the pool entry point at the end of
          // the row: the contents list is per-scope (all three tiers
          // draw from the same pool), so one compact button serves
          // the whole section.
          FcmSectionTitle(
            scopeLabel,
            trailing: ViewPlayersButton(onPressed: () => onInfo(head)),
          ),
          const SizedBox(height: 2),
          // Packs keep the exact size they have on a full three-pack
          // shelf: every cell gets the width a third of the row would
          // give it, so a section that shelves only one or two tiers
          // shows the same pack height as the full rows instead of
          // stretching giant foils. The short shelf is centred as a
          // group, keeping the same 8px rhythm between cells.
          LayoutBuilder(
            builder: (context, rowConstraints) {
              final shelfCellWidth = (rowConstraints.maxWidth - 2 * 8) / 3;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < ordered.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    SizedBox(
                      width: shelfCellWidth,
                      child: _StorePackCell(
                        key: ValueKey(
                          'store-pack-'
                          '${ordered[i].category.name}'
                          '-${ordered[i].scopeValue ?? 'ANY'}'
                          '-${ordered[i].tier.name}',
                        ),
                        offer: ordered[i],
                        ownedCount:
                            owned[_scopeKey(
                                  ordered[i].category.name,
                                  ordered[i].scopeValue,
                                  ordered[i].tier.name,
                                )]
                                ?.length ??
                            0,
                        coins: coins,
                        onTap: () {
                          final ownedHere =
                              (owned[_scopeKey(
                                ordered[i].category.name,
                                ordered[i].scopeValue,
                                ordered[i].tier.name,
                              )] ??
                              const <Pack>[]);
                          if (opening) return;
                          if (ownedHere.isNotEmpty) {
                            onOpen(ownedHere.first.id, ordered[i].tier);
                          } else {
                            onBuy(ordered[i]);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One tier cell of a scope section: the sealed foil pack exactly as it
/// looks before opening (same [FoilPackPainter] as the reveal cinematic),
/// painted in the tier's solid jewel metal — amethyst, sapphire or
/// champion gold — with the tier name stamped on the foil's plate and a
/// premium price plate hugging its foot. The scope title and its
/// players icon entry live on the section, not the
/// cell. There is no CLAIM/BUY button: tapping the cell IS the action —
/// an owned pack opens straight into the reveal, a buyable one opens
/// the YES/NO purchase dialog.
///
/// Owned and buyable cells share the exact same layout: the plate shows
/// the success-green FREE ×N metal when the club owns packs of this
/// type, the dark gold-rimmed coin chip otherwise. The shelf is
/// deliberately STATIC — no idle animation anywhere on the store: one
/// eager column paints up to 36 of these heavy foils (lattice, card
/// fan, sunburst, shadows), so an always-on animation here would keep
/// the whole grid repainting at 60fps; the green FREE plate alone
/// carries the claim affordance.
class _StorePackCell extends StatelessWidget {
  const _StorePackCell({
    super.key,
    required this.offer,
    required this.ownedCount,
    required this.coins,
    required this.onTap,
  });

  final StorePackOffer offer;
  final int ownedCount;
  final int? coins;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final offer = this.offer;
    final isFree = ownedCount > 0;
    final affordable = coins == null || coins! >= offer.price;
    final tierColor = offer.tier.accent;

    return FcmPressable(
      onTap: onTap,
      scale: 0.93,
      child: Column(
        children: [
          // The foil sizes the cell — it fills the cell's width by aspect
          // ratio and the plate sits a breath below, so nothing floats in
          // dead air.
          DecoratedBox(
            // Ambient light in the tier's colour spilling from behind
            // the pack, like a lit display case.
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: tierColor.withValues(alpha: 0.26),
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: kPackAspect,
              // The boundary lets one cell repaint (late logo decode,
              // affordability flip) without re-rasterizing the sibling
              // foils of its section.
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: FoilPackPainter(
                    shimmer: 0.42,
                    charge: 0,
                    glowColor: tierColor,
                    tint: tierColor,
                    stars: offer.tier.stars,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Fixed plate slot: the FREE and coin plates differ by a
          // pixel or two of natural height, so the slot pins one shared
          // cell height and the three packs in a row stay flush.
          SizedBox(
            height: 24,
            child: Center(
              child: PricePlate(
                isFree: isFree,
                ownedCount: ownedCount,
                price: offer.price,
                affordable: affordable,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
