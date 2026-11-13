// Directionality smoke test for the app shell: the whole GameShell
// (app bar, bottom nav, the five tabs) must build under an explicit RTL
// direction — Arabic users get the mirrored chrome — and under LTR as
// the control case. Providers are stubbed to their loading states (no
// database, no dataset), which is exactly what a cold start renders
// before the first frame of data lands: the worst case for layout
// surprises.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmBottomNav;
import 'package:fcm_rivals/l10n/app_localizations.dart';
import 'package:fcm_rivals/main.dart' show GameShell;

Future<void> pumpShell(WidgetTester tester, TextDirection direction) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Loading-state stubs: no drift database, no dataset import —
        // every screen shows its spinner/empty scaffold.
        clubProvider.overrideWith((ref) => const Stream.empty()),
        availablePacksProvider.overrideWith((ref) async => []),
        seasonSummaryProvider.overrideWith((ref) async => null),
        standingsProvider.overrideWith((ref) async => []),
        nextFixtureProvider.overrideWith((ref) async => null),
        campusProvider.overrideWith((ref) async => throw StateError('stub')),
        squadProvider.overrideWith((ref) async => {}),
        collectionProvider.overrideWith((ref) async => []),
        storeOffersProvider.overrideWith((ref) async => []),
        userSettingsProvider.overrideWith(
          (ref) async => throw StateError('stub'),
        ),
      ],
      child: MaterialApp(
        locale: direction == TextDirection.rtl
            ? const Locale('ar')
            : const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => Directionality(
          textDirection: direction,
          child: child!,
        ),
        home: const GameShell(),
      ),
    ),
  );
  // Two settle passes: the lazy tabs build on the first, the localized
  // rebuilds land on the second.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('the shell builds under RTL with a mirrored bottom nav and '
      'no overflow errors', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpShell(tester, TextDirection.rtl);

    // The nav bar renders at all, under the explicit RTL direction.
    final nav = find.byType(FcmBottomNav);
    expect(nav, findsOneWidget);
    expect(
      Directionality.of(tester.element(nav)),
      TextDirection.rtl,
      reason: 'the bottom nav must mirror for Arabic',
    );

    // Localized nav labels came through the AR bundle.
    expect(find.text('الموسم'), findsOneWidget);
    expect(find.text('المتجر'), findsOneWidget);

    // No widget threw and nothing overflowed horizontally.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same shell builds under LTR (control case)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpShell(tester, TextDirection.ltr);

    final nav = find.byType(FcmBottomNav);
    expect(nav, findsOneWidget);
    expect(
      Directionality.of(tester.element(nav)),
      TextDirection.ltr,
    );
    expect(find.text('Season'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
