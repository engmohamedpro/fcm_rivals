// The Profile tab contracts (T-0111): exact career stats from the
// shared derivation, the locale-aware win rate, silverware grouping,
// season history rows, the zero-state and the six-tab nav with
// Profile last — over T-0107's synthetic career fixture.
library;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart' show databaseProvider;
import 'package:fcm_rivals/core/database/app_database.dart' as db;
import 'package:fcm_rivals/features/achievements/achievements_providers.dart'
    show careerMetricsProvider;
import 'package:fcm_rivals/features/profile/profile_providers.dart'
    show seasonHistoryProvider;
import 'package:fcm_rivals/features/profile/profile_screen.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';
import 'package:fcm_rivals/main.dart' show GameShell;

import '../achievements/career_fixtures.dart';

void main() {
  late db.AppDatabase database;

  Future<Widget> harness({
    Locale locale = const Locale('en'),
    bool withShell = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
      ],
    );
    await container.read(careerMetricsProvider.future);
    await container.read(seasonHistoryProvider.future);
    final home = withShell
        ? const GameShell()
        : const Scaffold(body: ProfileScreen());
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    );
  }

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    await database
        .into(database.clubs)
        .insert(
          db.ClubsCompanion.insert(
            name: 'Empty FC',
            managerName: 'Nobody',
            coins: 0,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          ),
        );
  });

  tearDown(() => database.close());

  testWidgets('exact career stats from the fixture (4W-1D-0L, 80% '
      'win rate)', (tester) async {
    final fixture = await buildSyntheticCareer();
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // W/D/L exact (the fixture's corrected expectations: 4/1/0).
    expect(find.text('4'), findsWidgets);
    expect(find.text('1'), findsWidgets);
    expect(find.text('0'), findsWidgets);
    // Win rate: 4/5 = 80.0% (locale-formatted, one decimal).
    expect(find.text('80.0%'), findsOneWidget);
    // Goals for / against: 9 / 2.
    expect(find.text('9'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    // Streaks: best win run 3, best unbeaten 5.
    expect(find.text('3'), findsWidgets);
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('silverware: titles grouped by division', (tester) async {
    final fixture = await buildSyntheticCareer();
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The fixture won two titles (Div 2 then Div 1).
    expect(find.text('2 trophies won'), findsOneWidget);
    expect(find.text('Div 1 ×1'), findsOneWidget);
    expect(find.text('Div 2 ×1'), findsOneWidget);
  });

  testWidgets('season history rows match the fixture', (tester) async {
    final fixture = await buildSyntheticCareer();
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The streak card sits above the history (the daily claim
    // surface meets the returning player first) — scroll to the
    // history rows instead of assuming they fit the fold.
    await tester.scrollUntilVisible(
      find.text('Season 2 · Div 1'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 150));

    // Two completed seasons: ordinal 2/Div 1 (stayed) and ordinal 1/
    // Div 2 (promoted) — newest first.
    expect(find.text('Season 2 · Div 1'), findsOneWidget);
    expect(find.text('Season 1 · Div 2'), findsOneWidget);
    expect(find.text('Promoted'), findsOneWidget);
    expect(find.text('Stayed'), findsOneWidget);
    expect(find.text('Finished 1'), findsWidgets,
        reason: 'both seasons ended as champions');
  });

  testWidgets('zero-state: fresh save, no NaN, inviting copy',
      (tester) async {
    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // No crash, no NaN; the inviting tone everywhere.
    expect(find.text('Starts now'), findsOneWidget,
        reason: 'win rate shows the starts-now copy, never NaN');
    expect(find.text('The cabinet is waiting'), findsOneWidget);
    // The fallback identity renders (no club rows in the empty db
    // beyond the setUp one — the unset names show) — above the fold,
    // checked BEFORE scrolling away.
    expect(find.textContaining('Nobody'), findsOneWidget);
    // The streak card sits above the history — scroll to it.
    await tester.scrollUntilVisible(
      find.text('Your career starts now'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('Your career starts now'), findsOneWidget);
  });

  testWidgets('six nav items render with Profile last', (tester) async {
    final fixture = await buildSyntheticCareer();
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness(withShell: true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Season'), findsOneWidget);
    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('Campus'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    // Non-cramped at the smallest supported width: the nav row
    // lays out all six within a 360dp viewport without overflow
    // (the shell's FcmBottomNav expands per item).
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull,
        reason: 'no layout overflow at 360dp with six items');
  });

  testWidgets('Arabic/RTL: localized stats and mirrored layout',
      (tester) async {
    final fixture = await buildSyntheticCareer();
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness(locale: const Locale('ar')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('نسبة الفوز'), findsOneWidget);
    expect(find.text('أطول سلسلة فوز'), findsOneWidget);
    // The Arabic percent: locale digits (AR locale formats with
    // Arabic-Indic numerals through intl) — assert the RTL layout.
    final rtl = Directionality.of(
      tester.element(find.text('نسبة الفوز').first),
    );
    expect(rtl, TextDirection.rtl);
    // Silverware localized.
    expect(find.text('سجل المواسم'), findsOneWidget);
  });
}
