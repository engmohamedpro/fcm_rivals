part of 'season_store.dart';

/// SeasonStore fixture play family of [SeasonStore] (extracted from the store, app-structure
/// review task `2026-11-06_app-structure_finish-season-store-split`):
/// live-session play, result commit, replay rewind, and the quick simulation of remaining/round AI fixtures. Pure relocation — bodies unchanged; part of the store library so
/// private state and sibling members stay reachable. Public-named because
/// its members are the store's public API and every caller imports
/// season_store.dart directly, so existing call sites keep resolving with
/// zero edits.
extension SeasonFixturePlayOps on SeasonStore {
  /// Creates a live match session for the user's next fixture. The UI
  /// drives it; call [commitFixtureResult] with the finished session.
  /// [preMatchTalk] applies its multipliers from kick-off (GDD 15.1).
  /// [tactics] carries the MATCH-ONLY setup chosen on the pre-match
  /// screen (formation, custom tactics, mentality — GDD 10.4): the session is
  /// built from it and the club's saved default setup stays untouched.
  Future<MatchSession> startNextFixture(
    CollectionStore store, {
    MatchPepTalk? preMatchTalk,
    PreMatchTacticSelection? tactics,
  }) async {
    final next = await getNextFixture();
    if (next == null) {
      throw const SeasonException('No fixture to play');
    }
    final opponent = await loadOpponent(next.opponentClubId);
    return MatchSession.createAgainstClub(
      store: store,
      seed: _random.nextInt(1 << 31),
      opponentClub: opponent.club,
      opponentStarters: opponent.starters,
      opponentBench: opponent.bench,
      userAtHome: next.isHome,
      preMatchTalk: preMatchTalk,
      tactics: tactics,
    );
  }

  /// Records a played fixture: the MatchResult row (FR-038). Stamina and
  /// match rewards were already applied by [MatchSession.finish].
  ///
  /// The engine's home/away orientation follows the fixture (user home =
  /// user is MatchSide.home), so goals map straight through: the club
  /// listed as home is the side the engine tracked as home.
  Future<void> commitFixtureResult(
    MatchSession session,
    NextFixture fixture,
  ) async {
    final state = session.engine.state;
    final season = await getActiveSeason();
    if (season == null) {
      throw const SeasonException('No active season');
    }
    await _insertResult(
      season,
      fixtureId: fixture.fixtureId,
      round: fixture.round,
      homeClubId: fixture.isHome ? season.userClubId : fixture.opponentClubId,
      awayClubId: fixture.isHome ? fixture.opponentClubId : season.userClubId,
      homeGoals: state.scoreHome,
      awayGoals: state.scoreAway,
      seed: session.engine.seed,
    );
    // The AI opponent's squad also tires and recovers (GDD 11 symmetry);
    // its rolled injuries persist through the same pipeline (T-0055).
    final aiSide = fixture.isHome ? MatchSide.away : MatchSide.home;
    await _persistAiStamina(
      aiClubId: fixture.opponentClubId,
      players: session.engine.playersOf(aiSide),
      restDays: 3,
    );
    await _persistAiInjuries(
      aiClubId: fixture.opponentClubId,
      players: session.engine.playersOf(aiSide),
      injuries: session.engine.events,
    );
    // The rest of the round's AI fixtures resolve now (GDD 9.2 lockstep):
    // standings and AI stamina stay in step with the user's progress.
    await simulateAIFixturesThroughCurrentRound();
  }

  /// Rewinds one played user fixture so it can be replayed (GDD 19.3
  /// Match Replay, ad-gated): deletes the result row. The original match
  /// reward must not be duplicated, so the caller refunds the recorded
  /// reward before re-playing — the new finish() credits the fresh reward
  /// for the new result only.
  Future<int> rewindFixtureForReplay({
    required int fixtureId,
    required int rewardCoinsToRefund,
    required int userClubId,
  }) async {
    final existing = await (db.select(
      db.matchResults,
    )..where((r) => r.fixtureId.equals(fixtureId))).get();
    if (existing.isEmpty) {
      throw const SeasonException('Fixture has no result to replay');
    }
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.delete(
        db.matchResults,
      )..where((r) => r.fixtureId.equals(fixtureId))).go();
      if (rewardCoinsToRefund > 0) {
        // Relative debit — a concurrent coin movement can no longer be
        // overwritten by this refund (see coin_ops.dart). This is a
        // spend, not a credit: the earlier match reward is being taken
        // back before the replay re-earns it. Clamped to the balance
        // that is actually there: if the user already spent the reward
        // (bought a pack with it), the refund takes back only what
        // remains — the balance never goes below zero and the ledger
        // stays in agreement with it. The replayed match then credits
        // its fresh reward in full, as usual.
        final clubBefore = await (db.select(
          db.clubs,
        )..where((c) => c.id.equals(userClubId))).getSingle();
        final refund = rewardCoinsToRefund.clamp(0, clubBefore.coins);
        if (refund > 0) {
          await db.customUpdate(
            'UPDATE clubs SET coins = coins - ? WHERE id = ?',
            variables: [
              Variable.withInt(refund),
              Variable.withInt(userClubId),
            ],
            updates: {db.clubs},
            updateKind: UpdateKind.update,
          );
          final club = await (db.select(
            db.clubs,
          )..where((c) => c.id.equals(userClubId))).getSingle();
          await db
              .into(db.coinTransactions)
              .insert(
                CoinTransactionsCompanion.insert(
                  clubId: userClubId,
                  amount: -refund,
                  balanceAfter: club.coins,
                  reason: 'match_replay_refund',
                  detail: Value('Refund before replay of fixture $fixtureId'),
                  createdAt: now,
                ),
              );
        }
      }
    });
    return fixtureId;
  }

  /// Quick-simulates every unplayed fixture of the active season,
  /// including AI-vs-AI matches (GDD 9.6 difficulty must be testable
  /// through automated season simulations). User matches run through the
  /// full MatchEngine with the persisted squads; stamina and rewards are
  /// applied for user fixtures only.
  Future<int> simulateRemainingFixtures(CollectionStore store) async {
    final season = await getActiveSeason();
    if (season == null) {
      throw const SeasonException('No active season');
    }
    final playedIds = (await _resultsFor(season.id))
        .map((r) => r.fixtureId)
        .toSet();
    final fixtures =
        await (db.select(db.fixtures)
              ..where((f) => f.seasonId.equals(season.id))
              ..orderBy([
                (f) => OrderingTerm.asc(f.round),
                (f) => OrderingTerm.asc(f.id),
              ]))
            .get();

    var simulated = 0;
    for (final f in fixtures) {
      if (playedIds.contains(f.id)) continue;
      final involvesUser =
          f.homeClubId == season.userClubId ||
          f.awayClubId == season.userClubId;
      if (involvesUser) {
        final isHome = f.homeClubId == season.userClubId;
        final opponentId = isHome ? f.awayClubId : f.homeClubId;
        final opponent = await loadOpponent(opponentId);
        final session = await MatchSession.createAgainstClub(
          store: store,
          seed: _random.nextInt(1 << 31),
          opponentClub: opponent.club,
          opponentStarters: opponent.starters,
          opponentBench: opponent.bench,
          userAtHome: isHome,
        );
        session.simulateToEnd();
        await session.finish();
        await _insertResult(
          season,
          fixtureId: f.id,
          round: f.round,
          homeClubId: f.homeClubId,
          awayClubId: f.awayClubId,
          homeGoals: session.engine.state.scoreHome,
          awayGoals: session.engine.state.scoreAway,
          seed: session.engine.seed,
        );
      } else {
        await _simulateAiFixture(season, f);
      }
      simulated++;
    }
    return simulated;
  }

  /// Simulates the AI-vs-AI fixtures of every round the user has already
  /// completed (GDD 9.2: the league advances in lockstep with the user's
  /// fixtures). Call after committing a user result to keep standings and
  /// AI stamina in step; unplayed user fixtures and their rounds are left
  /// untouched. Returns the number of matches simulated.
  Future<int> simulateAIFixturesThroughCurrentRound() async {
    final season = await getActiveSeason();
    if (season == null) {
      throw const SeasonException('No active season');
    }
    final results = await _resultsFor(season.id);
    final playedIds = results.map((r) => r.fixtureId).toSet();
    // The user's last completed round = highest round with a user result.
    final userRounds = results.map((r) => r.round).toList(growable: false);
    if (userRounds.isEmpty) return 0;
    final lastUserRound = userRounds.reduce(math.max);

    final fixtures =
        await (db.select(db.fixtures)
              ..where((f) => f.seasonId.equals(season.id))
              ..orderBy([
                (f) => OrderingTerm.asc(f.round),
                (f) => OrderingTerm.asc(f.id),
              ]))
            .get();

    var simulated = 0;
    for (final f in fixtures) {
      if (f.round > lastUserRound) continue;
      final involvesUser =
          f.homeClubId == season.userClubId ||
          f.awayClubId == season.userClubId;
      if (involvesUser) continue; // user fixtures are played by the user
      if (playedIds.contains(f.id)) continue;
      await _simulateAiFixture(season, f);
      simulated++;
    }
    return simulated;
  }

  Future<void> _simulateAiFixture(Season season, Fixture f) async {
    final home = await loadOpponent(f.homeClubId);
    final away = await loadOpponent(f.awayClubId);
    final match = MatchEngine(
      seed: _random.nextInt(1 << 31),
      home: MatchTeamInput(
        teamId: home.club.id,
        teamName: home.club.name,
        formationCode: home.club.formationCode,
        tactics: tacticsFromDbPayload(home.club.tactics),
        mentality: _mentalityOf(home.club.mentality),
        starters: home.starters,
        bench: home.bench,
        aiControlled: true,
      ),
      away: MatchTeamInput(
        teamId: away.club.id,
        teamName: away.club.name,
        formationCode: away.club.formationCode,
        tactics: tacticsFromDbPayload(away.club.tactics),
        mentality: _mentalityOf(away.club.mentality),
        starters: away.starters,
        bench: away.bench,
        aiControlled: true,
      ),
    );
    match.simulateToEnd();
    await _insertResult(
      season,
      fixtureId: f.id,
      round: f.round,
      homeClubId: f.homeClubId,
      awayClubId: f.awayClubId,
      homeGoals: match.state.scoreHome,
      awayGoals: match.state.scoreAway,
      seed: match.seed,
    );
    // Both AI squads tire and recover symmetrically (GDD 11); their
    // rolled injuries persist through the same pipeline (T-0055).
    await _persistAiStamina(
      aiClubId: f.homeClubId,
      players: match.playersOf(MatchSide.home),
      restDays: 3,
    );
    await _persistAiStamina(
      aiClubId: f.awayClubId,
      players: match.playersOf(MatchSide.away),
      restDays: 3,
    );
    await _persistAiInjuries(
      aiClubId: f.homeClubId,
      players: match.playersOf(MatchSide.home),
      injuries: match.events,
    );
    await _persistAiInjuries(
      aiClubId: f.awayClubId,
      players: match.playersOf(MatchSide.away),
      injuries: match.events,
    );
  }

  Future<void> _insertResult(
    Season season, {
    required int fixtureId,
    required int round,
    required int homeClubId,
    required int awayClubId,
    required int homeGoals,
    required int awayGoals,
    required int seed,
  }) async {
    await db.transaction(() async {
      await db
          .into(db.matchResults)
          .insert(
            MatchResultsCompanion.insert(
              fixtureId: fixtureId,
              seasonId: season.id,
              round: round,
              homeClubId: homeClubId,
              awayClubId: awayClubId,
              homeGoals: homeGoals,
              awayGoals: awayGoals,
              seed: seed,
              engineVersion: matchEngineVersion,
              playedAt: DateTime.now(),
            ),
          );
    });
  }
}
