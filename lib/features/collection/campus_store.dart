/// FCM Rivals — campus store: facility levels and their upgrades.
///
/// Extracted from CollectionStore: reading the club's CampusLevels
/// and charging the escalating upgrade costs (GDD 3.5). Same
/// database, same transaction discipline — single-purpose home.
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../facilities/facilities.dart';
import '../../core/database/coin_ops.dart'
    show CoinOps, InsufficientFundsException;
import 'collection_store.dart' show CollectionException;

/// CollectionStore delegates here; see the library doc.
class CampusStore {
  CampusStore({required this.db});

  final AppDatabase db;

  /// The user club, or null before onboarding completes (same
  /// singleOrNull semantics as CollectionStore.getClub).
  Future<Club?> getClub() => (db.select(
    db.clubs,
  )..where((c) => c.isUser.equals(true))).getSingleOrNull();

  /// Facility enum name → instance, for reading FacilityLevels rows.
  static final Map<String, Facility> _facilityByCode = {
    for (final f in Facility.values) f.name: f,
  };

  Future<CampusLevels> getCampus() async {
    final club = await getClub();
    if (club == null) return CampusLevels.empty;
    final rows = await (db.select(
      db.facilityLevels,
    )..where((f) => f.clubId.equals(club.id))).get();
    return CampusLevels({
      for (final row in rows)
        if (_facilityByCode[row.facility] != null)
          _facilityByCode[row.facility]!: row.level,
    });
  }

  /// Builds the next level of [facility]: charges the escalating coin
  /// price, writes the level row and the ledger entry in one
  /// transaction. Returns the new level.
  Future<int> upgradeFacility(
    Facility facility, {
    FacilitiesCosts costs = defaultFacilitiesCosts,
  }) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final levels = await getCampus();
    final level = levels.levelOf(facility);
    if (level >= costs.maxLevel) {
      throw CollectionException(
        '${facility.title} is already at its maximum level',
      );
    }
    final price = costs.upgradeCost(level);
    if (club.coins < price) {
      throw CollectionException('Not enough coins (need $price)');
    }
    final nextLevel = level + 1;
    final now = DateTime.now();
    await db.transaction(() async {
      // Relative, conditional debit — same race-free guard as every
      // other coin movement (see coin_ops.dart).
      try {
        await db.spendCoins(
          club.id,
          price,
          reason: 'facility_upgrade',
          detail: '${facility.subtitle} level $nextLevel',
        );
      } on InsufficientFundsException {
        throw const CollectionException('Not enough coins');
      }
      final existing =
          await (db.select(db.facilityLevels)..where(
                (f) =>
                    f.clubId.equals(club.id) & f.facility.equals(facility.name),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await db
            .into(db.facilityLevels)
            .insert(
              FacilityLevelsCompanion.insert(
                clubId: club.id,
                facility: facility.name,
                level: Value(nextLevel),
                upgradedAt: Value(now),
              ),
            );
      } else {
        await (db.update(
          db.facilityLevels,
        )..where((f) => f.id.equals(existing.id))).write(
          FacilityLevelsCompanion(
            level: Value(nextLevel),
            upgradedAt: Value(now),
          ),
        );
      }
    });
    return nextLevel;
  }

  /// Applies a finished match (GDD 11 recovery + 17.6 rewards, FR-016):
  /// stamina recovery with the optional pep talk bonus, the reward credit
  /// and its ledger row — all in one transaction. Bench players who did
}
