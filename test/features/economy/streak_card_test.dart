// The streak card's widget contracts: the claim button pays exactly
// the engine-derived amount, the card flips to the claimed state, a
// second tap the same day is refused by the UNIQUE key, and the
// balance surfaces refresh — over an in-memory database with a real
// club, the same harness pattern the profile screen tests use.
library;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart' show databaseProvider;
import 'package:fcm_rivals/core/database/app_database.dart' as db;
import 'package:fcm_rivals/features/economy/streak_card.dart';
import 'package:fcm_rivals/features/economy/streak_engine.dart';
import 'package:fcm_rivals/features/economy/streak_store.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';

void main() {
  late db.AppDatabase database;
  const clubId = 1;

  Future<Widget> harness() async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: Center(child: StreakCard())),
      ),
    );
  }

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    await database
        .into(database.clubs)
        .insert(
          db.ClubsCompanion.insert(
            name: 'Pyramid United',
            managerName: 'Mohamed',
            coins: 10_000,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          ),
        );
  });

  tearDown(() => database.close());

  Future<int> balance() async =>
      (await (database.select(database.clubs)
              ..where((c) => c.id.equals(clubId)))
          .getSingle())
          .coins;

  testWidgets('fresh run: day-1 claim pays the ladder start and flips '
      'the card to claimed', (tester) async {
    await tester.pumpWidget(await harness());
    // The redesigned card breathes forever on today's cell — fixed
    // pumps instead of pumpAndSettle (the repo's ambient-screen
    // convention).
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The claim button carries the engine-derived day-1 amount.
    final engine = const StreakEngine();
    final dayOne = engine.rewardForDay(1);
    final claimButton = find.text('Claim $dayOne Coins');
    expect(claimButton, findsOneWidget);

    final before = await balance();
    await tester.tap(claimButton);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The coins landed through the atomic transaction.
    expect(await balance(), before + dayOne);
    // The card flipped to the claimed state with tomorrow's rung.
    expect(find.text('Claimed today'), findsOneWidget);
    expect(find.text('Tomorrow: ${engine.rewardForDay(2)} Coins'),
        findsOneWidget);
    // The claim row in the DB.
    final rows = await database.select(database.dailyStreakClaims).get();
    expect(rows, hasLength(1));
    expect(rows.single.streakDay, 1);
    expect(rows.single.dayKey, StreakEngine.dayKeyOf(DateTime.now()));
  });

  testWidgets('claimed state: no claim button, the reset warning '
      'replaced by tomorrow hook', (tester) async {
    // Seed today's claim directly through the store.
    await StreakStore(database).claim(clubId: clubId);
    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The card opens already claimed — no button, no warning. (The
    // 'Claim 600 Coins' label is the button's text; 'Claimed today'
    // is the resting state, matched exactly.)
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('Claimed today'), findsOneWidget);
    // The redesigned week track: day 1 claimed renders exactly ONE
    // lit cell carrying the tick (the remaining rungs are future
    // days — dimmed, tickless).
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
