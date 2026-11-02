import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../features/ads/ad_engine.dart' show AdEngine, AdRewardKind;
import '../../features/economy/economy_engine.dart';
import '../../features/squad/squad_engine.dart';
import '../../features/upgrades/upgrade_engine.dart' show UpgradeEngine;

/// Collection tab: owned players with sell and duplicate-merge actions
/// (GDD 5.7/8.1). Squad members cannot be sold (enforced by the store).
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider);
    const economy = EconomyEngine();

    return collection.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (cards) {
        if (cards.isEmpty) {
          return const Center(
              child: Text('Open your starting packs to build a squad.'));
        }
        // group duplicates by base player id (GDD 5.7 merge)
        final byPlayer = <int, List<PlayerCard>>{};
        for (final c in cards) {
          byPlayer.putIfAbsent(c.base.playerId, () => []).add(c);
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final card = cards[index];
            final duplicates =
                byPlayer[card.base.playerId] ?? const <PlayerCard>[];
            final sellPrice = economy.sellPriceOfUpgraded(
                card.base, card.upgradeLevel);
            final upgradeCost = card.upgradeLevel < UpgradeEngine.maxUpgradeLevel
                ? economy.upgradeCostOf(card.base, card.upgradeLevel)
                : null;
            return _CollectionTile(
              card: card,
              duplicateCount: duplicates.length,
              sellPrice: sellPrice,
              upgradeCost: upgradeCost,
              onSell: () => _sell(context, ref, card),
              onUpgrade: upgradeCost != null
                  ? () => _upgrade(context, ref, card)
                  : null,
              onMerge: duplicates.length >= 2
                  ? () => _merge(context, ref, duplicates[0], duplicates[1])
                  : null,
              inSquad: squadContains(ref, card),
            );
          },
        );
      },
    );
  }

  bool squadContains(WidgetRef ref, PlayerCard card) {
    final squad = ref.watch(squadProvider).valueOrNull ?? const {};
    return squad.values.any((c) => c.ownedId == card.ownedId);
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

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.card,
    required this.duplicateCount,
    required this.sellPrice,
    required this.upgradeCost,
    required this.onSell,
    required this.onUpgrade,
    required this.onMerge,
    required this.inSquad,
  });

  final PlayerCard card;
  final int duplicateCount;
  final int sellPrice;
  final int? upgradeCost;
  final VoidCallback onSell;
  final VoidCallback? onUpgrade;
  final VoidCallback? onMerge;
  final bool inSquad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = card.base.baseStats;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: card.upgradeLevel > 0
              ? Colors.amber.shade800
              : theme.colorScheme.primaryContainer,
          child: Text('${card.overall}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        title: Row(
          children: [
            Flexible(
                child: Text(card.base.name,
                    overflow: TextOverflow.ellipsis)),
            if (card.upgradeLevel > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('+${card.upgradeLevel}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white)),
              ),
            ],
            if (duplicateCount >= 2) ...[
              const SizedBox(width: 6),
              Text('×$duplicateCount',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ],
          ],
        ),
        subtitle: Text(
          '${card.position.code} · ${card.base.age}y · ${card.base.nationality} · '
          '${card.base.club}\n'
          'ATT ${stats.attack + card.upgradedAttack} · '
          'SUP ${stats.support + card.upgradedSupport} · '
          'DEF ${stats.defence + card.upgradedDefence} · '
          'GK ${stats.goalkeeping + card.upgradedGoalkeeping}'
          '${inSquad ? ' · in squad' : ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'sell') onSell();
            if (v == 'merge') onMerge?.call();
            if (v == 'upgrade') onUpgrade?.call();
          },
          itemBuilder: (context) => [
            if (onUpgrade != null)
              PopupMenuItem(
                  value: 'upgrade',
                  child: Text(
                      'Upgrade · ${formatCoins(upgradeCost!)} coins')),
            PopupMenuItem(
                value: 'sell',
                child: Text('Sell · ${formatCoins(sellPrice)} coins')),
            if (onMerge != null)
              const PopupMenuItem(
                  value: 'merge', child: Text('Merge duplicate (+1)')),
          ],
        ),
      ),
    );
  }
}
