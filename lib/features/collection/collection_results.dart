/// FCM Rivals — collection result models (extracted from
/// `collection_store.dart`, app-structure review task
/// `2026-11-05_app-structure_split-collection-results-catalog`):
/// the facade's exception type and the result snapshots its
/// operations return. Pure relocation.
library;

import '../../core/domain/players.dart';
import '../packs/pack_engine.dart';
import '../player_database/player_database.dart' show ImportResult;

/// Thrown when an operation would leave persistent state inconsistent.
class CollectionException implements Exception {
  const CollectionException(this.message);
  final String message;

  @override
  String toString() => 'CollectionException: $message';
}

/// The players drawn from one opened pack, in reveal order.
class PackOpenResult {
  const PackOpenResult({
    required this.players,
    this.tiers = const [],
    this.ownedIds = const [],
  });

  /// Drawn players (one per pack).
  final List<BasePlayer> players;

  /// The ROLLED rarity band each player was drawn under, as the
  /// [PackRarity] index (0 rare < 70, 1 epic 70-79, 2 legendary 80-89,
  /// 3 premium 90+), index-aligned with [players]. Drives reveal effects
  /// (GDD 5.6). T-0059: the old low/mid/high Market-Value tier indices
  /// are gone — the two-stage engine rolls rarity, not MV bands.
  final List<int> tiers;

  /// Owned-player row ids of the drawn players, index-aligned with
  /// [players] — the handle for sell- straight-from-the-reveal.
  final List<int> ownedIds;
}

/// One buyable pack in the store (GDD 5.5): category, scope, store tier
/// and the Economy-Engine-derived coin price.
class StorePackOffer {
  const StorePackOffer({
    required this.category,
    required this.title,
    required this.scopeValue,
    required this.tier,
    required this.price,
    required this.eligibleCount,
  });

  final PackCategory category;

  /// Store tier: bronze / silver / gold odds variety (GDD 5.5).
  final PackTier tier;

  /// Display title, e.g. 'ST Position Pack'.
  final String title;

  /// Scope filter value (position code), null for the global pack.
  final String? scopeValue;

  /// Coin price from `PackEngine.packPriceFor`.
  final int price;

  /// Number of eligible players in the pool.
  final int eligibleCount;
}

/// Players sold back to the system with the total credit.
class SaleResult {
  const SaleResult({required this.soldOwnedIds, required this.credit});

  final List<int> soldOwnedIds;
  final int credit;
}

/// One merged duplicate outcome.
class MergeResult {
  const MergeResult({
    required this.targetOwnedId,
    required this.duplicateOwnedId,
    required this.newUpgradeLevel,
    required this.attributeGain,
  });

  final int targetOwnedId;
  final int duplicateOwnedId;
  final int newUpgradeLevel;
  final Map<PlayerAttribute, int> attributeGain;
}

/// Removed-player compensation entry (GDD 4.8 step 6: notify with name).
class RemovalCompensation {
  const RemovalCompensation({
    required this.playerName,
    required this.upgradeLevel,
    required this.coins,
  });

  final String playerName;
  final int upgradeLevel;
  final int coins;
}

/// Result of applying a dataset update to the persisted world.
class DatasetUpdateReport {
  const DatasetUpdateReport({
    required this.importResult,
    required this.compensations,
  });

  final ImportResult importResult;
  final List<RemovalCompensation> compensations;

  int get totalCompensation => compensations.fold(0, (a, c) => a + c.coins);
}

/// Result of buying one upgrade level with coins (GDD 8.4).
class UpgradePurchaseResult {
  const UpgradePurchaseResult({
    required this.ownedId,
    required this.playerName,
    required this.upgradeLevel,
    required this.coins,
    required this.fullCost,
    required this.discountApplied,
  });

  final int ownedId;
  final String playerName;
  final int upgradeLevel;

  /// Coins actually charged (the discounted price when an ad discount
  /// applied).
  final int coins;

  /// Undiscounted Economy Engine price.
  final int fullCost;

  /// Whether the GDD 19.3 ad discount was applied (and consumed).
  final bool discountApplied;
}
