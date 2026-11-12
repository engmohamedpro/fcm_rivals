part of 'collection_store.dart';

/// Dataset import family of [CollectionStore] (extracted from the facade,
/// app-structure review task
/// `2026-11-06_app-structure_finish-collection-facade-split`): registry
/// warm-up, bundled-dataset import and the transactional dataset update
/// with removed-player compensation. Pure relocation — bodies unchanged;
/// part of the store library so the private registry state stays
/// reachable. Public-named because its members are the facade's public
/// API (providers, the simulator and tests call them directly), so every
/// existing call site keeps resolving with zero edits.
extension DatasetImportOps on CollectionStore {
  /// pack drawing before any update was applied in this session).
  Future<PlayerDatabase> _ensureRegistry() async {
    if (_registryLoaded) return _registry;
    final rows = await db.select(db.players).get();
    if (rows.isNotEmpty) {
      final dataset = PlayerDataset(
        version:
            (await db.select(db.datasetVersions).getSingleOrNull())?.version ??
            0,
        asOf: '',
        rows: [
          for (final r in rows)
            PlayerDatasetRow(
              playerId: r.playerId,
              name: r.name,
              position: Position.fromCode(r.position),
              nationality: r.nationality,
              marketValueEur: r.marketValueEur,
              clubId: r.clubId,
              clubName: r.clubName,
              clubCrestUrl: r.clubCrestUrl,
              leagueName: r.leagueName,
              leagueLogoUrl: r.leagueLogoUrl,
              imageUrl: r.imageUrl,
              isIcon: r.isIcon,
            ),
        ],
      );
      _registry.importDataset(dataset);
    }
    _registryLoaded = true;
    // The pool snapshot may be stale or absent — rebuild lazily on the
    // next engine use.
    _invalidatePackCache();
    return _registry;
  }

  /// Imports the bundled dataset into SQLite (idempotent per version) and
  /// primes the in-memory registry. The caller owns parsing — the app
  /// bootstrap decodes on a background isolate (see providers.dart).
  Future<void> importBundledDataset(PlayerDataset dataset) async {
    final current = await db.select(db.datasetVersions).getSingleOrNull();
    if (current != null && current.version >= dataset.version) return;
    await applyDatasetUpdate(dataset);
  }

  /// Applies a dataset update transactionally (FR-004..FR-008, NFR-003):
  /// registry update rules, upsert of player rows, removed-player
  /// compensation at the exact upgraded selling formula, squad slot cleanup.
  Future<DatasetUpdateReport> applyDatasetUpdate(PlayerDataset dataset) async {
    await _ensureRegistry();
    final importResult = _registry.importDataset(dataset);
    // Registry contents changed: the engine's identity-keyed band caches
    // must never outlive them.
    _invalidatePackCache();

    final club = await (db.select(
      db.clubs,
    )..where((c) => c.isUser.equals(true))).getSingleOrNull();
    final compensations = <RemovalCompensation>[];

    await db.transaction(() async {
      // Upsert current rows (regenerated stats included per GDD 4.6) in
      // ONE batched statement instead of ~20,876 awaited round trips:
      // the batch is atomic with the rest of this transaction, so
      // dataset updates and removed-player compensation still commit
      // or roll back together (FR-004..FR-008, NFR-003).
      await db.batch((batch) {
        batch.insertAll(
          db.players,
          [
            for (final player in [
              ...importResult.added,
              ...importResult.updated,
              ...importResult.regenerated,
            ])
              PlayersCompanion.insert(
                playerId: Value(player.playerId),
                name: player.name,
                position: player.position.code,
                nationality: player.nationality,
                marketValueEur: player.marketValueEur,
                overall: player.baseStats.overall,
                attack: player.baseStats.attack,
                support: player.baseStats.support,
                defence: player.baseStats.defence,
                goalkeeping: player.baseStats.goalkeeping,
                clubId: Value(player.clubId),
                clubName: Value(player.clubName),
                clubCrestUrl: Value(player.clubCrestUrl),
                leagueName: Value(player.leagueName),
                leagueLogoUrl: Value(player.leagueLogoUrl),
                imageUrl: Value(player.imageUrl),
                isIcon: Value(player.isIcon),
              ),
          ],
          mode: InsertMode.insertOrReplace,
        );
      });

      // Removed players: compensate owners, drop copies and squad slots
      // (GDD 4.8) — inside the same transaction as the data update.
      if (club != null) {
        for (final removed in importResult.removed) {
          final owned =
              await (db.select(db.ownedPlayers)..where(
                    (o) =>
                        o.playerId.equals(removed.playerId) &
                        o.status.equals('owned'),
                  ))
                  .get();
          for (final copy in owned) {
            final coins = economy.sellPriceOfUpgraded(
              removed,
              copy.upgradeLevel,
            );
            compensations.add(
              RemovalCompensation(
                playerName: removed.name,
                upgradeLevel: copy.upgradeLevel,
                coins: coins,
              ),
            );
            await (db.delete(
              db.ownedPlayers,
            )..where((o) => o.id.equals(copy.id))).go();
          }
        }
        if (compensations.isNotEmpty) {
          final total = compensations.fold<int>(0, (a, c) => a + c.coins);
          // Relative update — a concurrent coin movement (a pack
          // purchase, a match reward) can no longer be overwritten by
          // this credit (see coin_ops.dart). The legacy coinLedger
          // re-selects the row itself, so its balanceAfter is correct.
          await db.customUpdate(
            'UPDATE clubs SET coins = coins + ? WHERE id = ?',
            variables: [
              Variable.withInt(total),
              Variable.withInt(club.id),
            ],
            updates: {db.clubs},
            updateKind: UpdateKind.update,
          );
          await db.coinLedger(
            club.id,
            total,
            reason: 'removal_compensation',
            detail: '${compensations.length} players removed by dataset update',
          );
        }
      }

      await db
          .into(db.datasetVersions)
          .insertOnConflictUpdate(
            DatasetVersionsCompanion.insert(
              version: Value(dataset.version),
              asOf: dataset.asOf,
              digest: Value(dataset.digest),
              importedAt: DateTime.now(),
              playerCount: dataset.count,
            ),
          );
    });

    _registryLoaded = true;
    return DatasetUpdateReport(
      importResult: importResult,
      compensations: compensations,
    );
  }
}
