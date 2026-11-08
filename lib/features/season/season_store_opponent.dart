part of 'season_store.dart';

/// SeasonStore opponent squads family of [SeasonStore] (extracted from the store, app-structure
/// review task `2026-11-06_app-structure_finish-season-store-split`):
/// loading the persisted AI opponent squad for a fixture and persisting AI stamina after a match (GDD 9.4). Pure relocation — bodies unchanged; part of the store library so
/// private state and sibling members stay reachable. Public-named because
/// its members are the store's public API and every caller imports
/// season_store.dart directly, so existing call sites keep resolving with
/// zero edits.
extension SeasonOpponentOps on SeasonStore {
  /// Loads the AI opponent squad for a fixture (GDD 9.4 persisted squads):
  /// the club's FULL persisted squad at current condition, then the AI's
  /// rotation decision — the engine picks the starting XI and bench from
  /// everyone available, resting tired legs where a close-quality backup
  /// exists (GDD 11 symmetry: the AI manages its squad like the user).
  /// The persisted row order is no longer the XI: [AiOpponentSquad] is
  /// whatever the AI actually fields today.
  Future<AiOpponentSquad> loadOpponent(int clubId) async {
    final club = await (db.select(
      db.clubs,
    )..where((c) => c.id.equals(clubId))).getSingle();
    final rows = await (db.select(
      db.aiPlayers,
    )..where((p) => p.clubId.equals(clubId))).get();
    if (rows.isEmpty) {
      throw const SeasonException('AI club has no squad');
    }
    // Injured AI players sit out (T-0055, GDD 11.7): the available pool
    // excludes them. A gutted club backfills from the injured rows
    // (fewest matches out first) to stay at the formation's minimum —
    // it never fields fewer than a legal XI.
    var available = rows
        .where((r) => (r.injuryMatchesRemaining ?? 0) <= 0)
        .toList();
    if (available.length < Formation.startingXiSize) {
      final missing = Formation.startingXiSize - available.length;
      final sidelined = [...rows]
        ..removeWhere(available.contains)
        ..sort(
          (a, b) => (a.injuryMatchesRemaining ?? 0).compareTo(
            b.injuryMatchesRemaining ?? 0,
          ),
        );
      available = [...available, ...sidelined.take(missing)];
    }
    final squad = [
      for (final r in available)
        AiSquadPlayer(
          realPlayerId: r.realPlayerId,
          name: r.playerName,
          position: Position.fromCode(r.position),
          attack: r.attack,
          support: r.support,
          defence: r.defence,
          goalkeeping: r.goalkeeping,
          stamina: r.staminaPercent.toDouble(),
        ),
    ];
    final lineup = engine.pickAiLineup(squad, club.formationCode);
    return AiOpponentSquad(
      club: club,
      starters: [
        for (final p in lineup.starters)
          MatchPlayer(
            playerId: -10_000 - _rowIdOf(available, p),
            name: p.name,
            position: p.position,
            attack: p.attack,
            support: p.support,
            defence: p.defence,
            goalkeeping: p.goalkeeping,
            stamina: p.stamina,
          ),
      ],
      bench: [
        for (final p in lineup.bench)
          MatchPlayer(
            playerId: -10_000 - _rowIdOf(available, p),
            name: p.name,
            position: p.position,
            attack: p.attack,
            support: p.support,
            defence: p.defence,
            goalkeeping: p.goalkeeping,
            stamina: p.stamina,
          ),
      ],
    );
  }

  /// Row id for an [AiSquadPlayer] picked by [engine.pickAiLineup] —
  /// matched on identity: real players by their dataset id, synthetic
  /// ones by name+position (unique within a club's squad).
  int _rowIdOf(List<AiPlayer> rows, AiSquadPlayer p) {
    if (p.realPlayerId != null) {
      for (final r in rows) {
        if (r.realPlayerId == p.realPlayerId) return r.id;
      }
    }
    return rows
        .firstWhere(
          (r) => r.playerName == p.name && r.position == p.position.code,
        )
        .id;
  }

  /// Persists an AI club's post-match stamina (GDD 11 applies to every
  /// club, not just the user): match-end stamina plus the same natural
  /// recovery the user's squad gets, for EVERY squad member — players who
  /// missed the match recover their rest too (they used to be frozen at
  /// whatever condition they had, which quietly stacked AI squads at 100%
  /// forever after a season reset). AI squads tire and heal across a
  /// season symmetrically with the player.
  Future<void> _persistAiStamina({
    required int aiClubId,
    required Iterable<MatchPlayer> players,
    required int restDays,
  }) async {
    final byEngineId = {for (final p in players) p.playerId: p};
    final rows = await (db.select(
      db.aiPlayers,
    )..where((a) => a.clubId.equals(aiClubId))).get();
    // Recovery decrement (T-0055, GDD 11.7): every committed fixture
    // counts the AI club's injuries down by exactly one match, floor 0.
    // Runs BEFORE any new injury write so a player hurt in THIS match
    // keeps his full matches-out.
    await db.customUpdate(
      'UPDATE ai_players SET injury_matches_remaining = '
      'injury_matches_remaining - 1 WHERE club_id = ? AND '
      'injury_matches_remaining > 0',
      variables: [Variable.withInt(aiClubId)],
      updates: {db.aiPlayers},
      updateKind: UpdateKind.update,
    );
    await db.customUpdate(
      'UPDATE ai_players SET injury_kind = NULL WHERE club_id = ? AND '
      'injury_matches_remaining <= 0',
      variables: [Variable.withInt(aiClubId)],
      updates: {db.aiPlayers},
      updateKind: UpdateKind.update,
    );
    for (final row in rows) {
      final match = byEngineId[-10_000 - row.id];
      final currentStamina = match?.stamina ?? row.staminaPercent.toDouble();
      final minutes = match?.minutesPlayed ?? 0;
      final recovered = recoverStamina(
        config: const StaminaConfig(),
        currentStamina: currentStamina,
        minutesPlayed: minutes,
        restDays: restDays,
      );
      await (db.update(db.aiPlayers)..where((a) => a.id.equals(row.id))).write(
        AiPlayersCompanion(
          staminaPercent: Value(recovered.round().clamp(0, 100)),
        ),
      );
    }
  }

  /// Persists an AI club's rolled injuries from a finished match
  /// (T-0055): the engine's negative ids map back to aiPlayers rows
  /// (−10000 − row id). Call AFTER [_persistAiStamina] so a fresh injury
  /// keeps its full matches-out. The re-injury guard mirrors the user
  /// store — an injured player was never fielded.
  Future<void> _persistAiInjuries({
    required int aiClubId,
    required Iterable<MatchPlayer> players,
    required Iterable<MatchEvent> injuries,
  }) async {
    final ids = {for (final p in players) p.playerId};
    for (final e in injuries) {
      if (e.type != MatchEventType.injury) continue;
      final engineId = e.primaryPlayerId;
      if (engineId == null || !ids.contains(engineId)) continue;
      final rowId = -10_000 - engineId;
      final row = await (db.select(
        db.aiPlayers,
      )..where((a) => a.id.equals(rowId))).getSingleOrNull();
      if (row == null) continue;
      if ((row.injuryMatchesRemaining ?? 0) > 0) continue;
      await (db.update(db.aiPlayers)..where((a) => a.id.equals(rowId))).write(
        AiPlayersCompanion(
          injuryMatchesRemaining: Value(e.metadata['matchesOut'] as int),
          injuryKind: Value(e.metadata['kind'] as String),
        ),
      );
    }
  }
}
