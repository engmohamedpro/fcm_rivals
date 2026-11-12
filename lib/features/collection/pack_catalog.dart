/// FCM Rivals — pack catalog (extracted from
/// `collection_store.dart`, app-structure review task
/// `2026-11-05_app-structure_split-collection-results-catalog`):
/// builds the store's buyable position-pack offers with their
/// Economy-Engine-derived prices over the player registry.
/// Pure relocation of `getStoreOffers`' building logic.
library;


import '../../core/domain/players.dart';
import '../../core/ui/card_rarity.dart';
import '../economy/economy_engine.dart';
import '../packs/pack_engine.dart';
import '../player_database/player_database.dart';
import 'collection_results.dart';

/// Builds every position-pack offer for the store (GDD 5.5): one offer
/// per (position, tier) whose pool actually contains a card of that
/// tier's rarity — no legendary section for a pool that cannot draw
/// one. Prices come from the Economy Engine's expected-contents
/// formula via [PackEngine.packPriceFor].
///
/// Perf pass 2026-11-12: [engine] and [pool] are now INJECTED by the
/// caller (one long-lived engine + one stored pool snapshot, see
/// [CollectionStore._engineFor]) so the engine's identity-keyed band
/// cache survives across the ~39 offers this builds — before, each
/// offer constructed its own engine and filtered its own pool list,
/// re-sorting the full registry 39x per shelf render. The optional
/// parameters keep direct/test call sites working with a one-shot
/// engine (their pools are small).
List<StorePackOffer> storeOffersFor(
  PlayerDatabase registry,
  EconomyEngine economy, {
  PackEngine? engine,
  List<BasePlayer>? pool,
}) {
  final sharedEngine = engine ?? PackEngine(economy: economy);
  final poolRef = pool ?? registry.all.toList(growable: false);

  CardRarity rarityOf(PackTier tier) => switch (tier) {
      PackTier.rare => CardRarity.rare,
      PackTier.epic => CardRarity.epic,
      PackTier.legendary => CardRarity.legendary,
      // Icon tiers draw regulars of the epic/legendary/premium bands —
      // the shelf's rarity check reads the same three classes.
      PackTier.iconEpic => CardRarity.epic,
      PackTier.iconLegendary => CardRarity.legendary,
      PackTier.iconSupreme => CardRarity.legendary,
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
    final eligible = poolRef.where(scope.matches).toList(growable: false);
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
      price: sharedEngine.packPriceFor(scope, eligible),
      eligibleCount: eligible.length,
    );
  }

    final offers = <StorePackOffer>[];

    // The Icon section (owner request 2026-11-12): three packs ABOVE
    // the ST packs — pack 1 epic + icons, pack 2 epic/legendary +
    // icons, pack 3 epic/legendary/premium + icons, each carrying its
    // tier's tiny icon chance. Shelves only when the registry actually
    // holds icons (the tm-bundle dataset); an icon-less registry keeps
    // the store exactly as it was.
    final hasIcons = poolRef.any((p) => p.isIcon);
    if (hasIcons) {
      const iconTiers = [
        PackTier.iconEpic,
        PackTier.iconLegendary,
        PackTier.iconSupreme,
      ];
      for (final tier in iconTiers) {
        final scope = PackScope(category: PackCategory.icon, tier: tier);
        final eligible = poolRef.where(scope.matches).toList(growable: false);
        if (eligible.isEmpty) continue;
        offers.add(StorePackOffer(
          category: PackCategory.icon,
          title: '${tier.label} Pack',
          scopeValue: null,
          tier: tier,
          price: sharedEngine.packPriceFor(scope, eligible),
          eligibleCount: eligible.length,
        ));
      }
    }

    for (final position in Position.values) {
      for (final tier in PackTier.values) {
        if (tier.isIconTier) {
          continue; // icon tiers shelf in their own section
        }
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
