part of 'collection_store.dart';

/// Library-private internals of [CollectionStore] (extracted from the
/// facade, app-structure review task
/// `2026-11-06_app-structure_finish-collection-facade-split`): the
/// persisted-row-to-domain mapper and the AppDatabase ledger append used
/// inside caller-owned transactions. Pure relocation — bodies unchanged;
/// private scope, so no call site outside this library is affected.
extension _RowMapping on CollectionStore {
  /// Adapts a persisted player row to the domain model.
  BasePlayer _toBasePlayer(Player row) => BasePlayer(
    playerId: row.playerId,
    name: row.name,
    position: Position.fromCode(row.position),
    nationality: row.nationality,
    marketValueEur: row.marketValueEur,
    baseStats: BaseStats(
      overall: row.overall,
      attack: row.attack,
      support: row.support,
      defence: row.defence,
      goalkeeping: row.goalkeeping,
    ),
  );
}

extension on AppDatabase {
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
    final club = await (select(
      clubs,
    )..where((c) => c.id.equals(clubId))).getSingle();
    await into(coinTransactions).insert(
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
