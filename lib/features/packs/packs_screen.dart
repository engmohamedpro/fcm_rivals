import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_context.dart';
import '../../core/database/app_database.dart' show Pack;
import '../../core/domain/players.dart' show Position;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../features/collection/collection_store.dart'
    show CollectionStore, PackOpenResult, StorePackOffer;
import '../../features/packs/pack_engine.dart'
    show PackCategory, PackTier, PackTierColor;
import 'pack_effects.dart' show FoilPackPainter, kPackAspect;
import 'pack_opening_screen.dart';

/// Store tab (nav label 'Store', GDD 5.5): one SECTION per position,
/// grouping its tier varieties — Rare / Epic / Legendary, each with its
/// own odds of better players and its own price — under a shared title.
/// A tier only shelves when the position's pool holds a player of that
/// rarity, so a section without, say, legendary players simply shows one
/// cell fewer. Owned (free) packs of a type show a FREE ×N pill in place
/// of the price; otherwise the cell shows the coin price. There is no
/// per-cell button: tapping the pack itself opens it — an owned pack
/// straight into the reveal, a buyable one into the YES/NO purchase
/// confirmation. Each section's ghost players icon button opens the
/// scope's full contents list (searchable, filterable by
/// nationality).
class PacksScreen extends ConsumerStatefulWidget {
  const PacksScreen({super.key});

  @override
  ConsumerState<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends ConsumerState<PacksScreen> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final packs = ref.watch(availablePacksProvider);
    final offers = ref.watch(storeOffersProvider);
    final coins = ref.watch(clubProvider).valueOrNull?.coins;

    return RefreshIndicator(
      color: FcmColors.gold,
      backgroundColor: FcmColors.surface,
      onRefresh: () async {
        ref.invalidate(availablePacksProvider);
        ref.invalidate(storeOffersProvider);
      },
      child: offers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: FcmPanel(
                accent: FcmColors.danger,
                onTap: () => ref.invalidate(storeOffersProvider),
                child: Column(
                  children: [
                    Text('$e', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to retry',
                      style: TextStyle(color: FcmColors.gold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        data: (offers) => packs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: FcmPanel(
                  accent: FcmColors.danger,
                  onTap: () => ref.invalidate(availablePacksProvider),
                  child: Text('$e', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
          data: (packs) => _StoreGrid(
            packs: packs,
            offers: offers,
            coins: coins,
            opening: _opening,
            onOpen: (packId, tier) => _open(context, packId, tier),
            onBuy: (offer) => _buy(context, offer),
            // Opens the scope's contents list — same entry as the cells'
            // players icon buttons.
            onInfo: (offer) => _showContents(context, offer),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, int packId, PackTier tier) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final random = ref.read(randomProvider);
      // The chain identity must come from the row BEFORE the open
      // consumes it — after this the slot is only described by the
      // offers list.
      final packs =
          ref.read(availablePacksProvider).valueOrNull ?? const <Pack>[];
      Pack? row;
      for (final p in packs) {
        if (p.id == packId) {
          row = p;
          break;
        }
      }
      final result = await store.openPack(packId: packId, random: random);
      ref.invalidate(availablePacksProvider);
      ref.invalidate(collectionProvider);
      if (!context.mounted) return;
      await _reveal(
        context,
        store,
        result,
        tier,
        chain: row == null ? null : _chainTargetForPack(row),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// The cinematic both paths end in: the bought or claimed pack tears
  /// open wearing its own tier metal — the exact colour of the store
  /// cell it came from. When [chain] is set the reveal offers OPEN
  /// ANOTHER: popping with `true` acquires the next pack of the same
  /// shelf slot — free if one is owned, otherwise bought outright with
  /// no YES/NO — and loops straight into the next reveal.
  Future<void> _reveal(
    BuildContext context,
    CollectionStore store,
    PackOpenResult result,
    PackTier tier, {
    _ChainTarget? chain,
  }) async {
    // Captured before the push: the sell callback fires much later,
    // inside the reveal, when this context may already be unmounted.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = l10nOf(context);
    SnackBar sellMessage(int credit) =>
        SnackBar(content: Text(l10n.packsSoldFor(FcmCoinChip.compact(credit))));
    final chained = await AppRoutes.packReveal(
      context,
      players: result.players,
      ownedIds: result.ownedIds,
      packTint: tier.accent,
      packStars: tier.stars,
      chainInfo: chain == null ? null : _chainInfoFor(chain),
      queryBalance: () => ref.read(clubProvider).valueOrNull?.coins,
      onSell: (ownedId) => store.sellPlayers([ownedId]).then((sale) {
        ref.invalidate(collectionProvider);
        if (mounted) messenger.showSnackBar(sellMessage(sale.credit));
      }),
    );
    if (chained != true || chain == null || !context.mounted) return;
    final next = await _openAnotherInChain(context, store, chain);
    if (next != null && context.mounted) {
      await _reveal(context, store, next.result, next.tier, chain: chain);
    }
  }

  /// One chain hop: open another owned pack of the same slot for free,
  /// or buy one outright — the reveal's OPEN ANOTHER tap IS the decision
  /// (the capsule is only tappable when the balance covers the price),
  /// so there is no YES/NO here; the store still validates atomically.
  Future<_ChainReveal?> _openAnotherInChain(
    BuildContext context,
    CollectionStore store,
    _ChainTarget target,
  ) async {
    try {
      final random = ref.read(randomProvider);
      final packs =
          ref.read(availablePacksProvider).valueOrNull ?? const <Pack>[];
      Pack? owned;
      for (final p in packs) {
        if (_sameSlot(p, target)) {
          owned = p;
          break;
        }
      }
      final Pack pack;
      if (owned != null) {
        pack = owned;
      } else {
        final offer = _offerFor(target);
        if (offer == null) return null;
        final coins = ref.read(clubProvider).valueOrNull?.coins ?? 0;
        if (coins < offer.price) {
          // A race the capsule can't see (balance changed mid-reveal).
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10nOf(context).packsNotEnoughCoins)),
          );
          return null;
        }
        pack = await store.buyPack(
          category: target.category,
          tier: target.tier,
          nationality: target.category == PackCategory.nationality
              ? target.scopeValue
              : null,
          position: target.category == PackCategory.position
              ? Position.fromCode(target.scopeValue!)
              : null,
        );
      }
      final result = await store.openPack(packId: pack.id, random: random);
      ref.invalidate(availablePacksProvider);
      ref.invalidate(collectionProvider);
      return _ChainReveal(result: result, tier: target.tier);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('CollectionException: ', '')),
          ),
        );
      }
      return null;
    }
  }

  /// The shelf slot the current pack came from — the same product the
  /// OPEN ANOTHER chains into. Titles come from the matching offer when
  /// one exists (reward packs beyond the shelves fall back to a derived
  /// name).
  _ChainTarget? _chainTargetForPack(Pack pack) {
    // The persisted row stores the category and tier as plain text;
    // the chain target speaks the enums (unknown values fall back the
    // same way the pack engine parses them).
    final category =
        PackCategory.values.asNameMap()[pack.category] ?? PackCategory.global;
    final tier = PackTier.fromName(pack.tier);
    final probe = _ChainTarget(
      category: category,
      scopeValue: pack.scopeValue,
      tier: tier,
    );
    final match = _offerFor(probe);
    final title =
        match?.title ??
        (category == PackCategory.position
            ? '${pack.scopeValue} ${tier.label} Pack'
            : '${tier.label} ${category.label}');
    return _ChainTarget(
      category: category,
      scopeValue: pack.scopeValue,
      tier: tier,
      title: title,
    );
  }

  /// What the OPEN ANOTHER capsule shows: the same slot's price, the
  /// club balance and the owned (free) pack count. Null when the slot
  /// cannot repeat at all — no offer and nothing owned.
  PackChainInfo? _chainInfoFor(_ChainTarget target) {
    final packs =
        ref.read(availablePacksProvider).valueOrNull ?? const <Pack>[];
    final ownedCount = packs.where((p) => _sameSlot(p, target)).length;
    final offer = _offerFor(target);
    if (offer == null && ownedCount == 0) return null;
    return PackChainInfo(
      price: offer?.price ?? 0,
      balance: ref.read(clubProvider).valueOrNull?.coins ?? 0,
      ownedCount: ownedCount,
      title: target.title,
    );
  }

  bool _sameSlot(Pack pack, _ChainTarget target) =>
      PackCategory.values.asNameMap()[pack.category] == target.category &&
      pack.scopeValue == target.scopeValue &&
      PackTier.fromName(pack.tier) == target.tier;

  StorePackOffer? _offerFor(_ChainTarget target) {
    final offers =
        ref.read(storeOffersProvider).valueOrNull ?? const <StorePackOffer>[];
    for (final o in offers) {
      if (o.category == target.category &&
          o.scopeValue == target.scopeValue &&
          o.tier == target.tier) {
        return o;
      }
    }
    return null;
  }

  /// Shows the pack's obtainable players, highest rated first.
  Future<void> _showContents(
    BuildContext context,
    StorePackOffer offer, {
    String? title,
  }) async {
    final store = await ref.read(collectionStoreProvider.future);
    if (!context.mounted) return;
    await AppRoutes.packContents(
      context,
      title: title ?? offer.title,
      category: offer.category,
      scopeValue: offer.scopeValue,
      tier: offer.tier,
      loadPlayers: () => store.getPackPlayers(
        category: offer.category,
        scopeValue: offer.scopeValue,
        tier: offer.tier,
      ),
    );
  }

  /// Buy flow: coins are the game's hard currency, so the purchase always
  /// passes an explicit YES/NO confirmation first (price and an
  /// affordability check up front); the store still validates atomically.
  /// YES buys the pack and opens it straight into the reveal cinematic.
  Future<void> _buy(BuildContext context, StorePackOffer offer) async {
    final coins = ref.read(clubProvider).valueOrNull?.coins;
    final canAfford = coins == null || coins >= offer.price;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FcmColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Buy ${offer.title}?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // The same C coin the top bar shows — one currency, one
                // icon everywhere.
                const FcmCoinGlyph(size: 22),
                const SizedBox(width: 8),
                Text(
                  FcmCoinChip.compact(
                    offer.price,
                    l10n: AppLocalizations.of(dialogContext),
                  ),
                  style: const TextStyle(
                    color: FcmColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (!canAfford) ...[
              const SizedBox(height: 10),
              const Text(
                'Not enough coins',
                style: TextStyle(
                  color: FcmColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        // NO and YES share one row — equal width, a clear gap between
        // them — instead of the default action column.
        actions: [
          SizedBox(
            width: 110,
            child: FcmButton(
              compact: true,
              style: FcmButtonStyle.steel,
              label: 'NO',
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: FcmButton(
              compact: true,
              label: 'YES',
              onPressed: canAfford
                  ? () => Navigator.of(dialogContext).pop(true)
                  : null,
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    if (_opening) return;
    setState(() => _opening = true);
    try {
      // Buy, then fall straight into the reveal — the purchase is the
      // point of the dialog, so YES plays the opening cinematic instead
      // of parking the pack in the inventory behind a snackbar.
      final store = await ref.read(collectionStoreProvider.future);
      final pack = await store.buyPack(
        category: offer.category,
        tier: offer.tier,
        position: offer.category == PackCategory.position
            ? Position.fromCode(offer.scopeValue!)
            : null,
      );
      ref.invalidate(availablePacksProvider);
      if (!context.mounted) return;
      final random = ref.read(randomProvider);
      final result = await store.openPack(packId: pack.id, random: random);
      ref.invalidate(availablePacksProvider);
      ref.invalidate(collectionProvider);
      if (!context.mounted) return;
      await _reveal(
        context,
        store,
        result,
        offer.tier,
        chain: _ChainTarget(
          category: offer.category,
          scopeValue: offer.scopeValue,
          tier: offer.tier,
          title: offer.title,
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('CollectionException: ', '')),
          ),
        );
      }
    } finally {
      // Without this the store stayed dead after one purchase — the
      // opening flag never cleared, so every later BUY/CLAIM tap
      // returned early until the app was restarted.
      if (mounted) setState(() => _opening = false);
    }
  }
}

/// What OPEN ANOTHER chains into: the exact shelf slot — category, scope
/// and tier — of the pack just opened, so the next foil is the same
/// product the player chose. [title] names it on the reveal's handoff
/// line.
class _ChainTarget {
  const _ChainTarget({
    required this.category,
    required this.scopeValue,
    required this.tier,
    this.title = '',
  });

  final PackCategory category;
  final String? scopeValue;
  final PackTier tier;
  final String title;
}

/// The next link of the chain: a freshly opened pack of the same slot.
class _ChainReveal {
  const _ChainReveal({required this.result, required this.tier});

  final PackOpenResult result;
  final PackTier tier;
}

/// Scope key shared by owned packs and store offers, e.g.
/// 'global:bronze' or 'position:ST:gold' — the join between inventory
/// and grid cell: owned starting packs are bronze, so they stack under
/// the bronze cells only.
String _scopeKey(String category, String? scopeValue, String tier) =>
    '$category:${scopeValue ?? 'ANY'}:$tier';

/// The store: one section per scope — global first, then every position —
/// each grouping its three tier offers under a shared header.
class _StoreGrid extends StatelessWidget {
  const _StoreGrid({
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
            trailing: _ViewPlayersButton(onPressed: () => onInfo(head)),
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
/// type, the dark gold-rimmed coin chip otherwise. A cell with free
/// packs shakes its pack art in a slow heartbeat loop — shake, rest,
/// shake — so unclaimed packs call out from the shelf without turning
/// the whole grid into noise.
class _StorePackCell extends StatefulWidget {
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
  State<_StorePackCell> createState() => _StorePackCellState();
}

class _StorePackCellState extends State<_StorePackCell>
    with SingleTickerProviderStateMixin {
  /// The heartbeat: 0→1 runs one ~0.55s shake, then the curve rests at
  /// 1 until the loop wraps — shake, rest, shake. Only the pack art
  /// rides this transform; the texts under it stay still.
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final isFree = widget.ownedCount > 0;
    final affordable = widget.coins == null || widget.coins! >= offer.price;
    final tierColor = offer.tier.accent;

    return FcmPressable(
      onTap: widget.onTap,
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
              child: isFree
                  ? AnimatedBuilder(
                      animation: _nudge,
                      builder: (context, child) {
                        // t in 0..1 across the full cycle; the shake
                        // occupies the first quarter (~0.55s) only.
                        final t = _nudge.value;
                        final shakeT = (t / 0.25).clamp(0.0, 1.0).toDouble();
                        final wobble =
                            math.sin(shakeT * math.pi * 5) *
                            (1 - shakeT) *
                            0.034;
                        return Transform.rotate(
                          angle: wobble,
                          child: Transform.translate(
                            offset: Offset(wobble * 34, -wobble.abs() * 10),
                            child: child,
                          ),
                        );
                      },
                      child: CustomPaint(
                        painter: FoilPackPainter(
                          shimmer: 0.42,
                          charge: 0,
                          glowColor: tierColor,
                          tint: tierColor,
                          stars: offer.tier.stars,
                        ),
                      ),
                    )
                  : CustomPaint(
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
          const SizedBox(height: 4),
          // Fixed plate slot: the FREE and coin plates differ by a
          // pixel or two of natural height, so the slot pins one shared
          // cell height and the three packs in a row stay flush.
          SizedBox(
            height: 24,
            child: Center(
              child: _PricePlate(
                isFree: isFree,
                ownedCount: widget.ownedCount,
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

/// The price plate under the pack: one premium silhouette shared by the
/// coin price and the FREE ×N claim. The coin price is the top bar's
/// balance chip in miniature — dark chip, gold rim, soft gold glow and
/// the same C coin — so the currency reads as one language everywhere;
/// red metal replaces the gold when the price is out of reach. Owned
/// stacks swap the gold for the success-green "costs nothing" metal of
/// the claim actions, keeping the identical plate shape.
class _PricePlate extends StatelessWidget {
  const _PricePlate({
    required this.isFree,
    required this.ownedCount,
    required this.price,
    required this.affordable,
  });

  final bool isFree;
  final int ownedCount;
  final int price;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    if (isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          gradient: FcmColors.successGradient,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: FcmColors.success.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: FcmColors.success.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Text(
          'FREE ×$ownedCount',
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            color: FcmColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      );
    }
    final metal = affordable ? FcmColors.gold : FcmColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: metal.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: metal.withValues(alpha: 0.16), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FcmCoinGlyph(size: 13, color: affordable ? null : metal),
          const SizedBox(width: 4),
          FitText(
            FcmCoinChip.compact(price, l10n: AppLocalizations.of(context)),
            style: TextStyle(
              color: metal,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact ghost pill that ends a scope section's title row: the one
/// entry into that scope's contents list. Icon-only — the tooltip
/// carries the label. Sized to sit inside the title row without
/// inflating it.
class _ViewPlayersButton extends StatelessWidget {
  const _ViewPlayersButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'View players',
      child: FcmPressable(
        onTap: onPressed,
        scale: 0.94,
        child: Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
          child: const Icon(
            Icons.people_outline_rounded,
            size: 16,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
