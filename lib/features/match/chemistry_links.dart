/// FCM Rivals — chemistry links between players sharing a nationality
/// or a club (owner request 2026-11-11).
///
/// The pitch draws a line between linked players: one line per group
/// member minus one per dimension (a minimum spanning tree over the
/// card positions), which is also exactly the chemistry points the
/// group is worth (see `chemistry.dart`). A pair linked by BOTH
/// dimensions is drawn once, not twice.
///
/// The line's colour tells the pair's relationship (owner request
/// 2026-11-11): the pair shares ONE chemistry type (nationality or
/// club) → white; it shares BOTH → golden. The kind set is read from
/// the pair's attributes, not from which tree produced the edge, so a
/// pair sharing both is golden even when only one dimension's tree
/// happened to pick it.
///
/// Pure Dart, no Flutter imports (house pattern).
library;

import 'dart:math' as math;

/// A chemistry dimension a link can join two players through.
enum ChemistryLinkKind { nationality, club }

/// One link between two slots that share at least one chemistry type.
class ChemistryLink {
  const ChemistryLink(this.a, this.b, this.kinds);

  /// Slot indices of the two linked players (a < b).
  final int a;
  final int b;

  /// Chemistry types the linked PAIR shares — one entry reads as a
  /// white line, both as a golden line. Always non-empty: an edge only
  /// forms inside a group of a shared dimension.
  final Set<ChemistryLinkKind> kinds;
}

/// Links between the players in [nationalities] / [clubs] (slot →
/// grouping key per dimension) that share that dimension's key, laid
/// out over [centres] (slot → card centre). `null` / empty keys and
/// slots without a centre are ignored. The result is deterministic:
/// pairs in (a, b) order, kinds in enum order.
List<ChemistryLink> chemistryLinks({
  required Map<int, String?> nationalities,
  required Map<int, String?> clubs,
  required Map<int, ({double x, double y})> centres,
}) {
  // One spanning tree per dimension; the pair union is the link set.
  final pairs = <(int, int)>{
    ..._treePairs(nationalities, centres),
    ..._treePairs(clubs, centres),
  };
  final sorted = pairs.toList()
    ..sort(
      (p, q) =>
          p.$1 != q.$1 ? p.$1.compareTo(q.$1) : p.$2.compareTo(q.$2),
    );
  return [
    for (final (a, b) in sorted)
      ChemistryLink(a, b, {
        if (_sameKey(nationalities[a], nationalities[b]))
          ChemistryLinkKind.nationality,
        if (_sameKey(clubs[a], clubs[b])) ChemistryLinkKind.club,
      }),
  ];
}

bool _sameKey(String? x, String? y) =>
    x != null && x.isNotEmpty && x == y;

/// The (a, b) pairs (a < b) of one dimension's spanning trees: every
/// group of n ≥ 2 equal keys joined by n − 1 shortest edges (Prim).
List<(int, int)> _treePairs(
  Map<int, String?> keys,
  Map<int, ({double x, double y})> centres,
) {
  final groups = <String, List<int>>{};
  for (final entry in keys.entries) {
    final key = entry.value;
    if (key == null || key.isEmpty) continue;
    if (!centres.containsKey(entry.key)) continue;
    groups.putIfAbsent(key, () => <int>[]).add(entry.key);
  }

  final names = groups.keys.toList()..sort();
  final pairs = <(int, int)>[];
  for (final name in names) {
    final slots = groups[name]!..sort();
    if (slots.length < 2) continue;

    double dist(int i, int j) {
      final p = centres[i]!;
      final q = centres[j]!;
      return math.sqrt(
        (p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y),
      );
    }

    // Prim: grow the tree from the first slot, always adding the
    // closest outside slot.
    final inTree = <int>[slots.first];
    final outside = slots.sublist(1).toList();
    while (outside.isNotEmpty) {
      int? bestFrom;
      int? bestTo;
      var best = double.infinity;
      for (final from in inTree) {
        for (final to in outside) {
          final d = dist(from, to);
          if (d < best) {
            best = d;
            bestFrom = from;
            bestTo = to;
          }
        }
      }
      pairs.add((math.min(bestFrom!, bestTo!), math.max(bestFrom, bestTo)));
      inTree.add(bestTo);
      outside.remove(bestTo);
    }
  }
  return pairs;
}
