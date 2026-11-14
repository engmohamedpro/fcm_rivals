// Club campus facilities (GDD 3.5): escalating coin costs, persisted
// levels, and the two live hooks — the recovery centre's bonus inside
// post-match recovery and the training facilities' attribute fractions
// inside the match input.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/features/collection/collection_store.dart';
import 'package:fcm_rivals/features/facilities/facilities.dart';

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FacilitiesCosts', () {
    test('escalates geometrically and rounds to hundreds', () {
      const costs = FacilitiesCosts();
      expect(costs.upgradeCost(0), 4_000);
      expect(costs.upgradeCost(1), 6_200);
      expect(costs.upgradeCost(2), 9_600);
      // Every later level costs strictly more than the one before.
      for (var level = 0; level + 1 < costs.maxLevel; level++) {
        expect(
          costs.upgradeCost(level + 1),
          greaterThan(costs.upgradeCost(level)),
        );
      }
      // Level 10 is the ceiling — nothing more to buy.
      expect(costs.upgradeCost(costs.maxLevel), 0);
    });

    test('investedAt sums the levels already paid', () {
      const costs = FacilitiesCosts();
      expect(costs.investedAt(0), 0);
      expect(costs.investedAt(1), costs.upgradeCost(0));
      expect(
        costs.investedAt(3),
        costs.upgradeCost(0) + costs.upgradeCost(1) + costs.upgradeCost(2),
      );
    });
  });

  group('Facility effects', () {
    test('training facilities describe their attribute bonus per level', () {
      final attack = Facility.attack.effect;
      expect(attack.attributeFractionAt(0), 0);
      expect(attack.attributeFractionAt(4), closeTo(0.036, 1e-9));
      expect(attack.describeAt(4), contains('Attack'));

      final gk = Facility.goalkeeping.effect;
      expect(gk.attributeFractionAt(10), closeTo(0.11, 1e-9));
    });

    test('recovery and medical facilities carry no attribute bonus', () {
      expect(Facility.recovery.effect.attributeFractionAt(10), 0);
      expect(Facility.recovery.effect.recoveryPercentAt(4), 10.0);
      expect(Facility.medical.effect.injuryRiskAt(5), 3.0);
    });

    test('CampusLevels aggregates every facility contribution', () {
      final campus = const CampusLevels({
        Facility.attack: 4,
        Facility.support: 2,
        Facility.defence: 0,
        Facility.goalkeeping: 10,
        Facility.recovery: 3,
        Facility.medical: 5,
      });
      final f = campus.attributeFractions;
      expect(f.attack, closeTo(0.036, 1e-9));
      expect(f.support, closeTo(0.018, 1e-9));
      expect(f.defence, 0);
      expect(f.goalkeeping, closeTo(0.11, 1e-9));
      expect(campus.recoveryBonusPercent, 7.5);
      expect(campus.injuryRiskReductionPercent, 3.0);

      expect(CampusLevels.empty.attributeFractions.attack, 0);
      expect(CampusLevels.empty.recoveryBonusPercent, 0);
    });
  });

  group('CollectionStore campus', () {
    late AppDatabase db;
    late CollectionStore store;

    setUp(() async {
      db = memoryDb();
      store = CollectionStore(db: db);
      await store.createClub(
        clubName: 'FC Rivals',
        managerName: 'Mohamed',
        crestIndex: 0,
      );
    });

    tearDown(() async => db.close());

    test('starts empty, upgrades persist levels and charge coins', () async {
      final clubBefore = (await store.getClub())!;
      expect((await store.getCampus()).levelOf(Facility.attack), 0);

      final level1 = await store.upgradeFacility(Facility.attack);
      expect(level1, 1);
      final clubAfter = (await store.getClub())!;
      expect(
        clubAfter.coins,
        clubBefore.coins - defaultFacilitiesCosts.upgradeCost(0),
      );

      // Second level costs more than the first.
      final level2 = await store.upgradeFacility(Facility.attack);
      expect(level2, 2);
      final clubAfter2 = (await store.getClub())!;
      expect(
        clubAfter2.coins,
        clubAfter.coins - defaultFacilitiesCosts.upgradeCost(1),
      );
      expect((await store.getCampus()).levelOf(Facility.attack), 2);
      // Other facilities untouched.
      expect((await store.getCampus()).levelOf(Facility.recovery), 0);

      // The upgrade writes a ledger row (FR-016).
      final ledger = await (db.select(
        db.coinTransactions,
      )..where((t) => t.reason.equals('facility_upgrade'))).get();
      expect(ledger.length, 2);
      expect(ledger.last.detail, contains('attack academy level 2'));
    });

    test('rejects upgrades without enough coins', () async {
      // Burn the coins down with purchases until one fails.
      var lastError = '';
      for (var i = 0; i < 60; i++) {
        try {
          await store.upgradeFacility(Facility.goalkeeping);
        } catch (e) {
          lastError = '$e';
          break;
        }
      }
      expect(lastError, contains('Not enough coins'));
    });
  });
}
