/// FCM Rivals — atomic coin operations (FR-016, NFR-003).
///
/// Every coin movement goes through [spendCoins] or [creditCoins]: a
/// conditional, RELATIVE balance update executed as one SQL statement
/// (`UPDATE clubs SET coins = coins ? ? WHERE id = ? AND coins >= ?` for
/// spends) followed by the ledger row written from the post-update row,
/// all inside one transaction. Because the update is relative and its
/// affordability guard is in the WHERE clause, two overlapping movements
/// can no longer read the same balance and overwrite each other's effect
/// — the database serialises the statements and the balance moves by
/// exactly the sum of the applied movements.
///
/// These helpers replace the previous read-then-write pattern (read the
/// club row, compute `club.coins ± amount` in Dart, write the absolute
/// value), which lost or duplicated coins whenever two transactions
/// interleaved — e.g. a match reward resolving while the user buys a
/// pack. Callers may keep a friendly pre-check for an early, cheap
/// 'Not enough coins' error, but the guard here is what actually
/// enforces it.
library;

import 'package:drift/drift.dart';

import '../database/app_database.dart';

extension CoinOps on AppDatabase {
  /// Atomically debits [amount] coins from [clubId] and writes the
  /// ledger row. Throws [Exception] with 'Not enough coins' when the
  /// balance is insufficient — the WHERE clause is the guard, so this is
  /// race-free even under interleaved writes. Returns the new balance.
  Future<int> spendCoins(
    int clubId,
    int amount, {
    required String reason,
    String? detail,
  }) async {
    assert(amount > 0, 'spendCoins expects a positive amount');
    return transaction(() async {
      final updated = await customUpdate(
        'UPDATE clubs SET coins = coins - ? WHERE id = ? AND coins >= ?',
        variables: [
          Variable.withInt(amount),
          Variable.withInt(clubId),
          Variable.withInt(amount),
        ],
        updates: {clubs},
        updateKind: UpdateKind.update,
      );
      if (updated == 0) {
        // Either the club row is gone or the balance was too low; the
        // distinction does not matter for the caller, both are 'no'.
        throw Exception('Not enough coins');
      }
      final balance = await _postUpdateBalance(clubId);
      await _ledgerRow(
        clubId: clubId,
        amount: -amount,
        balanceAfter: balance,
        reason: reason,
        detail: detail,
      );
      return balance;
    });
  }

  /// Atomically credits [amount] coins to [clubId] and writes the
  /// ledger row. Credits are unconditional (rewards are never refused),
  /// but still relative, so a concurrent spend cannot be overwritten.
  /// Returns the new balance.
  Future<int> creditCoins(
    int clubId,
    int amount, {
    required String reason,
    String? detail,
  }) async {
    assert(amount >= 0, 'creditCoins expects a non-negative amount');
    if (amount == 0) {
      final club = await _clubOf(clubId);
      return club?.coins ?? 0;
    }
    return transaction(() async {
      await customUpdate(
        'UPDATE clubs SET coins = coins + ? WHERE id = ?',
        variables: [Variable.withInt(amount), Variable.withInt(clubId)],
        updates: {clubs},
        updateKind: UpdateKind.update,
      );
      final balance = await _postUpdateBalance(clubId);
      await _ledgerRow(
        clubId: clubId,
        amount: amount,
        balanceAfter: balance,
        reason: reason,
        detail: detail,
      );
      return balance;
    });
  }

  Future<Club?> _clubOf(int clubId) =>
      (select(clubs)..where((c) => c.id.equals(clubId))).getSingleOrNull();

  Future<int> _postUpdateBalance(int clubId) async {
    final club = await (select(
      clubs,
    )..where((c) => c.id.equals(clubId))).getSingle();
    return club.coins;
  }

  Future<void> _ledgerRow({
    required int clubId,
    required int amount,
    required int balanceAfter,
    required String reason,
    String? detail,
  }) async {
    await into(coinTransactions).insert(
      CoinTransactionsCompanion.insert(
        clubId: clubId,
        amount: amount,
        balanceAfter: balanceAfter,
        reason: reason,
        detail: Value(detail),
        createdAt: DateTime.now(),
      ),
    );
  }
}
