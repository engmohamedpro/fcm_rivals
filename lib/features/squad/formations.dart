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
/// owner's exact ladder, 2026-11-12). GK is exactly 1 — the keeper's
/// slot never changes. LM/RM get 0-1: the dataset carries 393 LM and
/// 457 RM players and the preset shapes use them as wide men, so a
/// custom shape may field one of each.
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
  Position.cb: (0, 3),
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
  for (final e in counts.entries) {
    final cap = positionCaps[e.key]!;
    if (e.value < cap.$1 || e.value > cap.$2) {
      return 'Too many ${e.key.code}s — a custom formation fields '
          '${cap.$1 == cap.$2 ? 'exactly ${cap.$1}' : '${cap.$1} to ${cap.$2}'}.';
    }
  }
  return null;
}

/// The canonical pitch anchors a custom formation places its slots at,
/// keyed by (position, occurrence index) — first CB, second CB, third
/// CB. Multiple slots of one position share a symmetric spread around
/// the position's home x, so two STs read as a strike PAIR, three CBs
/// as a back three, whatever slots they landed in.
///
/// The x/y values follow the same depth ladder and symmetry rules the
/// preset formations use (see the ladder above), so a custom shape
/// looks native on the pitch.
const Map<Position, List<(double x, double y)>> _customAnchors = {
  // The keeper: home, exactly one, slot 0.
  Position.gk: [(50, _gkY)],
  // Back line.
  Position.cb: [(36, _cbY), (64, _cbY), (50, _cbMidY)],
  Position.lb: [(14, _fbY)],
  Position.rb: [(86, _fbY)],
  // Midfield.
  Position.cdm: [(36, _cdmY), (64, _cdmY), (50, _cdmY)],
  Position.cm: [(32, _cmY), (68, _cmY), (50, _cmY)],
  Position.cam: [(32, _camY), (68, _camY), (50, _camY)],
  Position.lm: [(12, _wbY)],
  Position.rm: [(88, _wbY)],
  // Attack.
  Position.lw: [(16, _lwY)],
  Position.rw: [(84, _lwY)],
  Position.st: [(40, _stY), (60, _stY)],
};

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

  // The occurrence index of each position so far — the anchor table
  // spreads same-position slots symmetrically (first CB left, second
  // right, third centre).
  final seen = <Position, int>{};
  final slots = <FormationSlot>[];
  for (final p in positions) {
    final n = seen.update(p, (v) => v + 1, ifAbsent: () => 0);
    final anchor = _customAnchors[p]![n.clamp(0, _customAnchors[p]!.length - 1)];
    slots.add(FormationSlot(p, anchor.$1, anchor.$2));
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

/// Decodes a custom-formation code produced by [customFormation]. Any
/// malformed code resolves to null — callers fall back to the default
/// shape rather than crashing on a bad database value.
Formation? tryParseCustomFormation(String code) {
  if (!isCustomFormationCode(code)) return null;
  final body = code.substring(kCustomFormationPrefix.length);
  final parts = body.split(',');
  if (parts.length != Formation.startingXiSize) return null;
  final positions = <Position>[];
  for (final part in parts) {
    // Unknown codes (a corrupted or hand-edited database value) must
    // not throw: the whole code is rejected and the caller falls back
    // to the default shape.
    if (!_positionCodes.contains(part.toUpperCase())) return null;
    positions.add(Position.fromCode(part));
  }
  return customFormation(positions);
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
