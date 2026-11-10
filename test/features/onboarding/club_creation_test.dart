// T-0081: club creation shows the same formation picker the Team tab
// uses (an FcmDropdown of formation names) and tells the user nothing
// about rewards — the removed intro texts promised coins and 22 free
// packs, which the owner (2026-11-09) wants unadvertised. The screen is
// pumped with a real in-memory CollectionStore so the submit path runs
// end to end (createClub grants unchanged — the test asserts it still
// works, not what it grants). Both locales are covered: EN and AR.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart';
import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_dropdown.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/onboarding/club_creation_screen.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/settings/user_settings_store.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';

const List<List<String>> _seedPositions = [
  ['GK', 'Keeper'],
  ['CB', 'Back'],
  ['CM', 'Midfield'],
  ['RW', 'Wing'],
  ['ST', 'Striker'],
  ['CDM', 'Anchor'],
  ['LW', 'Winger'],
  ['CAM', 'Playmaker'],
  ['LB', 'Leftback'],
  ['RB', 'Rightback'],
  ['LM', 'Leftmid'],
  ['RM', 'Rightmid'],
];

String _datasetJson() => json.encode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': [
    for (var p = 0; p < _seedPositions.length; p++)
      for (var i = 0; i < 5; i++)
        [
          p * 10 + i + 1,
          '${_seedPositions[p][1]} ${p * 10 + i + 1}',
          _seedPositions[p][0],
          'Egypt',
          500_000 + (i * 3_000_000) + p * 100_000,
        ],
  ],
});

/// Pumps the ClubCreationScreen on a real in-memory store under the
/// given locale. The stream providers get stubs; the submit path uses
/// the real store.
Future<CollectionStore> pumpCreation(
  WidgetTester tester,
  Locale locale,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(_datasetJson()));
  addTearDown(() => db.close());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) => store),
        userSettingsProvider.overrideWith(
          (ref) async => throw StateError('stub'),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ClubCreationScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return store;
}


/// T-0096 harness: pumps the creation screen with a WORKING settings
/// store (the default harness stubs it with a throw, which would break
/// the toggle's persist step) and a localeProvider seeded with [tag].
Future<CollectionStore> pumpCreationWithSettings(
  WidgetTester tester,
  String tag,
) async {
  final db = AppDatabase(NativeDatabase.memory());
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(_datasetJson()));
  addTearDown(() => db.close());
  final settings = UserSettingsStore(database: db);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionStoreProvider.overrideWith((ref) => store),
        userSettingsProvider.overrideWith((ref) async => settings),
        localeProvider.overrideWith((ref) => tag),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: localeFromTag(ref.watch(localeProvider)) ??
              const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ClubCreationScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return store;
}

/// 'en'/'ar'/null → the matching Locale (null keeps the default EN in
/// this harness — the entry gate owns the system-follow case in prod).
Locale? localeFromTag(String? tag) =>
    tag == 'ar' ? const Locale('ar') : const Locale('en');

void main() {
  testWidgets(
    'the formation dropdown lists every formation and selection works '
    '(EN)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpCreation(tester, const Locale('en'));

      // The Team tab's picker: a closed field showing the live shape.
      final dropdown = find.byType(FcmDropdown<String>);
      expect(dropdown, findsOneWidget);
      expect(find.text(formations.first.name), findsOneWidget);
      // The census-badges list is gone: no per-formation option rows.
      expect(find.byType(ListView), findsNothing);

      // Opening the sheet lists every formation by name.
      await tester.tap(dropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final f in formations) {
        expect(find.text(f.name), findsAtLeastNWidgets(1),
            reason: '${f.name} missing from the sheet');
      }

      // Selecting one updates the closed field.
      await tester.tap(find.text('4-2-3-1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('4-2-3-1'), findsOneWidget);
    },
  );

  testWidgets(
    'no reward promises render in EN — the screen never mentions '
    'coins or packs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpCreation(tester, const Locale('en'));

      // The removed intro lines must not appear…
      expect(find.textContaining('free packs'), findsNothing);
      expect(find.textContaining('You start with coins'), findsNothing);
      // …and no other text on the screen promises a reward either.
      expect(find.textContaining('22'), findsNothing);
      expect(find.textContaining('coins'), findsNothing);
      expect(find.textContaining('pack'), findsNothing);
      // The heading and section labels are still there.
      expect(find.text('Create your club'), findsOneWidget);
      expect(find.text('STARTER FORMATION'), findsOneWidget);
    },
  );

  testWidgets(
    'no reward promises render in AR either — and the dropdown works '
    'mirrored',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpCreation(tester, const Locale('ar'));

      // The Arabic promise lines are gone.
      expect(find.textContaining('مجانية'), findsNothing);
      expect(find.textContaining('عملات'), findsNothing);
      expect(find.textContaining('٢٢'), findsNothing);
      expect(find.textContaining('حزمة'), findsNothing);
      // Localized heading still present.
      expect(find.text('أنشئ ناديك'), findsOneWidget);

      // The picker works under RTL exactly like the Team tab's.
      final dropdown = find.byType(FcmDropdown<String>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('4-4-2'), findsAtLeastNWidgets(1));
      await tester.tap(find.text('4-4-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('4-4-2'), findsOneWidget);
    },
  );

  testWidgets(
    'the submit path is intact: fields validate and createClub runs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = await pumpCreation(tester, const Locale('en'));

      // Validation fires on empty fields (form still wired).
      final submit = find.text('Start managing');
      expect(submit, findsOneWidget);
      await tester.tap(submit);
      await tester.pump();
      expect(find.text('Required'), findsNWidgets(2));

      // Fill the form and submit: createClub really runs — the club
      // lands with the picked formation (rewards unchanged is the
      // store's business, here only that the flow completes).
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Club name'),
        'FC Rivals',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Manager name'),
        'Mohamed',
      );
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      final club = await store.getClub();
      expect(club, isNotNull);
      expect(club!.name, 'FC Rivals');
      expect(club.formationCode, formations.first.code);
    },
  );

  testWidgets(
    'T-0096: the language toggle flips EN↔AR live and typed names '
    'survive',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await pumpCreationWithSettings(tester, 'en');

      // English first: the toggle glyph shows the ARABIC target 'ع'.
      expect(find.text('Create your club'), findsOneWidget);
      expect(find.text('ع'), findsOneWidget);

      // Type a club name — it must survive the flip (in-screen state).
      await tester.enterText(
        find.byType(TextFormField).first,
        'Pyramid United',
      );
      await tester.pump();

      // One tap flips the whole form to Arabic.
      await tester.tap(find.text('ع'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('أنشئ ناديك'), findsOneWidget);
      expect(find.text('Create your club'), findsNothing);
      expect(find.text('EN'), findsOneWidget, reason: 'the glyph flipped');

      // The typed name survived the locale change.
      expect(
        find.text('Pyramid United'),
        findsOneWidget,
        reason: 'the form state outlives the MaterialApp rebuild',
      );

      // A second tap returns to English — no duplicated toggle, no
      // glitch: exactly ONE glyph on screen either way.
      await tester.tap(find.text('EN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Create your club'), findsOneWidget);
      expect(find.text('ع'), findsOneWidget);
    },
  );
}
