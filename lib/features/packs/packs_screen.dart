import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart' show Pack;
import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../features/ads/ad_engine.dart' show AdRewardKind;
import '../../features/collection/collection_store.dart' show StorePackOffer;
import '../../features/packs/pack_engine.dart' show PackCategory;
import 'pack_effects.dart' show FoilPackPainter, kPackAspect;
import 'pack_opening_screen.dart';

/// Packs tab — the store (GDD 5.5): ONE grid of packs, every cell drawn as
/// the sealed foil pack the player later sees in the opening cinematic.
/// Owned (free) packs of a type show a FREE ×N pill in place of the price;
/// otherwise the cell shows the coin price from the Economy Engine.
/// Tapping a cell opens the next owned pack, or buys one when none are
/// left — free and bought packs live side by side, never separated.
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
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PackOpeningScreen(players: result.players),
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

  Future<void> _buy(BuildContext context, StorePackOffer offer) async {
    try {
      final store = await ref.read(collectionStoreProvider.future);
      await store.buyPack(
        category: offer.category,
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

/// Scope key shared by owned packs and store offers, e.g. 'global' or
/// 'position:ST' — the join between inventory and grid cell.
String _scopeKey(String category, String? scopeValue) =>
    scopeValue == null ? category : '$category:$scopeValue';

/// The store grid: rewarded-ad offer on top, then every pack cell.
class _StoreGrid extends StatelessWidget {
  const _StoreGrid({
    required this.packs,
    required this.offers,
    required this.coins,
    required this.opening,
    required this.onOpen,
    required this.onBuy,
  });

  final List<Pack> packs;
  final List<StorePackOffer> offers;
  final int? coins;
  final bool opening;
  final void Function(int packId) onOpen;
  final void Function(StorePackOffer offer) onBuy;

  @override
  Widget build(BuildContext context) {
    // Owned unopened packs grouped by scope: their count replaces the
    // price on the matching cell (free packs, GDD 5.8).
    final owned = <String, List<Pack>>{};
    for (final p in packs) {
      owned.putIfAbsent(_scopeKey(p.category, p.scopeValue), () => []).add(p);
    }
    // Wide screens (the app clamps at 820) get more columns so cells
    // keep phone-like proportions.
    final columns = MediaQuery.of(context).size.width >= 700 ? 5 : 3;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      children: [
        const FcmEntrance(index: 0, child: _FreePackAdCard()),
        const SizedBox(height: 8),
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
                final ownedHere =
                    owned[_scopeKey(offer.category.name, offer.scopeValue)] ??
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
/// opening (same [FoilPackPainter] as the reveal cinematic), a scope
/// badge, the title, and under it either the coin price or — when the
/// club owns packs of this type — a FREE ×N pill in its place.
class _StorePackCell extends StatelessWidget {
  const _StorePackCell({
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
    final isFree = ownedCount > 0;
    final affordable = coins == null || coins! >= offer.price;
    final scopeLabel = offer.scopeValue ?? 'ANY';
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
                          glowColor: FcmColors.gold,
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
                                color: FcmColors.gold.withValues(alpha: 0.7)),
                          ),
                          child: Text(
                            scopeLabel,
                            style: const TextStyle(
                              color: FcmColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
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
          const SizedBox(height: 3),
          if (isFree)
            FcmPill('FREE ×$ownedCount')
          else
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

/// Rewarded-ad free pack offer (GDD 19.3 'Free user-selected pack'):
/// one global pack per day for one completed ad. Always optional.
class _FreePackAdCard extends ConsumerStatefulWidget {
  const _FreePackAdCard();

  @override
  ConsumerState<_FreePackAdCard> createState() => _FreePackAdCardState();
}

class _FreePackAdCardState extends ConsumerState<_FreePackAdCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<AdRewardKind?>(
      future: _adAvailable(),
      builder: (context, snapshot) {
        final available = snapshot.data != null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 4),
          child: Opacity(
            opacity: available ? 1 : 0.6,
            child: FcmPanel(
              accent: available ? FcmColors.gold : null,
              glow: available,
              onTap: available && !_busy ? _claim : null,
              child: Row(
                children: [
                  const FcmIconBadge(
                      icon: Icons.play_arrow_rounded, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FitText('Free pack — watch an ad',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          available
                              ? 'One global pack (1 player) for a completed rewarded ad'
                              : 'Already claimed today · ads are always optional',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: FcmColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  if (_busy)
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Non-null when the free-pack ad is still available today.
  Future<AdRewardKind?> _adAvailable() async {
    final ads = await ref.read(adStoreProvider.future);
    final club = await ref.read(clubProvider.future);
    if (club == null) return null;
    return await ads.remainingToday(club.id, AdRewardKind.freePack) > 0
        ? AdRewardKind.freePack
        : null;
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final ads = await ref.read(adStoreProvider.future);
      final club = await ref.read(clubProvider.future);
      if (club == null) return;
      // Playback is simulated in v1; the store validates completion.
      await ads.grantFreePack(
        clubId: club.id,
        category: PackCategory.global,
        playbackCompleted: true,
      );
      ref.invalidate(availablePacksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Free pack added to your packs')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad reward unavailable')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
