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

Formation formationByCode(String code) =>
    formations.firstWhere((f) => f.code == code,
        orElse: () => formations.first);
