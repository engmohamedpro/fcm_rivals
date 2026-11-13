part of 'season_store.dart';

/// SeasonStore standings family of [SeasonStore] (extracted from the store, app-structure
/// review task `2026-11-06_app-structure_finish-season-store-split`):
/// standings, match history, season completion with rewards, and next-season rollover. Pure relocation — bodies unchanged; part of the store library so
/// private state and sibling members stay reachable. Public-named because
/// its members are the store's public API and every caller imports
/// season_store.dart directly, so existing call sites keep resolving with
/// zero edits.
extension SeasonStandingsOps on SeasonStore {
  /// Current standings of the active season (GDD 9.3).
  Future<List<StandingEntry>> getStandings() async {
    final season =
        await getActiveSeason() ??
        (await (db.select(
          db.seasons,
        )..orderBy([(s) => OrderingTerm.desc(s.id)])).get()).firstOrNull;
    if (season == null) return const [];
    final teams = await (db.select(
      db.leagueTeams,
    )..where((t) => t.seasonId.equals(season.id))).get();
    final clubRows = await db.select(db.clubs).get();
    final clubNames = {for (final c in clubRows) c.id: c.name};
    final clubIds = [for (final t in teams) t.clubId];
    final names = [for (final id in clubIds) clubNames[id] ?? '?'];

    final results = await _resultsFor(season.id);
    final indexByClub = {
      for (var i = 0; i < clubIds.length; i++) clubIds[i]: i,
    };
    final tuples = [
      for (final r in results)
        (
          round: r.round,
          homeIndex: indexByClub[r.homeClubId]!,
          awayIndex: indexByClub[r.awayClubId]!,
          homeGoals: r.homeGoals,
          awayGoals: r.awayGoals,
        ),
    ];
    return engine.computeStandings(
      clubIds: clubIds,
      names: names,
      results: tuples,
    );
  }

  /// Recent user results (FR-038 history), newest first.
  Future<List<MatchResult>> getMatchHistory({int limit = 10}) async {
    final seasons = await db.select(db.seasons).get();
    if (seasons.isEmpty) return const [];
    final userClubId = seasons.first.userClubId;
    final results =
        await (db.select(db.matchResults)
              ..where(
                (r) =>
                    r.homeClubId.equals(userClubId) |
                    r.awayClubId.equals(userClubId),
              )
              ..orderBy([
                (r) => OrderingTerm.desc(r.playedAt),
                (r) => OrderingTerm.desc(r.id),
              ])
              ..limit(limit))
            .get();
    return results;
  }

  /// Completes the active season (GDD 9.3/9.5, GDD 18): computes final
  /// standings, writes final positions, resolves promotion/relegation,
  /// pays season rewards with a ledger row, retires the AI clubs'
  /// squads and returns the completion summary. A new season is NOT
  /// started automatically — the UI asks the player.
  Future<SeasonCompletion> completeSeason(CollectionStore store) async {
    final season = await getActiveSeason();
    if (season == null) {
      throw const SeasonException('No active season');
    }
    // Ensure every fixture has a result first (AI-vs-AI remainder).
    await simulateRemainingFixtures(store);

    final standings = await getStandings();
    if (standings.isEmpty) {
      throw const SeasonException('Season has no standings');
    }
    final userEntry = standings.firstWhere(
      (e) => e.clubId == season.userClubId,
      orElse: () => throw const SeasonException('User missing from standings'),
    );
    final outcome = engine.outcomeForPosition(userEntry.position);
    final nextDivision = engine.nextDivisionFor(season.division, outcome);
    final baseRewardCoins = engine.seasonRewardCoins(
      division: season.division,
      position: userEntry.position,
    );

    // GDD 19.3 'Season reward multiplier': one ad watched during the
    // season boosts this payout by +25%; the boost is consumed here.
    final ads = AdStore(db: db);
    var seasonMultiplierUsed = false;
    var rewardCoins = baseRewardCoins;
    if (await ads.seasonMultiplierActive(season.userClubId)) {
      rewardCoins = const AdEngine().boostedSeasonReward(baseRewardCoins);
      seasonMultiplierUsed = true;
    }

    final now = DateTime.now();
    await db.transaction(() async {
      // Final positions for every league team (FR-038).
      for (final e in standings) {
        await (db.update(db.leagueTeams)..where(
              (t) => t.seasonId.equals(season.id) & t.clubId.equals(e.clubId),
            ))
            .write(LeagueTeamsCompanion(finalPosition: Value(e.position)));
      }
      await (db.update(db.seasons)..where((s) => s.id.equals(season.id))).write(
        SeasonsCompanion(
          status: const Value('completed'),
          endedAt: Value(now),
          finalPosition: Value(userEntry.position),
          outcome: Value(outcome.name),
        ),
      );

      // Retire AI squads (GDD 9.5) — EXCEPT clubs that move divisions WITH
      // the user: when the user is promoted, the other promoted clubs of
      // this division follow and keep their squads (same real players,
      // fresh condition); when relegated, the fellow relegated clubs
      // follow them down. Every other club regenerates with a fresh squad
      // for its division; historical RESULTS always stay (FR-038), only
      // squads go. The carried band shrinks to make room for the user's
      // own promotion/relegation slot.
      final teams =
          await (db.select(db.leagueTeams)..where(
                (t) => t.seasonId.equals(season.id) & t.isUser.equals(false),
              ))
              .get();
      final sorted = teams.toList()
        ..sort(
          (a, b) => (a.finalPosition ?? 99).compareTo(b.finalPosition ?? 99),
        );
      // Carried clubs travel with the user's own outcome (GDD 9.5):
      // promoted → the other top clubs go up with him, relegated → the
      // other bottom clubs go down. Staying means a fresh division.
      final carryIds = <int>{};
      if (outcome != SeasonOutcome.stayed && sorted.length >= 6) {
        final slots = engine.config.promotionSlots;
        final userPos = userEntry.position;
        if (outcome == SeasonOutcome.promoted) {
          for (final t in sorted.take(slots)) {
            if (t.finalPosition != userPos) carryIds.add(t.clubId);
          }
        } else {
          for (final t in sorted.skip(sorted.length - slots)) {
            if (t.finalPosition != userPos) carryIds.add(t.clubId);
          }
        }
      }
      for (final t in teams) {
        if (carryIds.contains(t.clubId)) {
          // Carried over: flag the league row and rest the squad to full
          // freshness for the new campaign — SAME players, no retuning.
          await (db.update(db.leagueTeams)..where((l) => l.id.equals(t.id)))
              .write(const LeagueTeamsCompanion(carriedOver: Value(true)));
          await (db.update(db.aiPlayers)
                ..where((p) => p.clubId.equals(t.clubId)))
              .write(const AiPlayersCompanion(staminaPercent: Value(100)));
        } else {
          await (db.delete(
            db.aiPlayers,
          )..where((p) => p.clubId.equals(t.clubId))).go();
        }
      }

      // Season rewards (GDD 18): coins + ledger row. Relative update —
      // a concurrent coin movement (the user buying a pack while the
      // season resolves) can no longer be overwritten by this credit
      // (see coin_ops.dart).
      final club = await (db.select(
        db.clubs,
      )..where((c) => c.id.equals(season.userClubId))).getSingle();
      await db.customUpdate(
        'UPDATE clubs SET coins = coins + ? WHERE id = ?',
        variables: [
          Variable.withInt(rewardCoins),
          Variable.withInt(club.id),
        ],
        updates: {db.clubs},
        updateKind: UpdateKind.update,
      );
      final clubRow = await (db.select(
        db.clubs,
      )..where((c) => c.id.equals(club.id))).getSingle();
      await db
          .into(db.coinTransactions)
          .insert(
            CoinTransactionsCompanion.insert(
              clubId: club.id,
              amount: rewardCoins,
              balanceAfter: clubRow.coins,
              reason: 'season_reward',
              detail: Value(
                'Season ${season.ordinal} · division ${season.division} · '
                'finished ${userEntry.position} (${outcome.name})'
                '${seasonMultiplierUsed ? ' · ad season multiplier' : ''}',
              ),
              createdAt: now,
            ),
          );
      if (seasonMultiplierUsed) {
        await ads.consumeSeasonMultiplier(club.id, now: now);
      }
    });

    return SeasonCompletion(
      seasonId: season.id,
      division: season.division,
      finalPosition: userEntry.position,
      outcome: outcome.name,
      nextDivision: nextDivision,
      rewardCoins: rewardCoins,
    );
  }

  /// Starts the next season in [division] after completion (GDD 9.5):
  /// the division's fresh opponents are generated from the real player
  /// database; the AI clubs that moved divisions WITH the user keep
  /// their squads — same real players, new division. Clubs whose squads
  /// were retired at completion (everyone else) are deleted along with
  /// their rows so the club table only ever grows by one season's worth.
  Future<int> startNextSeason(CollectionStore store) async {
    final summary = await getSeasonSummary();
    if (summary == null) {
      throw const SeasonException('No previous season');
    }
    if (!summary.isCompleted) {
      throw const SeasonException('The current season is still active');
    }
    final outcome = summary.outcome == null
        ? SeasonOutcome.stayed
        : SeasonOutcome.values.firstWhere(
            (o) => o.name == summary.outcome,
            orElse: () => SeasonOutcome.stayed,
          );
    final division = engine.nextDivisionFor(summary.division, outcome);

    // Carried-over clubs (GDD 9.5): the AI clubs that moved divisions
    // WITH the user (other promoted clubs when he went up, other
    // relegated clubs when he went down). Derived from final positions
    // minus the user's own slot — NOT from the carriedOver flag, which
    // marks how a club entered this season and would double-count.
    final seasonId = summary.seasonId;
    final teams =
        await (db.select(db.leagueTeams)..where(
              (t) => t.seasonId.equals(seasonId) & t.isUser.equals(false),
            ))
            .get();
    final sorted = teams.toList()
      ..sort(
        (a, b) => (a.finalPosition ?? 99).compareTo(b.finalPosition ?? 99),
      );
    final carriedIds = <int>{};
    if (outcome != SeasonOutcome.stayed && sorted.length >= 6) {
      final slots = engine.config.promotionSlots;
      final userPos = summary.finalPosition ?? 0;
      if (outcome == SeasonOutcome.promoted) {
        for (final t in sorted.take(slots)) {
          if (t.finalPosition != userPos) carriedIds.add(t.clubId);
        }
      } else {
        for (final t in sorted.skip(sorted.length - slots)) {
          if (t.finalPosition != userPos) carriedIds.add(t.clubId);
        }
      }
    }

    // Retire the club rows of squads that were deleted at completion:
    // their league rows are history, but an empty club would otherwise
    // linger forever in the clubs table.
    final retiredClubs = teams
        .map((t) => t.clubId)
        .where((id) => !carriedIds.contains(id))
        .toList();
    if (retiredClubs.isNotEmpty) {
      await (db.delete(db.clubs)..where((c) => c.id.isIn(retiredClubs))).go();
    }

    return startSeason(division: division, carriedClubIds: carriedIds);
  }
}
