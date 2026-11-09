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
import 'package:fcm_rivals/core/ui/fcm_backdrop.dart' show FcmBackdrop;
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
      'under a 40px status-bar inset: Team body top == 40, Season '
      'body top == 40 + 57 (dir: ${direction.name})',
      (WidgetTester tester) async {
        // The attempt-1 review found the collapse parked content under
        // the status bar and clamped the expanded bar below its
        // natural height — both because the wrapper ignored the top
        // inset. This test injects a device-typical 40px inset and
        // measures where the body REALLY starts on both tabs: that is
        // the invariant the old test only claimed in its name.
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(
          left: 0,
          top: 40,
          right: 0,
          bottom: 0,
        );
        addTearDown(tester.view.reset);
        await pumpShell(tester, direction);

        final teamLabel = direction == TextDirection.rtl ? 'الفريق' : 'Team';
        final seasonLabel =
            direction == TextDirection.rtl ? 'الموسم' : 'Season';
        final backdrop = find.byType(FcmBackdrop).first;

        // Season: the expanded slot absorbs the inset like the
        // pre-change AppBar did — body starts at inset + bar (97),
        // and the bar's own height is its natural inset-aware 97, not
        // clamped to 57.
        expect(
          tester.getTopLeft(backdrop).dy,
          40 + barHeight,
          reason: 'Season body must start below inset + app bar',
        );
        final expandedSlot = find.byKey(const ValueKey('shell-appbar-slot'));
        expect(tester.getSize(expandedSlot).height, 40 + barHeight);
        expect(tester.takeException(), isNull);

        // Team: the bar collapses to the inset alone — content starts
        // at 40 (never under the status bar, never with a dead gap).
        await tester.tap(find.text(teamLabel));
        await settleAnimation(tester);
        expect(
          tester.getTopLeft(backdrop).dy,
          40.0,
          reason: 'Team body must start at the inset, not under it',
        );
        expect(tester.getSize(expandedSlot).height, 40.0);

        // Back to Season: full height again.
        await tester.tap(find.text(seasonLabel));
        await settleAnimation(tester);
        expect(tester.getTopLeft(backdrop).dy, 40 + barHeight);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
