part of 'collection_store.dart';

/// Match-result family of [CollectionStore] (extracted from the
/// facade, T-0045): the post-match settlement — ad-daily-multiplier
/// reward boost, per-player stamina recovery (natural, ad-boosted or
/// pep-talk) and the relative coin credit with its ledger row, all in
/// one transaction. Pure relocation — body unchanged; part of the
/// store library so the private store state stays reachable.
/// Public-named because its members are the facade's public API (the
/// live match flow and tests call them directly), so every existing
/// call site keeps resolving with zero edits.
extension MatchResultOps on CollectionStore {
  Future<void> applyMatchResult({
    required int clubId,
    required int rewardCoins,
    required List<({int ownedId, int minutesPlayed})> players,
    List<({int ownedId, String kind, int matchesOut})> injuries = const [],
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final adEngine = const AdEngine();
    // GDD 19.3 'Daily reward multiplier': rewards earned today are boosted
    // while a daily-multiplier ad was watched (no consumption — it lasts
    // the whole day it was granted).
    final ads = adStore;
    var reward = rewardCoins;
    if (ads != null && rewardCoins > 0) {
      final club = await (db.select(
        db.clubs,
      )..where((c) => c.id.equals(clubId))).getSingleOrNull();
      if (club != null &&
          await ads.dailyMultiplierActive(club.id, now: timestamp)) {
        reward = adEngine.boostedMatchReward(rewardCoins);
      }
    }
    await db.transaction(() async {
      // Recovery decrement (T-0055, GDD 11.7): every committed fixture
      // counts the club's injuries down by exactly one match, floor 0,
      // clearing the kind at 0. Runs BEFORE the new injuries land, so a
      // player hurt in THIS match keeps his full matches-out.
      await db.customUpdate(
        'UPDATE owned_players SET injury_matches_remaining = '
        'injury_matches_remaining - 1 WHERE club_id = ? AND '
        'injury_matches_remaining > 0',
        variables: [Variable.withInt(clubId)],
        updates: {db.ownedPlayers},
        updateKind: UpdateKind.update,
      );
      await db.customUpdate(
        'UPDATE owned_players SET injury_kind = NULL WHERE club_id = ? '
        'AND injury_matches_remaining <= 0',
        variables: [Variable.withInt(clubId)],
        updates: {db.ownedPlayers},
        updateKind: UpdateKind.update,
      );
      // (The per-player stamina recovery pass is gone — owner request
      // 2026-11-14: no stamina anywhere. The DB column stays at its
      // default 100 for save compatibility; nothing reads it.)
      if (reward > 0) {
        // Relative credit — a concurrent coin movement (the user buying
        // a pack while the match resolves) can no longer be overwritten
        // by this reward (see coin_ops.dart).
        await db.customUpdate(
          'UPDATE clubs SET coins = coins + ? WHERE id = ?',
          variables: [Variable.withInt(reward), Variable.withInt(clubId)],
          updates: {db.clubs},
          updateKind: UpdateKind.update,
        );
        await db.coinLedger(
          clubId,
          reward,
          reason: 'match_reward',
          detail:
              'Match reward for ${players.length} squad players'
              '${reward != rewardCoins ? ' (ad daily multiplier)' : ''}',
        );
      }
      // Rolled injuries ride the same atomic transaction (T-0055): kind
      // + matches-out land with the reward. The re-injury guard
      // is belt-and-braces — an injured player was never fielded
      // (selection gating), so the row is always fit here.
      // Perf pass 2026-11-12 (M4): one SELECT for every injured id +
      // one batched UPDATE, replacing the per-injury await pairs.
      if (injuries.isNotEmpty) {
        final injuryIds = [for (final i in injuries) i.ownedId];
        final injuryRows = await (db.select(
          db.ownedPlayers,
        )..where((o) => o.id.isIn(injuryIds))).get();
        final injuryRowById = {for (final r in injuryRows) r.id: r};
        await db.batch((batch) {
          for (final injury in injuries) {
            final row = injuryRowById[injury.ownedId];
            if (row == null) continue;
            if ((row.injuryMatchesRemaining ?? 0) > 0) continue;
            batch.update(
              db.ownedPlayers,
              OwnedPlayersCompanion(
                injuryMatchesRemaining: Value(injury.matchesOut),
                injuryKind: Value(injury.kind),
              ),
              where: (o) => o.id.equals(injury.ownedId),
            );
          }
        });
      }
    });
  }
}
