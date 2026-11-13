/// FCM Rivals — on-pitch chemistry (owner spec 2026-11-09, extended
/// with club chemistry 2026-11-11, icon wildcards 2026-11-12).
///
/// Players gel through two dimensions, each with the same formula:
/// - nationality (owner spec 2026-11-09): every nationality group of
///   n ≥ 2 on-pitch players is worth (n − 1) percentage points — 2 Egypt
///   → +1%, 11 same → +10%;
/// - club (owner request 2026-11-11, "team chemistry"): players sharing
///   a real-world club, same group formula.
///
/// ICON players (owner request 2026-11-12) are wildcards in BOTH
/// dimensions: an icon groups with every other on-pitch player's
/// nationality AND every other player's club — "fulliles the two types
/// chimstry with all players in the formation". With i icons among n
/// on-pitch players, each dimension gains i × (n − 1) links.
///
/// The TOTAL is the sum of both dimensions clamped to 0..10: the +10%
/// ceiling stays as it was under the nationality-only spec, because it
/// is locked by the T-0068 balance gate (a 10% chemistry edge measured
/// 0.616 win rate against a hard 0.62 band). Adding the club dimension
/// and the icon wildcards widens the ways to build chemistry without
/// raising the maximum edge.
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

/// Chemistry percentage points earned within ONE dimension (pass the
/// grouping keys, e.g. nationalities or club keys): skip `null` and `''`
/// entries, group equal strings, add `max(0, n − 1)` per group of size
/// n ≥ 2, clamp the sum to 0..10.
int chemistryPercentOf(Iterable<String?> keys) {
  final counts = <String, int>{};
  for (final key in keys) {
    if (key == null || key.isEmpty) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  var sum = 0;
  for (final size in counts.values) {
    sum += math.max(0, size - 1);
  }
  return math.min(10, math.max(0, sum));
}

/// Chemistry percentage points for ONE dimension with icon wildcards
/// (owner request 2026-11-12): every icon joins every group. Regular keys
/// group as before; each icon adds (n − 1) links against every OTHER
/// on-pitch player — regular or icon alike. Icons never REDUCE
/// chemistry: they only add.
int chemistryPercentWithIcons({
  required Iterable<String?> keys,
  required Iterable<bool> icons,
}) {
  final keyList = keys.toList();
  final iconList = icons.toList();
  // Defensive alignment: the two iterables describe the same players.
  final n = math.min(keyList.length, iconList.length);
  final counts = <String, int>{};
  var iconsCount = 0;
  for (var i = 0; i < n; i++) {
    if (iconList[i]) {
      iconsCount++;
      continue;
    }
    final key = keyList[i];
    if (key == null || key.isEmpty) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  var sum = 0;
  for (final size in counts.values) {
    sum += math.max(0, size - 1);
  }
  // Each icon links to every OTHER player on the pitch — regular or
  // icon. The first icon links to (n − 1) players, the second to
  // (n − 1) as well (its pair with the first icon counts once from
  // this side), so i icons add i × (n − 1) links total.
  if (iconsCount > 0 && n > 1) {
    sum += iconsCount * (n - 1);
  }
  return math.min(10, math.max(0, sum));
}

/// Grouping key of a player's club for chemistry: the dataset club id
/// when known, the club display name as a fallback (id-less rows), ''
/// when the club is unknown. A shared key means a shared club, so
/// same-club players always group even when only one of id/name is set.
String clubChemistryKeyOf(int clubId, String clubName) => clubId != 0
    ? 'club:$clubId'
    : (clubName.isEmpty ? '' : 'club:$clubName');

/// Total on-pitch chemistry (owner request 2026-11-11; icon wildcards
/// 2026-11-12): nationality points plus club points — the same group
/// formula per dimension, icons joining every group in both — with the
/// combined sum clamped to 0..10 (see the library comment for why the
/// ceiling stays at 10).
int totalChemistryPercentOf({
  required Iterable<String?> nationalities,
  required Iterable<String?> clubs,
  Iterable<bool> icons = const [],
}) {
  // Without icons this is exactly the pre-2026-11-12 formula.
  if (!icons.any((i) => i)) {
    return math.min(
      10,
      chemistryPercentOf(nationalities) + chemistryPercentOf(clubs),
    );
  }
  return math.min(
    10,
    chemistryPercentWithIcons(keys: nationalities, icons: icons) +
        chemistryPercentWithIcons(keys: clubs, icons: icons),
  );
}
