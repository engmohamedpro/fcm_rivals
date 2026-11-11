// The RTL/locale release sweep (T-0113): both new surfaces (the
// Achievements hub, the Profile tab) under the Arabic locale — no
// overflow exceptions, directional layout, Arabic strings rendering.
library;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart' show databaseProvider;
import 'package:fcm_rivals/core/database/app_database.dart' as db;
import 'package:fcm_rivals/features/achievements/achievements_providers.dart';
import 'package:fcm_rivals/features/achievements/achievements_screen.dart';
import 'package:fcm_rivals/features/profile/profile_providers.dart';
import 'package:fcm_rivals/features/profile/profile_screen.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';

import 'career_fixtures.dart';

void main() {
  late db.AppDatabase database;

  Future<Widget> harness(Widget home) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
      ],
    );
    await container.read(careerMetricsProvider.future);
    await container.read(seasonHistoryProvider.future);
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: home),
      ),
    );
  }

  setUp(() async {
    database = await buildSyntheticCareer();
  });

  tearDown(() => database.close());

  testWidgets('ACHIEVEMENTS hub: Arabic RTL sweep, no overflow',
      (tester) async {
    await tester.pumpWidget(await harness(const AchievementsScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Arabic strings render (fonts set up repo-wide).
    expect(find.text('غرفة الكؤوس'), findsOneWidget);
    expect(find.text('المسيرة'), findsOneWidget);

    // Directional layout.
    expect(
      Directionality.of(
        tester.element(find.text('غرفة الكؤوس').first),
      ),
      TextDirection.rtl,
    );

    // The sweep: fling through the whole hub (the lazy sections) —
    // NO overflow exceptions at any scroll position.
    for (var i = 0; i < 20; i++) {
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -800),
        800,
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull,
        reason: 'the hub lays out mirrored without overflow at any '
            'scroll depth');
  });

  testWidgets('PROFILE tab: Arabic RTL sweep, no overflow',
      (tester) async {
    await tester.pumpWidget(await harness(const ProfileScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Arabic strings render.
    expect(find.text('الملف الشخصي'), findsNothing,
        reason: 'the nav label lives on the shell, not the screen');
    expect(find.text('نسبة الفوز'), findsOneWidget);

    // Directional layout — checked BEFORE scrolling away (the
    // identity header leaves the tree once the viewport moves).
    expect(
      Directionality.of(
        tester.element(find.text('نسبة الفوز').first),
      ),
      TextDirection.rtl,
    );

    // The streak card sits above the history now (the daily claim
    // surface meets the returning player first) — scroll to the
    // history title instead of assuming it fits the fold.
    await tester.scrollUntilVisible(
      find.text('سجل المواسم'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('سجل المواسم'), findsOneWidget);

    // The full sweep: fling through the stats, silverware, history
    // AND the showcase (cabinet + gallery) — no overflow anywhere.
    for (var i = 0; i < 24; i++) {
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -800),
        800,
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull,
        reason: 'the career card + prestige layer lay out mirrored '
            'without overflow at any depth');
  });

  testWidgets('the ZERO-state surfaces also pass RTL (fresh save)',
      (tester) async {
    // An empty database: the zero-states under Arabic.
    database = db.AppDatabase(NativeDatabase.memory());
    await database
        .into(database.clubs)
        .insert(
          db.ClubsCompanion.insert(
            name: 'Fresh FC',
            managerName: 'New Coach',
            coins: 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              1_700_000_000_000,
            ),
          ),
        );

    await tester.pumpWidget(await harness(const AchievementsScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('غرفة الكؤوس'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -800),
        800,
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(await harness(const ProfileScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('تبدأ الآن'), findsOneWidget,
        reason: 'the Arabic win-rate zero copy');
    for (var i = 0; i < 24; i++) {
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, -800),
        800,
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull);
  });
}
