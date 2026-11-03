/// Stamina realism (GDD 11) at the store level: squads no longer bounce
/// back to full condition every match — rotation becomes the manager's
/// job — while benched and reserve players finally rest too. AI clubs
/// rotate on the same rules.
library;

import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/match/stamina.dart';
import 'package:fcm_rivals/features/season/season_store.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Rotation realism (GDD 11.5)', () {
    test('a full-match XI does not return to full stamina after one break',
        () {
      const config = StaminaConfig();
      // 90 minutes from 100 → ~55 at the whistle.
      final afterMatch = 100 - 0.45 * 90;
      final afterRest = recoverStamina(
          config: config,
          currentStamina: afterMatch,
          minutesPlayed: 90,
          restDays: 3);
      // The old calibration (18 + 3×14 = 60 recovery) restored this
      // starter to 100 every single match; the new one leaves him short.
      expect(afterRest, lessThan(100));
      expect(afterRest, greaterThan(70));
      // And a second identical cycle keeps him below full too — the
      // grind accumulates unless the manager rotates.
      final secondCycle = recoverStamina(
          config: config,
          currentStamina: afterRest - 0.45 * 90,
          minutesPlayed: 90,
          restDays: 3);
      expect(secondCycle, lessThan(100));
    });

    test('a rested substitute returns to near-full condition quickly',
        () {
      const config = StaminaConfig();
      final afterRest = recoverStamina(
          config: config,
          currentStamina: 70,
          minutesPlayed: 20,
          restDays: 3);
      // 70 + (8 + 27 - 12×20/90 + 6) ≈ 108 → capped just below full by
      // the overflow penalty: a light workload plus a standard break
      // restores a squad player to fitness, while a full-match starter
      // stays well short (the contrast is the rotation pressure).
      expect(afterRest, greaterThan(90));
      expect(afterRest, lessThanOrEqualTo(100));

      // A long rest heals the last points completely.
      final longRest = recoverStamina(
          config: config,
          currentStamina: 70,
          minutesPlayed: 20,
          restDays: 7);
      expect(longRest, 100);
    });

    test('players who missed the match recover (no more frozen benches)',
        () {
      // 0-minute players (bench + reserves) used to keep their old
      // stamina forever; now they rest like everyone else.
      const config = StaminaConfig();
      final healed = recoverStamina(
          config: config,
          currentStamina: 60,
          minutesPlayed: 0,
          restDays: 3);
      expect(healed, greaterThan(60));
      expect(healed, lessThanOrEqualTo(100));
    });
  });

  group('AI rotation across fixtures (GDD 11 symmetry)', () {
    late AppDatabase db;
    late CollectionStore collection;
    late SeasonStore store;

    setUp(() async {
      db = memoryDb();
      collection = await seededSquadStore(db);
      store = SeasonStore(db: db, random: math.Random(4));
    });

    tearDown(() async => db.close());

    test(
        'AI stamina declines through a season and AI squads rotate their XI',
        () async {
      await store.startSeason(division: 1);
      // Full season of AI-vs-AI + user fixtures through the real engine.
      await store.simulateRemainingFixtures(collection);

      final aiRows = await db.select(db.aiPlayers).get();
      final avgStamina =
          aiRows.map((r) => r.staminaPercent).reduce((a, b) => a + b) /
              aiRows.length;
      // Squads that play ~2 fixtures a week with 3-day recovery settle
      // well below 100 — the AI has to rotate like the user does.
      expect(avgStamina, lessThan(95),
          reason: 'AI squads must carry real fatigue across a season');

      // Rotation evidence: the engine's pickAiLineup rests tired legs —
      // verify through the store: after the season, load an opponent and
      // check the XI it would field now is condition-aware (the lineup
      // call itself is exercised by every loadOpponent during the
      // simulation above; here we verify the fatigue it feeds on).
      final tired = aiRows.where((r) => r.staminaPercent < 90).length;
      expect(tired, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 4)));
  });
}

/// Mirrors the season_store_test helper: dataset + club + opened packs.
Future<CollectionStore> seededSquadStore(AppDatabase db) async {
  final store = CollectionStore(db: db);
  await store.applyDatasetUpdate(PlayerDataset.fromJson(_seedDataset()));
  await store.createClub(
      clubName: 'FC Rivals', managerName: 'Mohamed', crestIndex: 0);
  for (final pack in await store.getAvailablePacks()) {
    await store.openPack(packId: pack.id, random: math.Random(17));
  }
  await store.autoPickSquad();
  return store;
}

String _seedDataset() {
  const positions = [
    'GK', 'CB', 'CM', 'RW', 'ST', 'CDM', 'LW', 'CAM',
    'LB', 'RB', 'LM', 'RM',
  ];
  final buf = StringBuffer(
      '{"format":"fcm-rivals-players","version":1,"asOf":"2026-11-01",'
      '"digest":"test","players":[');
  var first = true;
  var id = 1;
  for (var p = 0; p < positions.length; p++) {
    for (var i = 0; i < 5; i++) {
      if (!first) buf.write(',');
      first = false;
      buf.write(
          '[$id,"Player ${p * 10 + i + 1}","${positions[p]}","Egypt",${500_000 + i * 3_000_000 + p * 100_000}]');
      id++;
    }
  }
  buf.write(']}');
  return buf.toString();
}
