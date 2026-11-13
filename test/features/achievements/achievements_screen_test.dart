// The Achievements hub screen contracts (T-0110): renders the catalog's
// categories, honest progress bars against derived metrics, the claim
// affordance only on eligible tiers, claimed state from the claims
// table, the empty save's zero-state, and the full Arabic/RTL pass —
// all over the REAL pipeline (in-memory database + T-0107's fixture
// career + T-0108's atomic service).
library;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/app/providers.dart' show databaseProvider;
import 'package:fcm_rivals/core/database/app_database.dart' as db;
import 'package:fcm_rivals/features/achievements/achievement_claim_service.dart';
import 'package:fcm_rivals/features/achievements/achievement_claims_repository.dart';
import 'package:fcm_rivals/features/achievements/achievements_providers.dart';
import 'package:fcm_rivals/features/achievements/achievements_screen.dart';
import 'package:fcm_rivals/l10n/app_localizations.dart';

import 'career_fixtures.dart';

void main() {
  late db.AppDatabase database;


  Future<Widget> harness({Locale locale = const Locale('en')}) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) async => database),
      ],
    );
    // Warm the derivation providers once so the screen's first build
    // lands with data (the watch streams self-prim).
    await container.read(careerMetricsProvider.future);
    await container.read(claimsProvider.future);
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
        home: const Scaffold(body: AchievementsScreen()),
      ),
    );
  }

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    await database
        .into(database.clubs)
        .insert(
          db.ClubsCompanion.insert(
            name: 'Test FC',
            managerName: 'Tester',
            coins: 1_000,
            createdAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
          ),
        );
  });

  tearDown(() => database.close());

  testWidgets('renders categories from the catalog with honest '
      'progress (synthetic career)', (tester) async {
    // The synthetic career in the harness database (the fixture
    // builder owns its in-memory db — swap it in as THE database).
    final fixture = await buildSyntheticCareer();
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The redesigned hub (2026-11-13): rooms render one at a time
    // behind the category carousel. Career appears as BOTH its chip
    // and the default wall heading; tapping the Attack chip swaps
    // the wall (Career's heading leaves, Attack's lands).
    expect(find.text('Career'), findsWidgets);

    // The wins ladder (in the DEFAULT Career room): 4 wins derived,
    // nothing claimed — the first rung (threshold 1) is ELIGIBLE:
    // progress 4 >= 1. The bar shows 4 / 1 — complete, honest. The
    // wins card sits below the fold (hero + streak eat the first
    // screen) — scroll it into view.
    await tester.scrollUntilVisible(
      find.text('4 / 1'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4 / 1'), findsWidgets);

    // The claim action appears for the eligible tier.
    expect(find.text('Claim'), findsWidgets);

    // The room swap: scrolling exposed the wins card but moved the
    // carousel (a horizontal Scrollable of its own) off-screen —
    // drag back to the top first, then tap the Attack chip.
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 1200),
      1000,
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.text('Attack'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Attack'), findsWidgets);
    expect(find.text('Career'), findsOneWidget,
        reason: 'only the Attack room chip keeps the Career label '
            'after the wall swap');
  });

  test('the claim pipeline lands atomically (real service, real '
      'ledger)', () async {
    final fixture = await buildSyntheticCareer();
    addTearDown(fixture.close);

    const clubId = 1;
    final balanceBefore =
        (await (fixture.select(fixture.clubs)
                  ..where((c) => c.id.equals(clubId)))
            .getSingle())
            .coins;

    // The REAL atomic pipeline — the same service call the claim
    // button's onPressed awaits (its async closure cannot run under
    // the widget test's fake clock; the pipeline is identical).
    final service = AchievementClaimService(fixture);
    final results = await service.claimAllTiers(
      clubId: clubId,
      achievementId: 'career_wins',
    );
    expect(results.whereType<ClaimGranted>().length, 3,
        reason: 'the fixture derives 4 wins: rungs 1, 2 and 4');

    final claims =
        await AchievementClaimsRepository(fixture).claimsForClub(clubId);
    expect(claims, isNotEmpty);
    final ledger = await fixture.select(fixture.coinTransactions).get();
    expect(ledger.any((r) => r.reason == 'achievement'), isTrue);
    final balanceAfter =
        (await (fixture.select(fixture.clubs)
                  ..where((c) => c.id.equals(clubId)))
            .getSingle())
            .coins;
    expect(balanceAfter, greaterThan(balanceBefore));

    // Double claim through the same path: idempotent, nothing new.
    final again = await service.claimAllTiers(
      clubId: clubId,
      achievementId: 'career_wins',
    );
    expect(again, isEmpty);
    final balanceAfterAgain =
        (await (fixture.select(fixture.clubs)
                  ..where((c) => c.id.equals(clubId)))
            .getSingle())
            .coins;
    expect(balanceAfterAgain, balanceAfter);
  });

  testWidgets('claimed tiers render claimed from the claims table '
      '(the live watch)', (tester) async {
    final fixture = await buildSyntheticCareer();
    // Pre-seed one REAL claim so the watch has a committed row to
    // fan out — performed in real async BEFORE the widget clock
    // starts (the drift watch opens with the widget).
    await AchievementClaimService(fixture).claimTier(
      clubId: 1,
      achievementId: 'career_wins',
      tierKey: '1',
    );
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Diagnostic: the harness container's claims snapshot — printed
    // once, removed before the final commit (T-0110 debugging aid).
    // (The widget tree cannot see the pre-seeded row if the watch's
    // FIRST event (the seeded read) landed before the widget existed
    // but the provider rebuilt from a closed prior database.)

    // The claimed state renders from the table — no local flag: the
    // card shows its claimed-rungs chip (1 claimed for the pre-seeded
    // career_wins claim), and eligible rungs still offer the action.
    // The wins card sits below the fold (hero + streak eat the first
    // screen) — scroll it into view.
    await tester.scrollUntilVisible(
      find.text('1 claimed'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1 claimed'), findsOneWidget,
        reason: 'the pre-claimed rung renders its state from the '
            'claims table through the live watch');
    expect(find.text('Claim'), findsWidgets,
        reason: 'other eligible rungs still offer the action');
  });

  testWidgets('ineligible tiers show no claim action (locked)', (
      tester) async {
    // Empty-ish save: 0 wins — every tier is locked.
    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Claim'), findsNothing,
        reason: 'nothing is claimable with 0 progress');
    expect(find.text('0 / 1'), findsWidgets,
        reason: 'the honest zero state, no fake progress');
  });

  testWidgets('empty save renders the zero-state gracefully', (
      tester) async {
    await tester.pumpWidget(await harness());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The hub header renders with 0 of N.
    expect(find.text('The Trophy Room'), findsOneWidget);
    expect(find.textContaining('of'), findsWidgets);
    // The hero's completion reads as a percent + the metal segment
    // bar (the ring is gone with the redesign).
    expect(find.text('0%'), findsOneWidget);
    // No crash: the default room rendered (chip + heading).
    expect(find.text('Career'), findsWidgets);
  });

  testWidgets('Arabic/RTL: the screen renders mirrored with real '
      'Arabic copy', (tester) async {
    final fixture = await buildSyntheticCareer();
    await database.close();
    database = fixture;

    await tester.pumpWidget(await harness(locale: const Locale('ar')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Career appears as BOTH its carousel chip and the default
    // wall heading (the redesign's one-room-at-a-time layout).
    expect(find.text('المسيرة'), findsWidgets);
    expect(find.text('غرفة الكؤوس'), findsOneWidget);
    // Direction captured at the fold.
    final rtl = Directionality.of(
      tester.element(find.text('المسيرة').first),
    );
    // The room swap works mirrored: الهجوم renders as BOTH its chip
    // and the new wall heading after the tap.
    await tester.tap(find.text('الهجوم'));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('الهجوم'), findsWidgets);
    // Back to Career — the eligible CLAIM rungs live there (the
    // wins ladder's first rungs), localized استحق, below the fold.
    await tester.tap(find.text('المسيرة'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.scrollUntilVisible(
      find.text('استحق'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('استحق'), findsWidgets);
    expect(rtl, TextDirection.rtl);
  });
}
