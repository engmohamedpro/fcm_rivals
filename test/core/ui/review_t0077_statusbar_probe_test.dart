// T-0077 reviewer evidence (committed with the FAIL review, following
// the tool/review_lift_probe.dart precedent from T-0072's review): the
// committed tests run with zero view padding, so the "no status-bar
// overlap" claim is never actually measured. This probe injects a 40px
// top inset (a typical device status bar) and measures where the body
// really starts when the app bar collapses on the Team tab — and, on
// the Season tab, whether the expanded bar still absorbs the inset the
// way the pre-T-0077 AppBar did (97px, not 57px).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmBackdrop;

import 'game_shell_appbar_test.dart' as shell;

void main() {
  testWidgets(
    'PROBE: Team tab body top under a 40px status-bar inset',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(
        left: 0,
        top: 40,
        right: 0,
        bottom: 0,
      );
      addTearDown(tester.view.reset);
      await shell.pumpShell(tester, TextDirection.ltr);

      final slot = find.byKey(const ValueKey('shell-appbar-slot'));
      final backdrop = find.byType(FcmBackdrop).first;

      // Season (default): body top should be 40 (inset) + bar height.
      final seasonTop = tester.getTopLeft(backdrop).dy;
      final seasonSlotH = tester.getSize(slot).height;
      // ignore: avoid_print
      print('PROBE season: bodyTop=$seasonTop slotHeight=$seasonSlotH');

      await tester.tap(find.text('Team'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final teamTop = tester.getTopLeft(backdrop).dy;
      final teamSlotH = tester.getSize(slot).height;
      // ignore: avoid_print
      print('PROBE team: bodyTop=$teamTop slotHeight=$teamSlotH');
      // ignore: avoid_print
      print(
        'PROBE verdict: ${teamTop >= 40 ? 'content starts below the inset (OK)' : 'OVERLAP: content starts under the 40px status bar'}',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
