import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart' show Pack;
import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../features/collection/collection_store.dart' show StorePackOffer;
import '../../features/packs/pack_engine.dart' show PackCategory, PackTierColor;
import 'pack_contents_screen.dart';
import 'pack_effects.dart' show FoilPackPainter, kPackAspect;
import 'pack_opening_screen.dart';

/// Packs tab — the store (GDD 5.5): ONE grid of packs in three tiers per
/// scope — Bronze / Silver / Gold — each with its own odds of better
/// players and its own price. Every cell is drawn as the sealed foil pack
/// the player later sees in the opening cinematic, tinted by its tier.
/// Owned (free) packs of a type show a FREE ×N pill in place of the
/// price; otherwise the cell shows the coin price with a BUY button.
/// Tapping a cell (or its INFO badge) shows the pack's full contents —
/// every obtainable player, highest rated first — while BUY opens the
/// YES/NO purchase confirmation.
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
        error: (e, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FcmPanel(
              accent: FcmColors.danger,
              onTap: () => ref.invalidate(storeOffersProvider),
              child: Column(
                children: [
                  Text('$e', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Tap to retry',
                      style: TextStyle(color: FcmColors.gold)),
                ],
              ),
            ),
          ),
        ]),
        data: (offers) => packs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: FcmPanel(
                accent: FcmColors.danger,
                onTap: () => ref.invalidate(availablePacksProvider),
                child: Text('$e', textAlign: TextAlign.center),
              ),
            ),
          ]),
          data: (packs) => _StoreGrid(
            packs: packs,
            offers: offers,
            coins: coins,
            opening: _opening,
            onOpen: (packId) => _open(context, packId),
            onBuy: (offer) => _buy(context, offer),
            onInfo: (offer) => _showContents(context, offer),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, int packId) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final random = ref.read(randomProvider);
      final result = await store.openPack(packId: packId, random: random);
      ref.invalidate(availablePacksProvider);
      ref.invalidate(collectionProvider);
      if (!context.mounted) return;
      // Captured before the push: the sell callback fires much later,
      // inside the reveal, when this context may already be unmounted.
      final messenger = ScaffoldMessenger.of(context);
      final sellMessage = (int credit) => SnackBar(
          content: Text('Sold for ${_groupDigits(credit)} coins'));
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PackOpeningScreen(
          players: result.players,
          ownedIds: result.ownedIds,
          onSell: (ownedId) => store.sellPlayers([ownedId]).then((sale) {
            ref.invalidate(clubProvider);
            ref.invalidate(collectionProvider);
            if (mounted) messenger.showSnackBar(sellMessage(sale.credit));
          }),
        ),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  /// Shows the pack's obtainable players, highest rated first.
  Future<void> _showContents(
      BuildContext context, StorePackOffer offer) async {
    final store = await ref.read(collectionStoreProvider.future);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PackContentsScreen(
        title: offer.title,
        category: offer.category,
        scopeValue: offer.scopeValue,
        tier: offer.tier,
        loadPlayers: () => store.getPackPlayers(
            category: offer.category,
            scopeValue: offer.scopeValue,
            tier: offer.tier),
      ),
    ));
  }

  /// Buy flow: coins are the game's hard currency, so the purchase always
  /// passes an explicit YES/NO confirmation first (price, balance and an
  /// affordability check up front); the store still validates atomically.
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
                const Icon(Icons.monetization_on_rounded,
                    color: FcmColors.gold, size: 22),
                const SizedBox(width: 8),
                Text(
                  '${_groupDigits(offer.price)} Coins',
                  style: const TextStyle(
                    color: FcmColors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (coins != null) ...[
              const SizedBox(height: 10),
              Text(
                canAfford
                    ? 'Balance: ${_groupDigits(coins)} Coins '
                        '· ${_groupDigits(coins - offer.price)} after'
                    : 'Balance: ${_groupDigits(coins)} Coins',
                style: const TextStyle(
                    color: FcmColors.textDim, fontWeight: FontWeight.w600),
              ),
            ],
            if (!canAfford) ...[
              const SizedBox(height: 10),
              const Text('Not enough coins',
                  style: TextStyle(
                      color: FcmColors.danger, fontWeight: FontWeight.w800)),
            ],
          ],
        ),
        actions: [
          FcmButton(
            compact: true,
            style: FcmButtonStyle.steel,
            label: 'NO',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          FcmButton(
            compact: true,
            label: 'YES',
            onPressed: canAfford
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final store = await ref.read(collectionStoreProvider.future);
      await store.buyPack(
        category: offer.category,
        tier: offer.tier,
        position: offer.category == PackCategory.position
            ? Position.fromCode(offer.scopeValue!)
            : null,
      );
      ref.invalidate(availablePacksProvider);
      ref.invalidate(clubProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pack bought — open it from the grid')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.replaceFirst('CollectionException: ', ''))));
      }
    }
  }
}

/// Thousands separator for dialog prices and balances, e.g. 12500 → 12,500.
String _groupDigits(int value) => value
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');

/// Scope key shared by owned packs and store offers, e.g.
/// 'global:bronze' or 'position:ST:gold' — the join between inventory
/// and grid cell: owned starting packs are bronze, so they stack under
/// the bronze cells only.
String _scopeKey(String category, String? scopeValue, String tier) =>
    '$category:${scopeValue ?? 'ANY'}:$tier';

/// The store grid: every pack cell, tier-coloured.
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
  final void Function(int packId) onOpen;
  final void Function(StorePackOffer offer) onBuy;
  final void Function(StorePackOffer offer) onInfo;

  @override
  Widget build(BuildContext context) {
    // Owned unopened packs grouped by scope+tier: their count replaces the
    // price on the matching cell (free packs, GDD 5.8).
    final owned = <String, List<Pack>>{};
    for (final p in packs) {
      owned
          .putIfAbsent(
              _scopeKey(p.category, p.scopeValue, p.tier), () => [])
          .add(p);
    }
    // Wide screens (the app clamps at 820) get more columns so cells
    // keep phone-like proportions.
    final columns = MediaQuery.of(context).size.width >= 700 ? 5 : 3;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      children: [
        GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 20,
          crossAxisSpacing: 8,
          childAspectRatio: 0.46,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < offers.length; i++)
              () {
                final offer = offers[i];
                final ownedHere = owned[_scopeKey(
                        offer.category.name, offer.scopeValue, offer.tier.name)] ??
                    const <Pack>[];
                return FcmEntrance(
                  index: i,
                  dx: 0,
                  dy: 16,
                  child: _StorePackCell(
                    offer: offer,
                    ownedCount: ownedHere.length,
                    coins: coins,
                    onTap: opening
                        ? null
                        : ownedHere.isNotEmpty
                            ? () => onOpen(ownedHere.first.id)
                            : () => onBuy(offer),
                    onInfo: () => onInfo(offer),
                  ),
                );
              }(),
          ],
        ),
      ],
    );
  }
}

/// One store cell: the sealed foil pack exactly as it looks before
/// opening (same [FoilPackPainter] as the reveal cinematic), tinted by
/// the pack's tier — bronze, silver or gold — with a scope badge, the
/// tier name, the title, and under it either the FREE ×N pill — when the
/// club owns packs of this type — or the coin price with a BUY button
/// that opens the purchase confirmation. The ⓘ badge opens the pack's
/// contents list.
class _StorePackCell extends StatelessWidget {
  const _StorePackCell({
    required this.offer,
    required this.ownedCount,
    required this.coins,
    required this.onTap,
    required this.onInfo,
  });

  final StorePackOffer offer;
  final int ownedCount;
  final int? coins;
  final VoidCallback? onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final isFree = ownedCount > 0;
    final affordable = coins == null || coins! >= offer.price;
    final scopeLabel = offer.scopeValue ?? 'ANY';
    final tierColor = offer.tier.accent;
    final shortTitle =
        offer.scopeValue == null ? 'Global Pack' : '${offer.scopeValue} Pack';

    return FcmPressable(
      onTap: onTap,
      scale: 0.93,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: kPackAspect,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: FoilPackPainter(
                          shimmer: 0.42,
                          charge: 0,
                          glowColor: tierColor,
                          tint: tierColor.withValues(alpha: 0.22),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: FcmColors.night.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: tierColor.withValues(alpha: 0.8)),
                          ),
                          child: Text(
                            scopeLabel,
                            style: TextStyle(
                              color: tierColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Contents list entry point.
                    Positioned(
                      right: 2,
                      top: 2,
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 15,
                          icon: Icon(Icons.info_outline_rounded,
                              color: Colors.white.withValues(alpha: 0.75)),
                          onPressed: onInfo,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FitText(
            shortTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FitText(
            offer.tier.label.toUpperCase(),
            style: TextStyle(
              color: tierColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 3),
          if (isFree)
            FcmPill('FREE ×$ownedCount')
          else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  size: 12,
                  color: affordable ? FcmColors.gold : FcmColors.danger,
                ),
                const SizedBox(width: 3),
                FitText(
                  _formatCoins(offer.price),
                  style: TextStyle(
                    color: affordable ? FcmColors.gold : FcmColors.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // The explicit buy affordance: tapping it (or the cell) opens
            // the YES/NO confirmation — nothing is ever bought silently.
            SizedBox(
              width: double.infinity,
              child: FcmButton(
                compact: true,
                label: 'BUY',
                onPressed: onTap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatCoins(int value) {
  if (value >= 1000000) {
    final m = value / 1000000;
    return m >= 10 ? '${m.round()}M' : '${m.toStringAsFixed(1)}M';
  }
  if (value >= 10000) return '${(value / 1000).round()}K';
  return '$value';
}
