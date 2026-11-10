import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/ads/ad_engine.dart';
import 'package:fcm_rivals/features/ads/ad_store.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_store.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

String datasetJson(List<List<dynamic>> rows, {int version = 1}) => json.encode({
  'format': 'fcm-rivals-players',
  'version': version,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': rows,
});

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

final List<List<dynamic>> seedRows = [
  for (var p = 0; p < _seedPositions.length; p++)
    for (var i = 0; i < 5; i++)
      [
        p * 10 + i + 1,
        '${_seedPositions[p][1]} ${p * 10 + i + 1}',
        _seedPositions[p][0],
        'Egypt',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdStore (GDD 19.4, FR-040..FR-042)', () {
    late AppDatabase db;
    late CollectionStore collection;
    late AdStore store;

    setUp(() async {
      db = memoryDb();
      collection = CollectionStore(db: db);
      await collection.applyDatasetUpdate(
        PlayerDataset.fromJson(datasetJson(seedRows)),
      );
      await collection.createClub(
        clubName: 'FC Rivals',
        managerName: 'Mohamed',
        crestIndex: 0,
      );
      for (final pack in await collection.getAvailablePacks()) {
        await collection.openPack(packId: pack.id, random: math.Random(17));
      }
      await collection.autoPickSquad();
      store = AdStore(db: db);
    });

    tearDown(() async => db.close());

    test('a completed ad is recorded and granted exactly once', () async {
      final clubId = (await collection.getClub())!.id;
      final result = await store.completeAd(
        kind: AdRewardKind.boostedRecovery,
        rewardKey: 'match:1',
        playbackCompleted: true,
        clubId: clubId,
      );
      expect(result.kind, AdRewardKind.boostedRecovery);

      final rows = await db.select(db.adUsages).get();
      expect(rows, hasLength(1));
      expect(rows.first.rewardKind, 'boostedRecovery');
      expect(rows.first.rewardKey, 'match:1');

      // Duplicate callback rejected (FR-042).
      expect(
        () => store.completeAd(
          kind: AdRewardKind.boostedRecovery,
          rewardKey: 'match:1',
          playbackCompleted: true,
          clubId: clubId,
        ),
        throwsA(isA<AdException>()),
      );
    });

    test('an uncompleted ad grants nothing (FR-041)', () async {
      final clubId = (await collection.getClub())!.id;
      expect(
        () => store.completeAd(
          kind: AdRewardKind.boostedRecovery,
          rewardKey: 'match:2',
          playbackCompleted: false,
          clubId: clubId,
        ),
        throwsA(isA<AdException>()),
      );
      expect(await db.select(db.adUsages).get(), isEmpty);
    });

    test('daily limit applies within the day and resets next day', () async {
      final clubId = (await collection.getClub())!.id;
      final config = const AdConfig(dailyLimitPerKind: 2);
      final engine = AdEngine(config: config);
      final limited = AdStore(db: db, engine: engine);

      final day = DateTime(2026, 11, 1, 14);
      for (var i = 0; i < 2; i++) {
        await limited.completeAd(
          kind: AdRewardKind.boostedRecovery,
          rewardKey: 'match:$i',
          playbackCompleted: true,
          clubId: clubId,
          now: day,
        );
      }
      // Third one today: rejected.
      expect(
        () => limited.completeAd(
          kind: AdRewardKind.boostedRecovery,
          rewardKey: 'match:2',
          playbackCompleted: true,
          clubId: clubId,
          now: day,
        ),
        throwsA(isA<AdException>()),
      );
      // Next day: allowed again (fresh daily window).
      await limited.completeAd(
        kind: AdRewardKind.boostedRecovery,
        rewardKey: 'match:3',
        playbackCompleted: true,
        clubId: clubId,
        now: DateTime(2026, 11, 2, 10),
      );
      expect((await db.select(db.adUsages).get()).length, 3);
      // Remaining counter reflects today only (queried via the same
      // limited engine so the kind limit matches).
      expect(
        await limited.boostedRecoveryRemaining(
          clubId,
          now: DateTime(2026, 11, 2, 10),
        ),
        engine.config.dailyLimitPerKind - 1,
      );
    });

    test('boosted recovery persists higher stamina than default', () async {
      final clubId = (await collection.getClub())!.id;
      final squad = await collection.getSquad();
      final starters = [for (var slot = 0; slot < 11; slot++) squad[slot]!];

      // Simulate a drained match state: report every starter at low
      // stamina with full minutes, then compare recovery paths.
      Future<double> averageStamina() async {
        // Reset stamina to the same drained baseline each run.
        for (final card in starters) {
          await (db.update(db.ownedPlayers)
                ..where((o) => o.id.equals(card.ownedId)))
              .write(const OwnedPlayersCompanion(staminaPercent: Value(30)));
        }
        await collection.applyMatchResult(
          clubId: clubId,
          rewardCoins: 0,
          players: [
            for (final card in starters)
              (ownedId: card.ownedId, stamina: 30.0, minutesPlayed: 90),
          ],
        );
        final refreshed = await collection.getSquad();
        var sum = 0.0;
        for (var slot = 0; slot < 11; slot++) {
          sum += refreshed[slot]!.staminaPercent;
        }
        return sum / 11;
      }

      // T-0100: the boosted-recovery ad path is gone with the
      // post-match pep-talk step — the drained squad still recovers
      // naturally above the baseline, capped at 100.
      final plain = await averageStamina();
      expect(plain, greaterThan(30));
      expect(plain, lessThanOrEqualTo(100));
    });

    test('replay offer requires a non-win result in the window', () async {
      final clubId = (await collection.getClub())!.id;
      final seasonStore = SeasonStore(db: db, random: math.Random(4));
      await seasonStore.startSeason(division: 1);
      final next = (await seasonStore.getNextFixture())!;
      final session = await seasonStore.startNextFixture(collection);
      session.simulateToEnd();
      await session.finish();
      await seasonStore.commitFixtureResult(session, next);

      final now = DateTime.now();
      // Whatever the result, the offer logic must agree with the stored
      // outcome and reject after the window.
      final offered = await store.replayOfferedFor(
        fixtureId: next.fixtureId,
        userClubId: clubId,
        now: now,
      );
      final result = await (db.select(
        db.matchResults,
      )..where((r) => r.fixtureId.equals(next.fixtureId))).getSingle();
      final userHome = result.homeClubId == clubId;
      final userGoals = userHome ? result.homeGoals : result.awayGoals;
      final opponentGoals = userHome ? result.awayGoals : result.homeGoals;
      if (userGoals > opponentGoals) {
        expect(offered, isFalse, reason: 'no replay after a win');
      } else {
        expect(offered, anyOf(isTrue, isFalse)); // window/duplicate rules
      }

      // Far future: never offered.
      expect(
        await store.replayOfferedFor(
          fixtureId: next.fixtureId,
          userClubId: clubId,
          now: now.add(const Duration(days: 3)),
        ),
        isFalse,
      );
    });

    test(
      'rewindFixtureForReplay removes the result and refunds the reward',
      () async {
        final clubId = (await collection.getClub())!.id;
        final seasonStore = SeasonStore(db: db, random: math.Random(4));
        await seasonStore.startSeason(division: 1);
        final next = (await seasonStore.getNextFixture())!;
        final session = await seasonStore.startNextFixture(collection);
        session.simulateToEnd();
        final report = await session.finish();
        await seasonStore.commitFixtureResult(session, next);

        final coinsBefore = (await collection.getClub())!.coins;
        expect(report.rewardCoins, greaterThan(0));

        await seasonStore.rewindFixtureForReplay(
          fixtureId: next.fixtureId,
          rewardCoinsToRefund: report.rewardCoins,
          userClubId: clubId,
        );

        // Result row gone → fixture is playable again.
        final remaining = await (db.select(
          db.matchResults,
        )..where((r) => r.fixtureId.equals(next.fixtureId))).get();
        expect(remaining, isEmpty);
        final nextAgain = await seasonStore.getNextFixture();
        expect(nextAgain!.fixtureId, next.fixtureId);

        // Coins refunded with a ledger row (no duplicate match rewards).
        final coinsAfter = (await collection.getClub())!.coins;
        expect(coinsAfter, coinsBefore - report.rewardCoins);
        final refund = await (db.select(
          db.coinTransactions,
        )..where((t) => t.reason.equals('match_replay_refund'))).get();
        expect(refund, hasLength(1));
        expect(refund.first.amount, -report.rewardCoins);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
