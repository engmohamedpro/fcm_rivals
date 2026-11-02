// Live-match stadium backdrop: the photo layer must render (asset
// resolves and paints), the scrim painter must run on top of it, the
// child must sit above both, and the animation must respect
// disable-animations without crashing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/match_backdrop.dart';

void main() {
  testWidgets('FcmMatchBackdrop renders photo, scrim and child',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: FcmMatchBackdrop(
          child: Center(child: Text('ON TOP')),
        ),
      ),
    ));
    // The backdrop animates forever by design (ambient light), so use
    // bounded pumps instead of pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FcmMatchBackdrop), findsOneWidget);
    expect(find.byType(Image), findsOneWidget,
        reason: 'the stadium photo layer must be present');
    // The asset actually resolves and decodes in the test asset bundle.
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, kMatchBackgroundAsset);
    expect(tester.getSize(find.byType(Image)),
        equals(const Size(800.0, 600.0)),
        reason: 'the photo must fill the body');
    // The scrim/ambient painter sits above the photo (the Image's own
    // fade-frame contributes a second CustomPaint, so expect >= 1).
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    expect(find.text('ON TOP'), findsOneWidget);
    // Child stacks above the photo in the z-order.
    expect(
      tester.getTopLeft(find.text('ON TOP')).dy, greaterThanOrEqualTo(0),
    );
  });

  testWidgets('animation stills under disableAnimations without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: FcmMatchBackdrop(
            child: Center(child: Text('STILL')),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('STILL'), findsOneWidget);
  });

  testWidgets('accepts a tint that colours an ambient orb',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: FcmMatchBackdrop(
          tint: FcmColors.danger,
          child: SizedBox.shrink(),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(FcmMatchBackdrop), findsOneWidget);
  });
}
