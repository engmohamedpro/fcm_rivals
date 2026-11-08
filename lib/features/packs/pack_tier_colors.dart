/// FCM Rivals — pack tier presentation colours (GDD 5.3, T-0059/T-0060).
///
/// Presentation-layer extension split out of `pack_engine.dart` so the
/// draw engine itself stays pure Dart (no Flutter imports) and can run
/// under plain `dart run` — the T-0060 probability probe and headless
/// batch sims import the engine without pulling the framework in. The
/// widgets that tint packs by tier import this file alongside the
/// engine; nothing else changed.
library;

import 'package:flutter/material.dart' show Color;

import 'pack_engine.dart' show PackTier;

/// Pack-rarity accent colours — the same jewel palette as the player-card
/// rarities ([CardRarity.accent]): rare → royal amethyst, epic → royal
/// sapphire, legendary → radiant champion gold. Cells, badges and foils
/// draw from these so a pack's rarity reads at a glance and matches the
/// cards it draws.
extension PackTierColor on PackTier {
  Color get accent => switch (this) {
    PackTier.rare => const Color(0xFF8B5CF6),
    PackTier.epic => const Color(0xFF3B82F6),
    PackTier.legendary => const Color(0xFFF7C948),
  };

  /// Rarity stars stamped on the foil: rare 3, epic 4, legendary 5 —
  /// the shelf and the reveal agree on the count.
  int get stars => switch (this) {
    PackTier.rare => 3,
    PackTier.epic => 4,
    PackTier.legendary => 5,
  };
}
