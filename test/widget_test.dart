// Smoke test for the development shell: the app boots, loads the bundled
// player dataset asset and renders the database screen.
//
// The asset is loaded through the real asset bundle, so this also verifies
// pubspec asset wiring end to end.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/main.dart';

void main() {
  testWidgets('app boots and imports the bundled player database',
      (WidgetTester tester) async {
    await tester.pumpWidget(const FcmRivalsApp());

    // Real asset I/O doesn't advance under FakeAsync; run it outside the
    // fake clock, then pump frames until the loaded state renders.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('FCM Rivals — Player Database'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // header card reports the imported count
    final header =
        find.textContaining('real players imported from the bundled');
    expect(header, findsOneWidget);

    // top of the imported database renders real player names
    expect(find.text('Erling Haaland'), findsWidgets);
  });
}
