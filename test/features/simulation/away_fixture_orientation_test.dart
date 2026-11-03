import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';
import 'package:fcm_rivals/features/season/season_store.dart';
import 'package:fcm_rivals/features/simulation/economy_simulator_dataset.dart';

/// Regression test for the away-fixture inversion: persisted results
/// must keep the engine's home/away orientation (user away = user goals
/// in the away column). Found by the §30 economy simulation harness.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('away fixtures persist engine orientation (no score swap)', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final dataset = SimDataset.generate(
        band: SimValueBand.medium, size: 160, random: math.Random(5));
    final collection = CollectionStore(db: db);
    await collection.applyDatasetUpdate(
        PlayerDataset.fromJson(dataset.toJson()));
    await collection.createClub(clubName: 'W', managerName: 'W', crestIndex: 0);
    for (final p in await collection.getAvailablePacks()) {
      await collection.openPack(packId: p.id, random: math.Random(1));
    }
    await collection.autoPickSquad();
    final seasonStore = SeasonStore(db: db, random: math.Random(2));
    await seasonStore.startSeason(division: 1);

    var checkedAway = 0;
    while (true) {
      final next = await seasonStore.getNextFixture();
      if (next == null) break;
      final session = await seasonStore.startNextFixture(collection);
      session.simulateToEnd();
      final live = session.engine.state;
      await session.finish();
      await seasonStore.commitFixtureResult(session, next);
      final row = await (db.select(db.matchResults)
            ..where((r) => r.fixtureId.equals(next.fixtureId)))
          .getSingle();
      expect(row.homeGoals, live.scoreHome,
          reason: 'home goals must equal engine home goals');
      expect(row.awayGoals, live.scoreAway,
          reason: 'away goals must equal engine away goals');
      if (!next.isHome) checkedAway++;
    }
    expect(checkedAway, greaterThan(0), reason: 'sample must include away fixtures');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 3)));
}
