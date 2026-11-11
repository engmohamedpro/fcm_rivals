/// FCM Rivals — chemistry links between same-nationality players.
///
/// The pitch draws a line between players of the same nationality. Each
/// nationality group of n ≥ 2 is joined by exactly n − 1 lines (a minimum
/// spanning tree over the card positions), which is also exactly the
/// number of chemistry points the group is worth (see `chemistry.dart`) —
/// so the lines on the pitch always add up to the percentage shown.
///
/// Pure Dart, no Flutter imports (house pattern).
library;

import 'dart:math' as math;

/// One link between two slots that share a nationality.
class ChemistryLink {
  const ChemistryLink(this.a, this.b, this.nationality);

  /// Slot indices of the two linked players (a < b).
  final int a;
  final int b;
  final String nationality;
}

/// Links between the players in [nationalities] (slot → nationality) that
/// share a nationality, laid out over [centres] (slot → card centre).
/// `null` / empty nationalities and slots without a centre are ignored.
/// The result is deterministic: groups in nationality order, edges in
/// the order Prim's algorithm adds them.
List<ChemistryLink> chemistryLinks({
  required Map<int, String?> nationalities,
  required Map<int, ({double x, double y})> centres,
}) {
  final groups = <String, List<int>>{};
  for (final entry in nationalities.entries) {
    final nationality = entry.value;
    if (nationality == null || nationality.isEmpty) continue;
    if (!centres.containsKey(entry.key)) continue;
    groups.putIfAbsent(nationality, () => <int>[]).add(entry.key);
  }

  final names = groups.keys.toList()..sort();
  final links = <ChemistryLink>[];
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
      links.add(
        ChemistryLink(
          math.min(bestFrom!, bestTo!),
          math.max(bestFrom, bestTo),
          name,
        ),
      );
      inTree.add(bestTo);
      outside.remove(bestTo);
    }
  }
  return links;
}
