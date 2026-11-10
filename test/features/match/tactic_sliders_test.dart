// The continuous 0–99 tactic sliders: the blend math between the tuned
// anchors, the per-group storage (override vs. nearest enum step), the
// normalisation invariants, persistence, and the slider wording.
//
// The headline guarantee: a slider parked exactly on an old enum step
// (0 / 50 / 99) behaves BIT-IDENTICALLY to that step, so every balance
// anchor the harness tuned still holds; only positions between anchors
// are new, and those are geometric blends of two tuned bundles.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/tactic_axis_copy.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

List<double> _fields(TacticModifiers m) => [
  m.attack,
  m.defence,
  m.possession,
  m.chance,
  m.stamina,
  m.passAccuracy,
  m.shotQuality,
];

void expectSameBundle(TacticModifiers actual, TacticModifiers expected) {
  expect(_fields(actual), _fields(expected));
}

void main() {
  group('step <-> scale mapping', () {
    test('three steps sit at 0, 50 and 99', () {
      expect(stepToScale(0, 3), 0);
      expect(stepToScale(1, 3), 50);
      expect(stepToScale(2, 3), 99);
    });

    test('step boundaries are 25 and 75, and out-of-range values clamp', () {
      expect(scaleToStep(24, 3), 0);
      expect(scaleToStep(25, 3), 1);
      expect(scaleToStep(74, 3), 1);
      expect(scaleToStep(75, 3), 2);
      expect(scaleToStep(99, 3), 2);
      expect(scaleToStep(-5, 3), 0);
      expect(scaleToStep(500, 3), 2);
    });

    test('every anchor round-trips through step and back', () {
      for (var i = 0; i < 3; i++) {
        expect(scaleToStep(stepToScale(i, 3), 3), i);
      }
    });
  });

  group('axisModifiers: blend between three anchors', () {
    const low = TacticModifiers(chance: 0.90, defence: 1.10);
    const high = TacticModifiers(chance: 1.20, stamina: 1.30);

    TacticModifiers at(int v) => axisModifiers(
      low: low,
      mid: TacticModifiers.identity,
      high: high,
      value: v,
    );

    test('the three anchors return their bundle exactly', () {
      expect(identical(at(0), low), isTrue);
      expect(identical(at(50), TacticModifiers.identity), isTrue);
      expect(identical(at(99), high), isTrue);
    });

    test('out-of-range values clamp to the ends', () {
      expect(identical(at(-3), low), isTrue);
      expect(identical(at(200), high), isTrue);
    });

    test('halfway is the geometric mean, on both sides of the default', () {
      expect(at(25).chance, closeTo(math.sqrt(0.90), 1e-12));
      expect(at(25).defence, closeTo(math.sqrt(1.10), 1e-12));
      expect(at(75).chance, closeTo(math.pow(1.20, 25 / 49), 1e-12));
      expect(at(75).stamina, closeTo(math.pow(1.30, 25 / 49), 1e-12));
    });

    test('monotonic and never outside the anchors', () {
      for (var v = 1; v <= 99; v++) {
        // chance rises from 0.90 (v=0) through 1.0 (v=50) to 1.20 (v=99).
        expect(at(v).chance, greaterThanOrEqualTo(at(v - 1).chance));
        expect(at(v).chance, inInclusiveRange(0.90, 1.20));
        // defence falls from 1.10 (v=0) to 1.0 (v>=50) and stays there.
        expect(at(v).defence, lessThanOrEqualTo(at(v - 1).defence));
        expect(at(v).defence, inInclusiveRange(1.0, 1.10));
      }
    });

    test('axisScalar follows the same shape', () {
      double s(int v) => axisScalar(low: 0.75, mid: 1.0, high: 1.30, value: v);
      expect(s(0), 0.75);
      expect(s(50), 1.0);
      expect(s(99), 1.30);
      expect(s(25), closeTo(math.sqrt(0.75), 1e-12));
    });

    test('mirrorModifiers is the reciprocal bundle', () {
      const m = TacticModifiers(chance: 1.04, shotQuality: 0.95);
      final mirror = mirrorModifiers(m);
      expect(m.chance * mirror.chance, closeTo(1.0, 1e-12));
      expect(m.shotQuality * mirror.shotQuality, closeTo(1.0, 1e-12));
      expect(mirror.attack, 1.0);
    });
  });

  group('InPossessionTactics sliders', () {
    test('defaults: every slider at 50, no overrides', () {
      const ip = InPossessionTactics();
      for (final axis in InPossessionTactics.axes) {
        expect(ip.scaleOf(axis), 50, reason: axis.name);
      }
      expect(ip.scales, isEmpty);
      expect(ip.isDefault, isTrue);
    });

    test('a slider on an old step is bit-identical to that enum step', () {
      for (final e in AttackTempo.values) {
        final viaSlider = const InPossessionTactics().withScale(
          TacticAxisId.tempo,
          stepToScale(e.index, 3),
        );
        final viaEnum = InPossessionTactics(tempo: e);
        expect(viaSlider.scales, isEmpty, reason: e.name);
        expect(viaSlider, viaEnum, reason: e.name);
        expectSameBundle(viaSlider.modifiers, viaEnum.modifiers);
      }
    });

    test('99 on tempo is exactly Fast', () {
      final ip = const InPossessionTactics().withScale(TacticAxisId.tempo, 99);
      expect(ip.tempo, AttackTempo.fast);
      expect(ip.scales, isEmpty);
      expect(ip, const InPossessionTactics(tempo: AttackTempo.fast));
    });

    test('between anchors: stored override, nearest enum step, blended '
        'bundle', () {
      final ip = const InPossessionTactics().withScale(TacticAxisId.width, 70);
      expect(ip.width, AttackWidth.standard, reason: 'nearest step');
      expect(ip.scales, {'width': 70});
      expect(ip.scaleOf(TacticAxisId.width), 70);
      expect(ip.isDefault, isFalse);
      // Wide anchors chance 1.03 / passAccuracy 0.96; 70 is 20/49 of the
      // way there, in log space.
      expect(ip.modifiers.chance, closeTo(math.pow(1.03, 20 / 49), 1e-9));
      expect(
        ip.modifiers.passAccuracy,
        closeTo(math.pow(0.96, 20 / 49), 1e-9),
      );
    });

    test('sliding back to the default restores the default tactics', () {
      final back = const InPossessionTactics()
          .withScale(TacticAxisId.width, 70)
          .withScale(TacticAxisId.width, 50);
      expect(back, const InPossessionTactics());
      expect(back.isDefault, isTrue);
    });

    test('choosing an exact enum step drops that instruction\'s override', () {
      final ip = const InPossessionTactics()
          .withScale(TacticAxisId.width, 70)
          .copyWith(width: AttackWidth.wide);
      expect(ip.width, AttackWidth.wide);
      expect(ip.scales, isEmpty);
    });

    test('an axis of another group leaves the group unchanged', () {
      const ip = InPossessionTactics();
      expect(ip.withScale(TacticAxisId.pressing, 10), ip);
    });

    group('final third = shot selection + crossing', () {
      test('exact old positions collapse back to the enum option', () {
        const base = InPossessionTactics();
        expect(
          base.withScale(TacticAxisId.shotSelection, 0).finalThird,
          FinalThirdApproach.workBallIntoBox,
        );
        expect(
          base.withScale(TacticAxisId.shotSelection, 99).finalThird,
          FinalThirdApproach.shootOnSight,
        );
        final early = base.withScale(TacticAxisId.crossing, 99);
        expect(early.finalThird, FinalThirdApproach.earlyCrosses);
        for (final ip in [
          base.withScale(TacticAxisId.shotSelection, 0),
          base.withScale(TacticAxisId.shotSelection, 99),
          early,
        ]) {
          expect(ip.scales, isEmpty);
        }
      });

      test('shot selection between anchors blends work-ball <-> balanced',
          () {
        final ip = const InPossessionTactics().withScale(
          TacticAxisId.shotSelection,
          30,
        );
        expect(ip.finalThird, FinalThirdApproach.balanced);
        expect(ip.scaleOf(TacticAxisId.shotSelection), 30);
        expect(ip.scaleOf(TacticAxisId.crossing), 50);
        // Work Ball anchors chance 0.92 / shotQuality 1.10; 30 is 20/50
        // of the way to the low end.
        expect(ip.modifiers.chance, closeTo(math.pow(0.92, 0.4), 1e-9));
        expect(ip.modifiers.shotQuality, closeTo(math.pow(1.10, 0.4), 1e-9));
      });

      test('crossing low end is the mirror of the Early Crosses anchor', () {
        final ip = const InPossessionTactics().withScale(
          TacticAxisId.crossing,
          0,
        );
        expect(ip.scaleOf(TacticAxisId.crossing), 0);
        expect(ip.finalThird, FinalThirdApproach.balanced);
        expect(ip.modifiers.chance, closeTo(1 / 1.04, 1e-12));
        expect(ip.modifiers.shotQuality, closeTo(1 / 0.95, 1e-12));
        expect(ip.modifiers.passAccuracy, closeTo(1 / 0.96, 1e-12));
      });

      test('a legacy Early Crosses save reads as crossing 99 and keeps '
          'its behaviour when only shot selection moves', () {
        const legacy = InPossessionTactics(
          finalThird: FinalThirdApproach.earlyCrosses,
        );
        expect(legacy.scaleOf(TacticAxisId.crossing), 99);
        expect(legacy.scaleOf(TacticAxisId.shotSelection), 50);
        final moved = legacy.withScale(TacticAxisId.shotSelection, 10);
        expect(moved.scaleOf(TacticAxisId.crossing), 99);
        expect(moved.scaleOf(TacticAxisId.shotSelection), 10);
        expect(moved.finalThird, FinalThirdApproach.earlyCrosses);
      });
    });
  });

  group('OutOfPossessionTactics sliders', () {
    test('defaults: 50 everywhere; foul and yellow scales are 1.0', () {
      const oop = OutOfPossessionTactics();
      for (final axis in OutOfPossessionTactics.axes) {
        expect(oop.scaleOf(axis), 50);
      }
      expect(oop.foulScale, 1.0);
      expect(oop.yellowScale, 1.0);
      expect(oop.isDefault, isTrue);
    });

    test('pressing on an old step is bit-identical to the enum', () {
      for (final e in PressingIntensity.values) {
        final viaSlider = const OutOfPossessionTactics().withScale(
          TacticAxisId.pressing,
          stepToScale(e.index, 3),
        );
        final viaEnum = OutOfPossessionTactics(pressing: e);
        expect(viaSlider, viaEnum, reason: e.name);
        expectSameBundle(viaSlider.modifiers, viaEnum.modifiers);
      }
    });

    test('tackling: foul and yellow scales hit the tuned anchors exactly', () {
      for (final e in TacklingAggression.values) {
        final oop = const OutOfPossessionTactics().withScale(
          TacticAxisId.tackling,
          stepToScale(e.index, 3),
        );
        expect(oop.tackling, e);
        expect(oop.foulScale, e.foulScale, reason: e.name);
        expect(oop.yellowScale, e.yellowScale, reason: e.name);
      }
    });

    test('tackling between anchors blends the foul rate smoothly', () {
      final oop = const OutOfPossessionTactics().withScale(
        TacticAxisId.tackling,
        25,
      );
      expect(oop.tackling, TacklingAggression.balanced);
      expect(oop.foulScale, closeTo(math.sqrt(0.75), 1e-12));
      expect(oop.yellowScale, closeTo(math.sqrt(0.70), 1e-12));
      // Strictly between Clean and Balanced.
      expect(oop.foulScale, inExclusiveRange(0.75, 1.0));
      // And the aggressive half rises monotonically towards 1.30.
      var last = 1.0;
      for (var v = 51; v <= 99; v++) {
        final f = const OutOfPossessionTactics()
            .withScale(TacticAxisId.tackling, v)
            .foulScale;
        expect(f, greaterThanOrEqualTo(last));
        last = f;
      }
      expect(last, closeTo(1.30, 1e-12));
    });

    test('defensive line 10: nearest step Deep, blended defence', () {
      final oop = const OutOfPossessionTactics().withScale(
        TacticAxisId.defensiveLine,
        10,
      );
      expect(oop.defensiveLine, DefensiveLine.deep);
      expect(oop.scales, {'defensiveLine': 10});
      // Deep anchors defence 1.05; 10 is 40/50 = 0.8 of the way.
      expect(oop.modifiers.defence, closeTo(math.pow(1.05, 0.8), 1e-9));
    });

    test('the offside trap switch is independent of the sliders', () {
      final oop = const OutOfPossessionTactics()
          .withScale(TacticAxisId.pressing, 80)
          .copyWith(offsideTrap: true);
      expect(oop.offsideTrap, isTrue);
      expect(oop.scaleOf(TacticAxisId.pressing), 80);
    });
  });

  group('TransitionTactics sliders', () {
    test('rest defence 99 is exactly Aggressive; counter-press 80 is '
        'Immediate with an override', () {
      final rest = const TransitionTactics().withScale(
        TacticAxisId.restDefence,
        99,
      );
      expect(rest.restDefence, RestDefence.aggressive);
      expect(rest.scales, isEmpty);

      final cp = const TransitionTactics().withScale(
        TacticAxisId.counterPress,
        80,
      );
      expect(cp.counterPress, CounterPress.immediate);
      expect(cp.scales, {'counterPress': 80});
      expect(cp.scaleOf(TacticAxisId.counterPress), 80);
    });

    test('attack on recovery on an old step is bit-identical', () {
      for (final e in AttackOnRecovery.values) {
        final viaSlider = const TransitionTactics().withScale(
          TacticAxisId.attackOnRecovery,
          stepToScale(e.index, 3),
        );
        final viaEnum = TransitionTactics(attackOnRecovery: e);
        expect(viaSlider, viaEnum, reason: e.name);
        expectSameBundle(viaSlider.modifiers, viaEnum.modifiers);
      }
    });
  });

  group('persistence', () {
    TeamTactics custom() => TeamTactics(
      inPossession: const InPossessionTactics()
          .withScale(TacticAxisId.width, 70)
          .withScale(TacticAxisId.tempo, 12)
          .withScale(TacticAxisId.shotSelection, 30),
      outOfPossession: const OutOfPossessionTactics()
          .withScale(TacticAxisId.pressing, 88)
          .withScale(TacticAxisId.tackling, 33)
          .copyWith(offsideTrap: true),
      transitions: const TransitionTactics().withScale(
        TacticAxisId.restDefence,
        61,
      ),
    );

    test('custom sliders round-trip through the DB payload', () {
      final t = custom();
      final back = tacticsFromDbPayload(jsonEncode(t.toJson()));
      expect(back, t);
      expectSameBundle(back.modifiers, t.modifiers);
      expect(back.outOfPossession.foulScale, t.outOfPossession.foulScale);
    });

    test('a tactics object with no overrides writes no scales key', () {
      final json = const TeamTactics(
        inPossession: InPossessionTactics(tempo: AttackTempo.fast),
      ).toJson();
      expect(json['inPossession'], {'tempo': 'fast'});
    });

    test('a pre-slider save loads exactly as before', () {
      final t = tacticsFromDbPayload(
        '{"inPossession":{"tempo":"fast","finalThird":"earlyCrosses"},'
        '"outOfPossession":{"pressing":"high","offsideTrap":true},'
        '"transitions":{"restDefence":"aggressive"}}',
      );
      expect(t.inPossession.tempo, AttackTempo.fast);
      expect(t.inPossession.finalThird, FinalThirdApproach.earlyCrosses);
      expect(t.outOfPossession.pressing, PressingIntensity.high);
      expect(t.outOfPossession.offsideTrap, isTrue);
      expect(t.transitions.restDefence, RestDefence.aggressive);
      expect(t.inPossession.scales, isEmpty);
    });

    test('garbage overrides are clamped, ignored or dropped, never thrown',
        () {
      final t = tacticsFromDbPayload(
        '{"inPossession":{"scales":{"tempo":500,"buildUp":-4,'
        '"width":"wide","bogus":3,"pressing":9}}}',
      );
      // 500 clamps to 99 -> exactly Fast; -4 clamps to 0 -> exactly Play
      // Out; a string is ignored; unknown and foreign-group keys dropped.
      expect(t.inPossession.tempo, AttackTempo.fast);
      expect(t.inPossession.buildUp, BuildUpStyle.playOut);
      expect(t.inPossession.width, AttackWidth.standard);
      expect(t.inPossession.scales, isEmpty);
      expect(t.outOfPossession.isDefault, isTrue);
    });

    test('a stored override wins over a contradicting enum name', () {
      final t = tacticsFromDbPayload(
        '{"inPossession":{"tempo":"slow","scales":{"tempo":70}}}',
      );
      expect(t.inPossession.tempo, AttackTempo.standard);
      expect(t.inPossession.scaleOf(TacticAxisId.tempo), 70);
    });

    test('the summary label counts a slid group as custom', () {
      expect(const TeamTactics().label, 'Balanced');
      expect(custom().label, 'Custom (3/3)');
      final one = const TeamTactics().copyWith(
        inPossession: const InPossessionTactics().withScale(
          TacticAxisId.width,
          70,
        ),
      );
      expect(one.label, 'Custom (1/3)');
    });

    test('equal behaviour, equal object, equal hash', () {
      final a = const InPossessionTactics()
          .withScale(TacticAxisId.width, 70)
          .withScale(TacticAxisId.tempo, 20);
      final b = const InPossessionTactics()
          .withScale(TacticAxisId.tempo, 20)
          .withScale(TacticAxisId.width, 70);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('slider wording (EN + AR)', () {
    test('every slider has a name and five distinct bands in both '
        'languages', () {
      for (final axis in TacticAxisId.values) {
        final copy = kTacticAxisCopy[axis];
        expect(copy, isNotNull, reason: axis.name);
        expect(copy!.bandsEn, hasLength(5), reason: axis.name);
        expect(copy.bandsAr, hasLength(5), reason: axis.name);
        expect(copy.bandsEn.toSet(), hasLength(5), reason: axis.name);
        expect(copy.bandsAr.toSet(), hasLength(5), reason: axis.name);
        expect(copy.nameEn.trim(), isNotEmpty);
        expect(copy.nameAr.trim(), isNotEmpty);
      }
    });

    test('bands split 0-99 into equal fifths', () {
      final w = kTacticAxisCopy[TacticAxisId.width]!;
      String en(int v) => w.band(v, arabic: false);
      expect(en(0), 'Very narrow');
      expect(en(19), 'Very narrow');
      expect(en(20), 'Narrow');
      expect(en(50), 'Standard');
      expect(en(79), 'Wide');
      expect(en(80), 'Very wide');
      expect(en(99), 'Very wide');
      expect(en(-10), 'Very narrow');
      expect(en(400), 'Very wide');
      expect(w.band(0, arabic: true), 'ضيق جداً');
      expect(w.band(99, arabic: true), 'عريض جداً');
    });
  });
}
