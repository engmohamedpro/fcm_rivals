/// FcmScaleSlider behaviour (T-0061 RTL + T-0062 stepped snapping).
///
/// T-0061 — the slider mirrors under an ambient RTL direction (Arabic):
/// the minimum end sits at the RIGHT, the fill spans from the right,
/// dragging LEFT increases the value, and the floating pill clamps
/// inside the track with Arabic text.
///
/// T-0062 — stepped mode: [FcmScaleSlider.steps] named steps make the
/// marker follow the finger but only ever report (and settle on) step
/// positions; free mode stays byte-identical to before.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_scale_slider.dart';

/// A pumpable slider host pinned to [direction] — the track gesture
/// surface carries [_trackKey] so the test can measure its rect
/// directly.
class _SliderHost extends StatelessWidget {
  const _SliderHost({
    required this.direction,
    required this.value,
    required this.onChanged,
    required this.onCommit,
    this.label,
    this.steps,
  });

  final TextDirection direction;
  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onCommit;
  final String? label;

  /// Stepped mode (T-0062); null keeps the free continuous mode.
  final int? steps;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          backgroundColor: const Color(0xFF101018),
          body: Center(
            child: SizedBox(
              width: 320,
              child: FcmScaleSlider(
                value: value,
                steps: steps,
                onChanged: onChanged,
                onChangeEnd: onCommit,
                valueLabel: (v) => label ?? 'قيمة $v',
                minLabel: 'دفاعي جداً',
                maxLabel: 'هجومي جداً',
                semanticsLabel: 'اختبار المقياس',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gold marker: a small circular [Container] inside the slider's
/// stacks — the thumb (2×thumbRadius = 20 logical px).
final Finder thumbFinder = find.byWidgetPredicate(
  (w) => w is Container && w.decoration is BoxDecoration,
);

void main() {

  testWidgets('RTL: value 0 puts the thumb at the right end and the '
      'fill spans from the right', (tester) async {
    var reported = -1;
    await tester.pumpWidget(
      _SliderHost(
        direction: TextDirection.rtl,
        value: 0,
        onChanged: (v) => reported = v,
        onCommit: (_) {},
      ),
    );

    final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
    // Every positioned child of the slider's stacks, scoped to the
    // slider. The thumb (gold circle, 20 wide) at value 0 must sit at
    // the RIGHT end: its centre ≈ track.right - thumbRadius.
    final thumbs = find.descendant(
      of: find.byType(FcmScaleSlider),
      matching: thumbFinder,
    );
    expect(thumbs, findsWidgets);
    // The rightmost small circle-ish container is the thumb.
    Rect? thumbRect;
    for (final t in thumbs.evaluate()) {
      final r = tester.getRect(find.byWidgetPredicate((w) => w == t.widget));
      if (r.width <= 22 && r.height <= 22) {
        if (thumbRect == null || r.left > thumbRect.left) {
          thumbRect = r;
        }
      }
    }
    expect(thumbRect, isNotNull, reason: 'the gold marker must render');
    expect(
      thumbRect!.center.dx,
      closeTo(sliderRect.right - 10, 6),
      reason: 'value 0 must anchor the thumb at the RIGHT end in RTL',
    );
    expect(reported, -1, reason: 'no gesture — no report');
  });

  testWidgets('RTL: dragging from the centre towards the LEFT raises '
      'the value; towards the RIGHT lowers it', (tester) async {
    final values = <int>[];
    var committed = -1;
    await tester.pumpWidget(
      _SliderHost(
        direction: TextDirection.rtl,
        value: 50,
        onChanged: values.add,
        onCommit: (v) => committed = v,
      ),
    );

    final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
    final centre = Offset(
      sliderRect.left + sliderRect.width / 2,
      sliderRect.top + sliderRect.height / 2,
    );

    // Drag LEFT by half the width: RTL mirrors the axis, so the value
    // must RISE (towards 100).
    await tester.dragFrom(centre, Offset(-sliderRect.width / 2, 0));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(values.last, greaterThan(50),
        reason: 'RTL drag left increases the value');
    expect(committed, greaterThan(50), reason: 'the gesture committed');

    // Reset and drag RIGHT: the value must FALL (towards 0).
    final values2 = <int>[];
    await tester.pumpWidget(
      _SliderHost(
        direction: TextDirection.rtl,
        value: 50,
        onChanged: values2.add,
        onCommit: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(centre, Offset(sliderRect.width / 2, 0));
    await tester.pumpAndSettle();
    expect(values2, isNotEmpty);
    expect(values2.last, lessThan(50),
        reason: 'RTL drag right decreases the value');
  });

  testWidgets('RTL: tap-to-set lands mirrored — a tap near the right '
      'edge sets a low value', (tester) async {
    final values = <int>[];
    await tester.pumpWidget(
      _SliderHost(
        direction: TextDirection.rtl,
        value: 50,
        onChanged: values.add,
        onCommit: (_) {},
      ),
    );

    final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
    // In RTL the minimum lives at the right: tapping just inside the
    // right edge must report a small value.
    await tester.tapAt(Offset(
      sliderRect.right - 12,
      sliderRect.top + sliderRect.height / 2,
    ));
    await tester.pumpAndSettle();
    expect(values, isNotEmpty);
    expect(values.last, lessThan(20),
        reason: 'a tap at the RTL right edge (the minimum) sets a low '
            'value');
  });

  testWidgets('RTL: the pill stays clamped inside the track with '
      'Arabic label text', (tester) async {
    await tester.pumpWidget(
      _SliderHost(
        direction: TextDirection.rtl,
        value: 100,
        onChanged: (_) {},
        onCommit: (_) {},
        label: 'هجومي جداً جداً جداً بعنوان طويل',
      ),
    );
    await tester.pumpAndSettle();

    final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
    // The pill is the LONG label ('... بعنوان طويل'); the scale's
    // max caption reads 'هجومي جداً' — the containing finder must stay
    // scoped to the long one only.
    final pill = find.textContaining('بعنوان طويل');
    expect(pill, findsOneWidget);
    final pillRect = tester.getRect(pill);
    // Clamped: the pill never spills past either end of the slider.
    expect(pillRect.left, greaterThanOrEqualTo(sliderRect.left - 1));
    expect(pillRect.right, lessThanOrEqualTo(sliderRect.right + 1));
    // And it rides ABOVE the track band (the pill band is the first
    // 22px of the column), not below it.
    expect(pillRect.bottom, lessThan(sliderRect.top + 30));
  });

  testWidgets('LTR baseline: value 0 keeps the thumb at the LEFT end '
      '(the untouched pre-T-0061 behaviour)', (tester) async {
    await tester.pumpWidget(
      _SliderHost(
        direction: TextDirection.ltr,
        value: 0,
        onChanged: (_) {},
        onCommit: (_) {},
        label: 'Defensive',
      ),
    );

    final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
    final thumbs = find.descendant(
      of: find.byType(FcmScaleSlider),
      matching: thumbFinder,
    );
    Rect? thumbRect;
    for (final t in thumbs.evaluate()) {
      final r = tester.getRect(find.byWidgetPredicate((w) => w == t.widget));
      if (r.width <= 22 && r.height <= 22) {
        if (thumbRect == null || r.left < thumbRect.left) {
          thumbRect = r;
        }
      }
    }
    expect(thumbRect, isNotNull);
    expect(
      thumbRect!.center.dx,
      closeTo(sliderRect.left + 10, 6),
      reason: 'LTR value 0 anchors the thumb at the LEFT end — unchanged',
    );
  });

  group('T-0062: stepped snapping', () {
    testWidgets('3 steps: released at 40 commits 50; at 95 commits 100; '
        'near the minimum commits 0', (tester) async {
      // Release at raw ~40 → snap 50 (round(40*2/100)=round(0.8)=1).
      var committed = -1;
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.ltr,
          value: 50,
          steps: 3,
          onChanged: (_) {},
          onCommit: (v) => committed = v,
        ),
      );
      final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
      // Drag to ~40% of the span then release.
      final startX = sliderRect.left + sliderRect.width * 0.50;
      final targetX = sliderRect.left + sliderRect.width * 0.40;
      await tester.dragFrom(
        Offset(startX, sliderRect.top + sliderRect.height / 2),
        Offset(targetX - startX, 0),
      );
      await tester.pumpAndSettle();
      expect(committed, 50, reason: 'release at 40 snaps to 50');

      // Release at raw ~95 → snap 100.
      committed = -1;
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.ltr,
          value: 50,
          steps: 3,
          onChanged: (_) {},
          onCommit: (v) => committed = v,
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(sliderRect.left + sliderRect.width * 0.50,
            sliderRect.top + sliderRect.height / 2),
        Offset(sliderRect.width * 0.45, 0),
      );
      await tester.pumpAndSettle();
      expect(committed, 100, reason: 'release at 95 snaps to 100');

      // Release near the minimum → snap 0.
      committed = -1;
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.ltr,
          value: 50,
          steps: 3,
          onChanged: (_) {},
          onCommit: (v) => committed = v,
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragFrom(
        Offset(sliderRect.left + sliderRect.width * 0.50,
            sliderRect.top + sliderRect.height / 2),
        Offset(-sliderRect.width * 0.49, 0),
      );
      await tester.pumpAndSettle();
      expect(committed, 0, reason: 'release near the minimum snaps to 0');
    });

    testWidgets('3 steps: the boundary releases 24 → 0, 25 → 50 and '
        '75 → 100 land on the verified sides (half away from zero)',
        (tester) async {
      // round(24*2/100)=round(0.48)=0; round(25*2/100)=round(0.5)=1
      // (half AWAY from zero); round(75*2/100)=round(1.5)=2.
      // The gesture x for a scale position v accounts for the thumb
      // inset: dx = thumbRadius + v/100 * (width - 2*thumbRadius).
      Future<int> releaseAtScale(int scale) async {
        var committed = -1;
        await tester.pumpWidget(
          _SliderHost(
            direction: TextDirection.ltr,
            value: 50,
            steps: 3,
            onChanged: (_) {},
            onCommit: (v) => committed = v,
          ),
        );
        await tester.pumpAndSettle();
        final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
        const thumbRadius = 10.0;
        final span = sliderRect.width - thumbRadius * 2;
        final startX = sliderRect.left + thumbRadius + 0.50 * span;
        final targetX = sliderRect.left + thumbRadius + scale / 100 * span;
        await tester.dragFrom(
          Offset(startX, sliderRect.top + sliderRect.height / 2),
          Offset(targetX - startX, 0),
        );
        await tester.pumpAndSettle();
        return committed;
      }

      expect(await releaseAtScale(24), 0, reason: '24 snaps to 0');
      expect(await releaseAtScale(25), 50, reason: '25 snaps to 50');
      expect(await releaseAtScale(75), 100, reason: '75 snaps to 100');
    });

    testWidgets('stepped mode: onChanged only ever reports step '
        'positions while the marker follows the finger', (tester) async {
      final reported = <int>[];
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.ltr,
          value: 0,
          steps: 3,
          onChanged: reported.add,
          onCommit: (_) {},
        ),
      );
      final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
      final centre = Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height / 2,
      );
      // A drag sweeping the whole axis: intermediate reports may repeat
      // steps, but every single report is a step position (0/50/100).
      await tester.dragFrom(centre, Offset(sliderRect.width * 0.9, 0));
      await tester.pumpAndSettle();
      expect(reported, isNotEmpty);
      for (final v in reported) {
        expect(v, anyOf(0, 50, 100),
            reason: 'stepped mode never reports an off-step position');
      }
      expect(reported.last, 100);
    });

    testWidgets('stepped mode: the pill names the snapped step',
        (tester) async {
      // No label override: the host's default label fn echoes the
      // value ('قيمة $v'), so the pill visibly names the SNAPPED step.
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.ltr,
          value: 0,
          steps: 3,
          onChanged: (_) {},
          onCommit: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
      final centre = Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height / 2,
      );
      // Release near 40 → snaps to 50 → the pill names the middle
      // step ('قيمة 50'), never the raw position.
      await tester.dragFrom(centre, Offset(-sliderRect.width * 0.10, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('قيمة 50'), findsOneWidget);
      expect(find.textContaining('قيمة 40'), findsNothing);
    });

    testWidgets('stepped mode: a release settles the marker exactly on '
        'the step (never floating between)', (tester) async {
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.ltr,
          value: 50,
          steps: 3,
          onChanged: (_) {},
          onCommit: (_) {},
        ),
      );
      final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
      final centre = Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height / 2,
      );
      // Release at ~62: snaps to 50 — after the settle animation the
      // thumb rests at the 50% position, not at 62%.
      await tester.dragFrom(centre, Offset(sliderRect.width * 0.12, 0));
      await tester.pumpAndSettle();

      final thumbs = find.descendant(
        of: find.byType(FcmScaleSlider),
        matching: thumbFinder,
      );
      Rect? thumbRect;
      for (final t in thumbs.evaluate()) {
        final r = tester.getRect(find.byWidgetPredicate((w) => w == t.widget));
        if (r.width <= 22 && r.height <= 22) {
          thumbRect ??= r;
        }
      }
      expect(thumbRect, isNotNull);
      expect(
        thumbRect!.center.dx,
        closeTo(sliderRect.left + sliderRect.width / 2, 3),
        reason: 'after settling, the marker rests exactly on the step',
      );
    });

    testWidgets('stepped mode in RTL: a drag towards the left still '
        'increases the value (snapped)', (tester) async {
      final reported = <int>[];
      var committed = -1;
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.rtl,
          value: 50,
          steps: 3,
          onChanged: reported.add,
          onCommit: (v) => committed = v,
        ),
      );
      final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
      final centre = Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height / 2,
      );
      // RTL: dragging LEFT increases — from 50 the release must be the
      // 100 step.
      await tester.dragFrom(centre, Offset(-sliderRect.width / 2, 0));
      await tester.pumpAndSettle();
      expect(reported, isNotEmpty);
      expect(reported.last, 100);
      expect(committed, 100,
          reason: 'RTL drag left increases — snapped to the max step');
    });

    testWidgets('free mode (steps: null) still commits raw positions — '
        'the pre-T-0062 behaviour', (tester) async {
      final reported = <int>[];
      var committed = -1;
      await tester.pumpWidget(
        _SliderHost(
          direction: TextDirection.ltr,
          value: 50,
          onChanged: reported.add,
          onCommit: (v) => committed = v,
        ),
      );
      final sliderRect = tester.getRect(find.byType(FcmScaleSlider));
      final centre = Offset(
        sliderRect.left + sliderRect.width / 2,
        sliderRect.top + sliderRect.height / 2,
      );
      // A raw release at ~62 must commit 62-ish, NOT a snapped 50 —
      // free mode never snaps.
      final gesture = await tester.startGesture(centre);
      await gesture.moveBy(Offset(sliderRect.width * 0.12, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(committed, greaterThan(55));
      expect(committed, lessThan(70));
      expect(reported, isNotEmpty);
      expect(reported.last, committed);
    });
  });
}
