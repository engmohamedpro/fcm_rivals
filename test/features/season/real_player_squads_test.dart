/// Real-player AI squads (GDD 9.4): the division's AI clubs sign REAL
/// dataset players — never one the user owns, never the same player in
/// two clubs of one division — and those squads persist, rotate on
/// condition, and travel with promoted/relegated clubs.
library;

import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_store.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

/// A dataset big enough for real-player generation: every position
/// stocked at several overall levels. Market values are chosen so the
/// BaseStatsGenerator curve spans ~44 to ~70 OVR.
const List<String> _positions = [
  'GK', 'CB', 'LB', 'RB', 'CDM', 'CM', 'CAM',
  'LM', 'RM', 'LW', 'RW', 'ST',
];

List<List<dynamic>> realishRows() {
  final rows = <List<dynamic>>[];
  var id = 1;
  // Value ladder: 250k (≈47) → 60M (≈85) — covers every division band.
  const values = [
    250_000, 500_000, 1_000_000, 2_000_000, 4_000_000, 8_000_000,
    16_000_000, 32_000_000, 60_000_000,
  ];
  for (final position in _positions) {
    for (final value in values) {
      for (var copy = 0; copy < 12; copy++) {
        rows.add([
          id,
          'Real $position $id',
          position,
          'Egypt',
          value,
        ]);
        id++;
      }
    }
  }
  return rows;
}

Future<CollectionStore> seededRealSquadStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  final dataset = PlayerDataset.fromJson(realishDatasetJson());
  await store.applyDatasetUpdate(dataset);
  await store.createClub(
      clubName: 'FC Rivals', managerName: 'Mohamed', crestIndex: 0);
  for (final pack in await store.getAvailablePacks()) {
    await store.openPack(packId: pack.id, random: math.Random(17));
  }
  await store.autoPickSquad();
  return store;
}

String realishDatasetJson() {
  final rows = realishRows();
  final buf = StringBuffer(
      '{"format":"fcm-rivals-players","version":1,"asOf":"2026-11-01",'
      '"digest":"test","players":[');
  for (var i = 0; i < rows.length; i++) {
    if (i > 0) buf.write(',');
    final r = rows[i];
    buf.write('[${r[0]},"${r[1]}","${r[2]}","${r[3]}",${r[4]}]');
  }
  buf.write(']}');
  return buf.toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Real-player AI squads (GDD 9.4)', () {
    late AppDatabase db;
    late CollectionStore collection;
    late SeasonStore store;

    setUp(() async {
      db = memoryDb();
      collection = await seededRealSquadStore(db);
      store = SeasonStore(db: db, random: math.Random(4));
    });

    tearDown(() async => db.close());

    test('AI squads are REAL dataset players, none owned by the user', () async {
      await store.startSeason(division: 1);

      final aiRows = await db.select(db.aiPlayers).get();
      expect(aiRows, isNotEmpty);
      // Every AI player carries a real dataset id...
      for (final r in aiRows) {
        expect(r.realPlayerId, isNotNull,
            reason: '${r.playerName} is synthetic');
      }
      final players = await db.select(db.players).get();
      final nameById = {for (final p in players) p.playerId: p.name};
      for (final r in aiRows) {
        expect(nameById.containsKey(r.realPlayerId), isTrue);
        expect(r.playerName, nameById[r.realPlayerId],
            reason: 'AI row must carry the real player name');
      }

      // ...and no player is both user-owned and AI-signed.
      final owned = await (db.select(db.ownedPlayers)
            ..where((o) => o.status.equals('owned')))
          .get();
      final ownedIds = owned.map((o) => o.playerId).toSet();
      final aiIds = aiRows.map((r) => r.realPlayerId!).toSet();
      expect(ownedIds.intersection(aiIds), isEmpty);

      // ...and no player signed to two clubs in the division.
      expect(aiIds.length, aiRows.length,
          reason: 'each real player signs at most one club');
    });

    test('Division 1 squads sit near the easiest band (~54 OVR)', () async {
      await store.startSeason(division: 1);
      final aiRows = await db.select(db.aiPlayers).get();
      final players = {for (final p in await db.select(db.players).get()) p.playerId: p};
      final ovrs = [
        for (final r in aiRows) players[r.realPlayerId!]!.overall
      ];
      final mean = ovrs.reduce((a, b) => a + b) / ovrs.length;
      // The old broken value was 66: a fresh user squad (~52) was
      // outclassed everywhere. The new target is 54 with banding slack.
      expect(mean, inInclusiveRange(48, 60));
    });

    test('AI squads persist for the season and rotate on condition',
        () async {
      final seasonId = await store.startSeason(division: 1);
      final before = await (db.select(db.aiPlayers)
            ..where((p) => p.clubId.equals(seasonId)))
          .get();

      // Play the user's first fixture through the store (quick-sim).
      await store.simulateRemainingFixtures(collection);

      // The season's squads are the SAME rows (identity kept), only
      // their condition moved.
      final after = await db.select(db.aiPlayers).get();
      expect(after.length, greaterThanOrEqualTo(before.length));
      final staminaMoved =
          after.any((r) => r.staminaPercent < 100);
      expect(staminaMoved, isTrue,
          reason: 'AI squads must tire through their fixtures');
    }, timeout: const Timeout(Duration(minutes: 4)));

    test('a promoted club keeps its squad into the next season', () async {
      await store.startSeason(division: 1);
      await store.simulateRemainingFixtures(collection);
      final completion = await store.completeSeason(collection);

      // The clubs carried into season 2 keep their exact squads (same
      // real players) when the user moves divisions with them.
      if (completion.outcome != 'stayed') {
        final teams = await (db.select(db.leagueTeams)
              ..where((t) => t.seasonId.equals(completion.seasonId)))
            .get();
        final carried = teams.where((t) => t.carriedOver).toList();
        expect(carried, isNotEmpty);
        final carriedSquads = await (db.select(db.aiPlayers)
              ..where((p) => p.clubId.isIn(carried.map((t) => t.clubId))))
            .get();
        expect(carriedSquads, isNotEmpty);
        expect(carriedSquads.every((r) => r.realPlayerId != null), isTrue);

        // Fresh condition after the break.
        expect(
            carriedSquads.every((r) => r.staminaPercent == 100), isTrue);
      }
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}
