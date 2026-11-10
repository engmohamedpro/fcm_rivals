import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_scale_slider.dart';
import 'package:fcm_rivals/features/match/tactic_slider_row.dart';
import 'package:fcm_rivals/features/match/tactics.dart';

Widget _host(Widget child, {Locale? locale}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: const [
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
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

    await tester.tapAt(Offset(rect.left + 1, rect.center.dy));
    await tester.pump();
    expect(commits.last, 0);
    expect(find.text('Very narrow'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
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
