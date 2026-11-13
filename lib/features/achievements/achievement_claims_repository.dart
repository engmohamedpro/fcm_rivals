/// FCM Rivals — the achievements claims repository (T-0106).
///
/// A THIN read/write layer over the `AchievementClaims` table and the
/// `UserSettings.equippedTitle` column: typed rows in, typed rows out,
/// the DB's UNIQUE key as the idempotency owner. NO coin logic lives
/// here — T-0108's claim pipeline owns the claim + payout transaction
/// (this repository exposes the raw insert so THAT transaction can
/// use it); the repository never touches the ledger.
///
/// The UNIQUE (clubId, achievementId, tierKey) constraint makes the
/// duplicate insert fail with drift's `InvalidDataException` wrapping
/// SQLite's UNIQUE violation — the exact behaviour the repository
/// tests pin, so a caller cannot silently double-claim.
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart' as db;

/// Read/write access to claimed achievement tiers and the equipped
/// title for ONE club (or the single settings row for the title).
class AchievementClaimsRepository {
  AchievementClaimsRepository(this.database);

  final db.AppDatabase database;

  // ---- Claims -------------------------------------------------------------

  /// Every claim the club ever made, newest first.
  Future<List<db.AchievementClaim>> claimsForClub(int clubId) {
    final query = database.select(database.achievementClaims)
      ..where((t) => t.clubId.equals(clubId))
      ..orderBy([(t) => OrderingTerm.desc(t.claimedAt)]);
    return query.get();
  }

  /// Whether the club already claimed this exact tier. The companion
  /// to the UNIQUE key: a caller checks this for UX, the DB enforces
  /// the truth — the check is advisory, the constraint is the law.
  Future<bool> hasClaim({
    required int clubId,
    required String achievementId,
    required String tierKey,
  }) async {
    final query = database.select(database.achievementClaims)
      ..where(
        (t) =>
            t.clubId.equals(clubId) &
            t.achievementId.equals(achievementId) &
            t.tierKey.equals(tierKey),
      )
      ..limit(1);
    return (await query.get()).isNotEmpty;
  }

  /// Inserts a raw claim row. Throws (drift wraps the SQLite UNIQUE
  /// violation as [InvalidDataException] with a message carrying
  /// 'UNIQUE constraint failed') when the (club, achievement, tier)
  /// triple already exists — the structural double-claim refusal.
  /// T-0108's pipeline calls this INSIDE its coin transaction so the
  /// claim and the payout commit or roll back together.
  Future<int> insertClaim({
    required int clubId,
    required String achievementId,
    required String tierKey,
    required int rewardCoins,
    String? titleGranted,
    required DateTime claimedAt,
  }) =>
      database
          .into(database.achievementClaims)
          .insert(
            db.AchievementClaimsCompanion.insert(
              clubId: clubId,
              achievementId: achievementId,
              tierKey: tierKey,
              rewardCoins: rewardCoins,
              titleGranted: titleGranted == null
                  ? const Value.absent()
                  : Value(titleGranted),
              claimedAt: claimedAt,
            ),
          );

  // ---- Equipped title -----------------------------------------------------

  /// The equipped title's id, or null (no title shown). Unknown ids
  /// (a catalog rename between versions) are the DOMAIN layer's
  /// graceful-fallback problem (T-0112) — this returns the stored
  /// string verbatim.
  Future<String?> getEquippedTitle() async {
    final row = await _settingsRow();
    return row?.equippedTitle;
  }

  /// Persists the equipped title; null clears it back to no-title.
  /// Upsert mirrors the settings store's write pattern (insert the
  /// single row when absent, update the column when present).
  Future<void> setEquippedTitle(String? titleId) async {
    final row = await _settingsRow();
    if (row == null) {
      await database
          .into(database.userSettings)
          .insert(
            db.UserSettingsCompanion.insert(
              id: _settingsRowId,
              equippedTitle: titleId == null
                  ? const Value.absent()
                  : Value(titleId),
            ),
          );
      return;
    }
    await (database.update(database.userSettings)
          ..where((t) => t.id.equals(_settingsRowId)))
        .write(db.UserSettingsCompanion(equippedTitle: Value(titleId)));
  }

  static const int _settingsRowId = 1;

  Future<db.UserSetting?> _settingsRow() async =>
      (database.select(database.userSettings)
            ..where((t) => t.id.equals(_settingsRowId)))
          .getSingleOrNull();
}
