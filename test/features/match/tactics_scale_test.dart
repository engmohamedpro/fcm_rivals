/// T-0063: the generic enum-scale helpers — `enumFromScale` /
/// `enumToScale` — and the mapping contract for every ordered tactic
/// axis: round-trips, defaults at 50, clamping, boundary rounding and
/// the nine-axis polarity table (the scale-100 end is always the
/// aggressive/riskier step, locked so a future enum reorder cannot
/// silently flip a slider).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/in_possession_tactics.dart';
import 'package:fcm_rivals/features/match/out_of_possession_tactics.dart';
import 'package:fcm_rivals/features/match/team_tactics.dart';
import 'package:fcm_rivals/features/match/transition_tactics.dart';

/// One ordered axis under test: its values, its DEFAULT (which must
/// map to scale 50 — the slider's centre tick) and the value the
/// scale-100 end must carry (the aggressive/riskier step).
class _Axis<T extends Enum> {
  const _Axis(this.name, this.values, this.defaultValue, this.aggressiveEnd);

  final String name;
  final List<T> values;
  final T defaultValue;
  final T aggressiveEnd;
}

void main() {
  final axes = <_Axis>[
    _Axis(
      'BuildUpStyle',
      BuildUpStyle.values,
      BuildUpStyle.mixed,
      BuildUpStyle.longBall,
    ),
    _Axis(
      'AttackTempo',
      AttackTempo.values,
      AttackTempo.standard,
      AttackTempo.fast,
    ),
    _Axis(
      'AttackWidth',
      AttackWidth.values,
      AttackWidth.standard,
      AttackWidth.wide,
    ),
    _Axis(
      'DefensiveLine',
      DefensiveLine.values,
      DefensiveLine.standard,
      DefensiveLine.high,
    ),
    _Axis(
      'PressingIntensity',
      PressingIntensity.values,
      PressingIntensity.mid,
      PressingIntensity.high,
    ),
    _Axis(
      'TacklingAggression',
      TacklingAggression.values,
      TacklingAggression.balanced,
      TacklingAggression.aggressive,
    ),
    _Axis(
      'CounterPress',
      CounterPress.values,
      CounterPress.balanced,
      CounterPress.immediate,
    ),
    _Axis(
      'AttackOnRecovery',
      AttackOnRecovery.values,
      AttackOnRecovery.balanced,
      AttackOnRecovery.fast,
    ),
    _Axis(
      'RestDefence',
      RestDefence.values,
      RestDefence.standard,
      RestDefence.aggressive,
    ),
    _Axis(
      'Mentality',
      Mentality.values,
      Mentality.balanced,
      Mentality.veryAttacking,
    ),
  ];

  group('enum-scale helpers: round-trips and defaults', () {
    test('every value round-trips through the scale on every axis', () {
      for (final axis in axes) {
        for (final v in axis.values) {
          final scale = enumToScale(axis.values, v);
          expect(
            enumFromScale(axis.values, scale),
            same(v),
            reason:
                '${axis.name}: $v ↔ scale $scale must round-trip '
                'exactly',
          );
        }
      }
    });

    test('every default maps to scale 50 (the centre tick)', () {
      for (final axis in axes) {
        expect(
          enumToScale(axis.values, axis.defaultValue),
          50,
          reason:
              '${axis.name}: the default (${axis.defaultValue.name}) sits '
              'at the middle index, so it must map to 50',
        );
      }
    });

    test('out-of-range scales clamp to the first / last value', () {
      for (final axis in axes) {
        expect(
          enumFromScale(axis.values, -5),
          same(axis.values.first),
          reason: '${axis.name}: -5 clamps to the first value',
        );
        expect(
          enumFromScale(axis.values, 105),
          same(axis.values.last),
          reason: '${axis.name}: 105 clamps to the last value',
        );
      }
    });
  });

  group('enum-scale helpers: boundary rounding', () {
    test('3 steps — scale 25 maps to the middle value, 75 to the last', () {
      // round(25 * 2 / 100) = round(0.5) = 1 (half away from zero);
      // round(75 * 2 / 100) = round(1.5) = 2.
      for (final axis in axes) {
        if (axis.values.length != 3) continue;
        expect(enumFromScale(axis.values, 25), same(axis.values[1]));
        expect(enumFromScale(axis.values, 75), same(axis.values[2]));
        // And the mirrored boundaries: 24 → first, 26 stays middle.
        expect(enumFromScale(axis.values, 24), same(axis.values[0]));
        expect(enumFromScale(axis.values, 26), same(axis.values[1]));
      }
    });

    test('7 steps (mentality) — 58 → Balanced, 59 → Positive', () {
      // round(58 * 6 / 100) = round(3.48) = 3 (Balanced);
      // round(59 * 6 / 100) = round(3.54) = 4 (Positive).
      expect(enumFromScale(Mentality.values, 58), Mentality.balanced);
      expect(enumFromScale(Mentality.values, 59), Mentality.positive);
      // The canonical positions themselves: 0, 17, 33, 50, 67, 83, 100.
      expect(mentalityToScale(Mentality.veryDefensive), 0);
      expect(mentalityToScale(Mentality.balanced), 50);
      expect(mentalityToScale(Mentality.veryAttacking), 100);
    });
  });

  group('enum-scale helpers: polarity guard (the 100 end is the risky step)', () {
    test('the nine ordered axes put their aggressive end at scale 100', () {
      const expected = <String, String>{
        'BuildUpStyle': 'longBall',
        'AttackTempo': 'fast',
        'AttackWidth': 'wide',
        'DefensiveLine': 'high',
        'PressingIntensity': 'high',
        'TacklingAggression': 'aggressive',
        'CounterPress': 'immediate',
        'AttackOnRecovery': 'fast',
        'RestDefence': 'aggressive',
      };
      for (final axis in axes) {
        final name = axis.name;
        if (!expected.containsKey(name)) continue; // mentality checked below
        expect(
          enumFromScale(axis.values, 100).name,
          expected[name],
          reason:
              '$name: scale 100 must be the aggressive/riskier step '
              '(${expected[name]}) — an enum reorder that flips this must '
              'fail CI, not the slider',
        );
        expect(
          enumToScale(axis.values, axis.aggressiveEnd),
          100,
          reason: '$name: the aggressive end must map back to 100',
        );
      }
      // Mentality polarity: 100 = Very Attacking (the owner's GDD 10.3).
      expect(enumFromScale(Mentality.values, 100), Mentality.veryAttacking);
    });
  });
}
