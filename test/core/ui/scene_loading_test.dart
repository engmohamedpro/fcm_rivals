// Scene-loading transition: the controller's timing rules (debounce,
// dismiss, no-host fallback) and the overlay's reduce-motion behaviour.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/scene_loading.dart';
import 'package:fcm_rivals/core/ui/scene_loading_transition.dart';

/// A host over a body whose loading marker is toggled by [loading].
Widget _app(ValueNotifier<bool> loading, {SceneLoadingController? controller}) {
  return MaterialApp(
    home: SceneLoadingHost(
      controller: controller,
      child: ValueListenableBuilder<bool>(
        valueListenable: loading,
        builder: (context, isLoading, _) => Scaffold(
          body: isLoading ? const SceneLoadingMarker() : const Text('ready'),
        ),
      ),
    ),
  );
}

Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('overlay appears only after the show delay and hides after '
      'the load ends', (tester) async {
    final loading = ValueNotifier<bool>(true);
    await tester.pumpWidget(_app(loading));

    // Debounce: a load shorter than 150 ms never flashes the overlay.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SceneLoadingTransition), findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(find.byType(SceneLoadingTransition), findsOneWidget);

    // The load ends: the overlay lingers for its minimum time, then fades.
    loading.value = false;
    await tester.pump();
    expect(find.text('ready'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SceneLoadingTransition), findsNothing);

    await _disposeApp(tester);
  });

  testWidgets('a load shorter than the show delay never shows the overlay', (
    tester,
  ) async {
    final loading = ValueNotifier<bool>(true);
    await tester.pumpWidget(_app(loading));
    await tester.pump(const Duration(milliseconds: 50));

    loading.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SceneLoadingTransition), findsNothing);

    await _disposeApp(tester);
  });

  testWidgets('an immediate load raises the overlay without the show delay', (
    tester,
  ) async {
    final loading = ValueNotifier<bool>(false);
    final controller = SceneLoadingController();
    await tester.pumpWidget(_app(loading, controller: controller));

    controller.begin(immediate: true);
    // Well inside the 150 ms debounce window.
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump();
    expect(find.byType(SceneLoadingTransition), findsOneWidget);

    controller.end();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SceneLoadingTransition), findsNothing);

    await _disposeApp(tester);
    controller.dispose();
  });

  testWidgets('tapping the overlay dismisses it until the next load', (
    tester,
  ) async {
    final loading = ValueNotifier<bool>(true);
    final controller = SceneLoadingController();
    await tester.pumpWidget(_app(loading, controller: controller));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byType(SceneLoadingTransition), findsOneWidget);

    await tester.tap(find.byType(SceneLoadingTransition));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SceneLoadingTransition), findsNothing);
    expect(controller.visible, isFalse);

    // Still loading, but the person dismissed it: it must not come back.
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(SceneLoadingTransition), findsNothing);

    await _disposeApp(tester);
    controller.dispose();
  });

  testWidgets('without a host the marker falls back to a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SceneLoadingMarker())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SceneLoadingTransition), findsNothing);
  });

  test('controller counts overlapping loads and tracks futures', () async {
    final controller = SceneLoadingController();
    controller.begin();
    controller.begin();
    expect(controller.pending, 2);
    controller.end();
    expect(controller.pending, 1);
    controller.end();
    expect(controller.pending, 0);
    // Extra end() calls are harmless.
    controller.end();
    expect(controller.pending, 0);

    final result = await controller.track(Future<int>.value(7));
    expect(result, 7);
    expect(controller.pending, 0);
    controller.dispose();
  });

  testWidgets('reduce motion renders a still overlay that settles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            size: Size(400, 800),
          ),
          child: SceneLoadingTransition(),
        ),
      ),
    );
    // No infinite loop: pumpAndSettle would time out if one were running.
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
  });
}
