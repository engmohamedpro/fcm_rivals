/// FCM Rivals — data-driven formation definitions (GDD 6.4).
///
/// A formation is pure data: 11 slots, each a field position with pitch
/// coordinates for rendering (x: 0..100 left→right, y: 0..100 own goal→
/// opponent goal). Adding formations requires no code changes.
///
/// The coordinates are ROLE-CORRECT, not just line-correct: every slot's
/// depth (y) comes from its role's rung on the shared ladder below, so a
/// holding midfielder always sits visibly deeper than an engineer, who
/// sits visibly deeper than a playmaker, whatever the shape. Full backs
/// (LB/RB) stand clearly ahead of their centre backs, and wing backs in
/// a back five live half a pitch higher still — a 3-x-x shape defends
/// with the back three and attacks with its wing backs already advanced.
/// x values are symmetric about 50 (a left back at 14 mirrors a right
/// back at 86), so every line reads centred.
///
/// ## Custom formations (owner request 2026-11-12)
///
/// The user can also build a CUSTOM shape by dragging players onto empty
/// pitch slots: every slot KEEPS its pitch place, and the slot's
/// POSITION becomes the dropped player's own. The position mix obeys
/// [positionCaps] (the owner's exact ladder: ST 0-2, LW/RW/LB/RB 0-1,
/// CAM 0-2, CM/CDM/CB 0-3, GK exactly 1 — LM/RM allowed 0-1 each
/// because the dataset carries them). A custom formation serialises as
/// the code `'C|GK,LB,CB,…'` (position codes, GK first); [customFormation]
/// builds it and [formationByCode] decodes it, so every consumer of
/// `formationByCode` (match engine, season, pre-match) sees it as just
/// another formation.
library;

import '../../core/domain/players.dart';

class FormationSlot {
  const FormationSlot(this.position, this.x, this.y);

  /// The position this slot asks for.
  final Position position;

  /// Pitch coordinates for rendering (percent of width/height).
  final double x;
  final double y;
}

class Formation {
  const Formation(this.code, this.name, this.slots);

  /// Stable identifier, e.g. '4-3-3'.
  final String code;

  /// Display name.
  final String name;

  /// Exactly 11 slots, GK first.
  final List<FormationSlot> slots;

  bool get isValid => slots.length == 11 && slots.first.position == Position.gk;

  /// Bench and reserves: slots 11..17 and 18..22 (GDD 6.1) carry no fixed
  /// position.
  static const int squadSize = 23;
  static const int startingXiSize = 11;
  static const int benchSize = 7;
  static const int reservesSize = 5;
}

/// The depth ladder every formation shares: how far up the pitch (y, own
/// goal → opponent goal) each role stands. Distinct rungs are at least
/// four apart, so adjacent roles are always visibly apart on the pitch.
const double _gkY = 5;
const double _cbY = 18;
const double _cbMidY = 15; // the middle CB of a back three
const double _fbY = 30; // LB / RB in a back four
const double _wb5Y = 26; // wing backs in a back five (5-x-x)
const double _wbY = 46; // wing backs of a back three (3-x-x mid five)
const double _cdmY = 43;
const double _cmY = 50;
const double _lmY = 54;
const double _camY = 64;
const double _lwY = 74;
const double _stY = 84;

/// All supported formations (GDD 6.4, extended). Ordered from the
/// balanced staples to the specialisms.
const List<Formation> formations = [
  // --- back four, flat midfield rows ---
  Formation('4-3-3', '4-3-3', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.cdm, 50, _cdmY),
    FormationSlot(Position.cm, 32, _cmY),
    FormationSlot(Position.cm, 68, _cmY),
    FormationSlot(Position.lw, 16, _lwY),
    FormationSlot(Position.st, 50, _stY),
    FormationSlot(Position.rw, 84, _lwY),
  ]),
  Formation('4-4-2', '4-4-2', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.lm, 14, _lmY),
    FormationSlot(Position.cm, 38, _cmY),
    FormationSlot(Position.cm, 62, _cmY),
    FormationSlot(Position.rm, 86, _lmY),
    FormationSlot(Position.st, 40, _stY),
    FormationSlot(Position.st, 60, _stY),
  ]),
  Formation('4-2-3-1', '4-2-3-1', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.cdm, 36, _cdmY),
    FormationSlot(Position.cdm, 64, _cdmY),
    FormationSlot(Position.lw, 16, _camY),
    FormationSlot(Position.cam, 50, _camY),
    FormationSlot(Position.rw, 84, _camY),
    FormationSlot(Position.st, 50, _stY),
  ]),
  Formation('4-1-4-1', '4-1-4-1', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.cdm, 50, _cdmY),
    FormationSlot(Position.lm, 14, _lmY),
    FormationSlot(Position.cm, 38, _cmY),
    FormationSlot(Position.cm, 62, _cmY),
    FormationSlot(Position.rm, 86, _lmY),
    FormationSlot(Position.st, 50, _stY),
  ]),
  Formation('4-5-1', '4-5-1', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.lm, 14, _lmY),
    FormationSlot(Position.cm, 34, _cmY),
    FormationSlot(Position.cdm, 50, _cdmY),
    FormationSlot(Position.cm, 66, _cmY),
    FormationSlot(Position.rm, 86, _lmY),
    FormationSlot(Position.st, 50, _stY),
  ]),

  // --- back four, second strikers / playmakers ---
  Formation('4-4-1-1', '4-4-1-1', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.lm, 14, 51),
    FormationSlot(Position.cm, 38, _cmY),
    FormationSlot(Position.cm, 62, _cmY),
    FormationSlot(Position.rm, 86, 51),
    FormationSlot(Position.cam, 50, _camY),
    FormationSlot(Position.st, 50, _stY),
  ]),
  Formation('4-2-2-2', '4-2-2-2', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.cdm, 36, _cdmY),
    FormationSlot(Position.cdm, 64, _cdmY),
    FormationSlot(Position.cam, 32, _camY),
    FormationSlot(Position.cam, 68, _camY),
    FormationSlot(Position.st, 40, _stY),
    FormationSlot(Position.st, 60, _stY),
  ]),
  Formation('4-1-2-1-2', '4-1-2-1-2 (diamond)', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.cdm, 50, _cdmY),
    FormationSlot(Position.cm, 26, _cmY),
    FormationSlot(Position.cm, 74, _cmY),
    FormationSlot(Position.cam, 50, _camY),
    FormationSlot(Position.st, 40, _stY),
    FormationSlot(Position.st, 60, _stY),
  ]),
  Formation('4-3-2-1', '4-3-2-1 (Christmas tree)', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 14, _fbY),
    FormationSlot(Position.cb, 36, _cbY),
    FormationSlot(Position.cb, 64, _cbY),
    FormationSlot(Position.rb, 86, _fbY),
    FormationSlot(Position.cm, 30, _cmY),
    FormationSlot(Position.cdm, 50, _cdmY),
    FormationSlot(Position.cm, 70, _cmY),
    FormationSlot(Position.cam, 36, _camY),
    FormationSlot(Position.cam, 64, _camY),
    FormationSlot(Position.st, 50, _stY),
  ]),

  // --- back three, wing backs advanced (3-x-x family) ---
  Formation('3-5-2', '3-5-2', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.cb, 28, _cbY),
    FormationSlot(Position.cb, 50, _cbMidY),
    FormationSlot(Position.cb, 72, _cbY),
    FormationSlot(Position.lm, 10, _wbY),
    FormationSlot(Position.cm, 34, _cmY),
    FormationSlot(Position.cdm, 50, _cdmY),
    FormationSlot(Position.cm, 66, _cmY),
    FormationSlot(Position.rm, 90, _wbY),
    FormationSlot(Position.st, 40, _stY),
    FormationSlot(Position.st, 60, _stY),
  ]),
  Formation('3-4-3', '3-4-3', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.cb, 28, _cbY),
    FormationSlot(Position.cb, 50, _cbMidY),
    FormationSlot(Position.cb, 72, _cbY),
    FormationSlot(Position.lm, 12, _wbY),
    FormationSlot(Position.cm, 38, _cmY),
    FormationSlot(Position.cm, 62, _cmY),
    FormationSlot(Position.rm, 88, _wbY),
    FormationSlot(Position.lw, 18, _lwY),
    FormationSlot(Position.st, 50, _stY),
    FormationSlot(Position.rw, 82, _lwY),
  ]),
  Formation('3-4-1-2', '3-4-1-2', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.cb, 28, _cbY),
    FormationSlot(Position.cb, 50, _cbMidY),
    FormationSlot(Position.cb, 72, _cbY),
    FormationSlot(Position.lm, 12, _wbY),
    FormationSlot(Position.cm, 38, _cmY),
    FormationSlot(Position.cm, 62, _cmY),
    FormationSlot(Position.rm, 88, _wbY),
    FormationSlot(Position.cam, 50, _camY),
    FormationSlot(Position.st, 40, _stY),
    FormationSlot(Position.st, 60, _stY),
  ]),

  // --- back five, wing backs advanced (5-x-x family) ---
  Formation('5-3-2', '5-3-2', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 10, _wb5Y),
    FormationSlot(Position.cb, 30, _cbY),
    FormationSlot(Position.cb, 50, _cbMidY),
    FormationSlot(Position.cb, 70, _cbY),
    FormationSlot(Position.rb, 90, _wb5Y),
    FormationSlot(Position.cm, 32, _cmY),
    FormationSlot(Position.cdm, 50, _cdmY),
    FormationSlot(Position.cm, 68, _cmY),
    FormationSlot(Position.st, 40, _stY),
    FormationSlot(Position.st, 60, _stY),
  ]),
  Formation('5-4-1', '5-4-1', [
    FormationSlot(Position.gk, 50, _gkY),
    FormationSlot(Position.lb, 10, _wb5Y),
    FormationSlot(Position.cb, 30, _cbY),
    FormationSlot(Position.cb, 50, _cbMidY),
    FormationSlot(Position.cb, 70, _cbY),
    FormationSlot(Position.rb, 90, _wb5Y),
    FormationSlot(Position.lm, 14, _lmY),
    FormationSlot(Position.cm, 38, _cmY),
    FormationSlot(Position.cm, 62, _cmY),
    FormationSlot(Position.rm, 86, _lmY),
    FormationSlot(Position.st, 50, _stY),
  ]),
];

Formation formationByCode(String code) => formations.firstWhere(
  (f) => f.code == code,
  orElse: () => formations.first,
);

// ---------------------------------------------------------------------------
// Custom formations (owner request 2026-11-12)
// ---------------------------------------------------------------------------

/// The custom-formation code prefix: `'C|GK,LB,CB,…'`.
const String kCustomFormationPrefix = 'C|';

/// How many slots a custom formation's position mix may carry (the
/// owner's exact ladder, 2026-11-13): GK exactly 1, CB exactly 2 or 3,
/// ST/CAM up to 2, CM/CDM up to 3, one wide man per wing at most
/// (LW/RW/LM/RM/LB/RB). The minima are part of the law: a back line
/// without a CB pair is not a shape anyone may field.
const Map<Position, (int min, int max)> positionCaps = {
  Position.gk: (1, 1),
  Position.st: (0, 2),
  Position.lw: (0, 1),
  Position.rw: (0, 1),
  Position.lm: (0, 1),
  Position.rm: (0, 1),
  Position.cam: (0, 2),
  Position.cm: (0, 3),
  Position.cdm: (0, 3),
  Position.cb: (2, 3),
  Position.rb: (0, 1),
  Position.lb: (0, 1),
};

/// True when [positions] is a legal custom XI: 11 entries, GK first
/// (the keeper's slot is fixed), and every position within its cap
/// from [positionCaps]. [positions] here are the XI slot positions in
/// slot order, GK first.
String? customFormationProblem(List<Position> positions) {
  if (positions.length != Formation.startingXiSize) {
    return 'A formation needs exactly ${Formation.startingXiSize} slots '
        '(${positions.length} given).';
  }
  if (positions.first != Position.gk) {
    return 'The goalkeeper keeps his slot — GK must come first.';
  }
  final counts = <Position, int>{};
  for (final p in positions) {
    counts.update(p, (n) => n + 1, ifAbsent: () => 1);
  }
  // Walk the CAPS, not the counts: a position the mix does not field at
  // all (zero CBs) must still meet its minimum — iterating only the
  // positions that are present let a back line with no centre backs
  // through.
  for (final e in positionCaps.entries) {
    final n = counts[e.key] ?? 0;
    final range = e.value.$1 == e.value.$2
        ? 'exactly ${e.value.$1}'
        : '${e.value.$1} to ${e.value.$2}';
    if (n > e.value.$2) {
      return 'Too many ${e.key.code}s — a custom formation fields $range.';
    }
    if (n < e.value.$1) {
      return 'Too few ${e.key.code}s — a custom formation fields $range.';
    }
  }
  return null;
}

/// The pitch anchor (x, y) of one [position] place: [index]-th player
/// of [count] teammates in the same position. The spread rules (owner
/// request 2026-11-13): a LONE player of a position stands at the
/// position's home x — CENTRED (a lone striker at 50, a lone CAM at
/// 50, never off to one side); a PAIR spreads symmetrically beside the
/// centre (a strike pair at 40/60, two CAMs at 40/60, two CMs at
/// 32/68); a TRIO spreads as a left-centre-right line (a back three at
/// 28/50/72, three CMs at 22/50/78 — count 3 is capped at 2 for ST
/// and CAM, so a trio only ever happens for CB/CM/CDM). Depth (y) is
/// the position's rung on the shared ladder, so every line keeps its
/// role depth whatever the mix.
///
/// Public because the drag layout (`squad_swap.dart`) re-spreads the
/// live mix with the same rules while a player is held.
(double, double) customAnchors(Position position, int index, int count) {
  // The spread ladder by count (owner request 2026-11-13): ONE player
  // of a position stands dead centre; TWO spread symmetrically beside
  // the centre; THREE line up left-centre-right. Counts above three
  // never happen (the caps cap them).
  final spread = <Position, Map<int, List<double>>>{
    Position.gk: {
      1: [50],
    },
    Position.cb: {
      2: [28, 72],
      3: [28, 50, 72],
    },
    Position.cdm: {
      1: [50],
      2: [32, 68],
      3: [22, 50, 78],
    },
    Position.cm: {
      1: [50],
      2: [32, 68],
      3: [22, 50, 78],
    },
    Position.cam: {
      1: [50],
      2: [32, 68],
      // A third CAM never fields (cap 2) — the pair is the widest.
    },
    Position.st: {
      1: [50],
      2: [40, 60],
      // A third ST never fields (cap 2).
    },
    // Wide men: the wing's own side, exactly one each.
    Position.lb: {
      1: [14],
    },
    Position.rb: {
      1: [86],
    },
    Position.lw: {
      1: [16],
    },
    Position.rw: {
      1: [84],
    },
    Position.lm: {
      1: [12],
    },
    Position.rm: {
      1: [88],
    },
  };
  final xs = spread[position]?[count.clamp(1, 3)] ?? [50];
  final x = xs[index.clamp(0, xs.length - 1)];
  final y = switch (position) {
    Position.gk => _gkY,
    Position.cb => index == 1 && count == 3 ? _cbMidY : _cbY,
    Position.lb || Position.rb => _fbY,
    Position.lw || Position.rw => _lwY,
    Position.lm || Position.rm => _wbY,
    Position.cdm => _cdmY,
    Position.cm => _cmY,
    Position.cam => _camY,
    Position.st => _stY,
  };
  return (x, y);
}

/// Builds the custom formation for [positions] (XI slot order, GK
/// first). The 11 slots keep the PITCH PLACES of the base shape the
/// user started from (dragging redefines WHAT a slot asks for, not
/// where it stands), and each slot's position comes straight from
/// [positions] — so the slot the user dropped a striker on now asks
/// for a striker, forever, until the shape changes.
///
/// Returns null (and the reason via [customFormationProblem]) when the
/// mix is illegal. The resulting [Formation.code] round-trips through
/// [formationByCode]: `'C|GK,LB,…'` — compact, readable in the database,
/// and decodable by every existing consumer without a schema change.
Formation? customFormation(List<Position> positions) {
  final problem = customFormationProblem(positions);
  if (problem != null) return null;

  // The occurrence index of each position so far — the anchor spread
  // places same-position slots symmetrically (first CB left, second
  // right, third centre).
  final seen = <Position, int>{};
  final counts = <Position, int>{};
  for (final p in positions) {
    counts.update(p, (n) => n + 1, ifAbsent: () => 1);
  }
  final slots = <FormationSlot>[];
  for (final p in positions) {
    final n = seen.update(p, (v) => v + 1, ifAbsent: () => 0);
    final (x, y) = customAnchors(p, n, counts[p]!);
    slots.add(FormationSlot(p, x, y));
  }

  // The code the formation serialises to. Positions in slot order,
  // comma-separated, GK first — decoded verbatim by formationByCode.
  final code = '$kCustomFormationPrefix${positions.map((p) => p.code).join(',')}';
  return Formation(code, 'Custom', slots);
}

/// True when [code] is a custom-formation code (see [customFormation]).
bool isCustomFormationCode(String code) =>
    code.startsWith(kCustomFormationPrefix);

/// Uppercase position codes for decode validation (see
/// [tryParseCustomFormation] — fromCode throws on unknowns).
final Set<String> _positionCodes = {
  for (final p in Position.values) p.code,
};

/// Decodes a custom-formation code produced by [customFormation] (legacy
/// `'C|GK,LB,…'`) or [customGridFormation] (`'C|GK@2.0,LB@0.1,…'`). Any
/// malformed code resolves to null — callers fall back to the default
/// shape rather than crashing on a bad database value.
Formation? tryParseCustomFormation(String code) {
  if (!isCustomFormationCode(code)) return null;
  final body = code.substring(kCustomFormationPrefix.length);
  final parts = body.split(',');
  if (parts.length != Formation.startingXiSize) return null;
  final positions = <Position>[];
  final cells = <GridCell>[];
  final isGrid = parts.any((part) => part.contains('@'));
  for (final part in parts) {
    final bits = part.split('@');
    if (bits.length != (isGrid ? 2 : 1)) return null;
    // Unknown codes (a corrupted or hand-edited database value) must
    // not throw: the whole code is rejected and the caller falls back
    // to the default shape.
    if (!_positionCodes.contains(bits[0].toUpperCase())) return null;
    positions.add(Position.fromCode(bits[0]));
    if (isGrid) {
      final rc = bits[1].split('.');
      if (rc.length != 2) return null;
      final col = int.tryParse(rc[0]);
      final row = int.tryParse(rc[1]);
      if (col == null || row == null) return null;
      cells.add(GridCell(col, row));
    }
  }
  return isGrid ? customGridFormation(positions, cells) : customFormation(positions);
}

/// Resolves any formation code: a preset ('4-3-3'), a custom
/// ('C|GK,…'), or a fallback to the default shape for anything
/// unknown — the drop-in replacement every `formationByCode` caller
/// can switch to when it must also honour custom shapes.
Formation formationOfCode(String code) {
  if (isCustomFormationCode(code)) {
    return tryParseCustomFormation(code) ?? formations.first;
  }
  return formationByCode(code);
}

// ---------------------------------------------------------------------------
// The pitch GRID (owner request 2026-11-13: "chess grid, like FM 26")
// ---------------------------------------------------------------------------
//
// The Team-tab pitch is a fixed chess-like grid of [kGridCols] columns ×
// [kGridRows] rows (row 0 = the keeper's row at the bottom). Every XI slot
// stands on ONE cell; dragging a player moves him to another cell and
// nothing else re-arranges — no re-spreading, no placeholders appearing
// and disappearing. What a cell ASKS FOR is a pure function of the cell
// ([positionOfCell]); a man standing out of his cell's position simply
// shows the compatibility warn mark and the match engine's compat factor
// applies (exactly like a preset slot).
//
// Persistence: a grid formation serialises as `'C|GK@2.0,LB@0.1,…'`
// (position `@` column `.` row, slot order, GK first). Presets and legacy
// custom codes carry no cells; [gridCellsOf] snaps their coordinates.

/// Grid size: columns (left → right) and rows (own goal → opponent goal).
const int kGridCols = 5;
const int kGridRows = 6;

/// The keeper's fixed cell: bottom row, centre column. Row 0 holds no other
/// cell.
const int kGridKeeperCol = 2;

/// One cell of the pitch grid.
class GridCell {
  const GridCell(this.col, this.row);

  final int col;
  final int row;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.col == col && other.row == row;

  @override
  int get hashCode => col * 31 + row;

  @override
  String toString() => 'GridCell($col, $row)';
}

/// True when ([col], [row]) is a cell a slot may stand on: inside the grid,
/// and in the keeper's row only the keeper's own cell.
bool isGridCellAllowed(int col, int row) =>
    col >= 0 &&
    col < kGridCols &&
    row >= 0 &&
    row < kGridRows &&
    (row > 0 || col == kGridKeeperCol);

/// What the cell ([col], [row]) asks for. Rows, back to front:
/// 1 LB · CB · RB, 2 LB · CDM · RB, 3 LM · CM · RM, 4 LW · CAM · RW,
/// 5 LW · ST · RW (the outer columns are the wings).
Position positionOfCell(int col, int row) {
  final side = col == 0 ? -1 : (col == kGridCols - 1 ? 1 : 0);
  Position pick(Position left, Position centre, Position right) =>
      side < 0 ? left : (side > 0 ? right : centre);
  return switch (row) {
    0 => Position.gk,
    1 => pick(Position.lb, Position.cb, Position.rb),
    2 => pick(Position.lb, Position.cdm, Position.rb),
    3 => pick(Position.lm, Position.cm, Position.rm),
    4 => pick(Position.lw, Position.cam, Position.rw),
    _ => pick(Position.lw, Position.st, Position.rw),
  };
}

/// The pitch coordinates (x, y percent) of a cell's centre.
(double, double) gridCellCentre(GridCell cell) => (
  (cell.col + 0.5) / kGridCols * 100,
  (cell.row + 0.5) / kGridRows * 100,
);

/// The legal-mix check of a grid formation. The owner's per-position
/// MAXIMUMS stay the law ([positionCaps]); the minimums do not apply on
/// the grid — a man must be free to leave a place before another arrives
/// (moving a centre back would otherwise be impossible). Returns null when
/// legal, else the reason.
String? gridFormationProblem(List<Position> positions, List<GridCell> cells) {
  if (positions.length != Formation.startingXiSize ||
      cells.length != Formation.startingXiSize) {
    return 'A formation needs exactly ${Formation.startingXiSize} slots.';
  }
  if (positions.first != Position.gk ||
      cells.first != const GridCell(kGridKeeperCol, 0)) {
    return 'The goalkeeper keeps his slot — GK must come first.';
  }
  final seen = <GridCell>{};
  for (final c in cells) {
    if (!isGridCellAllowed(c.col, c.row)) {
      return 'That is not a place on the pitch.';
    }
    if (!seen.add(c)) return 'Two players cannot share a place.';
  }
  final counts = <Position, int>{};
  for (final p in positions) {
    counts.update(p, (n) => n + 1, ifAbsent: () => 1);
  }
  for (final e in counts.entries) {
    final max = positionCaps[e.key]!.$2;
    if (e.value > max) {
      return 'Too many ${e.key.code}s — a custom formation fields at most '
          '$max.';
    }
  }
  return null;
}

/// True when [code] is a grid code (`'C|GK@2.0,…'`).
bool isGridFormationCode(String code) =>
    isCustomFormationCode(code) && code.contains('@');

/// Builds a grid formation: slot i asks for [positions]`[i]` and stands on
/// [cells]`[i]`. Null when [gridFormationProblem] says the mix is illegal.
Formation? customGridFormation(List<Position> positions, List<GridCell> cells) {
  if (gridFormationProblem(positions, cells) != null) return null;
  final slots = <FormationSlot>[];
  for (var i = 0; i < positions.length; i++) {
    final (x, y) = gridCellCentre(cells[i]);
    slots.add(FormationSlot(positions[i], x, y));
  }
  final code = '$kCustomFormationPrefix${[
    for (var i = 0; i < positions.length; i++)
      '${positions[i].code}@${cells[i].col}.${cells[i].row}',
  ].join(',')}';
  return Formation(code, 'Custom', slots);
}

/// The cell every slot of [formation] stands on, slot order. A grid
/// formation reads its own cells back; a preset (or legacy custom) snaps its
/// coordinates to the nearest free cell — the snap keeps the keeper on his
/// cell, rows ordered back to front, and resolves two slots that land on
/// one cell by moving the later one to the nearest free cell. Deterministic.
List<GridCell> gridCellsOf(Formation formation) {
  final slots = formation.slots;
  if (isGridFormationCode(formation.code)) {
    return [
      for (final s in slots)
        GridCell(
          (s.x / 100 * kGridCols).floor().clamp(0, kGridCols - 1),
          (s.y / 100 * kGridRows).floor().clamp(0, kGridRows - 1),
        ),
    ];
  }
  final taken = <GridCell>{};
  final out = <GridCell>[];
  for (var i = 0; i < slots.length; i++) {
    var want = i == 0
        ? const GridCell(kGridKeeperCol, 0)
        : GridCell(
            (slots[i].x / 100 * kGridCols).floor().clamp(0, kGridCols - 1),
            ((slots[i].y - _gkY) / (_stY - _gkY) * (kGridRows - 1))
                .round()
                .clamp(0, kGridRows - 1),
          );
    if (!isGridCellAllowed(want.col, want.row) || taken.contains(want)) {
      want = _nearestFreeCell(want, taken);
    }
    taken.add(want);
    out.add(want);
  }
  return out;
}

GridCell _nearestFreeCell(GridCell from, Set<GridCell> taken) {
  GridCell? best;
  var bestD = 1 << 30;
  for (var row = 1; row < kGridRows; row++) {
    for (var col = 0; col < kGridCols; col++) {
      final c = GridCell(col, row);
      if (taken.contains(c)) continue;
      final d = (col - from.col) * (col - from.col) +
          (row - from.row) * (row - from.row);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
  }
  return best ?? const GridCell(0, 1);
}
