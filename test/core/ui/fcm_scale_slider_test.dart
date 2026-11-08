/// T-0061: FcmScaleSlider RTL behaviour — the slider mirrors under an
/// ambient RTL direction (Arabic): the minimum end sits at the RIGHT,
/// the fill spans from the right, dragging LEFT increases the value,
/// and the floating pill clamps inside the track with Arabic text.
/// LTR behaviour is the untouched baseline covered by the squad view
/// suite (mentality row).
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
  });

  final TextDirection direction;
  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onCommit;
  final String? label;

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
}
