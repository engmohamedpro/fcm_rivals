// Regression tests for the Major review findings:
// M1 — the club row is a live drift watch (every coin movement
//      re-emits without manual provider invalidation);
// M2 — the replay refund is clamped to the balance actually present,
//      so the balance never goes below zero and the ledger agrees;
// M3 — spendCoins throws a typed InsufficientFundsException, so call
//      sites map it to their user-facing error instead of parsing
//      message strings.
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/database/coin_ops.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/packs/pack_engine.dart'
    show PackCategory, PackTier;
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/core/domain/players.dart' show Position;
import 'package:fcm_rivals/features/season/season_store.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<CollectionStore> seededStore() async {
    final store = CollectionStore(db: db);
    await store.applyDatasetUpdate(_seedDataset());
    await store.createClub(
      clubName: 'Major FC',
      managerName: 'Tester',
      crestIndex: 0,
    );
    // The createClub flow shelves the starting packs; open them so the
    // club owns real players, then seat a starting XI — matches are
    // unplayable (and pack draws find no eligible players) without
    // both, exactly like the ad-store tests set up.
    for (final pack in await store.getAvailablePacks()) {
      await store.openPack(packId: pack.id, random: math.Random(17));
    }
    await store.autoPickSquad();
    return store;
  }

  Future<int> balanceOf() async => (await (db.select(
    db.clubs,
  )..where((c) => c.isUser.equals(true))).getSingle()).coins;

  group('M1: live club watch', () {
    test('watchClub re-emits on every coin movement — a UI listening to '
        'the stream sees each new balance without invalidation', () async {
      final store = await seededStore();
      final club = (await store.getClub())!;
      final emitted = <int>[];
      final subscription = store.watchClub().listen(
        (row) => emitted.add(row?.coins ?? -1),
      );
      // Let the first emission (current row) land.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.creditCoins(club.id, 500, reason: 'match_reward');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.spendCoins(club.id, 200, reason: 'pack_purchase');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      final initial = emitted.first;
      expect(emitted, containsAllInOrder([initial, initial + 500]));
      expect(emitted.last, initial + 300);
      // The stream never diverges from the database: last emission is
      // exactly the row's coins after both movements.
      expect(emitted.last, await balanceOf());
    });
  });

  group('M2: clamped replay refund', () {
    test(
      'refund takes back only what remains when the user already '
      'spent the reward — balance never goes below zero, ledger agrees',
      () async {
        final store = await seededStore();
        final seasonStore = SeasonStore(db: db, random: math.Random(4));
        await seasonStore.startSeason(division: 1);
        final club = (await store.getClub())!;
        final fixture = (await seasonStore.getNextFixture())!;

        // Play the fixture; the reward is credited by the flow itself.
        final session = await seasonStore.startNextFixture(store);
        session.simulateToEnd();
        final report = await session.finish();
        await seasonStore.commitFixtureResult(session, fixture);
        expect(report.rewardCoins, greaterThan(0));

        // The user spends the reward down to a small remainder.
        final remainder = 100;
        final current = await balanceOf();
        expect(
          current,
          greaterThan(remainder),
          reason: 'the starting grant must dwarf the drained remainder',
        );
        await db.spendCoins(club.id, current - remainder, reason: 'test_setup');
        expect(await balanceOf(), remainder);

        // Rewind: refund clamps to the remainder, not the full reward.
        await seasonStore.rewindFixtureForReplay(
          fixtureId: fixture.fixtureId,
          rewardCoinsToRefund: report.rewardCoins,
          userClubId: club.id,
        );

        expect(await balanceOf(), 0, reason: 'clamped, never negative');
        final refunds = await (db.select(
          db.coinTransactions,
        )..where((t) => t.reason.equals('match_replay_refund'))).get();
        expect(refunds, hasLength(1));
        expect(refunds.single.amount, -remainder);
        expect(refunds.single.balanceAfter, 0);
        // The result row is gone — the fixture is replayable.
        final remaining = await (db.select(
          db.matchResults,
        )..where((r) => r.fixtureId.equals(fixture.fixtureId))).get();
        expect(remaining, isEmpty);
      },
    );

    test(
      'refund with enough balance still takes the full reward back',
      () async {
        final store = await seededStore();
        final seasonStore = SeasonStore(db: db, random: math.Random(4));
        await seasonStore.startSeason(division: 1);
        final club = (await store.getClub())!;
        final fixture = (await seasonStore.getNextFixture())!;
        final session = await seasonStore.startNextFixture(store);
        session.simulateToEnd();
        final report = await session.finish();
        await seasonStore.commitFixtureResult(session, fixture);

        final before = await balanceOf();
        await seasonStore.rewindFixtureForReplay(
          fixtureId: fixture.fixtureId,
          rewardCoinsToRefund: report.rewardCoins,
          userClubId: club.id,
        );
        expect(await balanceOf(), before - report.rewardCoins);
      },
    );
  });

  group('M3: typed insufficient funds', () {
    test('spendCoins throws InsufficientFundsException — no message '
        'parsing at call sites', () async {
      final store = await seededStore();
      final club = (await store.getClub())!;
      final before = await balanceOf();
      await expectLater(
        db.spendCoins(club.id, before + 1, reason: 'pack_purchase'),
        throwsA(isA<InsufficientFundsException>()),
      );
      // The exception still renders the user-facing message.
      try {
        await db.spendCoins(club.id, before + 1, reason: 'pack_purchase');
      } on InsufficientFundsException catch (e) {
        expect(e.amount, before + 1);
        expect(e.toString(), 'Not enough coins');
      }
      expect(await balanceOf(), before);
    });

    test('buyPack maps the typed failure to CollectionException with '
        'the exact user-facing message', () async {
      final store = await seededStore();
      final club = (await store.getClub())!;
      // A ST position offer: the seed pool holds two STs, so the scope
      // is never empty and the failure can only be the coin guard.
      final offers = await store.getStoreOffers();
      final stOffer = offers.firstWhere(
        (o) => o.scopeValue == 'ST' && o.tier == PackTier.rare,
      );
      final before = await balanceOf();
      // Drain to 1 coin, far below the price.
      await db.spendCoins(club.id, before - 1, reason: 'test_setup');
      await expectLater(
        () => store.buyPack(
          category: PackCategory.position,
          position: Position.st,
          tier: stOffer.tier,
        ),
        throwsA(
          isA<CollectionException>().having(
            (e) => e.message,
            'message',
            'Not enough coins',
          ),
        ),
      );
    });
  });
}

/// A minimal valid dataset (one player per position, plus a second ST
/// so the pool has variety) — just enough for the store to shelve pack
/// offers. Mirrors the seed shape used by collection_store_test.
PlayerDataset _seedDataset() => PlayerDataset.fromJson(
  _datasetJson([
    [1, 'Keeper One', 'GK', 'Egypt', 500_000],
    [2, 'Back One', 'CB', 'Egypt', 800_000],
    [3, 'Mid One', 'CM', 'Egypt', 1_200_000],
    [4, 'Wing One', 'RW', 'Egypt', 2_000_000],
    [5, 'Striker One', 'ST', 'Egypt', 3_000_000],
    [6, 'Anchor One', 'CDM', 'Egypt', 900_000],
    [7, 'Winger One', 'LW', 'Egypt', 1_800_000],
    [8, 'Playmaker One', 'CAM', 'Egypt', 2_400_000],
    [9, 'Leftback One', 'LB', 'Egypt', 700_000],
    [10, 'Rightback One', 'RB', 'Egypt', 700_000],
    [11, 'Leftmid One', 'LM', 'Egypt', 1_500_000],
    [12, 'Rightmid One', 'RM', 'Egypt', 1_500_000],
    [13, 'Striker Two', 'ST', 'Egypt', 25_000_000],
  ]),
);

String _datasetJson(List<List<dynamic>> rows) => jsonEncode({
  'format': 'fcm-rivals-players',
  'version': 1,
  'asOf': '2026-11-04',
  'digest': 'test',
  'players': rows,
});
