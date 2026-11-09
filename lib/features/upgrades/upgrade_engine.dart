/// FCM Rivals — Upgrade Engine (GDD 8, FR-014).
///
/// Duplicate merging progression. Pure Dart; all economy costs are
/// charged by the Economy Engine at the store layer (GDD 8.4).
library;

/// Immutable result of one duplicate merge.
class MergeOutcome {
  const MergeOutcome({required this.newUpgradeLevel});

  /// Target level after the merge (GDD 8.1 progression, owner decision
  /// 2026-11-09: levels are unlimited — no cap, no attribute points).
  final int newUpgradeLevel;
}

/// Merging rules (GDD 8.1, owner decision 2026-11-09):
/// - base + base → +1
/// - +1 + base → +2
/// - newLevel = targetLevel + duplicateLevel + 1
/// - each level is worth +1% of the base overall and all four base
///   attributes via `upgradedValue` — unlimited levels, no 99 cap, and
///   merging stays free (the Economy Engine prices only coin upgrades).
class UpgradeEngine {
  const UpgradeEngine();

  /// Level resulting from merging [duplicateLevel] into [targetLevel].
  int mergedLevel(int targetLevel, int duplicateLevel) =>
      targetLevel + duplicateLevel + 1;

  /// Whether two owned copies of the same player can be merged. Always
  /// true by level alone — levels are unlimited (owner decision
  /// 2026-11-09); the store still guards same-player/owned-state.
  bool canMerge({required int targetLevel, required int duplicateLevel}) =>
      true;

  /// Full merge outcome: the new level (the +N% stat math is derived
  /// everywhere from the level via `upgradedValue` — nothing random
  /// remains, so no Random is needed and results are fully
  /// deterministic).
  MergeOutcome merge({
    required int targetLevel,
    required int duplicateLevel,
  }) =>
      MergeOutcome(newUpgradeLevel: mergedLevel(targetLevel, duplicateLevel));
}
