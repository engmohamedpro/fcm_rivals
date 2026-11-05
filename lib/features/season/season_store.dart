/// FCM Rivals — season store (GDD 9, GDD 18, FR-035..FR-039).
///
/// Orchestrates the SeasonEngine over the Drift database: season creation
/// with 19 AI clubs and their persisted squads, the 38-round fixture list,
/// playing the user's fixtures through the MatchEngine (live via
/// MatchSession, or quick-simulated), standings, and season completion
/// with promotion/relegation, rewards and next-season generation.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/players.dart';
import '../ads/ad_engine.dart';
import '../ads/ad_store.dart';
import '../collection/collection_store.dart';
import '../match/match_engine.dart';
import '../match/match_forecast.dart';
import '../match/match_session.dart';
import '../match/pre_match_screen.dart' show PreMatchTacticSelection;
import '../match/stamina.dart' show StaminaConfig, recoverStamina;
import '../match/tactics.dart'
    show Mentality, MatchPepTalk, tacticsFromDbPayload;
import '../squad/formations.dart';
import '../squad/squad_engine.dart' show PlayerCard;
import 'season_engine.dart';

/// Season-specific errors.
class SeasonException implements Exception {
  const SeasonException(this.message);
  final String message;
  @override
  String toString() => 'SeasonException: $message';
}

/// Snapshot of the active (or last) season for the UI.
class SeasonSummary {
  const SeasonSummary({
    required this.seasonId,
    required this.division,
    required this.ordinal,
    required this.status,
    required this.roundsPlayed,
    required this.roundsTotal,
    this.finalPosition,
    this.outcome,
  });

  final int seasonId;
  final int division;
  final int ordinal;

  /// active | completed.
  final String status;
  final int roundsPlayed;
  final int roundsTotal;
  final int? finalPosition;
  final String? outcome;

  bool get isCompleted => status == 'completed';
}

/// The user's next fixture, if any.
class NextFixture {
  const NextFixture({
    required this.fixtureId,
    required this.round,
    required this.isHome,
    required this.opponentClubId,
    required this.opponentName,
  });

  final int fixtureId;
  final int round;

  /// Whether the user hosts this fixture.
  final bool isHome;
  final int opponentClubId;
  final String opponentName;
}

/// Season completion outcome for the user (GDD 18 rewards).
class SeasonCompletion {
  const SeasonCompletion({
    required this.seasonId,
    required this.division,
    required this.finalPosition,
    required this.outcome,
    required this.nextDivision,
    required this.rewardCoins,
    required this.rewardPackCategory,
  });

  final int seasonId;
  final int division;
  final int finalPosition;

  /// promoted | stayed | relegated.
  final String outcome;
  final int nextDivision;
  final int rewardCoins;

  /// GDD 18 pack reward: 'premium' for 1st, 'normal' for 2nd–3rd,
  /// 'choice' for other promotions, null when staying/relegated.
  final String? rewardPackCategory;
}

/// AI opponent squad loaded for a fixture.
class AiOpponentSquad {
  const AiOpponentSquad({
    required this.club,
    required this.starters,
    required this.bench,
  });

  final Club club;
  final List<MatchPlayer> starters;
  final List<MatchPlayer> bench;
}

class SeasonStore {
  SeasonStore({
    required this.db,
    this.engine = const SeasonEngine(),
    math.Random? random,
  }) : _random = random ?? math.Random();

  final AppDatabase db;
  final SeasonEngine engine;
  final math.Random _random;

  /// Starts a new season in [division] for the user club (FR-035/FR-036):
  /// creates the season row, 19 AI clubs with persisted squads (FR-039),
  /// league team rows and the 38-round fixture list.
  ///
  /// AI squads are drawn from the REAL imported player database (GDD 9.4),
  /// banded around the division's difficulty target and never reusing a
  /// player the user owns or one already signed to another club in this
  /// division (each real player appears in at most one squad per season).
  Future<int> startSeason({
    required int division,
    int? aiCount,
    Set<int> carriedClubIds = const {},
  }) async {
    final club = await _userClub();
    final existing = await getActiveSeason();
    if (existing != null) {
      throw const SeasonException('A season is already in progress');
    }

    final ordinal = (await (db.select(db.seasons)).get()).length + 1;
    final count = aiCount ?? engine.config.clubsPerDivision - 1;
    final carriedCount = carriedClubIds.isEmpty
        ? 0
        : carriedClubIds.length.clamp(0, 6);
    final pool = await _realPlayerPool();
    final ownedIds = await _userOwnedPlayerIds();
    final definitions = engine.generateAiClubs(
      division,
      random: _random,
      count: count - carriedCount,
      excludeNames: {club.name},
      pool: pool,
      excludePlayerIds: ownedIds,
    );

    final now = DateTime.now();
    return db.transaction(() async {
      final seasonId = await db
          .into(db.seasons)
          .insert(
            SeasonsCompanion.insert(
              division: division,
              ordinal: ordinal,
              userClubId: club.id,
              startedAt: now,
            ),
          );

      // User participates as league team index 0 (the rotation anchor).
      await db
          .into(db.leagueTeams)
          .insert(
            LeagueTeamsCompanion.insert(
              seasonId: seasonId,
              clubId: club.id,
              isUser: const Value(true),
            ),
          );

      final clubIds = [club.id];
      final names = [club.name];

      // Carried-over clubs first (GDD 9.5): a club that moved divisions
      // WITH the user re-signs into the new division with its squad kept
      // — same real players, same identity, fresh condition.
      if (carriedCount > 0) {
        final carried = await (db.select(
          db.clubs,
        )..where((c) => c.id.isIn(carriedClubIds.toList()))).get();
        for (final c in carried) {
          clubIds.add(c.id);
          names.add(c.name);
          await db
              .into(db.leagueTeams)
              .insert(
                LeagueTeamsCompanion.insert(
                  seasonId: seasonId,
                  clubId: c.id,
                  carriedOver: const Value(true),
                ),
              );
        }
      }

      for (final def in definitions) {
        final aiClubId = await db
            .into(db.clubs)
            .insert(
              ClubsCompanion.insert(
                name: def.name,
                managerName: def.managerName,
                crestIndex: Value(def.crestIndex),
                formationCode: Value(def.formationCode),
                tactics: Value(jsonEncode(def.tactics.toJson())),
                mentality: Value(def.mentality.name),
                coins: 0,
                isUser: const Value(false),
                createdAt: now,
              ),
            );
        clubIds.add(aiClubId);
        names.add(def.name);
        await db
            .into(db.leagueTeams)
            .insert(
              LeagueTeamsCompanion.insert(seasonId: seasonId, clubId: aiClubId),
            );
        // Persist the AI squad (GDD 9.4): XI in slot order, bench after —
        // real dataset players carry their playerId.
        for (final p in def.players) {
          await db
              .into(db.aiPlayers)
              .insert(
                AiPlayersCompanion.insert(
                  clubId: aiClubId,
                  playerName: p.name,
                  position: p.position.code,
                  attack: p.attack,
                  support: p.support,
                  defence: p.defence,
                  goalkeeping: p.goalkeeping,
                  realPlayerId: Value(p.realPlayerId),
                ),
              );
        }
      }

      // Fixtures (FR-036): anchor = user club for a natural home/away
      // pattern; store rounds 1-based.
      final pairings = engine.generateFixtures(clubIds.length, anchorIndex: 0);
      for (final p in pairings) {
        await db
            .into(db.fixtures)
            .insert(
              FixturesCompanion.insert(
                seasonId: seasonId,
                round: p.round + 1,
                homeClubId: clubIds[p.homeIndex],
                awayClubId: clubIds[p.awayIndex],
              ),
            );
      }
      return seasonId;
    });
  }

  /// The active season summary, or the latest completed one.
  Future<SeasonSummary?> getSeasonSummary() async {
    final rows = await (db.select(
      db.seasons,
    )..orderBy([(s) => OrderingTerm.desc(s.id)])).get();
    if (rows.isEmpty) return null;
    final s = rows.first;
    final played = await _resultsFor(s.id);
    final userRounds = played
        .where(
          (r) => r.homeClubId == s.userClubId || r.awayClubId == s.userClubId,
        )
        .length;
    return SeasonSummary(
      seasonId: s.id,
      division: s.division,
      ordinal: s.ordinal,
      status: s.status,
      roundsPlayed: userRounds,
      roundsTotal: engine.config.roundsPerSeason(),
      finalPosition: s.finalPosition,
      outcome: s.outcome,
    );
  }

  Future<Season?> getActiveSeason() async {
    final rows =
        await (db.select(db.seasons)
              ..where((s) => s.status.equals('active'))
              ..orderBy([(s) => OrderingTerm.desc(s.id)]))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// The user's next unplayed fixture (FR-037 flow), or null when the
  /// season is done.
  Future<NextFixture?> getNextFixture() async {
    final season = await getActiveSeason();
    if (season == null) return null;
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
    Fixture? next;
    for (final f in fixtures) {
      if (playedIds.contains(f.id)) continue;
      if (f.homeClubId != season.userClubId &&
          f.awayClubId != season.userClubId) {
        continue;
      }
      next = f;
      break;
    }
    if (next == null) return null;
    final isHome = next.homeClubId == season.userClubId;
    final opponentId = isHome ? next.awayClubId : next.homeClubId;
    final opponent = await (db.select(
      db.clubs,
    )..where((c) => c.id.equals(opponentId))).getSingle();
    return NextFixture(
      fixtureId: next.id,
      round: next.round,
      isHome: isHome,
      opponentClubId: opponentId,
      opponentName: opponent.name,
    );
  }

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
    final squad = [
      for (final r in rows)
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
            playerId: -10_000 - _rowIdOf(rows, p),
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
            playerId: -10_000 - _rowIdOf(rows, p),
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

  /// Everything the pre-match analysis screen shows (GDD 13): both squads
  /// as engine inputs, the Monte-Carlo forecast of the fixture, the
  /// opponent's last five results and their key men. Pure read path — no
  /// state changes until the match is actually played.
  Future<PreMatchData> loadPreMatchData(CollectionStore store) async {
    final next = await getNextFixture();
    if (next == null) {
      throw const SeasonException('No fixture to play');
    }
    final opponent = await loadOpponent(next.opponentClubId);
    final club = await store.getClub();
    if (club == null) {
      throw const SeasonException('No club');
    }
    final squad = await store.getSquad();
    if (squad.length < Formation.startingXiSize) {
      throw const CollectionException(
        'A full starting XI is required to play a match',
      );
    }

    final teamTactics = tacticsFromDbPayload(club.tactics);
    final mentality = Mentality.values.firstWhere(
      (m) => m.name == club.mentality,
      orElse: () => Mentality.balanced,
    );
    // The user's FULL squad list: starting XI, bench and reserves — every
    // owned player counts toward the forecast, not just the selected XI.
    final userSquadList = [
      for (var slot = 0; slot < Formation.squadSize; slot++)
        if (squad.containsKey(slot)) _userMatchPlayer(squad[slot]!),
    ];
    final forecast = forecastMatch(
      input: ForecastInput(
        userSquad: userSquadList,
        opponentSquad: [...opponent.starters, ...opponent.bench],
      ),
      random: math.Random(next.fixtureId * 31 + 17),
    );

    // Opponent context: league positions, last five results, key men.
    final standings = await getStandings();
    int positionOf(bool isUser) {
      for (final e in standings) {
        if (isUser ? e.name == club.name : e.clubId == opponent.club.id) {
          return e.position;
        }
      }
      return 1;
    }

    final season = await getActiveSeason();
    final results =
        season == null
              ? <MatchResult>[]
              : await (db.select(db.matchResults)..where(
                      (r) =>
                          r.seasonId.equals(season.id) &
                          (r.homeClubId.equals(opponent.club.id) |
                              r.awayClubId.equals(opponent.club.id)),
                    ))
                    .get()
          ..sort((a, b) => a.round.compareTo(b.round));
    final form = [
      for (final r
          in results.length <= 5
              ? results
              : results.sublist(results.length - 5))
        () {
          final home = r.homeClubId == opponent.club.id;
          final gf = home ? r.homeGoals : r.awayGoals;
          final ga = home ? r.awayGoals : r.homeGoals;
          return gf > ga ? 'W' : (gf < ga ? 'L' : 'D');
        }(),
    ];

    // Top-3 rated players of the whole squad (starters and bench), with
    // full attributes for the collection-style analysis cards.
    final keyMen = [
      for (final p in [
        ...opponent.starters,
        ...opponent.bench,
      ]..sort((a, b) => _overallOf(b).compareTo(_overallOf(a))))
        (
          name: p.name,
          position: p.position.code,
          overall: _overallOf(p),
          attack: p.attack,
          support: p.support,
          defence: p.defence,
          goalkeeping: p.goalkeeping,
        ),
    ].take(3).toList();

    return PreMatchData(
      fixtureLabel: 'League · Round ${next.round}',
      userClubName: club.name,
      opponentClubName: opponent.club.name,
      userAtHome: next.isHome,
      forecast: forecast,
      opponentForm: form,
      opponentPosition: positionOf(false),
      userPosition: positionOf(true),
      opponentKeyMen: keyMen,
      userFormationCode: club.formationCode,
      userTactics: teamTactics,
      userMentality: mentality,
      userSquad: squad,
    );
  }

  static int _overallOf(MatchPlayer p) =>
      ((p.attack + p.support + p.defence) / 3).round();

  static MatchPlayer _userMatchPlayer(PlayerCard card) => MatchPlayer(
    playerId: card.ownedId,
    name: card.base.name,
    position: card.position,
    attack: card.attribute(PlayerAttribute.attack),
    support: card.attribute(PlayerAttribute.support),
    defence: card.attribute(PlayerAttribute.defence),
    goalkeeping: card.attribute(PlayerAttribute.goalkeeping),
    stamina: card.staminaPercent.toDouble(),
  );

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
    // The AI opponent's squad also tires and recovers (GDD 11 symmetry).
    final aiSide = fixture.isHome ? MatchSide.away : MatchSide.home;
    await _persistAiStamina(
      aiClubId: fixture.opponentClubId,
      players: session.engine.playersOf(aiSide),
      restDays: 3,
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
    // Both AI squads tire and recover symmetrically (GDD 11).
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
  /// pays season rewards with a ledger row, grants reward packs, retires
  /// the AI clubs' squads and returns the completion summary. A new
  /// season is NOT started automatically — the UI asks the player.
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

    // GDD 18 pack rewards.
    final packCategory = switch (outcome) {
      SeasonOutcome.promoted =>
        userEntry.position == 1
            ? 'premium'
            : (userEntry.position <= 3 ? 'normal' : 'choice'),
      _ => null,
    };

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

      // Reward packs (GDD 18 table): 1st = premium, 2nd–3rd = normal pack,
      // other promotions = a pack of the user's choice (stored with a
      // 'season_choice' source the UI scopes when opening).
      if (packCategory != null) {
        await db
            .into(db.packs)
            .insert(
              PacksCompanion.insert(
                clubId: club.id,
                category: 'global',
                source: Value('season_$packCategory'),
                createdAt: now,
              ),
            );
      }
    });

    return SeasonCompletion(
      seasonId: season.id,
      division: season.division,
      finalPosition: userEntry.position,
      outcome: outcome.name,
      nextDivision: nextDivision,
      rewardCoins: rewardCoins,
      rewardPackCategory: packCategory,
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

  /// The real-player pool for AI squad generation (GDD 9.4): every
  /// imported dataset player as an [AiPoolPlayer]. Empty when no dataset
  /// is loaded yet — generation then falls back to synthetic players.
  Future<List<AiPoolPlayer>> _realPlayerPool() async {
    final rows = await db.select(db.players).get();
    return [
      for (final r in rows)
        AiPoolPlayer(
          playerId: r.playerId,
          name: r.name,
          position: Position.fromCode(r.position),
          overall: r.overall,
          attack: r.attack,
          support: r.support,
          defence: r.defence,
          goalkeeping: r.goalkeeping,
        ),
    ];
  }

  /// Dataset player ids the user already owns — AI squads never sign a
  /// player the user's collection holds (one identity per club, GDD 9.4).
  Future<Set<int>> _userOwnedPlayerIds() async {
    final rows = await (db.select(
      db.ownedPlayers,
    )..where((o) => o.status.equals('owned'))).get();
    return {for (final r in rows) r.playerId};
  }

  Future<Club> _userClub() async {
    final rows = await (db.select(
      db.clubs,
    )..where((c) => c.isUser.equals(true))).get();
    if (rows.isEmpty) {
      throw const SeasonException('No user club');
    }
    return rows.first;
  }

  Future<List<MatchResult>> _resultsFor(int seasonId) => (db.select(
    db.matchResults,
  )..where((r) => r.seasonId.equals(seasonId))).get();

  Mentality _mentalityOf(String name) => Mentality.values.firstWhere(
    (m) => m.name == name,
    orElse: () => Mentality.balanced,
  );
}
