/// FCM Rivals — data-driven formation definitions (GDD 6.4).
///
/// A formation is pure data: 11 slots, each a field position with pitch
/// coordinates for rendering (x: 0..100 left→right, y: 0..100 own goal→
/// opponent goal). Adding formations requires no code changes.
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

/// All supported formations (GDD 6.4 examples).
const List<Formation> formations = [
  Formation('4-3-3', '4-3-3', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 14, 24),
    FormationSlot(Position.cb, 36, 18),
    FormationSlot(Position.cb, 64, 18),
    FormationSlot(Position.rb, 86, 24),
    FormationSlot(Position.cdm, 50, 40),
    FormationSlot(Position.cm, 32, 50),
    FormationSlot(Position.cm, 68, 50),
    FormationSlot(Position.lw, 16, 74),
    FormationSlot(Position.st, 50, 84),
    FormationSlot(Position.rw, 84, 74),
  ]),
  Formation('4-2-3-1', '4-2-3-1', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 14, 24),
    FormationSlot(Position.cb, 36, 18),
    FormationSlot(Position.cb, 64, 18),
    FormationSlot(Position.rb, 86, 24),
    FormationSlot(Position.cdm, 36, 42),
    FormationSlot(Position.cdm, 64, 42),
    FormationSlot(Position.lw, 16, 64),
    FormationSlot(Position.cam, 50, 62),
    FormationSlot(Position.rw, 84, 64),
    FormationSlot(Position.st, 50, 84),
  ]),
  Formation('4-4-2', '4-4-2', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 14, 24),
    FormationSlot(Position.cb, 36, 18),
    FormationSlot(Position.cb, 64, 18),
    FormationSlot(Position.rb, 86, 24),
    FormationSlot(Position.lm, 14, 52),
    FormationSlot(Position.cm, 38, 48),
    FormationSlot(Position.cm, 62, 48),
    FormationSlot(Position.rm, 86, 52),
    FormationSlot(Position.st, 40, 82),
    FormationSlot(Position.st, 60, 82),
  ]),
  Formation('4-1-4-1', '4-1-4-1', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 14, 24),
    FormationSlot(Position.cb, 36, 18),
    FormationSlot(Position.cb, 64, 18),
    FormationSlot(Position.rb, 86, 24),
    FormationSlot(Position.cdm, 50, 38),
    FormationSlot(Position.lm, 14, 56),
    FormationSlot(Position.cm, 38, 54),
    FormationSlot(Position.cm, 62, 54),
    FormationSlot(Position.rm, 86, 56),
    FormationSlot(Position.st, 50, 84),
  ]),
  Formation('3-5-2', '3-5-2', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.cb, 28, 18),
    FormationSlot(Position.cb, 50, 16),
    FormationSlot(Position.cb, 72, 18),
    FormationSlot(Position.lm, 12, 48),
    FormationSlot(Position.cm, 34, 44),
    FormationSlot(Position.cdm, 50, 38),
    FormationSlot(Position.cm, 66, 44),
    FormationSlot(Position.rm, 88, 48),
    FormationSlot(Position.st, 40, 82),
    FormationSlot(Position.st, 60, 82),
  ]),
  Formation('3-4-3', '3-4-3', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.cb, 28, 18),
    FormationSlot(Position.cb, 50, 16),
    FormationSlot(Position.cb, 72, 18),
    FormationSlot(Position.lm, 14, 48),
    FormationSlot(Position.cm, 38, 46),
    FormationSlot(Position.cm, 62, 46),
    FormationSlot(Position.rm, 86, 48),
    FormationSlot(Position.lw, 18, 76),
    FormationSlot(Position.st, 50, 84),
    FormationSlot(Position.rw, 82, 76),
  ]),
  Formation('5-3-2', '5-3-2', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 10, 26),
    FormationSlot(Position.cb, 30, 17),
    FormationSlot(Position.cb, 50, 15),
    FormationSlot(Position.cb, 70, 17),
    FormationSlot(Position.rb, 90, 26),
    FormationSlot(Position.cm, 32, 48),
    FormationSlot(Position.cdm, 50, 42),
    FormationSlot(Position.cm, 68, 48),
    FormationSlot(Position.st, 40, 80),
    FormationSlot(Position.st, 60, 80),
  ]),
  Formation('5-4-1', '5-4-1', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 10, 26),
    FormationSlot(Position.cb, 30, 17),
    FormationSlot(Position.cb, 50, 15),
    FormationSlot(Position.cb, 70, 17),
    FormationSlot(Position.rb, 90, 26),
    FormationSlot(Position.lm, 14, 54),
    FormationSlot(Position.cm, 38, 50),
    FormationSlot(Position.cm, 62, 50),
    FormationSlot(Position.rm, 86, 54),
    FormationSlot(Position.st, 50, 82),
  ]),
  Formation('4-2-2-2', '4-2-2-2', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 14, 24),
    FormationSlot(Position.cb, 36, 18),
    FormationSlot(Position.cb, 64, 18),
    FormationSlot(Position.rb, 86, 24),
    FormationSlot(Position.cdm, 36, 42),
    FormationSlot(Position.cdm, 64, 42),
    FormationSlot(Position.cam, 32, 64),
    FormationSlot(Position.cam, 68, 64),
    FormationSlot(Position.st, 40, 82),
    FormationSlot(Position.st, 60, 82),
  ]),
  Formation('4-3-2-1', '4-3-2-1', [
    FormationSlot(Position.gk, 50, 5),
    FormationSlot(Position.lb, 14, 24),
    FormationSlot(Position.cb, 36, 18),
    FormationSlot(Position.cb, 64, 18),
    FormationSlot(Position.rb, 86, 24),
    FormationSlot(Position.cm, 30, 44),
    FormationSlot(Position.cdm, 50, 40),
    FormationSlot(Position.cm, 70, 44),
    FormationSlot(Position.cam, 36, 64),
    FormationSlot(Position.cam, 64, 64),
    FormationSlot(Position.st, 50, 84),
  ]),
];

Formation formationByCode(String code) =>
    formations.firstWhere((f) => f.code == code,
        orElse: () => formations.first);
