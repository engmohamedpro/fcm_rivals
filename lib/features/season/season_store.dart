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
import '../match/pre_match_tactics_selection.dart';
import '../match/stamina.dart' show StaminaConfig, recoverStamina;
import '../match/tactics.dart'
    show Mentality, MatchPepTalk, tacticsFromDbPayload;
import '../squad/formations.dart';
import '../squad/squad_engine.dart' show PlayerCard;
import 'season_engine.dart';
import 'season_models.dart';

export 'season_models.dart';

part 'season_store_opponent.dart';
part 'season_store_fixture_play.dart';
part 'season_store_standings.dart';

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
                // T-0099: the full spec persists into the `crest`
                // column; crestIndex keeps the spec's PRIMARY palette
                // index so legacy consumers (pre-T-0097 reads) stay in
                // range and consistent.
                crestIndex: Value(def.crest.primaryIndex),
                crest: Value(def.crest.encode()),
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
      userCrest: CollectionStore.crestOf(club),
      opponentCrest: CollectionStore.crestOf(opponent.club),
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
    nationality: card.base.nationality,
    clubId: card.base.clubId,
    clubName: card.base.clubName,
    stamina: card.staminaPercent.toDouble(),
  );

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
