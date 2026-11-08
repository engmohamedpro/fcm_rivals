/// FCM Rivals — card rarity partition (GDD 5.3, T-0047/T-0059).
///
/// Data-only split out of `fcm_style.dart` (T-0060): the pure economy
/// chain (`pack_catalog.dart`, the pack engine audit tests) needs the
/// OVR→rarity mapping WITHOUT the Flutter-tinted style file, so the
/// whole collection/economy closure stays runnable under plain
/// `dart run` (the T-0060 probability probe and economy soak). The
/// colour gradient presentation stays in `fcm_style.dart`, which
/// re-exports this enum for its existing importers.
library;

/// The card rarity partition shared by the pack reveal, the collection
/// and the squad: rare, epic and legendary — one rarity language shared
/// with the store's pack tiers. Higher rarity gets bigger reveal
/// effects (GDD 5.6).
enum CardRarity {
  rare,
  epic,
  legendary;

  /// Rating thresholds: 80+ legendary (the owner's 2026-11-07 regrade,
  /// T-0047 — every player rated 80+ shows the golden legendary colour in
  /// every surface), 70+ epic, otherwise rare.
  static CardRarity fromOverall(int overall) {
    if (overall >= 80) return CardRarity.legendary;
    if (overall >= 70) return CardRarity.epic;
    return CardRarity.rare;
  }

  String get label => switch (this) {
    CardRarity.rare => 'RARE',
    CardRarity.epic => 'EPIC',
    CardRarity.legendary => 'LEGENDARY',
  };
}
