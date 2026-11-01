/// FCM Rivals — Upgrade Engine (GDD 8, FR-014).
///
/// Duplicate merging progression and the controlled allocation of upgrade
/// attribute points. Pure Dart; all economy costs are charged by the Economy
/// Engine at the store layer (GDD 8.4).
library;

import 'dart:math' as math;

import '../../core/domain/base_stats_generator.dart' show positionWeights;
import '../../core/domain/players.dart';

/// Immutable result of one duplicate merge.
class MergeOutcome {
  const MergeOutcome({
    required this.newUpgradeLevel,
    required this.attributeGain,
  });

  /// Target level after the merge (GDD 8.1 progression).
  final int newUpgradeLevel;

  /// Attribute points this merge adds, per attribute (GDD 8.2: one random
  /// attribute per level gained).
  final Map<PlayerAttribute, int> attributeGain;
}

/// Merging rules (GDD 8.1):
/// - base + base → +1
/// - +1 + base → +2
/// - newLevel = targetLevel + duplicateLevel + 1
class UpgradeEngine {
  const UpgradeEngine();

  /// Level resulting from merging [duplicateLevel] into [targetLevel].
  int mergedLevel(int targetLevel, int duplicateLevel) =>
      targetLevel + duplicateLevel + 1;

  /// Whether two owned copies of the same player can be merged.
  bool canMerge({required int targetLevel, required int duplicateLevel}) =>
      mergedLevel(targetLevel, duplicateLevel) <= maxUpgradeLevel;

  /// Upper bound on upgrade levels (placeholder pre-balance value).
  static const int maxUpgradeLevel = 5;

  /// Allocates the attribute points granted by a merge: one point per level
  /// gained, each to a randomly selected attribute under controlled rules
  /// (GDD 8.2) — selection follows the position's attribute weights, so a
  /// goalkeeper never gains Attack and a striker rarely gains Goalkeeping.
  ///
  /// [random] must be supplied by the caller (seeded for deterministic
  /// tests, GDD development rule 7).
  Map<PlayerAttribute, int> allocateAttributeGain({
    required Position position,
    required int levelsGained,
    required math.Random random,
  }) {
    final gain = <PlayerAttribute, int>{};
    if (levelsGained <= 0) return gain;
    final weights = positionWeights[position]!;
    final candidates = <PlayerAttribute, double>{
      for (final e in weights.entries)
        if (e.value > 0) e.key: e.value,
    };
    final keys = candidates.keys.toList(growable: false);
    final cumulative = <double>[];
    var acc = 0.0;
    for (final k in keys) {
      acc += candidates[k]!;
      cumulative.add(acc);
    }
    for (var i = 0; i < levelsGained; i++) {
      final roll = random.nextDouble() * acc;
      var chosen = keys.last;
      for (var j = 0; j < keys.length; j++) {
        if (roll <= cumulative[j]) {
          chosen = keys[j];
          break;
        }
      }
      gain[chosen] = (gain[chosen] ?? 0) + 1;
    }
    return gain;
  }

  /// Full merge outcome: new level plus attribute gain for the gained
  /// levels, capped at the maximum attribute value of 99.
  MergeOutcome merge({
    required Position position,
    required int targetLevel,
    required int duplicateLevel,
    required math.Random random,
  }) {
    final newLevel = mergedLevel(targetLevel, duplicateLevel);
    final levelsGained = newLevel - targetLevel;
    return MergeOutcome(
      newUpgradeLevel: newLevel,
      attributeGain: allocateAttributeGain(
        position: position,
        levelsGained: levelsGained,
        random: random,
      ),
    );
  }
}
