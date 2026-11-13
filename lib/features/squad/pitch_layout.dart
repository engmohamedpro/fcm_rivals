/// FCM Rivals — pitch layout solver (Team tab, pre-match, live tactics).
///
/// Pure Dart, UI-independent (SRS 21.1). Places the eleven slots of a
/// formation on a pitch of a given size so that
///  * no two cards (nor the names under them) ever touch — every pair is
///    separated by at least [kPitchGapH] / [kPitchGapV];
///  * every card sits where its ROLE belongs: the keeper at the bottom,
///    the back line above him, midfield, then the attack at the top, and
///    inside each line the players keep the formation's left-to-right
///    order (a left back is left of the centre backs, the right winger is
///    right of the striker);
///  * the cards are as BIG as the pitch allows, up to [kPitchCardMaxWidth]
///    (the bench card size) — a 5-across line shrinks the whole formation
///    just enough to fit with air between the cards.
///
/// The formation data (x 0..100 left→right, y 0..100 own goal→opponent
/// goal) stays the single source of truth for WHO stands WHERE relative
/// to whom; this solver only decides the size and resolves the crowding.
library;

import 'dart:math' as math;

import 'formations.dart';

/// Space kept around the pitch edge.
const double kPitchMargin = 8;

/// Minimum air between two neighbouring slot footprints.
const double kPitchGapH = 4;
const double kPitchGapV = 4;

/// Horizontal room a slot reserves around its card for the name (the
/// footprint is the card plus this).
const double kPitchSlotPad = 10;

/// Smallest and largest card (shield) width on the pitch. The maximum is
/// the bench / reserves card size, so no card on the pitch is ever bigger
/// than its neighbours in the strips.
const double kPitchCardMinWidth = 30;
const double kPitchCardMaxWidth = 64;

/// Consecutive slots whose y differs by more than this start a new line
/// (back line, midfield, attack…). The keeper is always a line of his own.
const double kPitchRowSplit = 12;

/// Vertical air reserved between two lines (and above the top line) for
/// the STAGGER: a line's deeper or higher players (a holding midfielder
/// under the engineers, a striker over the wingers) may use up to one
/// reserve each side, so role depth stays visible even when the pitch is
/// packed and the cards small.
const double kPitchStaggerReserve = 8;

/// Width : height of a card — kept equal to `kPlayerCardAspect`; this file
/// stays free of UI imports.
const double _cardAspect = 0.70;

/// One slot's footprint on the pitch (card + name + optional stat row and
/// stamina bar), in pitch coordinates.
class PitchBox {
  const PitchBox(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
}

/// The solved layout of one formation on one pitch.
class PitchLayout {
  const PitchLayout({
    required this.cardWidth,
    required this.slotWidth,
    required this.slotHeight,
    required this.boxes,
    required this.rows,
  });

  /// Width of each card (shield).
  final double cardWidth;

  /// Width of each slot footprint (card plus name room).
  final double slotWidth;

  /// Height of each slot footprint.
  final double slotHeight;

  /// Footprint of every slot, indexed like `Formation.slots`.
  final List<PitchBox> boxes;

  /// The lines of the formation, keeper first: slot indices per line.
  final List<List<int>> rows;
}

/// Height of one slot footprint for a card of width [w]: the shield, the
/// 3px gap, the surname line, and — when shown — the stat row and the
/// stamina bar. The text line height is budgeted generously (1.3×) so
/// platform font differences can never push a name into the next line.
double pitchFootprintHeight(
  double w, {
  bool showStats = false,
  bool showStamina = false,
}) {
  var h = w / _cardAspect + 3 + math.max(9.0, w * 0.19) * 1.3;
  if (showStats) {
    h += 2 + math.max(6.5, w * 0.115) * 1.1 + math.max(9.0, w * 0.17) * 1.1;
  }
  if (showStamina) h += 3 + 5;
  return h;
}

/// Groups the formation's slots into lines, keeper first, then from the
/// back line forward. Inside a line the slots are ordered left → right.
List<List<int>> pitchRows(Formation formation) {
  final slots = formation.slots;
  final order = <int>[for (var i = 1; i < slots.length; i++) i]
    ..sort((a, b) {
      final byY = slots[a].y.compareTo(slots[b].y);
      return byY != 0 ? byY : slots[a].x.compareTo(slots[b].x);
    });
  final rows = <List<int>>[
    [0],
  ];
  var current = <int>[order.first];
  for (var k = 1; k < order.length; k++) {
    if (slots[order[k]].y - slots[order[k - 1]].y > kPitchRowSplit) {
      rows.add(current);
      current = <int>[];
    }
    current.add(order[k]);
  }
  rows.add(current);
  for (final row in rows) {
    row.sort((a, b) => slots[a].x.compareTo(slots[b].x));
  }
  return rows;
}

/// Solves the layout of [formation] on a pitch of [width] × [height].
/// [showStats] / [showStamina] say whether the cards carry the stat row
/// and the stamina bar (no surface shows stat rows today; the tactics
/// surfaces show stamina, the Team tab shows neither) — taller cards
/// mean fewer rows fit, so the size adapts.
PitchLayout computePitchLayout({
  required Formation formation,
  required double width,
  required double height,
  bool showStats = false,
  bool showStamina = false,
}) {
  final slots = formation.slots;
  final rows = pitchRows(formation);
  final rowCount = rows.length;

  bool fits(double w) {
    final sw = w + kPitchSlotPad;
    final sh = pitchFootprintHeight(
      w,
      showStats: showStats,
      showStamina: showStamina,
    );
    // The vertical budget keeps a stagger reserve between the lines (see
    // [kPitchStaggerReserve]): lines whose players stand at different
    // depths need air to show it, so a five-line shape gives up a little
    // card size instead of flattening its holding midfielder.
    if (rowCount * sh +
            (rowCount - 1) * (kPitchGapV + 2 * kPitchStaggerReserve) +
            kPitchStaggerReserve >
        height - 2 * kPitchMargin) {
      return false;
    }
    for (final row in rows) {
      if (row.length * sw + (row.length - 1) * kPitchGapH >
          width - 2 * kPitchMargin) {
        return false;
      }
    }
    return true;
  }

  // The biggest card that fits every line with air between the cards.
  var w = kPitchCardMaxWidth;
  while (w > kPitchCardMinWidth && !fits(w)) {
    w -= 0.25;
  }
  w = math.max(w, kPitchCardMinWidth);

  final sw = w + kPitchSlotPad;
  final sh = pitchFootprintHeight(
    w,
    showStats: showStats,
    showStamina: showStamina,
  );
  final spanY = height - 2 * kPitchMargin - sh;
  final spanX = width - 2 * kPitchMargin - sw;

  double meanY(List<int> row) =>
      row.fold<double>(0, (a, i) => a + slots[i].y) / row.length;

  // Line positions: the formation's own depth, then pushed apart so
  // consecutive lines never touch. rows[0] (keeper) is the lowest line:
  // tops DEcrease with the row index.
  final tops = <double>[
    for (final row in rows) kPitchMargin + (1 - meanY(row) / 100) * spanY,
  ];
  final step = sh + kPitchGapV;
  for (var pass = 0; pass < 6; pass++) {
    for (var k = 1; k < rowCount; k++) {
      tops[k] = math.min(tops[k], tops[k - 1] - step);
    }
    if (tops[rowCount - 1] < kPitchMargin) {
      tops[rowCount - 1] = kPitchMargin;
      for (var k = rowCount - 2; k >= 0; k--) {
        tops[k] = math.max(tops[k], tops[k + 1] + step);
      }
    }
    tops[0] = math.min(tops[0], height - kPitchMargin - sh);
  }
  // Re-space the lines: every gap at least [kPitchGapV] plus two
  // stagger reserves (one per facing line), any leftover height shared
  // between the gaps in proportion to their own size — the formation
  // keeps its depth structure and fills the pitch. The keeper sits
  // flush at the bottom edge; the top line keeps one reserve of
  // headroom for its own stagger.
  {
    final usable = height - 2 * kPitchMargin;
    final minGap = kPitchGapV + 2 * kPitchStaggerReserve;
    final gaps = <double>[
      for (var k = 1; k < rowCount; k++)
        math.max(tops[k - 1] - tops[k] - sh, minGap),
    ];
    var need = rowCount * sh + kPitchStaggerReserve;
    for (final g in gaps) {
      need += g;
    }
    if (need <= usable) {
      final extra = usable - need;
      final gapSum = gaps.fold<double>(0, (a, g) => a + g);
      tops[0] = height - kPitchMargin - sh; // the keeper, flush
      var top = tops[0];
      for (var k = 1; k < rowCount; k++) {
        final g = gapSum > 0
            ? gaps[k - 1] + extra * gaps[k - 1] / gapSum
            : gaps[k - 1] + extra / gaps.length;
        top -= sh + g;
        tops[k] = top;
      }
    }
  }

  final boxes = List<PitchBox>.filled(slots.length, const PitchBox(0, 0, 0, 0));
  for (var k = 0; k < rowCount; k++) {
    final row = rows[k]; // already left → right
    final rowMean = meanY(row);

    // Unclamped, each slot would sit exactly at its own formation depth
    // (the row's mean places the line, the stagger differentiates inside
    // it). The stagger budget below keeps that safe: a slot may use at
    // most HALF the air to any other line — the facing slot of that
    // line may claim the other half — and never leave the pitch.
    var allow = double.infinity;
    for (var k2 = 0; k2 < rowCount; k2++) {
      if (k2 == k) continue;
      allow = math.min(allow, (tops[k2] - tops[k]).abs() - sh - kPitchGapV);
    }
    allow = math.min(allow, tops[k] - kPitchMargin);
    allow = math.min(allow, height - kPitchMargin - sh - tops[k]);
    allow = math.max(0.0, allow / 2);

    // Slot CENTRES from the formation's x. Centres, not left edges: a
    // symmetric formation (left back 14, right back 86) then reads
    // symmetric on the pitch whatever the card size. A formation's
    // outermost x (a 5-x-x wing back at 10) can map outside the card's
    // usable range, so the centres start clamped into it.
    final minC = kPitchMargin + sw / 2;
    final maxC = width - kPitchMargin - sw / 2;
    final centres = <double>[
      for (final i in row)
        (kPitchMargin + sw / 2 + slots[i].x / 100 * spanX)
            .clamp(minC, maxC)
            .toDouble(),
    ];
    // Push the centres apart to the minimum spacing, clamp the line
    // into the pitch, then RE-CENTRE the occupied span on the pitch so
    // the line's outer cards end up equidistant from the edges — a
    // symmetric formation reads symmetric (the centring fix).
    final stepX = sw + kPitchGapH;
    for (var pass = 0; pass < 6; pass++) {
      for (var j = 1; j < centres.length; j++) {
        centres[j] = math.max(centres[j], centres[j - 1] + stepX);
      }
      if (centres.last > maxC) {
        centres[centres.length - 1] = maxC;
        for (var j = centres.length - 2; j >= 0; j--) {
          centres[j] = math.min(centres[j], centres[j + 1] - stepX);
        }
      }
      centres[0] = math.max(centres[0], minC);
    }
    if (centres.length > 1) {
      final span = centres.last - centres.first;
      if (span < maxC - minC) {
        // The line fits with room: place its occupied span centrally.
        final shift = (minC + maxC - span) / 2 - centres.first;
        for (var j = 0; j < centres.length; j++) {
          centres[j] += shift;
        }
      }
    }

    for (var j = 0; j < row.length; j++) {
      final i = row[j];
      // The stagger keeps the formation's own depth differences inside
      // a merged line — a holding midfielder visibly deeper than the
      // wide men beside him.
      final stagger = (-(slots[i].y - rowMean) / 100 * spanY)
          .clamp(-allow, allow)
          .toDouble();
      boxes[i] = PitchBox(centres[j] - sw / 2, tops[k] + stagger, sw, sh);
    }
  }

  return PitchLayout(
    cardWidth: w,
    slotWidth: sw,
    slotHeight: sh,
    boxes: boxes,
    rows: rows,
  );
}

/// One spare place of the drag preview: how deep it stands ([y], formation
/// coordinates, own goal → opponent goal) and which pitch edge it prefers.
class SparePlaceRequest {
  const SparePlaceRequest({required this.y, required this.leftSide});

  final double y;
  final bool leftSide;
}

bool _boxesTouch(PitchBox a, PitchBox b) =>
    a.left < b.right + kPitchGapH &&
    a.right + kPitchGapH > b.left &&
    a.top < b.bottom + kPitchGapV &&
    a.bottom + kPitchGapV > b.top;

/// Places the spare places of a live drag (positions the shape does not
/// field — the RB of a 3-4-3) on the pitch WITHOUT standing on a card.
///
/// Each request starts beside the line whose depth is nearest its own and
/// takes the preferred pitch edge, then the other one; when both edges of
/// that line are taken by cards it scans the edges for the nearest free
/// spot, and only when the pitch has no free spot at all does it overlap
/// (the nearest line, preferred edge). Earlier spares count as taken for
/// later ones, so spares never stack either. Returns one box per request,
/// in order.
///
/// The old placement pinned every spare to the edge at its line's top
/// without looking at the cards there — so a spare place covered the
/// outermost card of the line and that player vanished behind the ghost
/// (and could not be dropped on).
List<PitchBox> placeSparePlaces({
  required PitchLayout layout,
  required Formation formation,
  required double width,
  required double height,
  required List<SparePlaceRequest> requests,
}) {
  final sw = layout.slotWidth;
  final sh = layout.slotHeight;
  final margin = kPitchMargin + 4.0;
  final minTop = margin;
  final maxTop = math.max(minTop, height - margin - sh);
  final taken = <PitchBox>[...layout.boxes];
  final placed = <PitchBox>[];

  bool isFree(PitchBox candidate) {
    for (final b in taken) {
      if (_boxesTouch(candidate, b)) return false;
    }
    return true;
  }

  double meanY(List<int> row) =>
      row.fold<double>(0, (a, i) => a + formation.slots[i].y) / row.length;

  for (final request in requests) {
    final rowOrder = List<int>.generate(layout.rows.length, (r) => r)
      ..sort(
        (a, b) => (meanY(layout.rows[a]) - request.y).abs().compareTo(
          (meanY(layout.rows[b]) - request.y).abs(),
        ),
      );
    final lefts = request.leftSide
        ? <double>[margin, width - margin - sw]
        : <double>[width - margin - sw, margin];

    PitchBox? chosen;
    PitchBox? firstChoice;
    var preferredTop = minTop;

    // 1. Beside the nearest line, preferred edge first.
    for (var k = 0; k < rowOrder.length && chosen == null; k++) {
      final row = layout.rows[rowOrder[k]];
      final top = layout.boxes[row.first].top
          .clamp(minTop, maxTop)
          .toDouble();
      if (k == 0) preferredTop = top;
      for (final left in lefts) {
        final candidate = PitchBox(left, top, sw, sh);
        firstChoice ??= candidate;
        if (isFree(candidate)) {
          chosen = candidate;
          break;
        }
      }
    }

    // 2. Scan both edges for the free spot nearest the preferred depth.
    if (chosen == null) {
      final step = math.max(4.0, sh / 4);
      final tops = <double>[];
      for (var t = minTop; t <= maxTop; t += step) {
        tops.add(t);
      }
      tops.sort(
        (a, b) =>
            (a - preferredTop).abs().compareTo((b - preferredTop).abs()),
      );
      for (final top in tops) {
        for (final left in lefts) {
          final candidate = PitchBox(left, top, sw, sh);
          if (isFree(candidate)) {
            chosen = candidate;
            break;
          }
        }
        if (chosen != null) break;
      }
    }

    final box = chosen ?? firstChoice ?? PitchBox(lefts.first, minTop, sw, sh);
    placed.add(box);
    taken.add(box);
  }
  return placed;
}
