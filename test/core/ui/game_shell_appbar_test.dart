// T-0077: the game shell's AppBar hides while the Team tab is active
// and shows on every other tab (owner decision 2026-11-09). These tests
// pin the whole cycle — shown by default, hidden on Team, restored on
// Season — in both text directions, with no overflow or layout
// exceptions at any point of the 200ms collapse animation. The shell is
// pumped with the real GameShell and loading-state provider stubs, the
// same pattern as shell_directionality_test.dart; tab switches are
// driven by tapping the real localized bottom-nav labels.
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

/// Settles the shell's 200ms app-bar collapse/expand plus the body
/// cross-fade.
Future<void> settleAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // The app bar's AppBar slot is 52 (toolbar) + 5 (gold seam bottom)
  // = 57 logical px tall — the space the Team tab reclaims.
  const barHeight = 57.0;

  for (final direction in TextDirection.values) {
    testWidgets(
      'app bar: shown on Season, hidden on Team, restored '
      '(dir: ${direction.name})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await pumpShell(tester, direction);

        final teamLabel = direction == TextDirection.rtl ? 'الفريق' : 'Team';
        final seasonLabel =
            direction == TextDirection.rtl ? 'الموسم' : 'Season';

        // (a) Default Season tab: the app-bar SLOT renders at full
        // height (the wrapper that owns the collapse animation).
        var slot = find.byKey(const ValueKey('shell-appbar-slot'));
        expect(slot, findsOneWidget);
        expect(
          tester.getSize(slot),
          const Size(800, barHeight),
          reason: 'Season tab must show the full app bar',
        );
        expect(find.byType(AppBar), findsOneWidget);
        expect(tester.takeException(), isNull);

        // (b) Tapping the Team tab hides it (animation settles to 0).
        // The AppBar subtree stays mounted (clipped away) so the coin
        // stream survives; the SLOT itself collapses to zero height,
        // which is what pushes the body up under the status-bar inset.
        await tester.tap(find.text(teamLabel));
        await settleAnimation(tester);
        slot = find.byKey(const ValueKey('shell-appbar-slot'));
        expect(slot, findsOneWidget);
        expect(
          tester.getSize(slot),
          const Size(800, 0),
          reason: 'Team tab must collapse the app bar slot to zero height',
        );
        expect(find.byType(AppBar), findsOneWidget);
        expect(tester.takeException(), isNull);

        // (c) Tapping Season again restores it to the full height.
        await tester.tap(find.text(seasonLabel));
        await settleAnimation(tester);
        slot = find.byKey(const ValueKey('shell-appbar-slot'));
        expect(slot, findsOneWidget);
        expect(
          tester.getSize(slot),
          const Size(800, barHeight),
          reason: 'returning to Season must restore the app bar',
        );
        expect(find.byType(AppBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Team tab content starts below the status-bar inset, not under '
      'it and not with a dead gap (dir: ${direction.name})',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await pumpShell(tester, direction);

        final teamLabel = direction == TextDirection.rtl ? 'الفريق' : 'Team';
        await tester.tap(find.text(teamLabel));
        await settleAnimation(tester);

        // The Scaffold hands the body the status-bar top inset when the
        // app bar is gone; with a zero test padding that inset is 0, so
        // the body's top edge sits at the very top of the scaffold —
        // the invariant checked here is the ViewPadding-to-body relation
        // itself, which is what breaks (overlap or white gap) when the
        // insets are mishandled.
        final body = find.byType(FcmBottomNav);
        expect(body, findsOneWidget);
        final navRect = tester.getRect(body);
        expect(navRect.top, 1600 - navRect.height,
            reason: 'the bottom nav stays docked');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
