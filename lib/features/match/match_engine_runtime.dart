part of 'match_engine.dart';

/// Engine runtime support (extracted from the engine class file,
/// app-structure review task `2026-11-05_app-structure_split-match-engine`):
/// team totals, the squad-quality forecast measure, the public match
/// snapshot, the seeded PRNG wrapper, per-team match runtime and role
/// weights. Part of the engine library so the engine and its other
/// part files can use the private runtime types.

/// Effective team totals (GDD 12.2): individual attributes at FULL VALUE
/// (fatigue decoupling, owner decision 2026-11-07 — stamina never scales
/// performance) aggregated with slot role weights, then modified by
/// mentality, custom tactics, live actions, pep talk and home advantage.
class TeamTotals {
  const TeamTotals({
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
  });

  final double attack;
  final double support;
  final double defence;
  final double goalkeeping;
}

/// Neutral squad-quality totals for the pre-match forecast (GDD 13): the
/// role-weighted mean of EVERY player's raw attributes keyed by natural
/// position — the whole squad list (starting XI + bench + reserves) counts
/// alike, with no formation slots, no stamina scaling, no tactics, no
/// mentality and no home edge. A like-for-like measure of what each squad
/// is worth on paper.
TeamTotals squadQualityTotals(List<MatchPlayer> squad) {
  double attackSum = 0, supportSum = 0, defenceSum = 0;
  var attackW = 0.0, supportW = 0.0, defenceW = 0.0;
  double gkSum = 0;
  var gkCount = 0;
  for (final p in squad) {
    final pos = p.position;
    final aw = _MatchEngineRole.attack[pos]!;
    final sw = _MatchEngineRole.support[pos]!;
    final dw = _MatchEngineRole.defence[pos]!;
    attackSum += p.attack * aw;
    attackW += aw;
    supportSum += p.support * sw;
    supportW += sw;
    defenceSum += p.defence * dw;
    defenceW += dw;
    if (pos == Position.gk) {
      gkSum += p.goalkeeping;
      gkCount++;
    }
  }
  return TeamTotals(
    attack: attackW > 0 ? attackSum / attackW : 0,
    support: supportW > 0 ? supportSum / supportW : 0,
    defence: defenceW > 0 ? defenceSum / defenceW : 0,
    // No goalkeeper in the list at all: the engine's fallback for a
    // missing keeper applies (GDD 12.3 step 8).
    goalkeeping: gkCount > 0 ? gkSum / gkCount : 40,
  );
}

/// Public match snapshot for UI and persistence (GDD 26.1).
class MatchState {
  const MatchState({
    required this.minute,
    required this.scoreHome,
    required this.scoreAway,
    required this.isFinished,
    required this.isHalfTime,
    required this.substitutionsHome,
    required this.substitutionsAway,
  });

  final int minute;
  final int scoreHome;
  final int scoreAway;
  final bool isFinished;
  final bool isHalfTime;
  final int substitutionsHome;
  final int substitutionsAway;
}

/// Seeded PRNG wrapper (GDD 26.2): one fixed initial seed, an advancing
/// internal state and a draw counter. The seed is never regenerated.
class MatchRandom {
  MatchRandom(this.initialSeed) : _random = math.Random(initialSeed);

  final int initialSeed;
  final math.Random _random;
  int drawCount = 0;

  double nextDouble() {
    drawCount++;
    return _random.nextDouble();
  }

  int nextInt(int max) {
    drawCount++;
    return _random.nextInt(max);
  }

  bool chance(num p) => nextDouble() < p;
}

/// Per-team mutable match runtime.
class _TeamRuntime {
  _TeamRuntime.from(MatchTeamInput input)
    : teamId = input.teamId,
      teamName = input.teamName,
      formation = formationByCode(input.formationCode),
      tactics = input.tactics,
      mentality = input.mentality,
      aiControlled = input.aiControlled,
      medicalCentreLevel = input.medicalCentreLevel,
      onPitch = [for (final p in input.starters) p.clone()],
      bench = [for (final p in input.bench) p.clone()],
      offPitch = [];

  final int teamId;
  final String teamName;
  Formation formation;
  TeamTactics tactics;
  Mentality mentality;

  /// The mentality's contribution, refined by the tactics' fine
  /// mentality slider when it belongs to the current step.
  MentalityEffect get mentalityFx =>
      mentalityEffect(mentality, tactics.mentalityScale);

  final bool aiControlled;

  /// On-pitch players by formation slot; null = empty slot (sent off).
  final List<MatchPlayer?> onPitch;
  final List<MatchPlayer> bench;
  final List<MatchPlayer> offPitch;

  /// This club's Medical Centre level (GDD 11.7): reduces every
  /// player's injury risk multiplicatively (T-0054).
  final int medicalCentreLevel;

  /// Injuries sustained this match (per-team cap guard, GDD 11.7).
  int injuriesThisMatch = 0;

  int substitutionsUsed = 0;
  LiveMatchAction? activeAction;
  int actionExpiresMinute = 0;
  int aiChanges = 0;
  int lastAiChangeMinute = 0;

  /// AI substitution bookkeeping: last minute an AI sub was made (subs
  /// are spaced ≥ 5 minutes apart) and whether the chasing-game
  /// attacker swap has already been used this match.
  int lastAiSubMinute = 0;
  bool aiChaseSubDone = false;

  /// Active pep talk (GDD 15): persistent multipliers, at most one at a
  /// time — a later talk replaces the earlier one.
  ActionModifiers pepTalkModifiers = const ActionModifiers(
    attack: 1,
    defence: 1,
    stamina: 1,
  );

  /// Team totals (GDD 12.2): raw attributes per player (no stamina term —
  /// a 40% starter performs exactly like a fresh one), then 1. mentality,
  /// 2. custom tactics, 3. live actions, 4. pep talk, 5. home advantage,
  /// 6. nationality chemistry — in this order.
  TeamTotals computeTotals({
    required bool isHome,
    required double homeAdvantage,
    required ActionModifiers actionModifiers,
  }) {
    double attackSum = 0, supportSum = 0, defenceSum = 0;
    var attackW = 0.0, supportW = 0.0, defenceW = 0.0;
    double gkEff = 0;
    for (var slot = 0; slot < onPitch.length; slot++) {
      final player = onPitch[slot];
      if (player == null) continue;
      final slotPosition = slot < formation.slots.length
          ? formation.slots[slot].position
          : player.position;
      // Out-of-position penalty via squad compatibility (GDD 6.3).
      final compat = const SquadEngine().compatibilityOf(
        player.position,
        slotPosition,
      );
      final aw = _MatchEngineRole.attack[slotPosition]! * compat;
      final sw = _MatchEngineRole.support[slotPosition]! * compat;
      final dw = _MatchEngineRole.defence[slotPosition]! * compat;
      attackSum += player.attack * aw;
      attackW += aw;
      supportSum += player.support * sw;
      supportW += sw;
      defenceSum += player.defence * dw;
      defenceW += dw;
      if (slotPosition == Position.gk) gkEff = player.goalkeeping.toDouble();
    }
    // Perf pass 2026-11-12 (M1): hoisted — each `tactics.modifiers` read
    // allocates two fresh TacticModifiers and each `mentalityFx` read
    // re-derives from the slider; computeTotals runs 2x/minute per team.
    final mFx = mentalityFx;
    final tFx = tactics.modifiers;
    final attack =
        (attackW > 0 ? attackSum / attackW : 0) *
        mFx.attack *
        tFx.attack *
        actionModifiers.attack *
        pepTalkModifiers.attack;
    final support = supportW > 0 ? supportSum / supportW : 0;
    final defence =
        (defenceW > 0 ? defenceSum / defenceW : 0) *
        mFx.defence *
        tFx.defence *
        actionModifiers.defence *
        pepTalkModifiers.defence;
    final goalkeeping = gkEff * mFx.defence * tFx.defence;
    // Chemistry (owner spec 2026-11-09, club half added 2026-11-11):
    // every shared nationality group AND every shared club group of
    // n ≥ 2 on-pitch players adds (n − 1) points, and the combined sum
    // (capped at 10, T-0068 gate) multiplies all four totals. Computed
    // from the live onPitch list each turn, so substitutions and red
    // cards re-evaluate it automatically; nationality-less and
    // club-less fixtures stay at exactly 1.0.
    final chemistryPercent = totalChemistryPercentOf(
      nationalities: [for (final player in onPitch) player?.nationality],
      clubs: [
        for (final player in onPitch)
          player == null
              ? ''
              : clubChemistryKeyOf(player.clubId, player.clubName),
      ],
      icons: [for (final player in onPitch) player?.isIcon ?? false],
    );
    final chemistryFactor = 1 + chemistryPercent / 100;
    final homeFactor = isHome ? homeAdvantage : 1.0;
    return TeamTotals(
      attack: attack * homeFactor * chemistryFactor,
      support: support * homeFactor * chemistryFactor,
      defence: defence * homeFactor * chemistryFactor,
      goalkeeping: goalkeeping * homeFactor * chemistryFactor,
    );
  }

  /// Reassigns on-pitch players to a new formation's slots (GDD 10.1):
  /// greedy best-fit by compatibility-weighted slot rating.
  void changeFormation(Formation newFormation, MatchRandom random) {
    formation = newFormation;
    final players = onPitch.whereType<MatchPlayer>().toList();
    final assigned = <MatchPlayer, int>{};
    // Rarest slot first: GK, then fewest natural fits.
    final slotOrder = List.generate(newFormation.slots.length, (i) => i)
      ..sort((a, b) {
        final pa = _naturalFits(newFormation.slots[a].position, players);
        final pb = _naturalFits(newFormation.slots[b].position, players);
        return pa != pb ? pa.compareTo(pb) : a.compareTo(b);
      });
    final available = {...players.map((p) => p.playerId)};
    for (final slotIndex in slotOrder) {
      final slot = newFormation.slots[slotIndex];
      int? bestId;
      var bestScore = -1.0;
      for (final id in available) {
        final p = players.firstWhere((x) => x.playerId == id);
        final compat = const SquadEngine().compatibilityOf(
          p.position,
          slot.position,
        );
        final score = compat * (p.attack + p.support + p.defence);
        if (score > bestScore) {
          bestScore = score;
          bestId = id;
        }
      }
      if (bestId != null) {
        assigned[players.firstWhere((x) => x.playerId == bestId)] = slotIndex;
        available.remove(bestId);
      }
    }
    onPitch.fillRange(0, onPitch.length, null);
    for (final e in assigned.entries) {
      onPitch[e.value] = e.key;
    }
  }

  int _naturalFits(Position slotPosition, List<MatchPlayer> players) => players
      .where(
        (p) =>
            const SquadEngine().compatibilityOf(p.position, slotPosition) > 0.5,
      )
      .length;

  /// Substitution (GDD 10.5): the substitute takes the outgoing player's
  /// slot; totals, stamina, statistics and ratings update from this point.
  void substitute(int outPlayerId, int inPlayerId, int maxSubstitutions) {
    if (substitutionsUsed >= maxSubstitutions) {
      throw StateError('Maximum substitutions reached');
    }
    final index = onPitch.indexWhere((p) => p?.playerId == outPlayerId);
    if (index == -1) {
      throw StateError('Player $outPlayerId is not on the pitch');
    }
    final benchIndex = bench.indexWhere((p) => p.playerId == inPlayerId);
    if (benchIndex == -1) {
      throw StateError('Player $inPlayerId is not on the bench');
    }
    final incoming = bench.removeAt(benchIndex);
    final outgoing = onPitch[index]!;
    onPitch[index] = incoming;
    offPitch.add(outgoing);
    substitutionsUsed++;
  }
}


/// Role weights referenced by the runtime (kept separate from the engine
/// class body for readability).
class _MatchEngineRole {
  static const Map<Position, double> attack = {
    Position.st: 1.0,
    Position.lw: 0.85,
    Position.rw: 0.85,
    Position.cam: 0.85,
    Position.lm: 0.6,
    Position.rm: 0.6,
    Position.cm: 0.6,
    Position.cdm: 0.4,
    Position.lb: 0.35,
    Position.rb: 0.35,
    Position.cb: 0.25,
    Position.gk: 0.05,
  };
  static const Map<Position, double> support = {
    Position.cam: 1.0,
    Position.cm: 1.0,
    Position.lw: 0.85,
    Position.rw: 0.85,
    Position.lm: 0.85,
    Position.rm: 0.85,
    Position.cdm: 0.8,
    Position.st: 0.7,
    Position.lb: 0.7,
    Position.rb: 0.7,
    Position.cb: 0.6,
    Position.gk: 0.1,
  };
  static const Map<Position, double> defence = {
    Position.cb: 1.0,
    Position.lb: 0.9,
    Position.rb: 0.9,
    Position.cdm: 0.9,
    Position.cm: 0.7,
    Position.lm: 0.6,
    Position.rm: 0.6,
    Position.cam: 0.5,
    Position.lw: 0.4,
    Position.rw: 0.4,
    Position.st: 0.4,
    Position.gk: 0.05,
  };
}
