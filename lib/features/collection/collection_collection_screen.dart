import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart' show kPlayerCardAspect;
import '../../features/ads/ad_engine.dart' show AdEngine, AdRewardKind;
import '../../features/economy/economy_engine.dart';
import '../../features/squad/squad_engine.dart';
import '../../features/upgrades/upgrade_engine.dart' show UpgradeEngine;
import 'player_detail_sheet.dart';

enum _Filter { all, gk, def, mid, att }

enum _Sort { overall, newest, value }

/// Collection tab: every owned player as a rarity-coloured card, with
/// filters, sorting, a detail sheet and sell / upgrade / merge actions
/// (GDD 5.7/8.1). Squad members cannot be sold (enforced by the store).
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.overall;

  static const _def = {Position.cb, Position.lb, Position.rb};
  static const _mid = {
    Position.cdm,
    Position.cm,
    Position.cam,
    Position.lm,
    Position.rm
  };
  static const _att = {Position.st, Position.lw, Position.rw};

  bool _matches(PlayerCard c) => switch (_filter) {
        _Filter.all => true,
        _Filter.gk => c.position == Position.gk,
        _Filter.def => _def.contains(c.position),
        _Filter.mid => _mid.contains(c.position),
        _Filter.att => _att.contains(c.position),
      };

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(collectionProvider);
    const economy = EconomyEngine();
    final squad = ref.watch(squadProvider).valueOrNull ?? const {};
    final squadIds = {for (final c in squad.values) c.ownedId};

    return collection.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (cards) {
        if (cards.isEmpty) {
          return const FcmEmptyState(
            icon: Icons.collections_bookmark,
            title: 'Your collection is empty',
            message: 'Open your starting packs to build a squad.',
          );
        }
        // group duplicates by base player id (GDD 5.7 merge)
        final byPlayer = <int, List<PlayerCard>>{};
        for (final c in cards) {
          byPlayer.putIfAbsent(c.base.playerId, () => []).add(c);
        }
        final shown = cards.where(_matches).toList()
          ..sort((a, b) => switch (_sort) {
                _Sort.overall => b.overall.compareTo(a.overall),
                _Sort.newest => b.ownedId.compareTo(a.ownedId),
                _Sort.value =>
                  b.base.marketValueEur.compareTo(a.base.marketValueEur),
              });

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FitText(
                            '${cards.length} players',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                        _SortMenu(
                          value: _sort,
                          onChanged: (v) => setState(() => _sort = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final f in _Filter.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(switch (f) {
                                  _Filter.all => 'All',
                                  _Filter.gk => 'GK',
                                  _Filter.def => 'DEF',
                                  _Filter.mid => 'MID',
                                  _Filter.att => 'ATT',
                                }),
                                selected: _filter == f,
                                showCheckmark: false,
                                onSelected: (_) {
                                  fcmTick();
                                  setState(() => _filter = f);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (shown.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: FcmEmptyState(
                  icon: Icons.filter_alt_off,
                  title: 'No players here yet',
                  message: 'Try another filter.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverGrid.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    childAspectRatio: kPlayerCardAspect * 0.88,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final card = shown[i];
                    final copies =
                        byPlayer[card.base.playerId]?.length ?? 1;
                    final dupes =
                        byPlayer[card.base.playerId] ?? const <PlayerCard>[];
                    final inSquad = squadIds.contains(card.ownedId);
                    return FcmEntrance(
                      index: i % 6,
                      child: _GridCard(
                        card: card,
                        copies: copies,
                        inSquad: inSquad,
                        onTap: () => _openDetail(
                            context, economy, card, dupes, inSquad),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  void _openDetail(BuildContext context, EconomyEngine economy,
      PlayerCard card, List<PlayerCard> dupes, bool inSquad) {
    final sellPrice =
        economy.sellPriceOfUpgraded(card.base, card.upgradeLevel);
    final upgradeCost = card.upgradeLevel < UpgradeEngine.maxUpgradeLevel
        ? economy.upgradeCostOf(card.base, card.upgradeLevel)
        : null;
    final other = dupes.where((d) => d.ownedId != card.ownedId);
    showPlayerDetail(
      context,
      card: card,
      inSquad: inSquad,
      copies: dupes.length,
      actions: PlayerDetailActions(
        upgradeLabel: upgradeCost == null
            ? null
            : 'Upgrade · ${formatCoins(upgradeCost)} coins',
        onUpgrade: upgradeCost != null
            ? () => _upgrade(context, ref, card)
            : null,
        onMerge: other.isNotEmpty
            ? () => _merge(context, ref, card, other.first)
            : null,
        sellLabel: 'Sell · ${formatCoins(sellPrice)} coins',
        onSell: () => _sell(context, ref, card),
      ),
    );
  }

  Future<void> _sell(BuildContext context, WidgetRef ref, PlayerCard card) async {
    // GDD 19.3 'Player selling bonus': offer the ad before the sale so
    // the boosted price is the one confirmed. Optional, skippable.
    final ads = await ref.read(adStoreProvider.future);
    final club = await ref.read(clubProvider.future);
    final canBoost = club != null &&
        await ads.remainingToday(club.id, AdRewardKind.sellingBonus) > 0;
    var bonusWatched = false;
    if (canBoost) {
      if (!context.mounted) return;
      bonusWatched = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Boost this sale?'),
              content: const Text(
                  'Watch a rewarded ad to add +20% to the selling price of '
                  'this sale. Ads are always optional.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('No thanks')),
                FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Watch ad')),
              ],
            ),
          ) ??
          false;
      if (bonusWatched) {
        try {
          await ads.grantBoost(
            clubId: club.id,
            kind: AdRewardKind.sellingBonus,
            playbackCompleted: true,
          );
        } catch (_) {
          bonusWatched = false;
        }
      }
    }
    if (!context.mounted) return;

    final price = _price(card);
    final boostedPrice =
        bonusWatched ? const AdEngine().sellingBonus(price) : price;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sell player?'),
        content: Text(
            '${card.base.name} will be sold for ${formatCoins(boostedPrice)} coins. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sell')),
        ],
      ),
    );
    if (confirmed != true) return;
    final store = await ref.read(collectionStoreProvider.future);
    try {
      final result = await store.sellPlayers([card.ownedId]);
      ref.invalidate(collectionProvider);
      ref.invalidate(clubProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Sold for ${formatCoins(result.credit)} coins')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  int _price(PlayerCard card) => EconomyEngine()
      .sellPriceOfUpgraded(card.base, card.upgradeLevel);

  /// Buys one upgrade level with coins (GDD 8.4). When the user has
  /// watched an upgrade-discount ad (GDD 19.3) the dialog shows the
  /// discounted price; the store charges and consumes it.
  Future<void> _upgrade(BuildContext context, WidgetRef ref, PlayerCard card) async {
    const economy = EconomyEngine();
    final store = await ref.read(collectionStoreProvider.future);
    final club = await ref.read(clubProvider.future);
    if (club == null) return;
    if (!context.mounted) return;
    final ads = await ref.read(adStoreProvider.future);
    final fullCost =
        economy.upgradeCostOf(card.base, card.upgradeLevel);
    final discounted = await ads.upgradeDiscountActive(club.id);
    final price = discounted
        ? const AdEngine().discountedUpgradeCost(fullCost)
        : fullCost;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upgrade ${card.base.name}?'),
        content: Text(
            'Next level: +${card.upgradeLevel + 1}\n'
            'Cost: ${formatCoins(price)} coins'
            '${discounted ? ' (ad discount applied)' : ''}\n'
            'Balance: ${formatCoins(club.coins)} coins'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Upgrade')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result = await store.buyUpgrade(
        ownedId: card.ownedId,
        random: ref.read(randomProvider),
      );
      ref.invalidate(collectionProvider);
      ref.invalidate(clubProvider);
      ref.invalidate(squadProvider);
      if (context.mounted) {
        final gains = result.upgradeLevel;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${card.base.name} upgraded to +$gains for ${formatCoins(result.coins)} coins')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _merge(BuildContext context, WidgetRef ref,
      PlayerCard target, PlayerCard duplicate) async {
    final store = await ref.read(collectionStoreProvider.future);
    final random = ref.read(randomProvider);
    try {
      final result = await store.mergeDuplicates(
        targetOwnedId: target.ownedId,
        duplicateOwnedId: duplicate.ownedId,
        random: random,
      );
      ref.invalidate(collectionProvider);
      ref.invalidate(squadProvider);
      if (context.mounted) {
        final gains = result.attributeGain.entries
            .map((e) => '+${e.value} ${e.key.name}')
            .join(', ');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${target.base.name} upgraded to +${result.newUpgradeLevel}'
                '${gains.isEmpty ? '' : ' ($gains)'}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

/// One card in the grid with its copy count and squad marker.
class _GridCard extends StatelessWidget {
  const _GridCard({
    required this.card,
    required this.copies,
    required this.inSquad,
    required this.onTap,
  });

  final PlayerCard card;
  final int copies;
  final bool inSquad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarity = rarityOf(card);
    return FcmPressable(
      onTap: onTap,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: Align(
                alignment: Alignment.topCenter,
                child: ownedCardView(
                  card,
                  width: w,
                  glow: rarity == CardRarity.legendary ? 0.35 : 0,
                ),
              ),
            ),
            if (copies >= 2)
              Positioned(
                left: -4,
                bottom: 22,
                child: FcmPill('×$copies', color: FcmColors.royal),
              ),
            if (inSquad)
              const Positioned(
                right: -4,
                bottom: 22,
                child: FcmPill('XI', color: FcmColors.success),
              ),
          ],
        );
      }),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final _Sort value;
  final ValueChanged<_Sort> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Sort>(
      tooltip: 'Sort',
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem(value: _Sort.overall, child: Text('Highest rating')),
        PopupMenuItem(value: _Sort.newest, child: Text('Newest first')),
        PopupMenuItem(value: _Sort.value, child: Text('Market value')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18, color: FcmColors.gold),
            const SizedBox(width: 6),
            Text(
              switch (value) {
                _Sort.overall => 'Rating',
                _Sort.newest => 'Newest',
                _Sort.value => 'Value',
              },
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
