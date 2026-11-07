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
    required List<({int ownedId, double stamina, int minutesPlayed})> players,
    PepTalk? pepTalk,
    int restDays = 3,
    bool adBoostedRecovery = false,
    DateTime? now,
  }) async {
    final timestamp = now ?? DateTime.now();
    final staminaConfig = const StaminaConfig();
    final adEngine = const AdEngine();
    // Campus recovery centre (GDD 3.5/11.5): its bonus is added to the
    // natural recovery of every player who featured — one decimal of
    // design space the manager invests in across seasons.
    final campus = await getCampus();
    final campusRecoveryBonus = campus.recoveryBonusPercent;
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
      for (final p in players) {
        final row = await (db.select(
          db.ownedPlayers,
        )..where((o) => o.id.equals(p.ownedId))).getSingleOrNull();
        if (row == null) continue;
        var next = row.staminaPercent.toDouble();
        if (p.minutesPlayed > 0) {
          final afterNatural = recoverStamina(
            config: staminaConfig,
            currentStamina: p.stamina,
            minutesPlayed: p.minutesPlayed,
            restDays: restDays,
            campusRecoveryBonus: campusRecoveryBonus,
          );
          if (adBoostedRecovery) {
            // Ad-supported boosted recovery (GDD 19.3): +15% natural
            // recovery for eligible players. Mutually exclusive with a
            // pep talk on the same transaction (GDD 19.4).
            next = adEngine.boostedRecovery(
              staminaAfterNaturalRecovery: afterNatural,
              naturalRecovery: afterNatural - p.stamina,
            );
          } else if (pepTalk != null) {
            next = applyPepTalkBonus(
              pepTalk: pepTalk,
              currentStamina: p.stamina,
              naturalRecovery: afterNatural - p.stamina,
              staminaAfterNaturalRecovery: afterNatural,
              minutesPlayed: p.minutesPlayed,
            );
          } else {
            next = afterNatural;
          }
        } else {
          // Players who missed the match still REST: the same natural
          // recovery minus the workload, applied to their current
          // condition. They used to be frozen at their old stamina
          // forever — benched and reserve players never healed between
          // fixtures, which made the squad's condition one-way ratchet.
          next = recoverStamina(
            config: staminaConfig,
            currentStamina: next,
            minutesPlayed: 0,
            restDays: restDays,
            campusRecoveryBonus: campusRecoveryBonus,
          );
        }
        await (db.update(
          db.ownedPlayers,
        )..where((o) => o.id.equals(p.ownedId))).write(
          OwnedPlayersCompanion(
            staminaPercent: Value(next.round().clamp(0, 100)),
          ),
        );
      }
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
    });
  }
}
