/// FCM Rivals — match session orchestration (GDD 12.5, FR-024..FR-034).
///
/// Bridges the pure Match Engine with the collection store: builds engine
/// inputs from the persisted squad, applies live commands, and on full time
/// persists stamina, credits match rewards and exposes the full report
/// (commentary, statistics, ratings — all derived from the same events).
library;


import '../../core/database/app_database.dart' as db;
import '../collection/collection_store.dart';
import '../economy/economy_engine.dart';
import '../../core/domain/players.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import 'match_engine.dart';
import 'match_report.dart';
import 'stamina.dart';
import 'tactics.dart';

/// Complete post-match output for the report screen and persistence.
class MatchReportResult {
  const MatchReportResult({
    required this.state,
    required this.homeRatings,
    required this.awayRatings,
    required this.stats,
    required this.commentary,
    required this.rewardCoins,
  });

  final MatchState state;
  final List<PlayerMatchRating> homeRatings;
  final List<PlayerMatchRating> awayRatings;
  final MatchStatsReport stats;
  final List<CommentaryLine> commentary;
  final int rewardCoins;

  PlayerMatchRating? get manOfTheMatch {
    final all = [...homeRatings, ...awayRatings].where((r) => r.played);
    if (all.isEmpty) return null;
    return all.reduce((a, b) => a.rating >= b.rating ? a : b);
  }
}

/// Live session over one match (GDD 26.1 MatchState + command queue).
class MatchSession {
  MatchSession._(this.engine, this._store, this._club, this._opponentName,
      this._opponentTeamId);

  final MatchEngine engine;
  final CollectionStore _store;
  final db.Club? _club;
  final String _opponentName;

  /// Engine team id of the away side (-1 for synthetic friendly opponents,
  /// the persisted club id for season fixtures).
  final int _opponentTeamId;

  /// Creates a session from the user's current squad (FR-025: player
  /// attributes and stamina feed the engine, GDD 12.2) against a synthetic
  /// friendly opponent.
  static Future<MatchSession> create({
    required CollectionStore store,
    required int seed,
    required String opponentName,
    required int opponentAverageOverall,
    MatchEngineConfig config = defaultMatchEngineConfig,
  }) async {
    final inputs = await _userTeamInputs(store);
    // Friendly opponent (GDD 12.6): mirrored squad at the requested strength.
    final opponent = _generateOpponent(
      teamId: -1,
      name: opponentName,
      averageOverall: opponentAverageOverall,
      formationCode: '4-3-3',
    );
    final engine = MatchEngine(
      seed: seed,
      config: config,
      home: inputs.$1,
      away: MatchTeamInput(
        teamId: -1,
        teamName: opponentName,
        formationCode: '4-3-3',
        style: PlayingStyle.balanced,
        mentality: Mentality.balanced,
        starters: opponent,
        bench: const [],
        aiControlled: true,
      ),
    );
    return MatchSession._(engine, store, inputs.$2, opponentName, -1);
  }

  /// Creates a session against a persisted AI club (season fixtures): the
  /// opponent's squad, formation and tactics come from the database, and
  /// statistics/ratings carry the real club ids.
  static Future<MatchSession> createAgainstClub({
    required CollectionStore store,
    required int seed,
    required db.Club opponentClub,
    required List<MatchPlayer> opponentStarters,
    required List<MatchPlayer> opponentBench,
    bool userAtHome = true,
    MatchEngineConfig config = defaultMatchEngineConfig,
  }) async {
    final inputs = await _userTeamInputs(store);
    final style = PlayingStyle.values.firstWhere(
        (s) => s.name == opponentClub.playingStyle,
        orElse: () => PlayingStyle.balanced);
    final mentality = Mentality.values.firstWhere(
        (m) => m.name == opponentClub.mentality,
        orElse: () => Mentality.balanced);
    final opponentTeam = MatchTeamInput(
      teamId: opponentClub.id,
      teamName: opponentClub.name,
      formationCode: opponentClub.formationCode,
      style: style,
      mentality: mentality,
      starters: opponentStarters,
      bench: opponentBench,
      aiControlled: true,
    );
    final engine = MatchEngine(
      seed: seed,
      config: config,
      home: userAtHome ? inputs.$1 : opponentTeam,
      away: userAtHome ? opponentTeam : inputs.$1,
    );
    return MatchSession._(
        engine, store, inputs.$2, opponentClub.name, opponentClub.id);
  }

  /// The user's engine input + club row, shared by both factories.
  static Future<(MatchTeamInput, db.Club)> _userTeamInputs(
      CollectionStore store) async {
    final club = await store.getClub();
    if (club == null) {
      throw const CollectionException('No club');
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
    final starters = <MatchPlayer>[
      for (var slot = 0; slot < Formation.startingXiSize; slot++)
        _toMatchPlayer(squad[slot]!),
    ];
    final bench = <MatchPlayer>[
      for (var slot = Formation.startingXiSize;
          slot < Formation.squadSize && squad.containsKey(slot);
          slot++)
        _toMatchPlayer(squad[slot]!),
    ];
    return (
      MatchTeamInput(
        teamId: club.id,
        teamName: club.name,
        formationCode: club.formationCode,
        style: style,
        mentality: mentality,
        starters: starters,
        bench: bench,
      ),
      club
    );
  }

  static MatchPlayer _toMatchPlayer(PlayerCard card) => MatchPlayer(
        playerId: card.ownedId,
        name: card.base.name,
        position: card.position,
        attack: card.attribute(PlayerAttribute.attack),
        support: card.attribute(PlayerAttribute.support),
        defence: card.attribute(PlayerAttribute.defence),
        goalkeeping: card.attribute(PlayerAttribute.goalkeeping),
        stamina: card.staminaPercent.toDouble(),
      );

  /// Deterministic synthetic opponent (no persistent AI clubs yet — those
  /// arrive with the division iteration; friendly opponents are generated
  /// from the seed + requested strength).
  static List<MatchPlayer> _generateOpponent({
    required int teamId,
    required String name,
    required int averageOverall,
    required String formationCode,
  }) {
    final formation = formationByCode(formationCode);
    return [
      for (var slot = 0; slot < formation.slots.length; slot++)
        MatchPlayer(
          playerId: -1000 - slot,
          name: '$name ${formation.slots[slot].position.code}',
          position: formation.slots[slot].position,
          attack: averageOverall,
          support: averageOverall,
          defence: averageOverall,
          goalkeeping: averageOverall,
        ),
    ];
  }

  /// User squad names for commentary.
  Map<int, String> get userPlayerNames => {
        for (final p in engine.playersOf(MatchSide.home)) p.playerId: p.name,
      };

  /// Queues a live tactical change (GDD 10.4/16).
  void queueCommand(MatchCommand command) => engine.queueCommand(command);

  /// Advances one minute of live play (FR-029: commands applied at their
  /// minute affect future events only).
  List<MatchEvent> advanceMinute() => engine.advanceMinute();

  bool get isFinished => engine.isFinished;

  /// Runs the remaining minutes without live input (quick-sim path).
  List<MatchEvent> simulateToEnd() => engine.simulateToEnd();

  /// Full-time processing: builds the report, persists stamina (GDD 11),
  /// credits match rewards with a ledger row (GDD 17.6) and applies the
  /// optional post-match pep talk (GDD 11.6) in one transaction.
  Future<MatchReportResult> finish({
    PepTalk? pepTalk,
    int restDays = 3,
  }) async {
    if (!engine.isFinished) {
      engine.simulateToEnd();
    }
    final state = engine.state;
    final events = engine.events;

    final stats = computeStats(
      events,
      homeTeamId: _club!.id,
      awayTeamId: _opponentTeamId,
    );
    final homeRatings = computePlayerRatings(
      events: events,
      players: engine.playersOf(MatchSide.home),
      teamId: _club.id,
      teamGoals: state.scoreHome,
      teamGoalsConceded: state.scoreAway,
    );
    final awayRatings = computePlayerRatings(
      events: events,
      players: engine.playersOf(MatchSide.away),
      teamId: _opponentTeamId,
      teamGoals: state.scoreAway,
      teamGoalsConceded: state.scoreHome,
    );
    final commentary = generateCommentary(
      events,
      playerNames: {
        for (final p in [
          ...engine.playersOf(MatchSide.home),
          ...engine.playersOf(MatchSide.away),
        ])
          p.playerId: p.name,
      },
      homeTeamName: _club.name,
      awayTeamName: _opponentName,
    );

    // Match rewards (GDD 17.6): base + per-goal, win bonus.
    final economy = const EconomyEngine();
    var reward = economy.config.baseMatchReward +
        state.scoreHome * economy.config.matchRewardPerGoal;
    if (state.scoreHome > state.scoreAway) reward = (reward * 1.5).round();

    await _store.applyMatchResult(
      clubId: _club.id,
      rewardCoins: reward,
      players: [
        for (final p in engine.playersOf(MatchSide.home))
          (ownedId: p.playerId, stamina: p.stamina, minutesPlayed: p.minutesPlayed),
      ],
      pepTalk: pepTalk,
      restDays: restDays,
    );

    return MatchReportResult(
      state: state,
      homeRatings: homeRatings,
      awayRatings: awayRatings,
      stats: stats,
      commentary: commentary,
      rewardCoins: reward,
    );
  }
}
