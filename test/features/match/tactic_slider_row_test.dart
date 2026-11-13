import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_scale_slider.dart';
import 'package:fcm_rivals/features/match/tactic_slider_row.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

Widget _host(Widget child, {Locale? locale}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  // The GLOBAL delegates actually load 'ar'; the Default* pair only
  // carries 'en', so the Arabic assertion below used to die on the
  // missing-localizations warning before it ever reached a finder.
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(
    body: Center(child: SizedBox(width: 360, child: child)),
  ),
);

void main() {
  testWidgets('shows name, number and the wording of the value in one row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TacticSliderRow(
          axis: TacticAxisId.width,
          value: 55,
          onCommit: (_) {},
        ),
      ),
    );
    expect(find.text('WIDTH'), findsOneWidget);
    expect(find.text('55'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.byType(FcmScaleSlider), findsOneWidget);
  });

  testWidgets('tapping the far ends commits 0 and 99 with their wording', (
    tester,
  ) async {
    final commits = <int>[];
    await tester.pumpWidget(
      _host(
        TacticSliderRow(
          axis: TacticAxisId.width,
          value: 50,
          onCommit: commits.add,
        ),
      ),
    );
    final rect = tester.getRect(find.byType(FcmScaleSlider));

    // Tap INSIDE the gesture band: the GestureDetector is the slider's
    // TRACK band — the bottom 24px of the widget's 50px column (pill
    // band 22 + gap 4 above it). rect.center lands on the dead gap,
    // so the tap never reaches a listener and no commit fires.
    // _updateFromDx maps x across [thumbRadius .. w - thumbRadius] →
    // [0 .. max]: the band's own left/right edges (±10px dead zone
    // each side) tap the true 0 and max.
    final band = Rect.fromLTWH(
      rect.left,
      rect.bottom - 24,
      rect.width,
      24,
    );
    await tester.tapAt(Offset(band.left + 1, band.center.dy));
    await tester.pump();
    expect(commits.last, 0);
    expect(find.text('Very narrow'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tapAt(Offset(band.right - 1, band.center.dy));
    await tester.pump();
    expect(commits.last, 99);
    expect(find.text('Very wide'), findsOneWidget);
  });

  testWidgets('the wording follows the committed value from the owner', (
    tester,
  ) async {
    Widget row(int v) => _host(
      TacticSliderRow(axis: TacticAxisId.tempo, value: v, onCommit: (_) {}),
    );
    await tester.pumpWidget(row(10));
    expect(find.text('Very slow'), findsOneWidget);
    await tester.pumpWidget(row(90));
    expect(find.text('Very fast'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
  });

  testWidgets('Arabic shows the Arabic name and wording', (tester) async {
    await tester.pumpWidget(
      _host(
        TacticSliderRow(
          axis: TacticAxisId.width,
          value: 50,
          onCommit: (_) {},
        ),
        locale: const Locale('ar'),
      ),
    );
    expect(find.text('عادي'), findsOneWidget);
  });
}
