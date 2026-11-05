/// FCM Rivals — pack catalog (extracted from
/// `collection_store.dart`, app-structure review task
/// `2026-11-05_app-structure_split-collection-results-catalog`):
/// builds the store's buyable position-pack offers with their
/// Economy-Engine-derived prices over the player registry.
/// Pure relocation of `getStoreOffers`' building logic.
library;

import 'dart:math' as math;

import '../../core/domain/players.dart';
import '../../core/ui/fcm_style.dart' show CardRarity;
import '../economy/economy_engine.dart';
import '../packs/pack_engine.dart';
import '../player_database/player_database.dart';
import 'collection_results.dart';

/// Builds every position-pack offer for the store (GDD 5.5): one offer
/// per (position, tier) whose pool actually contains a card of that
/// tier's rarity — no legendary section for a pool that cannot draw
/// one. Prices come from the Economy Engine's expected-contents
/// formula via [PackEngine.packPriceFor].
List<StorePackOffer> storeOffersFor(PlayerDatabase registry, EconomyEngine economy) {
    final pool = registry.all.toList(growable: false);

    CardRarity rarityOf(PackTier tier) => switch (tier) {
      PackTier.rare => CardRarity.rare,
      PackTier.epic => CardRarity.epic,
      PackTier.legendary => CardRarity.legendary,
    };

    StorePackOffer? offerFor(
      PackCategory category,
      String? scopeValue,
      PackTier tier,
      String baseTitle,
    ) {
      final scope = PackScope(
        category: category,
        position: category == PackCategory.position && scopeValue != null
            ? Position.fromCode(scopeValue)
            : null,
        tier: tier,
      );
      final eligible = pool.where(scope.matches).toList(growable: false);
      if (!eligible.any(
        (p) => CardRarity.fromOverall(p.baseStats.overall) == rarityOf(tier),
      )) {
        return null;
      }
      return StorePackOffer(
        category: category,
        title: '${tier.label} $baseTitle',
        scopeValue: scopeValue,
        tier: tier,
        price: PackEngine(
          random: math.Random(0),
          economy: economy,
        ).packPriceFor(scope, eligible),
        eligibleCount: eligible.length,
      );
    }

    final offers = <StorePackOffer>[];
    for (final position in Position.values) {
      for (final tier in PackTier.values) {
        final offer = offerFor(
          PackCategory.position,
          position.code,
          tier,
          '${position.code} Position Pack',
        );
        if (offer != null) offers.add(offer);
      }
    }
    return offers;
}
