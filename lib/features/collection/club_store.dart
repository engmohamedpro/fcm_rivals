/// FCM Rivals — club store: the user club row and its coin ledger.
///
/// Extracted from CollectionStore so club concerns evolve on their
/// own: reads/writes of the `clubs` row, the dev-only test grant,
/// and the ledger-row extension shared by larger transactions.
/// Every coin movement still runs through the same atomic
/// transactions (FR-016, NFR-003) — same database, same behaviour.
library;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/coin_ops.dart' show CoinOps;

/// CollectionStore delegates here; see the library doc.
class ClubStore {
  ClubStore({required this.db});

  final AppDatabase db;


  /// The user club, or null before onboarding completes. Uses
  /// getSingleOrNull — watchSingle would throw on the empty table on a
  /// fresh install, crashing club creation.
  Future<Club?> getClub() => (db.select(
    db.clubs,
  )..where((c) => c.isUser.equals(true))).getSingleOrNull();

  /// Live stream of the user club row: drift re-emits on every write
  /// to `clubs`, so coin movements land in the UI the moment they
  /// commit — no manual provider invalidation needed. Emits null until
  /// onboarding creates the club.
  Stream<Club?> watchClub() => (db.select(
    db.clubs,
  )..where((c) => c.isUser.equals(true))).watchSingleOrNull();

  /// Appends one ledger row for [amount] credited to [clubId]. Must be
  /// called AFTER the balance update inside the same transaction so
  /// balanceAfter reflects the post-transaction state (FR-016).
  ///
  /// Kept for call sites that update the balance inside their own larger
  /// transaction (e.g. applyMatchResult's stamina writes share it); new
  /// coin movements should prefer [CoinOps.spendCoins]/[CoinOps.creditCoins]
  /// which are relative and race-free.
  Future<void> coinLedger(
    int clubId,
    int amount, {
    required String reason,
    String? detail,
  }) async {
    final club = await (db.select(
      db.clubs,
    )..where((c) => c.id.equals(clubId))).getSingle();
    await db.into(db.coinTransactions).insert(
      CoinTransactionsCompanion.insert(
        clubId: clubId,
        amount: amount,
        balanceAfter: club.coins,
        reason: reason,
        detail: Value(detail),
        createdAt: DateTime.now(),
      ),
    );
  }
}
