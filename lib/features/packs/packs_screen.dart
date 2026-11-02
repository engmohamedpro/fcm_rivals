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
import 'pack_opening_screen.dart';

/// Packs tab: the store (GDD 5.5). Shows the club's free unopened packs —
/// with their count and the total earned so far — above the buyable pack
/// list, every offer with its coin price from the Economy Engine.
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
          data: (packs) => _StoreList(
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
            const SnackBar(content: Text('Pack added — open it below')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.replaceFirst('CollectionException: ', ''))));
      }
    }
  }
}

/// The store list: free packs section, then every buyable offer.
class _StoreList extends StatelessWidget {
  const _StoreList({
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
    // Fixed: header, ad card, store header. Then one row per free pack,
    // then one row per buyable offer.
    final fixedRows = 3;
    return ListView.builder(
      // Build a generous window so a screenful of rows is always ready.
      cacheExtent: 900,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      itemCount: fixedRows + packs.length + offers.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _FreeSectionHeader(count: packs.length);
        }
        if (index == 1) {
          return const FcmEntrance(index: 1, child: _FreePackAdCard());
        }
        final packIndex = index - 2;
        if (packIndex < packs.length) {
          final pack = packs[packIndex];
          final position = pack.scopeValue != null
              ? Position.fromCode(pack.scopeValue!)
              : null;
          return FcmEntrance(
            index: packIndex,
            dx: 24,
            dy: 0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PackRow(
                label: position?.code ?? 'G',
                title: position != null
                    ? '${position.code} Position Pack'
                    : 'Global Pack',
                onTap: opening ? null : () => onOpen(pack.id),
              ),
            ),
          );
        }
        if (packIndex == packs.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 10),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded,
                    color: FcmColors.gold, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: FitText('BUY PACKS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      )),
                ),
              ],
            ),
          );
        }
        final offerIndex = packIndex - packs.length - 1;
        final offer = offers[offerIndex];
        return FcmEntrance(
          index: offerIndex,
          dx: 20,
          dy: 0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _StoreOfferRow(
              offer: offer,
              coins: coins,
              onBuy: () => onBuy(offer),
            ),
          ),
        );
      },
    );
  }
}

/// 'FREE PACKS (n/total)' header with the club's unopened pack count and
/// the total free packs earned since the club was founded.
class _FreeSectionHeader extends ConsumerWidget {
  const _FreeSectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(totalFreePacksProvider).valueOrNull ?? 0;
    return FcmEntrance(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            const Icon(Icons.inventory_2_rounded,
                color: FcmColors.gold, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: FitText(
                count == 0
                    ? 'FREE PACKS · $total opened'
                    : 'FREE PACKS · $count of $total to open',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            FcmPill(
              '$count',
              color: count > 0 ? FcmColors.gold : FcmColors.silver,
              filled: count > 0,
            ),          ],
        ),
      ),
    );
  }
}

/// One unopened free pack: foil icon, title and an OPEN pill.
class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.label,
    required this.title,
    required this.onTap,
  });

  final String label;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          _MiniPack(label: label),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FitText(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text(
                  '1 player · low, medium or high value tier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: FcmColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const FcmPill('OPEN'),
        ],
      ),
    );
  }
}

/// One buyable pack offer (GDD 5.5): title, eligible pool size and the
/// coin price. Disabled with a hint when the balance is too low.
class _StoreOfferRow extends StatelessWidget {
  const _StoreOfferRow({
    required this.offer,
    required this.coins,
    required this.onBuy,
  });

  final StorePackOffer offer;
  final int? coins;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final affordable = coins == null || coins! >= offer.price;
    return FcmPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      accent: affordable ? null : FcmColors.danger,
      onTap: onBuy,
      child: Row(
        children: [
          _MiniPack(
              label: offer.scopeValue ?? 'G',
              tint: FcmColors.steelGradient),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FitText(offer.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  '${offer.eligibleCount} eligible players · 1 draw',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: FcmColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: FcmColors.gold, size: 16),
                  const SizedBox(width: 4),
                  FitText(_formatCoins(offer.price),
                      style: const TextStyle(
                          color: FcmColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w900)),
                ],
              ),
              if (!affordable) ...[
                const SizedBox(height: 2),
                const Text('Not enough coins',
                    style: TextStyle(
                        color: FcmColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ],
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
          padding: const EdgeInsets.only(bottom: 12, top: 4),
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
      ref.invalidate(totalFreePacksProvider);
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

/// Tiny foil-pack icon for the pack list. [tint] switches between the
/// golden free packs and the steel store offers.
class _MiniPack extends StatelessWidget {
  const _MiniPack({required this.label, this.tint = FcmColors.goldGradient});

  final String label;
  final Gradient tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A342C), Color(0xFF141419)],
        ),
        border: Border.all(color: FcmColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: FcmColors.bronze.withValues(alpha: 0.55), blurRadius: 10),
        ],
      ),
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(gradient: tint),
        child: FitText(label,
            align: Alignment.center,
            style: const TextStyle(
                color: FcmColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
      ),
    );
  }
}
