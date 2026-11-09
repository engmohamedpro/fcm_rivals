/// FCM Rivals — on-pitch nationality chemistry (owner spec 2026-11-09).
///
/// Players sharing a nationality on the pitch gel better: every
/// nationality group of n ≥ 2 on-pitch players is worth (n − 1)
/// percentage points, groups add up, and the sum is clamped to 0..10.
/// The owner's verbatim examples:
/// - 2 players of one nationality → +1% (3 same → +2%, "and so on",
///   11 same → +10%),
/// - 2 Egypt + 4 Brazil + 5 distinct → 1% + 3% = +4%.
///
/// The engine multiplies the team's attack, support, defence and
/// goalkeeping totals by (1 + percent / 100) in
/// `_TeamRuntime.computeTotals`, computed from the players CURRENTLY on
/// the pitch — substitutions and red cards re-evaluate it live.
///
/// Pure Dart, no Flutter imports (house pattern, see
/// `lib/core/domain/players.dart`).
library;

import 'dart:math' as math;

/// Chemistry percentage points earned by the nationalities currently on
/// the pitch: skip `null` and `''` entries, group equal strings, add
/// `max(0, n − 1)` per group of size n ≥ 2, clamp the sum to 0..10.
int chemistryPercentOf(Iterable<String?> nationalities) {
  final counts = <String, int>{};
  for (final nationality in nationalities) {
    if (nationality == null || nationality.isEmpty) continue;
    counts[nationality] = (counts[nationality] ?? 0) + 1;
  }
  var sum = 0;
  for (final size in counts.values) {
    sum += math.max(0, size - 1);
  }
  return math.min(10, math.max(0, sum));
}
