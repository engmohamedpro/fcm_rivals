// FcmBottomNav behaviour: switching tabs, re-tapping the active tab, and the
// badge mirroring under RTL.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_widgets.dart'
    show FcmBottomNav, FcmNavItem;

Widget _host({
  required TextDirection direction,
  required int index,
  required ValueChanged<int> onChanged,
  ValueChanged<int>? onReselected,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        bottomNavigationBar: FcmBottomNav(
          items: const [
            FcmNavItem('One', Icons.looks_one_rounded),
            FcmNavItem('Two', Icons.looks_two_rounded, badge: 3),
            FcmNavItem('Three', Icons.looks_3_rounded),
          ],
          index: index,
          onChanged: onChanged,
          onReselected: onReselected,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tapping another tab calls onChanged, not onReselected',
      (tester) async {
    final changed = <int>[];
    final reselected = <int>[];
    await tester.pumpWidget(_host(
      direction: TextDirection.ltr,
      index: 0,
      onChanged: changed.add,
      onReselected: reselected.add,
    ));

    await tester.tap(find.text('Three'));
    await tester.pump();

    expect(changed, [2]);
    expect(reselected, isEmpty);
  });

  testWidgets('tapping the active tab calls onReselected only',
      (tester) async {
    final changed = <int>[];
    final reselected = <int>[];
    await tester.pumpWidget(_host(
      direction: TextDirection.ltr,
      index: 1,
      onChanged: changed.add,
      onReselected: reselected.add,
    ));

    await tester.tap(find.text('Two'));
    await tester.pump();

    expect(changed, isEmpty);
    expect(reselected, [1]);
  });

  testWidgets('the badge sits on the opposite side of the icon in RTL',
      (tester) async {
    Future<double> badgeMinusIcon(TextDirection d) async {
      await tester.pumpWidget(_host(
        direction: d,
        index: 0,
        onChanged: (_) {},
      ));
      await tester.pump();
      final badge = tester.getCenter(find.text('3'));
      final icon = tester.getCenter(find.byIcon(Icons.looks_two_rounded));
      return badge.dx - icon.dx;
    }

    final ltr = await badgeMinusIcon(TextDirection.ltr);
    final rtl = await badgeMinusIcon(TextDirection.rtl);

    expect(ltr, greaterThan(0), reason: 'LTR: badge to the right of the icon');
    expect(rtl, lessThan(0), reason: 'RTL: badge mirrors to the left');
  });
}
