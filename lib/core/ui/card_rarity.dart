/// FCM Rivals — card rarity partition (GDD 5.3, T-0047/T-0059).
library;

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
