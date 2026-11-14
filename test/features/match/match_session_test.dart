import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_session.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

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

/// Opens every pack and auto-picks a full 23-man squad. The 12 free
/// starting packs (cheapest four positions) leave the collection short,
/// so the remaining seed players are added directly before Auto Pick.
Future<CollectionStore> seededSquadStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(datasetJson(seedRows)));
  await store.createClub(
    clubName: 'FC Rivals',
    managerName: 'Mohamed',
    crestIndex: 0,
  );
  for (final pack in await store.getAvailablePacks()) {
    await store.openPack(packId: pack.id, random: math.Random(17));
  }
  final club = await store.getClub();
  final drawnIds = (await store.getCollection())
      .map((c) => c.base.playerId)
      .toSet();
  final now = DateTime.now();
  for (final row in seedRows) {
    if (drawnIds.contains(row[0] as int)) continue;
    await db
        .into(db.ownedPlayers)
        .insert(
          OwnedPlayersCompanion.insert(
            clubId: club!.id,
            playerId: row[0] as int,
            acquiredAt: now,
          ),
        );
  }
  await store.autoPickSquad();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatchSession friendly match (FR-024..FR-034)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededSquadStore(db);
    });

    tearDown(() async => db.close());

    Future<MatchReportResult> playFriendly({
      int restDays = 3,
      int seed = 5,
    }) async {
      final session = await MatchSession.create(
        store: store,
        seed: seed,
        opponentName: 'Cairo XI',
        opponentAverageOverall: 68,
      );
      session.simulateToEnd();
      return session.finish(restDays: restDays);
    }

    test('a full squad produces a complete, consistent report', () async {
      final report = await playFriendly();

      expect(report.state.isFinished, isTrue);
      expect(report.state.scoreHome, greaterThanOrEqualTo(0));
      expect(report.homeRatings.length, 23); // full squad
      expect(report.awayRatings.length, 11);
      // commentary is non-empty and consistent (FR-031)
      expect(report.commentary.first.text, contains('Kick-off'));
      expect(report.commentary.last.text, contains('Full time'));
      final goalLines = report.commentary
          .where((l) => l.text.startsWith('GOAL!'))
          .length;
      expect(goalLines, report.state.scoreHome + report.state.scoreAway);
      // man of the match exists and is a player who featured
      expect(report.manOfTheMatch, isNotNull);
      expect(report.manOfTheMatch!.played, isTrue);
    });

    test(
      'match rewards credit the club with a ledger row (GDD 17.6/FR-016)',
      () async {
        final before = (await store.getClub())!.coins;
        final report = await playFriendly();
        final after = (await store.getClub())!.coins;
        expect(after - before, report.rewardCoins);
        expect(report.rewardCoins, greaterThan(0));

        final ledger = await (db.select(
          db.coinTransactions,
        )..where((t) => t.reason.equals('match_reward'))).get();
        expect(ledger.length, 1);
        expect(ledger.first.amount, report.rewardCoins);
        expect(ledger.first.balanceAfter, after);
      },
    );

    test(
      'live tactical commands work through the session (FR-022/FR-029)',
      () async {
        final session = await MatchSession.create(
          store: store,
          seed: 33,
          opponentName: 'Cairo XI',
          opponentAverageOverall: 68,
        );
        // Half the match on balanced mentality.
        for (var m = 0; m < 45; m++) {
          session.advanceMinute();
        }
        session.queueCommand(
          const ChangeMentalityCommand(
            atMinute: 46,
            side: MatchSide.home,
            mentality: Mentality.attacking,
          ),
        );
        session.queueCommand(
          const LiveActionCommand(
            atMinute: 46,
            side: MatchSide.home,
            action: LiveMatchAction.pushForward,
          ),
        );
        final report = await session.finish();

        // User commands only (the AI opponent adapts on its own).
        final homeTactical = session.engine.events
            .where(
              (e) =>
                  e.type == MatchEventType.tacticalChange &&
                  e.side == MatchSide.home,
            )
            .toList();
        final homeLive = session.engine.events
            .where(
              (e) =>
                  e.type == MatchEventType.liveAction &&
                  e.side == MatchSide.home,
            )
            .toList();
        expect(homeTactical.length, 1);
        expect(homeLive.length, 1);
        // commands recorded for replay (GDD 12.5)
        expect(session.engine.appliedCommands.length, 2);
        expect(report.state.isFinished, isTrue);
      },
    );

    test('playing without a full XI is rejected (GDD 6.1)', () async {
      // A club with packs unopened has no squad at all.
      final db2 = memoryDb();
      final store2 = CollectionStore(db: db2);
      await store2.applyDatasetUpdate(
        PlayerDataset.fromJson(datasetJson(seedRows)),
      );
      await store2.createClub(
        clubName: 'Bare FC',
        managerName: 'M',
        crestIndex: 0,
      );
      try {
        await expectLater(
          MatchSession.create(
            store: store2,
            seed: 1,
            opponentName: 'X',
            opponentAverageOverall: 60,
          ),
          throwsA(isA<CollectionException>()),
        );
      } finally {
        await db2.close();
      }
    });
  });
}
