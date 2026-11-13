/// FCM Rivals — chemistry links between players sharing a nationality
/// or a club (owner request 2026-11-11; icon wildcards 2026-11-12).
///
/// The pitch draws a line between linked players: one line per group
/// member minus one per dimension (a minimum spanning tree over the
/// card positions), which is also exactly the chemistry points the
/// group is worth (see `chemistry.dart`). A pair linked by BOTH
/// dimensions is drawn once, not twice.
///
/// The line's colour tells the pair's relationship: the pair shares ONE
/// chemistry type (nationality or club) → white; it shares BOTH →
/// golden. An icon pairs with EVERY other slot in both kinds — the
/// legend's thread runs to the whole formation.
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
///
/// [icons] (owner request 2026-11-12): slots holding ICON players are
/// chemistry wildcards — an icon link joins BOTH kinds to every other
/// centred slot, so the pitch shows the icon's thread to all players
/// and the chemistry math (chemistry.dart) agrees with the drawing.
/// Omitted / empty means no icons, the pre-2026-11-12 behaviour.
List<ChemistryLink> chemistryLinks({
  required Map<int, String?> nationalities,
  required Map<int, String?> clubs,
  required Map<int, ({double x, double y})> centres,
  Map<int, bool> icons = const {},
}) {
  final iconSlots = [
    for (final entry in icons.entries)
      if (entry.value && centres.containsKey(entry.key)) entry.key,
  ]..sort();

  final pairs = <(int, int)>{
    ..._treePairs(nationalities, centres, iconSlots: iconSlots),
    ..._treePairs(clubs, centres, iconSlots: iconSlots),
  };
  final sorted = pairs.toList()
    ..sort(
      (p, q) =>
          p.$1 != q.$1 ? p.$1.compareTo(q.$1) : p.$2.compareTo(q.$2),
    );
  return [
    for (final (a, b) in sorted)
      ChemistryLink(a, b, {
        if (_sameKey(nationalities[a], nationalities[b]) ||
            _wildcardPair(icons, a, b))
          ChemistryLinkKind.nationality,
        if (_sameKey(clubs[a], clubs[b]) || _wildcardPair(icons, a, b))
          ChemistryLinkKind.club,
      }),
  ];
}

/// An icon slot pairs with EVERY other slot in both dimensions.
bool _wildcardPair(Map<int, bool> icons, int a, int b) =>
    (icons[a] ?? false) || (icons[b] ?? false);

bool _sameKey(String? x, String? y) =>
    x != null && x.isNotEmpty && x == y;

/// The (a, b) pairs (a < b) of one dimension's spanning trees: every
/// group of n ≥ 2 equal keys joined by n − 1 shortest edges (Prim).
/// [iconSlots] (when non-empty) each join EVERY group — an icon slot is
/// appended to all groups of the dimension and the icons form their own
/// group, exactly the wildcard rule of chemistry.dart: the icon's
/// i × (n − 1) links show as trees joined at the icon.
List<(int, int)> _treePairs(
  Map<int, String?> keys,
  Map<int, ({double x, double y})> centres, {
  List<int> iconSlots = const [],
}) {
  final groups = <String, List<int>>{};
  for (final entry in keys.entries) {
    final key = entry.value;
    if (key == null || key.isEmpty) continue;
    if (!centres.containsKey(entry.key)) continue;
    groups.putIfAbsent(key, () => <int>[]).add(entry.key);
  }

  if (iconSlots.isNotEmpty) {
    // Icons join every group …
    for (final key in groups.keys.toList()) {
      groups[key] = [...groups[key]!, ...iconSlots];
    }
    // … and pair with EVERY centred regular of the dimension — even
    // ones whose key grouped with nobody (all-distinct nationalities):
    // the icon's thread runs to all players, not just group members.
    final grouped = <int>{};
    for (final members in groups.values) {
      grouped.addAll(members);
    }
    for (final entry in keys.entries) {
      if (iconSlots.contains(entry.key)) continue;
      if (grouped.contains(entry.key)) continue;
      if (!centres.containsKey(entry.key)) continue;
      // A lone regular links to the icons only — icon-to-regular pairs,
      // one tree rooted at the first icon.
      groups.putIfAbsent('icon:lone:${entry.key}', () => <int>[]).addAll([
        iconSlots.first,
        entry.key,
      ]);
    }
    // … and group together as their own dimension-agnostic clique.
    groups.putIfAbsent('icon:icon', () => <int>[]).addAll(iconSlots);
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
