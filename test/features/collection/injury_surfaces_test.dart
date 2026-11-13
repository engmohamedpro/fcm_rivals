/// T-0056: the collection surfaces' injury state — the grid card badge
/// and the detail sheet's availability line — over a real in-memory
/// store, in EN (fallback) and AR (delegates scoped in).
library;

import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmButton;
import 'package:fcm_rivals/core/ui/injury_badge.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/collection/player_detail_sheet.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/squad/squad_engine.dart' show PlayerCard;
import 'package:fcm_rivals/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CollectionStore store;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = CollectionStore(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Dataset + club + one owned player, marked injured when [matchesOut]
  /// is positive.
  Future<int> seedOwned({required int matchesOut}) async {
    // The shipped tm bundle (owner request 2026-11-12): loaded from
    // disk inside runAsync — rootBundle has no asset to serve in the
    // plain test environment.
    final playersText = await rootBundle.loadString(
      'assets/data/tm-players.json',
    );
    final iconsText = await rootBundle.loadString(
      'assets/data/tm-icons.json',
    );
    final clubsText = await rootBundle.loadString('assets/data/tm-clubs.json');
    final leaguesText = await rootBundle.loadString(
      'assets/data/tm-leagues.json',
    );
    await store.importBundledDataset(
      PlayerDataset.fromTmBundle(
        playersJson: playersText,
        iconsJson: iconsText,
        clubsJson: clubsText,
        leaguesJson: leaguesText,
      ),
    );
    final clubId = await store.createClub(
      clubName: 'Pyramid United',
      managerName: 'Mohamed',
      crestIndex: 0,
    );
    // A fresh club owns packs, not players (GDD 5.8): open the first
    // starting pack to materialize one owned instance.
    final packs = await store.getAvailablePacks();
    await store.openPack(packId: packs.first.id, random: math.Random(5));
    final owned = await (db.select(
      db.ownedPlayers,
    )..where((o) => o.clubId.equals(clubId))).get();
    final row = owned.first;
    if (matchesOut > 0) {
      await (db.update(
        db.ownedPlayers,
      )..where((o) => o.id.equals(row.id))).write(
        OwnedPlayersCompanion(
          injuryMatchesRemaining: Value(matchesOut),
          injuryKind: const Value('serious'),
        ),
      );
    }
    return row.id;
  }

  Future<PlayerCard> ownedCard(int ownedId) async =>
      (await store.getCollection()).firstWhere((c) => c.ownedId == ownedId);

  Future<void> pumpSheet(
    WidgetTester tester,
    PlayerCard card, {
    Locale? locale,
    required String trigger,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: locale == null
            ? null
            : AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (sheetContext) => Center(
              child: FcmButton(
                label: trigger,
                onPressed: () =>
                    showPlayerDetail(sheetContext, card: card),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(trigger));
    await tester.pumpAndSettle(const Duration(seconds: 1));
  }

  testWidgets('the detail sheet states the availability with the badge '
      '(EN)', (tester) async {
    int ownedId = 0;
    PlayerCard? card;
    await tester.runAsync(() async {
      ownedId = await seedOwned(matchesOut: 3);
      card = await ownedCard(ownedId);
    });
    await pumpSheet(tester, card!, trigger: 'open');

    expect(find.byType(InjuryBadge), findsOneWidget);
    expect(find.text('Out for 3 matches'), findsOneWidget);
  });

  testWidgets('a fit player shows no availability line', (tester) async {
    int ownedId = 0;
    PlayerCard? card;
    await tester.runAsync(() async {
      ownedId = await seedOwned(matchesOut: 0);
      card = await ownedCard(ownedId);
    });
    await pumpSheet(tester, card!, trigger: 'open');

    expect(find.textContaining('Out for'), findsNothing);
    expect(find.byType(InjuryBadge), findsNothing);
  });

  testWidgets('the Arabic sheet renders the localized line (RTL)',
      (tester) async {
    int ownedId = 0;
    PlayerCard? card;
    await tester.runAsync(() async {
      ownedId = await seedOwned(matchesOut: 2);
      card = await ownedCard(ownedId);
    });
    await pumpSheet(
      tester,
      card!,
      trigger: 'افتح',
      locale: const Locale('ar'),
    );

    expect(find.text('خارج 2 مباراة'), findsOneWidget);
  });
}
