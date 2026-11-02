/// FCM Rivals — season store (GDD 9, GDD 18, FR-035..FR-039).
///
/// Orchestrates the SeasonEngine over the Drift database: season creation
/// with 19 AI clubs and their persisted squads, the 38-round fixture list,
/// playing the user's fixtures through the MatchEngine (live via
/// MatchSession, or quick-simulated), standings, and season completion
/// with promotion/relegation, rewards and next-season generation.
library;

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
import '../match/stamina.dart' show StaminaConfig, recoverStamina;
import '../match/tactics.dart' show PlayingStyle, Mentality, MatchPepTalk;
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
  const AiOpponentSquad({required this.club, required this.starters, required this.bench});

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
    final carriedCount =
        carriedClubIds.isEmpty ? 0 : carriedClubIds.length.clamp(0, 6);
    final definitions = engine.generateAiClubs(
      division,
      random: _random,
      count: count - carriedCount,
      excludeNames: {club.name},
    );

    final now = DateTime.now();
    return db.transaction(() async {
      final seasonId = await db.into(db.seasons).insert(SeasonsCompanion.insert(
            division: division,
            ordinal: ordinal,
            userClubId: club.id,
            startedAt: now,
          ));

      // User participates as league team index 0 (the rotation anchor).
      await db.into(db.leagueTeams).insert(LeagueTeamsCompanion.insert(
            seasonId: seasonId,
            clubId: club.id,
            isUser: const Value(true),
          ));

      final clubIds = [club.id];
      final names = [club.name];

      // Carried-over clubs first (GDD 9.5): re-sign the retained squad
      // into the new division, retuned for its difficulty target.
      if (carriedCount > 0) {
        final carried = await (db.select(db.clubs)
              ..where((c) => c.id.isIn(carriedClubIds.toList())))
            .get();
        for (final c in carried) {
          clubIds.add(c.id);
          names.add(c.name);
          await db.into(db.leagueTeams).insert(LeagueTeamsCompanion.insert(
                seasonId: seasonId,
                clubId: c.id,
                carriedOver: const Value(true),
              ));
          await _retuneCarriedSquad(c.id, division: division);
        }
      }

      for (final def in definitions) {
        final aiClubId = await db.into(db.clubs).insert(ClubsCompanion.insert(
              name: def.name,
              managerName: def.managerName,
              crestIndex: Value(def.crestIndex),
              formationCode: Value(def.formationCode),
              playingStyle: Value(def.style.name),
              mentality: Value(def.mentality.name),
              coins: 0,
              isUser: const Value(false),
              createdAt: now,
            ));
        clubIds.add(aiClubId);
        names.add(def.name);
        await db.into(db.leagueTeams).insert(LeagueTeamsCompanion.insert(
              seasonId: seasonId,
              clubId: aiClubId,
            ));
        // Persist the AI squad (GDD 9.4): XI in slot order, bench after.
        for (final p in def.players) {
          await db.into(db.aiPlayers).insert(AiPlayersCompanion.insert(
                clubId: aiClubId,
                playerName: p.name,
                position: p.position.code,
                attack: p.attack,
                support: p.support,
                defence: p.defence,
                goalkeeping: p.goalkeeping,
              ));
        }
      }

      // Fixtures (FR-036): anchor = user club for a natural home/away
      // pattern; store rounds 1-based.
      final pairings = engine.generateFixtures(clubIds.length, anchorIndex: 0);
      for (final p in pairings) {
        await db.into(db.fixtures).insert(FixturesCompanion.insert(
              seasonId: seasonId,
              round: p.round + 1,
              homeClubId: clubIds[p.homeIndex],
              awayClubId: clubIds[p.awayIndex],
            ));
      }
      return seasonId;
    });
  }

  /// The active season summary, or the latest completed one.
  Future<SeasonSummary?> getSeasonSummary() async {
    final rows = await (db.select(db.seasons)
          ..orderBy([(s) => OrderingTerm.desc(s.id)]))
        .get();
    if (rows.isEmpty) return null;
    final s = rows.first;
    final played = await _resultsFor(s.id);
    final userRounds = played
        .where((r) =>
            r.homeClubId == s.userClubId || r.awayClubId == s.userClubId)
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
    final rows = await (db.select(db.seasons)
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
    final playedIds = (await _resultsFor(season.id)).map((r) => r.fixtureId).toSet();
    final fixtures = await (db.select(db.fixtures)
          ..where((f) => f.seasonId.equals(season.id))
          ..orderBy([
            (f) => OrderingTerm.asc(f.round),
            (f) => OrderingTerm.asc(f.id),
          ]))
        .get();
    Fixture? next;
    for (final f in fixtures) {
      if (playedIds.contains(f.id)) continue;
      if (f.homeClubId != season.userClubId && f.awayClubId != season.userClubId) {
        continue;
      }
      next = f;
      break;
    }
    if (next == null) return null;
    final isHome = next.homeClubId == season.userClubId;
    final opponentId = isHome ? next.awayClubId : next.homeClubId;
    final opponent = await (db.select(db.clubs)
          ..where((c) => c.id.equals(opponentId)))
        .getSingle();
    return NextFixture(
      fixtureId: next.id,
      round: next.round,
      isHome: isHome,
      opponentClubId: opponentId,
      opponentName: opponent.name,
    );
  }

  /// Loads the AI opponent squad for a fixture (GDD 9.4 persisted squads).
  Future<AiOpponentSquad> loadOpponent(int clubId) async {
    final club = await (db.select(db.clubs)..where((c) => c.id.equals(clubId)))
        .getSingle();
    final rows = await (db.select(db.aiPlayers)
          ..where((p) => p.clubId.equals(clubId)))
        .get();
    if (rows.isEmpty) {
      throw const SeasonException('AI club has no squad');
    }
    List<MatchPlayer> toPlayers(Iterable<AiPlayer> rs) => [
          for (final r in rs)
            MatchPlayer(
              playerId: -10_000 - r.id,
              name: r.playerName,
              position: Position.fromCode(r.position),
              attack: r.attack,
              support: r.support,
              defence: r.defence,
              goalkeeping: r.goalkeeping,
              stamina: r.staminaPercent.toDouble(),
            ),
        ];
    final starters = toPlayers(rows.take(11));
    final bench = toPlayers(rows.skip(11));
    return AiOpponentSquad(club: club, starters: starters, bench: bench);
  }

  /// Persists an AI club's post-match stamina (GDD 11 applies to every
  /// club, not just the user): match-end stamina plus the same natural
  /// recovery the user's squad gets, so AI squads tire and heal across a
  /// season symmetrically with the player. Until now AI clubs kept 100%
  /// stamina forever — a large hidden difficulty asymmetry found by the
  /// §30 simulation harness.
  Future<void> _persistAiStamina({
    required int aiClubId,
    required Iterable<MatchPlayer> players,
    required int restDays,
  }) async {
    for (final p in players) {
      if (p.minutesPlayed == 0) continue;
      final row = await (db.select(db.aiPlayers)
            ..where((a) => a.id.equals(-(p.playerId + 10_000))))
          .getSingleOrNull();
      if (row == null) continue;
      final recovered = recoverStamina(
        config: const StaminaConfig(),
        currentStamina: p.stamina,
        minutesPlayed: p.minutesPlayed,
        restDays: restDays,
      );
      await (db.update(db.aiPlayers)..where((a) => a.id.equals(row.id)))
          .write(AiPlayersCompanion(
              staminaPercent: Value(recovered.round().clamp(0, 100))));
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
          'A full starting XI is required to play a match');
    }

    final style = PlayingStyle.values.firstWhere(
        (s) => s.name == club.playingStyle,
        orElse: () => PlayingStyle.balanced);
    final mentality = Mentality.values.firstWhere(
        (m) => m.name == club.mentality,
        orElse: () => Mentality.balanced);
    final userTeam = MatchTeamInput(
      teamId: club.id,
      teamName: club.name,
      formationCode: club.formationCode,
      style: style,
      mentality: mentality,
      starters: [
        for (var slot = 0; slot < Formation.startingXiSize; slot++)
          _userMatchPlayer(squad[slot]!),
      ],
      bench: [
        for (var slot = Formation.startingXiSize;
            slot < Formation.squadSize && squad.containsKey(slot);
            slot++)
          _userMatchPlayer(squad[slot]!),
      ],
    );
    final opponentStyle = PlayingStyle.values.firstWhere(
        (s) => s.name == opponent.club.playingStyle,
        orElse: () => PlayingStyle.balanced);
    final opponentMentality = Mentality.values.firstWhere(
        (m) => m.name == opponent.club.mentality,
        orElse: () => Mentality.balanced);
    final opponentTeam = MatchTeamInput(
      teamId: opponent.club.id,
      teamName: opponent.club.name,
      formationCode: opponent.club.formationCode,
      style: opponentStyle,
      mentality: opponentMentality,
      starters: opponent.starters,
      bench: opponent.bench,
      aiControlled: true,
    );

    final forecast = forecastMatch(
      input: ForecastInput(
        userTeam: userTeam,
        opponentTeam: opponentTeam,
        userAtHome: next.isHome,
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
    final results = season == null
        ? <MatchResult>[]
        : await (db.select(db.matchResults)
              ..where((r) =>
                  r.seasonId.equals(season.id) &
                  (r.homeClubId.equals(opponent.club.id) |
                      r.awayClubId.equals(opponent.club.id))))
            .get()
          ..sort((a, b) => a.round.compareTo(b.round));
    final form = [
      for (final r in results.length <= 5 ? results : results.sublist(results.length - 5))
        () {
          final home = r.homeClubId == opponent.club.id;
          final gf = home ? r.homeGoals : r.awayGoals;
          final ga = home ? r.awayGoals : r.homeGoals;
          return gf > ga ? 'W' : (gf < ga ? 'L' : 'D');
        }()
    ];

    final keyMen = [
      for (final p in [...opponent.starters]..sort((a, b) => _overallOf(b).compareTo(_overallOf(a))))
        (name: p.name, overall: _overallOf(p)),
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
    );
  }

  static int _overallOf(MatchPlayer p) => ((p.attack + p.support + p.defence) / 3).round();

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
  Future<MatchSession> startNextFixture(CollectionStore store,
      {MatchPepTalk? preMatchTalk}) async {
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
    );
  }

  /// Records a played fixture: the MatchResult row (FR-038). Stamina and
  /// match rewards were already applied by [MatchSession.finish].
  ///
  /// The engine's home/away orientation follows the fixture (user home =
  /// user is MatchSide.home), so goals map straight through: the club
  /// listed as home is the side the engine tracked as home.
  Future<void> commitFixtureResult(MatchSession session, NextFixture fixture) async {
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
    final aiSide =
        fixture.isHome ? MatchSide.away : MatchSide.home;
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
    final existing = await (db.select(db.matchResults)
          ..where((r) => r.fixtureId.equals(fixtureId)))
        .get();
    if (existing.isEmpty) {
      throw const SeasonException('Fixture has no result to replay');
    }
    final now = DateTime.now();
    await db.transaction(() async {
      await (db.delete(db.matchResults)
            ..where((r) => r.fixtureId.equals(fixtureId)))
          .go();
      if (rewardCoinsToRefund > 0) {
        final club = await (db.select(db.clubs)
              ..where((c) => c.id.equals(userClubId)))
            .getSingle();
        await (db.update(db.clubs)..where((c) => c.id.equals(userClubId)))
            .write(ClubsCompanion(coins: Value(club.coins - rewardCoinsToRefund)));
        await db.into(db.coinTransactions).insert(CoinTransactionsCompanion.insert(
              clubId: userClubId,
              amount: -rewardCoinsToRefund,
              balanceAfter: club.coins - rewardCoinsToRefund,
              reason: 'match_replay_refund',
              detail: Value('Refund before replay of fixture $fixtureId'),
              createdAt: now,
            ));
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
    final playedIds = (await _resultsFor(season.id)).map((r) => r.fixtureId).toSet();
    final fixtures = await (db.select(db.fixtures)
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
          f.homeClubId == season.userClubId || f.awayClubId == season.userClubId;
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

    final fixtures = await (db.select(db.fixtures)
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
          f.homeClubId == season.userClubId || f.awayClubId == season.userClubId;
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
        style: _styleOf(home.club.playingStyle),
        mentality: _mentalityOf(home.club.mentality),
        starters: home.starters,
        bench: home.bench,
        aiControlled: true,
      ),
      away: MatchTeamInput(
        teamId: away.club.id,
        teamName: away.club.name,
        formationCode: away.club.formationCode,
        style: _styleOf(away.club.playingStyle),
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
        restDays: 3);
    await _persistAiStamina(
        aiClubId: f.awayClubId,
        players: match.playersOf(MatchSide.away),
        restDays: 3);
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
      await db.into(db.matchResults).insert(MatchResultsCompanion.insert(
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
          ));
    });
  }

  /// Current standings of the active season (GDD 9.3).
  Future<List<StandingEntry>> getStandings() async {
    final season = await getActiveSeason() ??
        (await (db.select(db.seasons)
              ..orderBy([(s) => OrderingTerm.desc(s.id)]))
            .get())
            .firstOrNull;
    if (season == null) return const [];
    final teams = await (db.select(db.leagueTeams)
          ..where((t) => t.seasonId.equals(season.id)))
        .get();
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
        )
    ];
    return engine.computeStandings(
        clubIds: clubIds, names: names, results: tuples);
  }

  /// Recent user results (FR-038 history), newest first.
  Future<List<MatchResult>> getMatchHistory({int limit = 10}) async {
    final seasons = await db.select(db.seasons).get();
    if (seasons.isEmpty) return const [];
    final userClubId = seasons.first.userClubId;
    final results = await (db.select(db.matchResults)
          ..where((r) => r.homeClubId.equals(userClubId) |
              r.awayClubId.equals(userClubId))
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
    final baseRewardCoins =
        engine.seasonRewardCoins(division: season.division, position: userEntry.position);

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
      SeasonOutcome.promoted => userEntry.position == 1 ? 'premium' : (userEntry.position <= 3 ? 'normal' : 'choice'),
      _ => null,
    };

    final now = DateTime.now();
    await db.transaction(() async {
      // Final positions for every league team (FR-038).
      for (final e in standings) {
        await (db.update(db.leagueTeams)
              ..where((t) =>
                  t.seasonId.equals(season.id) & t.clubId.equals(e.clubId)))
            .write(LeagueTeamsCompanion(finalPosition: Value(e.position)));
      }
      await (db.update(db.seasons)..where((s) => s.id.equals(season.id)))
          .write(SeasonsCompanion(
        status: const Value('completed'),
        endedAt: Value(now),
        finalPosition: Value(userEntry.position),
        outcome: Value(outcome.name),
      ));

      // Retire AI squads (GDD 9.5) — EXCEPT carried-over clubs: the three
      // promoted and three relegated clubs keep their squads for the
      // next season in their new division. Everyone else regenerates;
      // historical RESULTS always stay (FR-038), only squads go.
      final teams = await (db.select(db.leagueTeams)
            ..where((t) => t.seasonId.equals(season.id) & t.isUser.equals(false)))
          .get();
      // Promoted = top 3, relegated = bottom 3 of the final table
      // (GDD 9.3); the user may occupy one of those spots.
      final sorted = teams.toList()
        ..sort((a, b) => (a.finalPosition ?? 99).compareTo(b.finalPosition ?? 99));
      // Retain the promoted (top 3) and relegated (bottom 3) AI clubs
      // (GDD 9.5). The user's own spot is excluded because the user club
      // always continues — it is not part of this table.
      final carryIds = <int>{};
      if (sorted.length >= 6) {
        for (final t in sorted.take(3)) {
          carryIds.add(t.clubId);
        }
        for (final t in sorted.skip(sorted.length - 3)) {
          carryIds.add(t.clubId);
        }
      }
      for (final t in teams) {
        if (carryIds.contains(t.clubId)) {
          // Carried over: flag the league row and reset the squad to full
          // freshness for the new campaign.
          await (db.update(db.leagueTeams)
                ..where((l) => l.id.equals(t.id)))
              .write(const LeagueTeamsCompanion(carriedOver: Value(true)));
          await (db.update(db.aiPlayers)
                ..where((p) => p.clubId.equals(t.clubId)))
              .write(const AiPlayersCompanion(
                  staminaPercent: Value(100)));
        } else {
          await (db.delete(db.aiPlayers)
                ..where((p) => p.clubId.equals(t.clubId)))
              .go();
        }
      }

      // Season rewards (GDD 18): coins + ledger row.
      final club = await (db.select(db.clubs)
            ..where((c) => c.id.equals(season.userClubId)))
          .getSingle();
      await (db.update(db.clubs)..where((c) => c.id.equals(club.id)))
          .write(ClubsCompanion(coins: Value(club.coins + rewardCoins)));
      await db.into(db.coinTransactions).insert(CoinTransactionsCompanion.insert(
            clubId: club.id,
            amount: rewardCoins,
            balanceAfter: club.coins + rewardCoins,
            reason: 'season_reward',
            detail: Value('Season ${season.ordinal} · division ${season.division} · '
                'finished ${userEntry.position} (${outcome.name})'
                '${seasonMultiplierUsed ? ' · ad season multiplier' : ''}'),
            createdAt: now,
          ));
      if (seasonMultiplierUsed) {
        await ads.consumeSeasonMultiplier(club.id, now: now);
      }

      // Reward packs (GDD 18 table): 1st = premium, 2nd–3rd = normal pack,
      // other promotions = a pack of the user's choice (stored with a
      // 'season_choice' source the UI scopes when opening).
      if (packCategory != null) {
        await db.into(db.packs).insert(PacksCompanion.insert(
              clubId: club.id,
              category: 'global',
              source: Value('season_$packCategory'),
              createdAt: now,
            ));
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

  /// Starts the next season in [division] after completion (GDD 9.5:
  /// fresh opponents are generated; carried-over promoted/relegated clubs
  /// are a future refinement — v1 generates a fresh division each season,
  /// which the GDD's 17-new-clubs rule permits).
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
            orElse: () => SeasonOutcome.stayed);
    final division = engine.nextDivisionFor(summary.division, outcome);

    // Carried-over clubs (GDD 9.5): the promoted (top 3) and relegated
    // (bottom 3) AI clubs of the completed season re-sign. Derived from
    // final positions — NOT from the carriedOver flag, which marks how a
    // club entered this season and would double-count on re-sign rows.
    final seasonId = summary.seasonId;
    final teams = await (db.select(db.leagueTeams)
          ..where((t) => t.seasonId.equals(seasonId) & t.isUser.equals(false)))
        .get();
    final sorted = teams.toList()
      ..sort((a, b) =>
          (a.finalPosition ?? 99).compareTo(b.finalPosition ?? 99));
    final carriedIds = <int>{};
    if (sorted.length >= 6) {
      for (final t in sorted.take(3)) {
        carriedIds.add(t.clubId);
      }
      for (final t in sorted.skip(sorted.length - 3)) {
        carriedIds.add(t.clubId);
      }
    }

    return startSeason(division: division, carriedClubIds: carriedIds);
  }

  /// Re-tunes a carried-over squad for its new division (GDD 9.6): the
  /// club keeps identity, formation and players, but each attribute is
  /// shifted by the division difficulty delta so the squad tracks the
  /// new target average overall. Values stay within the generator's
  /// 35–94 band.
  Future<void> _retuneCarriedSquad(int clubId, {required int division}) async {
    final rows = await (db.select(db.aiPlayers)
          ..where((p) => p.clubId.equals(clubId)))
        .get();
    final target = engine.config.targetAverageOverall(division);
    // Estimate the squad's current average overall from its attributes.
    final current = rows.isEmpty
        ? target
        : rows
                .map((p) => (p.attack + p.support + p.defence + p.goalkeeping) /
                    4)
                .reduce((a, b) => a + b) /
            rows.length;
    final delta = (target - current).round();
    if (delta == 0) return;
    for (final p in rows) {
      int shift(int value) => (value + delta).clamp(35, 94).toInt();
      await (db.update(db.aiPlayers)..where((a) => a.id.equals(p.id)))
          .write(AiPlayersCompanion(
        attack: Value(shift(p.attack)),
        support: Value(shift(p.support)),
        defence: Value(shift(p.defence)),
        goalkeeping: Value(shift(p.goalkeeping)),
        staminaPercent: const Value(100),
      ));
    }
  }

  Future<Club> _userClub() async {
    final rows = await (db.select(db.clubs)
          ..where((c) => c.isUser.equals(true)))
        .get();
    if (rows.isEmpty) {
      throw const SeasonException('No user club');
    }
    return rows.first;
  }

  Future<List<MatchResult>> _resultsFor(int seasonId) =>
      (db.select(db.matchResults)..where((r) => r.seasonId.equals(seasonId)))
          .get();

  PlayingStyle _styleOf(String name) => PlayingStyle.values
      .firstWhere((s) => s.name == name, orElse: () => PlayingStyle.balanced);

  Mentality _mentalityOf(String name) => Mentality.values
      .firstWhere((m) => m.name == name, orElse: () => Mentality.balanced);
}
