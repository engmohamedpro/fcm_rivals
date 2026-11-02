import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart' show Pack;
import '../../core/domain/players.dart' show BasePlayer, Position;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart' show FcmMiniCard, kPlayerCardAspect;
import '../../features/collection/collection_store.dart' show StorePackOffer;
import '../../features/packs/pack_engine.dart'
    show PackCategory, PackTier, PackTierColor;
import '../../features/squad/squad_view.dart' show SquadCardRow;
import 'pack_contents_screen.dart';
import 'pack_effects.dart' show FoilPackPainter, kPackAspect;
import 'pack_opening_screen.dart';

/// Packs tab — the store (GDD 5.5): one SECTION per scope — the global
/// pack or one position — grouping its three tier varieties — Bronze /
/// Silver / Gold, each with its own odds of better players and its own
/// price — under a shared title and a shared strip of obtainable
/// players: the three rarities of one scope draw from the exact same
/// pool, so the section shows it once. Owned (free) packs of a type
/// show a FREE ×N pill in place of the price; otherwise the cell shows
/// the coin price with a BUY button. The section header's player count
/// and each cell's INFO badge open the full contents list, highest
/// rated first; BUY opens the YES/NO purchase confirmation.
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
            // The section strips share one pool loader: all tiers of a
            // scope match the same players, so the tier is irrelevant.
            onLoadPool: (category, scopeValue) async {
              final store = await ref.read(collectionStoreProvider.future);
              return store.getPackPlayers(
                  category: category,
                  scopeValue: scopeValue,
                  tier: PackTier.bronze);
            },
            onViewAll: (offer) => _showContents(context, offer,
                title: offer.scopeValue == null
                    ? 'Global Pack — All Players'
                    : '${offer.scopeValue} Pack — All Players'),
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
  Future<void> _showContents(BuildContext context, StorePackOffer offer,
      {String? title}) async {
    final store = await ref.read(collectionStoreProvider.future);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PackContentsScreen(
        title: title ?? offer.title,
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
  /// passes an explicit YES/NO confirmation first (price and an
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
            if (!canAfford) ...[
              const SizedBox(height: 10),
              const Text('Not enough coins',
                  style: TextStyle(
                      color: FcmColors.danger, fontWeight: FontWeight.w800)),
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

/// The store: one section per scope — global first, then every position —
/// each grouping its three tier offers under a shared header and a
/// shared strip of obtainable players.
class _StoreGrid extends StatelessWidget {
  const _StoreGrid({
    required this.packs,
    required this.offers,
    required this.coins,
    required this.opening,
    required this.onOpen,
    required this.onBuy,
    required this.onInfo,
    required this.onLoadPool,
    required this.onViewAll,
  });

  final List<Pack> packs;
  final List<StorePackOffer> offers;
  final int? coins;
  final bool opening;
  final void Function(int packId) onOpen;
  final void Function(StorePackOffer offer) onBuy;
  final void Function(StorePackOffer offer) onInfo;

  /// Loads the shared eligible pool of a scope (tier-agnostic — all
  /// tiers of one scope draw from the same players).
  final Future<List<BasePlayer>> Function(
      PackCategory category, String? scopeValue) onLoadPool;

  /// Opens the full contents list of a scope.
  final void Function(StorePackOffer offer) onViewAll;

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

    // Group the offers into scope sections, keeping store order (global
    // first, then positions).
    final sectionOrder = <String>[];
    final sections = <String, List<StorePackOffer>>{};
    for (final offer in offers) {
      final key = '${offer.category.name}:${offer.scopeValue ?? 'ANY'}';
      sections.putIfAbsent(key, () {
        sectionOrder.add(key);
        return <StorePackOffer>[];
      }).add(offer);
    }

    // The whole store in one eagerly-built column: every section renders
    // once (same cost as the old shrink-wrapped grid) and stays findable
    // for tests; the RefreshIndicator still has its scrollable.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      child: Column(
        children: [
          for (final key in sectionOrder)
            _ScopeSection(
              key: ValueKey('store-section-$key'),
              offers: sections[key]!,
              owned: owned,
              coins: coins,
              opening: opening,
              onOpen: onOpen,
              onBuy: onBuy,
              onInfo: onInfo,
              onLoadPool: onLoadPool,
              onViewAll: onViewAll,
            ),
        ],
      ),
    );
  }
}

/// One scope group: shared title — 'Global Pack' or 'ST Pack' — with the
/// pool size, the row of the three tier cells side by side, and below
/// them the shared strip of obtainable players (best first). The three
/// rarities of one scope draw from the exact same pool, so the section
/// states that once instead of repeating it per cell.
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
    required this.onLoadPool,
    required this.onViewAll,
  });

  final List<StorePackOffer> offers;
  final Map<String, List<Pack>> owned;
  final int? coins;
  final bool opening;
  final void Function(int packId) onOpen;
  final void Function(StorePackOffer offer) onBuy;
  final void Function(StorePackOffer offer) onInfo;
  final Future<List<BasePlayer>> Function(
      PackCategory category, String? scopeValue) onLoadPool;
  final void Function(StorePackOffer offer) onViewAll;

  @override
  Widget build(BuildContext context) {
    // Sort the section's tiers into store order: bronze, silver, gold.
    final byTier = {
      for (final o in offers) o.tier: o,
    };
    final ordered = [
      for (final t in PackTier.values)
        if (byTier.containsKey(t)) byTier[t]!,
    ];
    final head = ordered.first;
    final scopeLabel =
        head.scopeValue == null ? 'Global Pack' : '${head.scopeValue} Pack';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Shared title: what the section is about plus the pool size,
        // tapping it opens the full contents list of the scope.
        FcmSectionTitle(
          scopeLabel,
          trailing: FcmPill(
            '${head.eligibleCount} PLAYERS',
            color: FcmColors.silver,
          ),
        ),
        SizedBox(
          height: 250,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < ordered.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _StorePackCell(
                    offer: ordered[i],
                    ownedCount: owned[_scopeKey(ordered[i].category.name,
                            ordered[i].scopeValue, ordered[i].tier.name)]
                        ?.length ??
                        0,
                    coins: coins,
                    onTap: () {
                      final ownedHere = owned[_scopeKey(ordered[i].category.name,
                              ordered[i].scopeValue, ordered[i].tier.name)] ??
                          const <Pack>[];
                      if (opening) return;
                      if (ownedHere.isNotEmpty) {
                        onOpen(ownedHere.first.id);
                      } else {
                        onBuy(ordered[i]);
                      }
                    },
                    onInfo: () => onInfo(ordered[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // The shared player strip: the section's common pool, best first.
        _PoolStrip(
          offer: head,
          onLoadPool: onLoadPool,
          onViewAll: onViewAll,
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// The shared obtainable-player strip of one scope: up to 10 mini cards
/// (overall + rarity + surname, no stat rows), best rated first, and a
/// VIEW ALL tail card that opens the full contents list.
class _PoolStrip extends StatelessWidget {
  const _PoolStrip({
    required this.offer,
    required this.onLoadPool,
    required this.onViewAll,
  });

  final StorePackOffer offer;
  final Future<List<BasePlayer>> Function(
      PackCategory category, String? scopeValue) onLoadPool;
  final void Function(StorePackOffer offer) onViewAll;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BasePlayer>>(
      future: onLoadPool(offer.category, offer.scopeValue),
      builder: (context, snapshot) {
        final players = snapshot.data ?? const <BasePlayer>[];
        // Card width shared with the bench strips of the squad screen.
        const cardWidth = SquadCardRow.cardWidth;
        final stripHeight = cardWidth / kPlayerCardAspect + 20;
        return SizedBox(
          height: stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: players.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              if (i == players.length) {
                // VIEW ALL tail: opens the scope's full contents list.
                return FcmPressable(
                  onTap: () => onViewAll(offer),
                  child: Container(
                    width: cardWidth,
                    decoration: BoxDecoration(
                      color: FcmColors.silver.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: FcmColors.silver.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_forward_rounded,
                            color: FcmColors.goldSoft, size: 20),
                        const SizedBox(height: 4),
                        FitText(
                          'VIEW ALL',
                          style: TextStyle(
                            color: FcmColors.goldSoft,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final p = players[i];
              final rarity = CardRarity.fromOverall(p.baseStats.overall);
              return FcmMiniCard(
                overall: p.baseStats.overall,
                position: p.position.code,
                name: p.name.split(' ').last,
                rarity: rarity,
                width: cardWidth,
              );
            },
          ),
        );
      },
    );
  }
}

/// One tier cell of a scope section: the sealed foil pack exactly as it
/// looks before opening (same [FoilPackPainter] as the reveal cinematic),
/// painted in the tier's solid metal — bronze, silver or gold — with the
/// tier name under it, a price slot and one action button. The scope
/// title and player pool live on the section, not the cell. Owned and
/// buyable cells share the exact same layout: the slot shows the
/// FREE ×N pill when the club owns packs of this type, the coin price
/// otherwise; the button reads CLAIM — which opens the next owned pack
/// straight into the reveal, no confirmation — or BUY, which opens the
/// YES/NO purchase dialog. The ⓘ badge opens the pack's contents list.
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
    final tierColor = offer.tier.accent;

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
                          tint: tierColor,
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
            offer.tier.label.toUpperCase(),
            style: TextStyle(
              color: tierColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 3),
          // Price slot: FREE ×N pill for owned packs, coin price otherwise
          // — fixed height so both variants keep one identical layout.
          SizedBox(
            height: 20,
            child: Center(
              child: isFree
                  ? FcmPill('FREE ×$ownedCount')
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          size: 12,
                          color:
                              affordable ? FcmColors.gold : FcmColors.danger,
                        ),
                        const SizedBox(width: 3),
                        FitText(
                          _formatCoins(offer.price),
                          style: TextStyle(
                            color: affordable
                                ? FcmColors.gold
                                : FcmColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 6),
          // CLAIM opens the next owned pack straight into the reveal —
          // no confirmation dialog; BUY opens the YES/NO purchase dialog.
          SizedBox(
            width: double.infinity,
            child: FcmButton(
              compact: true,
              label: isFree ? 'CLAIM' : 'BUY',
              onPressed: onTap,
            ),
          ),
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
