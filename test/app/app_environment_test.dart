// Environment switch tests (environment request 2026-11-12):
// FcmApp is the single compile-time source of truth for which app
// this binary is (dev / qa / production).
//
// `flutter test` runs with NO APP_ENV define, so these tests pin the
// fallback path: a debug-mode compile without a define resolves to
// dev. The explicit-define paths are compile-time — they cannot be
// exercised in the same test process, so they are verified by the
// build commands documented on FcmApp itself:
//   flutter run --dart-define=APP_ENV=qa
//   flutter build apk --release --dart-define=APP_ENV=production
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/app_environment.dart';

void main() {
  group('FcmApp environment switch', () {
    test('is a const — gates tree-shake like kDebugMode did', () {
      // If this fails, someone made the environment a runtime value
      // and debug code could ship in production binaries.
      const env = FcmApp.env;
      const isDev = FcmApp.isDev;
      const isQa = FcmApp.isQa;
      const isProduction = FcmApp.isProduction;
      expect(env, isNotNull);
      expect(isDev, isA<bool>());
      expect(isQa, isA<bool>());
      expect(isProduction, isA<bool>());
    });

    test('exactly one environment is active', () {
      final active = [
        FcmApp.isDev,
        FcmApp.isQa,
        FcmApp.isProduction,
      ].where((v) => v).length;
      expect(active, 1);
    });

    test(
      'no APP_ENV define + debug compile → dev (the flutter test default)',
      () {
        // `flutter test` compiles in debug mode with no APP_ENV
        // define, so the fallback resolves to dev: the debug draw
        // picker and the test-coin button stay available in tests.
        expect(FcmApp.env, AppEnvironment.dev);
        expect(FcmApp.isDev, isTrue);
        expect(FcmApp.isQa, isFalse);
        expect(FcmApp.isProduction, isFalse);
      },
    );

    test('tag names the active environment', () {
      expect(FcmApp.tag, 'env:dev');
      expect(FcmApp.tag, 'env:${FcmApp.env.name}');
    });

    test('the enum values stay stable — they are a build interface', () {
      // Build commands and CI pass these names as --dart-define
      // values; renaming one breaks every build pipeline, so the set
      // is pinned here.
      expect(
        AppEnvironment.values.map((e) => e.name),
        containsAll(['dev', 'qa', 'production']),
      );
    });
  });
}
