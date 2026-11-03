import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_logo.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart';

void main() {
  testWidgets('the wordmark asset decodes and renders',
      (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: const Scaffold(
        backgroundColor: FcmColors.night,
        body: Center(child: FcmWordmark(size: 32)),
      ),
    ));
    await tester.pumpAndSettle();

    // The wordmark is the transparent logo art (not the text fallback).
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, kFcmWordmarkAsset);
    expect(find.text('FCM'), findsNothing);
    expect(find.text('RIVALS'), findsNothing);
  });
}
