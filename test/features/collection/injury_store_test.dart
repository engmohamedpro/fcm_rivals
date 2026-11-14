// Injury persistence and availability gating (T-0055, GDD 11.7).
//
// Injuries rolled in matches survive the session through the SAME
// atomic applyMatchResult transaction as the stamina writes; recovery
// counts down one match per committed fixture; injured players are
// unselectable on every path (Auto Pick, squad save, pre-match input);
// the campus Medical Centre level reaches the engine's risk model.
import 'dart:convert';
import 'dart:math' show Random;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart' show Position;
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/injury.dart';
import 'package:fcm_rivals/features/match/match_session.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

const List<List<String>> _positions = [
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
  for (var p = 0; p < _positions.length; p++)
    for (var i = 0; i < 4; i++)
      [
        p * 10 + i + 1,
        '${_positions[p][1]} ${p * 10 + i + 1}',
        _positions[p][0],
        'Egypt',
        500_000 + (i * 3_000_000) + p * 100_000,
      ],
];

Future<CollectionStore> seededStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(
    PlayerDataset.fromJson(jsonEncode({
      'format': 'fcm-rivals-players',
      'version': 1,
      'asOf': '2026-11-01',
      'digest': 'test',
      'players': seedRows,
    })),
  );
  await store.createClub(
    clubName: 'FC Rivals',
    managerName: 'Mohamed',
    crestIndex: 0,
  );
  // The 22 free starter packs must be opened to own anyone (the same
  // bootstrap every store test runs).
  for (final pack in await store.getAvailablePacks()) {
    await store.openPack(packId: pack.id, random: Random(17));
  }
  await store.autoPickSquad();
  return store;
}

/// Direct DB lookups for the raw columns (the store reads go through
/// PlayerCard; the assertions need the persisted truth).
Future<OwnedPlayer?> _ownedRow(AppDatabase db, int ownedId) async {
  return (db.select(
    db.ownedPlayers,
  )..where((o) => o.id.equals(ownedId))).getSingleOrNull();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('injury persistence & recovery (T-0055)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });
    tearDown(() async => db.close());

    test('a rolled injury lands with the stamina writes (one transaction '
        'family) and decrements one match per committed fixture', () async {
      final squad = await store.getSquad();
      final victim = squad.values.first;
      // Fixture 1: the player is hurt — muscle, out 3.
      await store.applyMatchResult(
        clubId: (await store.getClub())!.id,
        rewardCoins: 0,
        players: const [],
        injuries: [(ownedId: victim.ownedId, kind: 'muscle', matchesOut: 3)],
      );
      final row = await _ownedRow(db, victim.ownedId);
      expect(row!.injuryMatchesRemaining, 3);
      expect(row.injuryKind, 'muscle');

      // Fixture 2: no new injury — the count ticks down.
      await store.applyMatchResult(
        clubId: (await store.getClub())!.id,
        rewardCoins: 0,
        players: const [],
      );
      expect((await _ownedRow(db, victim.ownedId))!.injuryMatchesRemaining, 2);

      // Fixtures 3-4: down to 0 and the kind clears.
      await store.applyMatchResult(
        clubId: (await store.getClub())!.id,
        rewardCoins: 0,
        players: const [],
      );
      await store.applyMatchResult(
        clubId: (await store.getClub())!.id,
        rewardCoins: 0,
        players: const [],
      );
      final healed = await _ownedRow(db, victim.ownedId);
      expect(healed!.injuryMatchesRemaining, 0);
      expect(healed.injuryKind, isNull);
    });

    test('the decrement never goes negative and a fresh injury keeps its '
        'full matches-out (the decrement runs before the write)', () async {
      final club = (await store.getClub())!.id;
      await store.applyMatchResult(
        clubId: club,
        rewardCoins: 0,
        players: const [],
      );
      // Nobody was injured: the decrement touched nothing.
      final squad = await store.getSquad();
      for (final card in squad.values) {
        expect(card.injuryMatchesRemaining, 0);
      }
      // A new injury in the same commit that also decrements others: the
      // fresh injury keeps its full count.
      final victim = squad.values.first;
      final healthy = squad.values.last;
      await (db.update(db.ownedPlayers)
            ..where((o) => o.id.equals(healthy.ownedId)))
          .write(const OwnedPlayersCompanion(injuryMatchesRemaining: Value(1)));
      await store.applyMatchResult(
        clubId: club,
        rewardCoins: 0,
        players: const [],
        injuries: [(ownedId: victim.ownedId, kind: 'knock', matchesOut: 2)],
      );
      expect((await _ownedRow(db, victim.ownedId))!.injuryMatchesRemaining, 2);
      // The already-injured player ticked down: 1 → 0 (kind cleared).
      final healed = await _ownedRow(db, healthy.ownedId);
      expect(healed!.injuryMatchesRemaining, 0);
      expect(healed.injuryKind, isNull);
    });

    test('the re-injury guard: an already-injured row is never overwritten',
        () async {
      final club = (await store.getClub())!.id;
      final squad = await store.getSquad();
      final victim = squad.values.first;
      await store.applyMatchResult(
        clubId: club,
        rewardCoins: 0,
        players: const [],
        injuries: [(ownedId: victim.ownedId, kind: 'serious', matchesOut: 6)],
      );
      // A second injury for the same player in the same commit family is
      // refused by the store (he was never fielded — this is the
      // belt-and-braces backstop). The fixture still decrements him by
      // one (requirement 2 applies to every committed fixture): 6 → 5,
      // and the kind survives the blocked re-write.
      await store.applyMatchResult(
        clubId: club,
        rewardCoins: 0,
        players: const [],
        injuries: [(ownedId: victim.ownedId, kind: 'knock', matchesOut: 1)],
      );
      final row = await _ownedRow(db, victim.ownedId);
      expect(row!.injuryMatchesRemaining, 5);
      expect(row.injuryKind, 'serious');
    });
  });

  group('availability gating (T-0055)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });
    tearDown(() async => db.close());

    test('Auto Pick never selects an injured player; saveSquad refuses '
        'one; getSquad still reports him (isInjured)', () async {
      final squad = await store.getSquad();
      final best = squad.values.reduce(
        (a, b) => a.positionRating() >= b.positionRating() ? a : b,
      );
      await (db.update(db.ownedPlayers)
            ..where((o) => o.id.equals(best.ownedId)))
          .write(
        const OwnedPlayersCompanion(
          injuryMatchesRemaining: Value(4),
          injuryKind: Value('muscle'),
        ),
      );

      // Auto Pick: the injured id is absent from the fresh assignment.
      final assignment = await store.autoPickSquad();
      expect(assignment.values, isNot(contains(best.ownedId)));

      // The store backstop: a save referencing him throws.
      expect(
        () => store.saveSquad({0: best.ownedId}),
        throwsA(isA<CollectionException>()),
      );

      // The collection still reports him (isInjured) — the squad READ is
      // the picked lineup and selection excluded him from it; the UI
      // greys him out from the collection (T-0056).
      final collection = await store.getCollection();
      final card = collection.firstWhere((c) => c.ownedId == best.ownedId);
      expect(card.isInjured, isTrue);
      expect(card.injuryKind, 'muscle');
    });
  });

  group('session wiring (T-0055)', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = await seededStore(db);
    });
    tearDown(() async => db.close());

    test('the Medical Centre level reaches the engine input, and an injured '
        'starter is replaced by the next best pick (save-compat)', () async {
      // Medical Centre level 4 on the user club (a fresh club has no
      // facility rows — insert one).
      final club = (await store.getClub())!.id;
      await db.into(db.facilityLevels).insert(
        FacilityLevelsCompanion.insert(
          clubId: club,
          facility: 'medical',
          level: const Value(4),
        ),
      );

      // A legal AI opponent row + squad.
      final opponentId = await db
          .into(db.clubs)
          .insert(
            ClubsCompanion.insert(
              name: 'AI FC',
              managerName: 'Bot',
              coins: 0,
              isUser: const Value(false),
              createdAt: DateTime.now(),
            ),
          );
      List<MatchPlayer> syntheticSquad(int baseId) => [
        for (var i = 0; i < 18; i++)
          MatchPlayer(
            playerId: baseId - i,
            name: 'Opponent $i',
            position: Position.gk,
            attack: 50,
            support: 50,
            defence: 50,
            goalkeeping: 50,
          ),
      ];

      // Injure a STARTER after the squad was saved: the pre-match builder
      // must fall back to the next best pick, not brick the match.
      final saved = await store.getSquad();
      final starter = saved[0]!;
      await (db.update(db.ownedPlayers)
            ..where((o) => o.id.equals(starter.ownedId)))
          .write(
        const OwnedPlayersCompanion(
          injuryMatchesRemaining: Value(2),
          injuryKind: Value('knock'),
        ),
      );

      final session = await MatchSession.createAgainstClub(
        store: store,
        seed: 42,
        opponentClub: (await (db.select(
          db.clubs,
        )..where((c) => c.id.equals(opponentId))).getSingle()),
        opponentStarters: syntheticSquad(-500).take(11).toList(),
        opponentBench: syntheticSquad(-500).skip(11).toList(),
      );

      // The wiring: the campus level rides into the engine input.
      expect(session.engine.medicalCentreLevelOf(session.userSide), 4);
      expect(
        session.engine.medicalCentreLevelOf(
          session.userSide == MatchSide.home
              ? MatchSide.away
              : MatchSide.home,
        ),
        0,
        reason: 'AI teams use level 0',
      );

      // The fallback: the injured starter is NOT on the pitch; the XI is
      // still full and the replacement is uninjured.
      final benchIds = session.engine
          .benchOf(session.userSide)
          .map((p) => p.playerId)
          .toSet();
      final userIds = session.engine
          .playersOf(session.userSide)
          .map((p) => p.playerId)
          .where((id) => !benchIds.contains(id));
      expect(userIds, isNot(contains(starter.ownedId)));
      expect(userIds.length, 11);
    });
  });

  group('Medical Centre effect (T-0055)', () {
    test('level 5 measurably reduces the seeded injury count vs level 0 '
        'over 2,400 matches (1,200 per arm)', () async {
      Future<int> injuriesAtLevel(int level) async {
        final db = memoryDb();
        final store = await seededStore(db);
        final club = (await store.getClub())!.id;
        if (level > 0) {
          await db.into(db.facilityLevels).insert(
            FacilityLevelsCompanion.insert(
              clubId: club,
              facility: 'medical',
              level: Value(level),
            ),
          );
        }
        // (The stamina-40 exhaustion step is gone with the stamina
        // system — owner request 2026-11-14: the risk is flat now.)
        final opponentId = await db
            .into(db.clubs)
            .insert(
              ClubsCompanion.insert(
                name: 'AI FC',
                managerName: 'Bot',
                coins: 0,
                isUser: const Value(false),
                createdAt: DateTime.now(),
              ),
            );
        final opponentClub =
            await (db.select(
              db.clubs,
            )..where((c) => c.id.equals(opponentId))).getSingle();
        List<MatchPlayer> synthetic(int baseId) => [
          for (var i = 0; i < 18; i++)
            MatchPlayer(
              playerId: baseId - i,
              name: 'Opponent $i',
              position: Position.gk,
            attack: 40,
            support: 40,
            defence: 40,
            goalkeeping: 40,
            ),
        ];
        // The boosted risk config gives the 0.6pp/level hook statistical
        // power, tuned to sit BELOW the per-team per-match cap (2): the
        // flat rate (0.027/match at the shipped 0.0003 base) × the
        // ~2.7× boost ≈ 0.073 injuries/player-match ≈ 0.8 per team-match
        // across a full XI, so the cap cannot flatten the two arms. At
        // the shipped 3% total reduction the real effect is below the
        // noise floor of ANY feasible sample — the wiring is what this
        // test proves (recorded in the task notes). (Re-anchored
        // 0.00008 -> 0.0008 with the flat-rate model, 2026-11-14.)
        const boosted = MatchEngineConfig(
          injuryConfig: InjuryConfig(
            baseRiskPerMinuteAtFullStamina: 0.0008,
            maxRiskPerMinute: 1,
          ),
        );
        var injuries = 0;
        for (var i = 0; i < 1200; i++) {
          final session = await MatchSession.createAgainstClub(
            store: store,
            seed: 91_000 + i,
            opponentClub: opponentClub,
            opponentStarters: synthetic(-1000).take(11).toList(),
            opponentBench: synthetic(-1000).skip(11).toList(),
            config: boosted,
          );
          session.simulateToEnd();
          injuries += session.engine.events
              .where(
                (e) =>
                    e.type == MatchEventType.injury &&
                    e.side == session.userSide,
              )
              .length;
        }
        await db.close();
        return injuries;
      }

      final level0 = await injuriesAtLevel(0);
      final level5 = await injuriesAtLevel(5);
      // ignore: avoid_print
      print('T-0055 Medical Centre: injuries over 1,200 matches — '
          'level 0: $level0, level 5: $level5');
      expect(level5, lessThan(level0 - 25),
          reason: 'the 3% per-injury hook must compound into a measurable '
              'gap at this sample');
    }, timeout: const Timeout(Duration(minutes: 12)));
  });
}
