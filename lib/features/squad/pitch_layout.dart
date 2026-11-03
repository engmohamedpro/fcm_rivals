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
double pitchFootprintHeight(double w,
    {bool showStats = false, bool showStamina = false}) {
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
/// and the stamina bar (the Team tab shows neither, the pre-match phase
/// both) — taller cards mean fewer rows fit, so the size adapts.
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
    final sh = pitchFootprintHeight(w,
        showStats: showStats, showStamina: showStamina);
    if (rowCount * sh + (rowCount - 1) * kPitchGapV >
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
  final sh = pitchFootprintHeight(w,
      showStats: showStats, showStamina: showStamina);
  final spanY = height - 2 * kPitchMargin - sh;
  final spanX = width - 2 * kPitchMargin - sw;

  double meanY(List<int> row) =>
      row.fold<double>(0, (a, i) => a + slots[i].y) / row.length;

  // Line positions: the formation's own depth, then pushed apart so
  // consecutive lines never touch. rows[0] (keeper) is the lowest line:
  // tops DEcrease with the row index.
  final tops = <double>[
    for (final row in rows)
      kPitchMargin + (1 - meanY(row) / 100) * spanY,
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

  // Slots keep a little of the formation's own stagger (a holding
  // midfielder a touch deeper than the wide men) — but only as much as the
  // free space between the lines allows, so the lines never collide.
  var slack = double.infinity;
  for (var k = 1; k < rowCount; k++) {
    slack = math.min(slack, tops[k - 1] - tops[k]);
  }
  final allow = math.max(0.0, (slack - step) / 2);

  final boxes = List<PitchBox>.filled(slots.length, const PitchBox(0, 0, 0, 0));
  for (var k = 0; k < rowCount; k++) {
    final row = rows[k]; // already left → right
    final rowMean = meanY(row);

    // Left edges from the formation's x, then pushed to the minimum
    // spacing from the left and the right so the line never overlaps and
    // never leaves the pitch; left-to-right order is preserved.
    final lefts = <double>[
      for (final i in row) kPitchMargin + slots[i].x / 100 * spanX,
    ];
    final stepX = sw + kPitchGapH;
    final maxLeft = width - kPitchMargin - sw;
    for (var pass = 0; pass < 6; pass++) {
      for (var j = 1; j < lefts.length; j++) {
        lefts[j] = math.max(lefts[j], lefts[j - 1] + stepX);
      }
      if (lefts.last > maxLeft) {
        lefts[lefts.length - 1] = maxLeft;
        for (var j = lefts.length - 2; j >= 0; j--) {
          lefts[j] = math.min(lefts[j], lefts[j + 1] - stepX);
        }
      }
      lefts[0] = math.max(lefts[0], kPitchMargin);
    }

    for (var j = 0; j < row.length; j++) {
      final i = row[j];
      final stagger = (-(slots[i].y - rowMean) / 100 * spanY)
          .clamp(-allow, allow)
          .toDouble();
      boxes[i] = PitchBox(lefts[j], tops[k] + stagger, sw, sh);
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
