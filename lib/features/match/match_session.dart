/// FCM Rivals — match session orchestration (GDD 12.5, FR-024..FR-034).
///
/// Bridges the pure Match Engine with the collection store: builds engine
/// inputs from the persisted squad, applies live commands, and on full time
/// persists stamina, credits match rewards and exposes the full report
/// (commentary, ratings — all derived from the same events; the momentum
/// timeline for the bar is derived live in the match screen).
library;

import '../../core/database/app_database.dart' as db;
import '../../core/domain/crest.dart' show CrestSpec;
import '../collection/collection_store.dart';
import '../economy/economy_engine.dart';
import '../../core/domain/players.dart';
import '../facilities/facilities.dart' show Facility;
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import 'match_engine.dart';
import 'match_report.dart';
import 'pre_match_tactics_selection.dart';
import 'tactics.dart';

/// Complete post-match output for the report screen and persistence.
class MatchReportResult {
  const MatchReportResult({
    required this.state,
    required this.homeRatings,
    required this.awayRatings,
    required this.commentary,
    required this.rewardCoins,
  });

  final MatchState state;
  final List<PlayerMatchRating> homeRatings;
  final List<PlayerMatchRating> awayRatings;
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
  MatchSession._(
    this.engine,
    this._store,
    this._club,
    this._opponentName,
    this._opponentTeamId,
    this._homeName,
    this._awayName, {
    this.homeCrest,
    this.awayCrest,
  });

  final MatchEngine engine;
  final CollectionStore _store;
  final db.Club? _club;
  final String _opponentName;

  /// Engine team id of the away side (-1 for synthetic friendly opponents,
  /// the persisted club id for season fixtures).
  final int _opponentTeamId;

  /// Display names in engine home/away order, for the scoreboard and the
  /// live commentary (the user is NOT always the home side).
  final String _homeName;
  final String _awayName;

  /// Crests in engine home/away order for the live header; null (a
  /// synthetic friendly opponent) falls back to initials.
  final CrestSpec? homeCrest;
  final CrestSpec? awayCrest;

  /// Creates a session from the user's current squad (FR-025: player
  /// attributes and stamina feed the engine, GDD 12.2) against a synthetic
  /// friendly opponent. [preMatchTalk] applies its multipliers from
  /// kick-off (GDD 15.1) — it never requires an ad (FR-043). [tactics]
  /// optionally overrides the club's saved setup for this match only.
  static Future<MatchSession> create({
    required CollectionStore store,
    required int seed,
    required String opponentName,
    required int opponentAverageOverall,
    MatchPepTalk? preMatchTalk,
    PreMatchTacticSelection? tactics,
    MatchEngineConfig config = defaultMatchEngineConfig,
  }) async {
    final inputs = await _userTeamInputs(store, tactics: tactics);
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
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: opponent,
        bench: const [],
        aiControlled: true,
      ),
    );
    if (preMatchTalk != null) {
      engine.queueCommand(
        PepTalkCommand(atMinute: 0, side: MatchSide.home, talk: preMatchTalk),
      );
    }
    return MatchSession._(
      engine,
      store,
      inputs.$2,
      opponentName,
      -1,
      inputs.$2.name,
      opponentName,
      // The friendly opponent has no persisted spec — a badge derived
      // from its name, so every club on screen reads as a crest.
      homeCrest: CollectionStore.crestOf(inputs.$2),
      awayCrest: CrestSpec.derived(opponentName),
    );
  }

  /// Creates a session against a persisted AI club (season fixtures): the
  /// opponent's squad, formation and tactics come from the database, and
  /// statistics/ratings carry the real club ids. [preMatchTalk] applies
  /// from kick-off (GDD 15.1). [tactics] carries the MATCH-ONLY setup
  /// chosen on the pre-match screen (GDD 10.4): the engine's formation,
  /// custom tactics and mentality come from it instead of the club's
  /// saved defaults, and when the formation differs the starting XI is
  /// re-picked in memory — nothing is persisted.
  static Future<MatchSession> createAgainstClub({
    required CollectionStore store,
    required int seed,
    required db.Club opponentClub,
    required List<MatchPlayer> opponentStarters,
    required List<MatchPlayer> opponentBench,
    bool userAtHome = true,
    MatchPepTalk? preMatchTalk,
    PreMatchTacticSelection? tactics,
    MatchEngineConfig config = defaultMatchEngineConfig,
  }) async {
    final inputs = await _userTeamInputs(store, tactics: tactics);
    // The opponent club's persisted tactics payload: legacy values (the
    // pre-v11 style names) load as the default setup.
    final opponentTactics = tacticsFromDbPayload(opponentClub.tactics);
    final mentality = Mentality.values.firstWhere(
      (m) => m.name == opponentClub.mentality,
      orElse: () => Mentality.balanced,
    );
    final opponentTeam = MatchTeamInput(
      teamId: opponentClub.id,
      teamName: opponentClub.name,
      formationCode: opponentClub.formationCode,
      tactics: opponentTactics,
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
    if (preMatchTalk != null) {
      engine.queueCommand(
        PepTalkCommand(
          atMinute: 0,
          side: userAtHome ? MatchSide.home : MatchSide.away,
          talk: preMatchTalk,
        ),
      );
    }
    return MatchSession._(
      engine,
      store,
      inputs.$2,
      opponentClub.name,
      opponentClub.id,
      userAtHome ? inputs.$2.name : opponentClub.name,
      userAtHome ? opponentClub.name : inputs.$2.name,
      homeCrest: CollectionStore.crestOf(userAtHome ? inputs.$2 : opponentClub),
      awayCrest: CollectionStore.crestOf(userAtHome ? opponentClub : inputs.$2),
    );
  }

  /// The user's engine input + club row, shared by both factories.
  /// [tactics] overrides the club's saved setup for this match only: its
  /// custom tactics and mentality replace the club's, and a different
  /// formation re-picks the whole squad in memory (same Auto Pick rules
  /// as the Team tab) so the exact shape the user previewed kicks off.
  ///
  /// Campus training facilities (GDD 3.5) add their small permanent
  /// attribute fractions on top of every player's card values here —
  /// campus fractions simply add to the card values (fatigue decoupling,
  /// owner decision 2026-11-07: attributes are never stamina-scaled).
  static Future<(MatchTeamInput, db.Club)> _userTeamInputs(
    CollectionStore store, {
    PreMatchTacticSelection? tactics,
  }) async {
    final club = await store.getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final campus = await store.getCampus();
    final fractions = campus.attributeFractions;
    // The Medical Centre's risk reduction reaches the engine through the
    // team input (T-0055, GDD 3.5/11.7).
    final medicalCentreLevel = campus.levelOf(Facility.medical);
    final formationCode = tactics?.formationCode ?? club.formationCode;
    final teamTactics = tactics?.tactics ?? tacticsFromDbPayload(club.tactics);
    final mentality =
        tactics?.mentality ??
        Mentality.values.firstWhere(
          (m) => m.name == club.mentality,
          orElse: () => Mentality.balanced,
        );
    final formation = formationByCode(formationCode);
    final squad = await store.getSquad();
    Map<int, PlayerCard> assignment = squad;
    if (formation.code != club.formationCode || tactics != null) {
      // Match-only shape: re-pick the squad for the chosen formation so
      // the engine's XI matches the pitch the user just set up.
      final collection = await store.getCollection();
      assignment = const SquadEngine()
          .autoPick(collection, formation)
          .map(
            (slot, ownedId) => MapEntry(
              slot,
              collection.firstWhere((c) => c.ownedId == ownedId),
            ),
          );
    }
    if (assignment.length < Formation.startingXiSize) {
      throw const CollectionException(
        'A full starting XI is required to play a match',
      );
    }
    // Save-compat guard (T-0055): an injury sustained mid-season must
    // never brick an existing saved setup. Injured BENCH entries simply
    // sit out (the bench plays short). Each injured STARTER is replaced
    // by the best available candidate — squad members not on the pitch
    // (a bench promotion) plus any unassigned owned players — reading
    // compatibility × position rating like Auto Pick; the XI is what
    // must be legal.
    final injuredBenchIds = {
      for (final e in assignment.entries)
        if (e.key >= Formation.startingXiSize && e.value.isInjured)
          e.value.ownedId,
    };
    if (injuredBenchIds.isNotEmpty) {
      assignment.removeWhere((slot, p) => injuredBenchIds.contains(p.ownedId));
    }
    final injuredStarters = [
      for (final e in assignment.entries)
        if (e.key < Formation.startingXiSize && e.value.isInjured) e.key,
    ];
    if (injuredStarters.isNotEmpty) {
      final collection = await store.getCollection();
      final onPitch = {
        for (final e in assignment.entries)
          if (e.key < Formation.startingXiSize && !e.value.isInjured)
            e.value.ownedId,
      };
      final pool = [
        // Squad members sitting out this match (bench + reserves).
        for (final e in assignment.entries)
          if (e.key >= Formation.startingXiSize &&
              !e.value.isInjured &&
              !onPitch.contains(e.value.ownedId))
            e.value,
        // Unassigned owned players.
        for (final c in collection)
          if (!assignment.values.any((p) => p.ownedId == c.ownedId) &&
              (c.injuryMatchesRemaining == 0))
            c,
      ];
      for (final slot in injuredStarters) {
        final replacement = _bestForSlot(pool, formation, slot, onPitch);
        assignment[slot] = replacement;
        // He vacates his old bench/reserve slot: one squad slot per
        // player, the bench plays short.
        final oldEntries = assignment.entries
            .where(
              (e) =>
                  e.value.ownedId == replacement.ownedId && e.key != slot,
            )
            .toList();
        for (final e in oldEntries) {
          assignment.remove(e.key);
        }
        onPitch.add(replacement.ownedId);
      }
    }
    final starters = <MatchPlayer>[
      for (var slot = 0; slot < Formation.startingXiSize; slot++)
        _toMatchPlayer(assignment[slot]!, fractions),
    ];
    final bench = <MatchPlayer>[
      for (
        var slot = Formation.startingXiSize;
        slot < Formation.squadSize && assignment.containsKey(slot);
        slot++
      )
        _toMatchPlayer(assignment[slot]!, fractions),
    ];
    return (
      MatchTeamInput(
        teamId: club.id,
        teamName: club.name,
        formationCode: formationCode,
        tactics: teamTactics,
        mentality: mentality,
        starters: starters,
        bench: bench,
        medicalCentreLevel: medicalCentreLevel,
      ),
      club,
    );
  }

  /// Card → engine player, with the campus training-facility fractions
  /// (GDD 3.5) added to each attribute. The boost is small by design —
  /// it nudges totals, it never replaces squad quality.
  static MatchPlayer _toMatchPlayer(
    PlayerCard card,
    ({double attack, double support, double defence, double goalkeeping})
    fractions,
  ) => MatchPlayer(
    playerId: card.ownedId,
    name: card.base.name,
    position: card.position,
    attack: (card.attribute(PlayerAttribute.attack) * (1 + fractions.attack))
        .round(),
    support: (card.attribute(PlayerAttribute.support) * (1 + fractions.support))
        .round(),
    defence: (card.attribute(PlayerAttribute.defence) * (1 + fractions.defence))
        .round(),
    goalkeeping:
        (card.attribute(PlayerAttribute.goalkeeping) *
                (1 + fractions.goalkeeping))
            .round(),
    nationality: card.base.nationality,
    clubId: card.base.clubId,
    clubName: card.base.clubName,
    stamina: card.staminaPercent.toDouble(),
  );

  /// The next best available player for [slotIndex] when a saved squad
  /// references an injured one (T-0055 save-compat guard): best
  /// compatibility × position rating from the replacement pool — the
  /// same reading Auto Pick uses. With no compatible body left the best
  /// remaining player plays out of position; only an empty pool throws.
  static PlayerCard _bestForSlot(
    List<PlayerCard> pool,
    Formation formation,
    int slotIndex,
    Set<int> onPitch,
  ) {
    final slotPosition = formation.slots[slotIndex].position;
    final engine = const SquadEngine();
    PlayerCard? best;
    var bestScore = -1.0;
    for (final card in pool) {
      if (onPitch.contains(card.ownedId)) continue;
      final score =
          engine.compatibilityOf(card.position, slotPosition) *
          card.positionRating();
      if (score > bestScore) {
        bestScore = score;
        best = card;
      }
    }
    if (best == null) {
      throw const CollectionException(
        'No available player to replace an injured starter',
      );
    }
    pool.remove(best);
    return best;
  }

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

  /// Display name of the engine's home side (scoreboard, commentary).
  String get homeTeamName => _homeName;

  /// Display name of the engine's away side (scoreboard, commentary).
  String get awayTeamName => _awayName;

  /// The engine player with [playerId] on either side, or null.
  MatchPlayer? matchPlayerById(int playerId) {
    for (final side in MatchSide.values) {
      for (final p in engine.playersOf(side)) {
        if (p.playerId == playerId) return p;
      }
    }
    return null;
  }

  /// The dataset record behind the ENGINE player [playerId] (an owned-card
  /// id for the user's players, a synthetic id for league opponents) —
  /// portrait, rating and real club logo for the GOAL moment's scorer
  /// card. Null for synthetic friendly-opponent players and unknown ids.
  Future<BasePlayer?> basePlayerOf(int playerId) =>
      _store.getBasePlayerForMatchPlayer(playerId);

  /// Squad names of the user's club for commentary.
  Map<int, String> get userPlayerNames => {
    for (final p in engine.playersOf(userSide)) p.playerId: p.name,
  };

  /// Names of every player on BOTH sides, for live commentary on matches
  /// against named AI squads (league fixtures) where opponent events must
  /// name real players, not 'an opponent'.
  Map<int, String> get allPlayerNames => {
    for (final p in [
      ...engine.playersOf(MatchSide.home),
      ...engine.playersOf(MatchSide.away),
    ])
      p.playerId: p.name,
  };

  /// The engine team id of the home side — the user's club id when the
  /// user is home, the opponent's id otherwise. The live momentum bar
  /// attributes events by these ids ([computeMomentumSeries]); null for
  /// friendly previews that run without a persisted club, where the bar
  /// simply stays on its baseline.
  int? get homeTeamId =>
      userSide == MatchSide.home ? _club?.id : _opponentTeamId;

  /// The engine team id of the away side — mirror of [homeTeamId].
  int? get awayTeamId =>
      userSide == MatchSide.home ? _opponentTeamId : _club?.id;

  /// Queues a live tactical change (GDD 10.4/16).
  void queueCommand(MatchCommand command) => engine.queueCommand(command);

  /// Queues the half-time pep talk (GDD 15.2): applied at the first
  /// minute of the second half, affecting future events only.
  void queueHalfTimeTalk(MatchPepTalk talk) {
    engine.queueCommand(
      PepTalkCommand(atMinute: 46, side: userSide, talk: talk),
    );
  }

  /// The engine side carrying the user's club.
  MatchSide get userSide =>
      engine.playersOf(MatchSide.home).any((p) => p.playerId >= 0)
      ? MatchSide.home
      : MatchSide.away;

  /// Advances one minute of live play (FR-029: commands applied at their
  /// minute affect future events only).
  List<MatchEvent> advanceMinute() => engine.advanceMinute();

  bool get isFinished => engine.isFinished;

  /// Runs the remaining minutes without live input (quick-sim path).
  List<MatchEvent> simulateToEnd() => engine.simulateToEnd();

  /// Full-time processing: builds the report, persists stamina (GDD 11)
  /// and credits match rewards with a ledger row (GDD 17.6) in one
  /// transaction. T-0100: the post-match pep-talk / boosted-recovery
  /// choice is gone — every match settles with the default recovery
  /// (natural + campus bonus, [restDays] rest).
  Future<MatchReportResult> finish({int restDays = 3}) async {
    if (!engine.isFinished) {
      engine.simulateToEnd();
    }
    final club = _club!;
    final state = engine.state;
    final events = engine.events;

    // Side orientation: the user is NOT always home (away season
    // fixtures) — ratings, rewards and stamina persistence must
    // follow the user's actual side.
    final userAtHome = userSide == MatchSide.home;
    final userGoals = userAtHome ? state.scoreHome : state.scoreAway;
    final opponentGoals = userAtHome ? state.scoreAway : state.scoreHome;
    final homeTeamId = userAtHome ? club.id : _opponentTeamId;
    final awayTeamId = userAtHome ? _opponentTeamId : club.id;

    final homeRatings = computePlayerRatings(
      events: events,
      players: engine.playersOf(MatchSide.home),
      teamId: homeTeamId,
      teamGoals: state.scoreHome,
      teamGoalsConceded: state.scoreAway,
    );
    final awayRatings = computePlayerRatings(
      events: events,
      players: engine.playersOf(MatchSide.away),
      teamId: awayTeamId,
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
      homeTeamName: userAtHome ? club.name : _opponentName,
      awayTeamName: userAtHome ? _opponentName : club.name,
      keyEventsOnly: true,
    );

    // Match rewards (GDD 17.6): base + per-goal for the USER's goals,
    // win bonus for the user's result.
    final economy = const EconomyEngine();
    var reward =
        economy.config.baseMatchReward +
        userGoals * economy.config.matchRewardPerGoal;
    if (userGoals > opponentGoals) reward = (reward * 1.5).round();

    // The match's rolled injuries ride the same atomic commit (T-0055):
    // the event's primaryPlayerId IS the user player's ownedId — the
    // session builds the user's MatchPlayers from owned ids.
    final injuries = [
      for (final e in engine.events)
        if (e.type == MatchEventType.injury && e.side == userSide)
          (
            ownedId: e.primaryPlayerId!,
            kind: e.metadata['kind'] as String,
            matchesOut: e.metadata['matchesOut'] as int,
          ),
    ];

    await _store.applyMatchResult(
      clubId: club.id,
      rewardCoins: reward,
      players: [
        for (final p in engine.playersOf(userSide))
          (
            ownedId: p.playerId,
            stamina: p.stamina,
            minutesPlayed: p.minutesPlayed,
          ),
      ],
      injuries: injuries,
      restDays: restDays,
    );

    return MatchReportResult(
      state: state,
      homeRatings: homeRatings,
      awayRatings: awayRatings,
      commentary: commentary,
      rewardCoins: reward,
    );
  }
}
