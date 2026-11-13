import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_context.dart';
import '../../core/database/app_database.dart' show Pack;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../features/collection/collection_store.dart'
    show CollectionStore, PackOpenResult, StorePackOffer;
import '../../features/packs/pack_engine.dart'
    show
        PackCategory,
        PackTier,
        normalizePositionScopeValue,
        parsePositionScopeValue;
import 'pack_tier_colors.dart';
import 'pack_opening_screen.dart';
import 'packs_store_widgets.dart';

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

    // No pull-to-refresh (owner decision 2026-11-09): a swipe could
    // invalidate the pack/offer providers mid-browse. Refresh stays
    // reachable through the error panel's tap-to-retry and the
    // providers' natural refresh on screen re-entry.
    return offers.when(
      loading: () => const SceneLoadingMarker(),
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
        loading: () => const SceneLoadingMarker(),
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
      data: (packs) => Column(
        children: [
          Expanded(
            child: StoreGrid(
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
        ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('CollectionException: ', '')),
          ),
        );
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
    // The capsule's numbers are computed from the post-open DB state
    // (T-0084): that needs the round-trips below, so re-check the
    // context before the push.
    PackChainInfo? chainInfo;
    if (chain != null) {
      chainInfo = await _chainInfoFor(store, chain);
      if (!context.mounted) return;
    }
    final chained = await AppRoutes.packReveal(
      context,
      players: result.players,
      ownedIds: result.ownedIds,
      newFlags: result.newFlags,
      packTint: tier.accent,
      packStars: tier.stars,
      chainInfo: chainInfo,
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
    // Captured before the first await: the shortfall branch below fires
    // after real DB round-trips, when this context may have unmounted.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = l10nOf(context);
    try {
      final random = ref.read(randomProvider);
      // Fresh by necessity (T-0084): this runs after the previous open
      // consumed a pack and invalidated the provider — a synchronous
      // valueOrNull would still see that consumed row and try to reopen
      // it. Awaiting the provider's next computation returns the
      // post-open DB state, so the owned lookup below can never pick a
      // pack that no longer exists.
      final packs = await ref.read(availablePacksProvider.future);
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
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.packsNotEnoughCoins)),
          );
          return null;
        }
        pack = await store.buyPack(
          category: target.category,
          tier: target.tier,
          nationality: target.category == PackCategory.nationality
              ? target.scopeValue
              : null,
          positions: target.category == PackCategory.position
              ? parsePositionScopeValue(target.scopeValue)
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
  /// name). A single-position scope ('RW' from a starting pack) maps
  /// onto its merged shelf group ('RW+RM'), so the chain follows the
  /// store's merged sections.
  _ChainTarget? _chainTargetForPack(Pack pack) {
    // The persisted row stores the category and tier as plain text;
    // the chain target speaks the enums (unknown values fall back the
    // same way the pack engine parses them).
    final category =
        PackCategory.values.asNameMap()[pack.category] ?? PackCategory.global;
    final tier = PackTier.fromName(pack.tier);
    final scopeValue = category == PackCategory.position && pack.scopeValue != null
        ? normalizePositionScopeValue(pack.scopeValue!)
        : pack.scopeValue;
    final probe = _ChainTarget(
      category: category,
      scopeValue: scopeValue,
      tier: tier,
    );
    final match = _offerFor(probe);
    final title =
        match?.title ??
        (category == PackCategory.position
            ? '${scopeValue ?? ''} ${tier.label} Pack'
            : '${tier.label} ${category.label}');
    return _ChainTarget(
      category: category,
      scopeValue: scopeValue,
      tier: tier,
      title: title,
    );
  }

  /// What the OPEN ANOTHER capsule shows: the same slot's price, the
  /// club balance and the owned (free) pack count. Null when the slot
  /// cannot repeat at all — no offer and nothing owned.
  ///
  /// Async by necessity (T-0084): it runs right after the open consumed
  /// a pack and invalidated `availablePacksProvider`, so a synchronous
  /// valueOrNull read would still count the consumed row — the +1 the
  /// capsule used to show. Awaiting the provider's next computation
  /// yields the post-open DB state, and the balance is read straight
  /// from the store so it matches the DB at push time (a mid-reveal
  /// sale still refreshes through the reveal's queryBalance callback).
  Future<PackChainInfo?> _chainInfoFor(
    CollectionStore store,
    _ChainTarget target,
  ) async {
    final packs = await ref.read(availablePacksProvider.future);
    final ownedCount = packs.where((p) => _sameSlot(p, target)).length;
    final offer = _offerFor(target);
    if (offer == null && ownedCount == 0) return null;
    return PackChainInfo(
      price: offer?.price ?? 0,
      balance: (await store.getClub())?.coins ?? 0,
      ownedCount: ownedCount,
      title: target.title,
    );
  }

  /// Same shelf slot = same category + tier + normalized scope: an
  /// owned 'RW' pack belongs to the merged 'RW+RM' slot exactly like a
  /// bought 'RW+RM' one does.
  bool _sameSlot(Pack pack, _ChainTarget target) =>
      PackCategory.values.asNameMap()[pack.category] == target.category &&
      _normalizedScope(pack.scopeValue) == _normalizedScope(target.scopeValue) &&
      PackTier.fromName(pack.tier) == target.tier;

  /// Scope comparison under the merged-shelf lens: group members
  /// ('RW', 'RM') read as their group code ('RW+RM'); anything else —
  /// nationalities, singles — passes through unchanged.
  static String? _normalizedScope(String? value) =>
      value == null ? null : normalizePositionScopeValue(value);

  StorePackOffer? _offerFor(_ChainTarget target) {
    final offers =
        ref.read(storeOffersProvider).valueOrNull ?? const <StorePackOffer>[];
    for (final o in offers) {
      if (o.category == target.category &&
          _normalizedScope(o.scopeValue) == _normalizedScope(target.scopeValue) &&
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
      // T-0126: the SAME pack's own odds — never a cross-pool
      // aggregate — computed from the engine's real draw math.
      loadOdds: () => store.getPackPlayerOdds(
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
    // A full squad cannot open the pack, so it is not sold either: say so
    // before the price dialog instead of after the coins moved.
    final capacity = await ref.read(squadCapacityProvider.future);
    if (!context.mounted) return;
    if (capacity.isFull) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Your squad is full (${capacity.owned}/${capacity.capacity} '
              'players) — buy more slots on the Team tab.',
            ),
          ),
        );
      return;
    }
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
        positions: offer.category == PackCategory.position
            ? parsePositionScopeValue(offer.scopeValue)
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
