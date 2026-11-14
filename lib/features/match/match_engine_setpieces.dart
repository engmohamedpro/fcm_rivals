part of 'match_engine.dart';

/// AI adaptation, AI substitutions and the attack/defence weighting
/// tables privates of [MatchEngine] (extracted, app-structure review
/// task `2026-11-05_app-structure_split-match-engine`). Pure
/// relocation — bodies unchanged.
extension _MatchEngineAi on MatchEngine {
  List<MatchEvent> _issueCard(
    int minute,
    MatchSide side,
    _TeamRuntime team,
    MatchPlayer fouler, {
    required bool straightRed,
  }) {
    final produced = <MatchEvent>[];
    fouler.yellowCards++;
    final secondYellow = fouler.yellowCards >= 2;
    final isRed = straightRed || secondYellow;
    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.card,
        side: side,
        primaryPlayerId: fouler.playerId,
        metadata: {
          'card': isRed ? 'red' : 'yellow',
          'secondYellow': secondYellow && !straightRed,
        },
      ),
    );
    if (isRed) _sendOff(team, fouler);
    return produced;
  }

  void _sendOff(_TeamRuntime team, MatchPlayer player) {
    player.sentOff = true;
    team.onPitch[team.onPitch.indexOf(player)] = null;
    team.offPitch.add(player);
  }

  List<MatchEvent> _corner(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att, {
    required bool headerChance,
  }) {
    final produced = <MatchEvent>[];
    final taker = _pickAttacker(att)!;
    _involvedThisMinute.add(taker.playerId);
    // The defending keeper fights for the cross (GDD 14): a share of
    // corners end in a claim rather than a header — his visible
    // involvement, so keepers register in low-scoring matches too.
    // Deterministic minute rotation (~1 in 3): no extra random draw, so
    // the engine's random stream (and every calibrated distribution)
    // is unchanged.
    final defendingGk = _oppositeRuntime(attackerSide).onPitch
        .whereType<MatchPlayer>()
        .firstOrNull;
    final claimed = !headerChance && minute % 3 == 0;
    if (claimed && defendingGk != null && !defendingGk.sentOff) {
      _involvedThisMinute.add(defendingGk.playerId);
    }
    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.corner,
        side: attackerSide,
        primaryPlayerId: taker.playerId,
        metadata: claimed ? const {'gkClaim': true} : const {},
      ),
    );
    // The header draw is ALWAYS taken (even on a claim, where its result
    // is discarded) so the random stream stays byte-identical to the
    // pre-claim engine and every calibrated distribution holds.
    final headerDraw = _random.chance(config.headerFromCorner);
    if (!claimed && (headerChance || headerDraw)) {
      produced.addAll(
        _shoot(
          minute,
          attackerSide,
          att,
          _oppositeRuntime(attackerSide),
          ChanceQuality.header,
        ),
      );
    }
    return produced;
  }

  /// Chance creation → shot → outcome (GDD 12.3 steps 6-9), carrying
  /// the phase-2 defensive hooks: the offside trap's stochastic
  /// quality gamble and the line-height interactions with the
  /// OPPONENT's build-up (both runtimes are in scope here).
  List<MatchEvent> _attackChance(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att,
    _TeamRuntime def,
    TeamTotals defTotals,
  ) {
    var quality = ChanceQuality.normal;
    if (_random.chance(0.28)) quality = ChanceQuality.bigChance;
    return _shoot(
      minute,
      attackerSide,
      att,
      def,
      quality,
      defenderQualityScale: _concededChanceQualityScale(att, def),
    );
  }

  /// The defending side's conceded-chance quality scale from its
  /// offside trap and line-height interactions with the attacker's
  /// build-up (phase 2 Task 3).
  double _concededChanceQualityScale(_TeamRuntime att, _TeamRuntime def) {
    final oop = def.tactics.outOfPossession;
    var scale = 1.0;

    // Offside trap: stochastic hook — most conceded chances tighten
    // (×0.94), a beaten trap (6%) is amplified (×1.15). Net negative
    // for the opponent, with tail risk.
    if (oop.offsideTrap) {
      scale *= _random.chance(OffsideTrapToggles.beatenShare)
          ? OffsideTrapToggles.beatenQuality
          : OffsideTrapToggles.heldQuality;
    }

    // Line-height interaction matrix (both teams' instructions):
    // a high line is punished by balls in behind; a deep block
    // concedes territory to patient build-up.
    final ip = att.tactics.inPossession;
    final directOpponent =
        ip.buildUp == BuildUpStyle.longBall || ip.tempo == AttackTempo.fast;
    final patientOpponent =
        ip.buildUp == BuildUpStyle.playOut || ip.tempo == AttackTempo.slow;
    if (oop.defensiveLine == DefensiveLine.high && directOpponent) {
      scale *= 1.06; // balls in behind: better chances conceded
    } else if (oop.defensiveLine == DefensiveLine.deep && patientOpponent) {
      scale *= 0.96; // conceded territory: worse chances conceded
    }
    return scale;
  }

  List<MatchEvent> _shoot(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att,
    _TeamRuntime def,
    ChanceQuality quality, {
    MatchPlayer? shooterOverride,
    double defenderQualityScale = 1.0,
  }) {
    final produced = <MatchEvent>[];
    final shooter = shooterOverride ?? _pickShooter(att);
    if (shooter == null) return produced;
    _involvedThisMinute.add(shooter.playerId);

    MatchPlayer? assister;
    if (quality != ChanceQuality.penalty && quality != ChanceQuality.freeKick) {
      if (_random.chance(config.assistChance)) {
        assister = _pickAssister(att, exclude: shooter);
      }
    }

    // Attributes at FULL VALUE (fatigue decoupling, owner decision
    // 2026-11-07): a tired shooter shoots and a tired keeper keeps
    // exactly as well as fresh ones — stamina never scales performance
    // (GDD 11.2/12.2).
    final shooterEff = shooter.attack;
    final gk = def.onPitch.whereType<MatchPlayer>().firstOrNull;
    final gkEff = gk?.goalkeeping ?? 40;

    // Shot accuracy (GDD 12.3 step 7).
    final qualityOnTargetBonus = switch (quality) {
      ChanceQuality.bigChance => 0.36,
      ChanceQuality.header => -0.12,
      ChanceQuality.freeKick => -0.08,
      ChanceQuality.penalty => 0.44,
      ChanceQuality.normal => 0.0,
    };
    // Dimensionless shooter share (T-0116 — the conversion twin of
    // the chance layer's normalized edge): the shooter-vs-keeper
    // balance as (share − 0.5) × 2 — 0 at equality, bounded ±1, and
    // INVARIANT to symmetric percentage growth (both attributes +N%
    // leave the share unchanged), so the conversion response cannot
    // saturate as the upgrade ladder climbs. (A composed-home cap
    // here was measured DEAD and reverted: _shoot reads the raw
    // player goalkeeping — the home factor never composed into this
    // layer's keeper at all.)
    final shooterShare =
        (shooterEff / (shooterEff + gkEff) - 0.5) * 2;
    final onTargetP =
        (config.onTargetBase +
                config.onTargetScale * shooterShare +
                qualityOnTargetBonus)
            .clamp(0.10, 0.95);

    // Goalkeeper reaction (GDD 12.3 step 8) — BOUNDED conversion: the
    // shooter-minus-keeper edge moves the goal rate by at most a few
    // points per side (goalDiffScale), so a superstar against a weak
    // keeper converts ~+10..15 points, never 'scores every time'. This
    // is what keeps even huge power gaps producing real scorelines:
    // more chances for the favourite, not certain goals.
    final qualityGoalFactor = switch (quality) {
      ChanceQuality.bigChance => 1.85,
      ChanceQuality.header => 0.72,
      ChanceQuality.freeKick => 0.68,
      ChanceQuality.penalty => 1.55,
      ChanceQuality.normal => 1.0,
    };
    // In-Possession shot quality (GDD 10.2 phase 1): Work Ball into Box
    // trades chance volume for better looks, Shoot on Sight the
    // reverse — a per-side hook on the chance→goal conversion path so
    // the two are tellable apart. Penalties are set pieces, not
    // built-up play: their conversion stays anchored.
    final shotQuality = quality == ChanceQuality.penalty
        ? 1.0
        : att.tactics.modifiers.shotQuality * defenderQualityScale;
    final goalPGivenOnTarget =
        (config.goalBase +
                config.goalScale * qualityGoalFactor +
                config.goalDiffScale * shooterShare)
            .clamp(0.04, 0.88) *
        shotQuality;

    // xG (GDD 13.2): P(on target) × P(goal | on target).
    final xg = onTargetP * goalPGivenOnTarget;

    // Penalties get a dedicated draw (GDD 13.1): no block layer — a
    // 28%-blocked penalty is not football — a near-certain on-target
    // rate and a high, shooter-vs-keeper dependent conversion.
    final isPenalty = quality == ChanceQuality.penalty;
    final penaltyOnTargetP = (config.penaltyOnTarget).clamp(0.10, 0.99);
    final penaltyGoalP =
        (config.penaltyGoalBase +
                config.penaltyGoalEdgeScale * ((shooterEff - gkEff) / 100))
            .clamp(0.30, 0.95);
    final penaltyXg = penaltyOnTargetP * penaltyGoalP;

    ShotOutcome outcome;
    if (isPenalty) {
      outcome = _random.chance(penaltyOnTargetP)
          ? (_random.chance(penaltyGoalP)
                ? ShotOutcome.goal
                : ShotOutcome.saved)
          : ShotOutcome.offTarget;
    } else if (_random.chance(config.blockChance)) {
      outcome = ShotOutcome.blocked;
    } else if (_random.chance(onTargetP / (1 - config.blockChance))) {
      outcome = _random.chance(goalPGivenOnTarget)
          ? ShotOutcome.goal
          : ShotOutcome.saved;
    } else {
      outcome = ShotOutcome.offTarget;
    }

    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.shot,
        side: attackerSide,
        primaryPlayerId: shooter.playerId,
        secondaryPlayerId: assister?.playerId,
        shotOutcome: outcome,
        quality: quality,
        xg: isPenalty ? penaltyXg : xg,
        metadata: {
          'isBigChance':
              quality == ChanceQuality.bigChance ||
              quality == ChanceQuality.penalty,
          'gkPlayerId': gk?.playerId,
        },
      ),
    );

    if (outcome == ShotOutcome.goal) {
      _involvedThisMinute.add(gk?.playerId ?? -1);
      if (attackerSide == MatchSide.home) {
        _scoreHome++;
      } else {
        _scoreAway++;
      }
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.goal,
          side: attackerSide,
          primaryPlayerId: shooter.playerId,
          secondaryPlayerId: assister?.playerId,
          shotOutcome: ShotOutcome.goal,
          quality: quality,
          xg: xg,
        ),
      );
      return produced;
    }
    if (outcome == ShotOutcome.saved) {
      // Keeper claims it: the save is the GK's visible contribution to
      // the minute (GDD 14 — keepers must appear in involvement lists
      // even in low-scoring matches, not only when they concede).
      if (gk != null && !gk.sentOff) {
        _involvedThisMinute.add(gk.playerId);
      }
      // A share of saves ends in a corner: the keeper parries the ball
      // out behind his own goal line (GDD 13.2 corners).
      if (_random.chance(config.cornerFromSave)) {
        produced.addAll(
          _corner(minute, attackerSide, att, headerChance: false),
        );
      }
    }
    if (outcome == ShotOutcome.blocked &&
        _random.chance(config.cornerFromBlock)) {
      produced.addAll(_corner(minute, attackerSide, att, headerChance: true));
    }
    return produced;
  }

  // -------------------------------------------------------------------------
  // Selection helpers (position-weighted, GDD 12.4 player positions)
  // -------------------------------------------------------------------------

  static const Map<Position, double> _shooterWeights = {
    Position.st: 4.0,
    Position.lw: 2.6,
    Position.rw: 2.6,
    Position.cam: 2.4,
    Position.lm: 1.4,
    Position.rm: 1.4,
    Position.cm: 1.0,
    Position.cdm: 0.4,
    Position.lb: 0.4,
    Position.rb: 0.4,
    Position.cb: 0.7,
    Position.gk: 0.01,
  };

  static const Map<Position, double> _creatorWeights = {
    Position.cam: 4.0,
    Position.lw: 2.6,
    Position.rw: 2.6,
    Position.cm: 2.4,
    Position.lm: 2.0,
    Position.rm: 2.0,
    Position.st: 1.6,
    Position.cdm: 1.0,
    Position.lb: 0.9,
    Position.rb: 0.9,
    Position.cb: 0.4,
    Position.gk: 0.01,
  };

  static const Map<Position, double> _defenderWeights = {
    Position.cdm: 3.2,
    Position.cb: 3.0,
    Position.lb: 2.2,
    Position.rb: 2.2,
    Position.cm: 2.0,
    Position.lm: 1.2,
    Position.rm: 1.2,
    Position.cam: 0.8,
    Position.lw: 0.6,
    Position.rw: 0.6,
    Position.st: 0.4,
    Position.gk: 0.05,
  };

  MatchPlayer? _pickWeighted(
    Iterable<MatchPlayer> players,
    Map<Position, double> weights, {
    double Function(MatchPlayer)? weightAdjust,
  }) {
    final pool = players.where((p) => !p.sentOff).toList();
    if (pool.isEmpty) return null;
    final ticket = <MatchPlayer, double>{};
    var total = 0.0;
    for (final p in pool) {
      var w = weights[p.position] ?? 0.5;
      if (weightAdjust != null) w *= weightAdjust(p);
      total += w;
      ticket[p] = w;
    }
    var roll = _random.nextDouble() * total;
    for (final e in ticket.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return pool.last;
  }

  MatchPlayer? _pickAttacker(_TeamRuntime team) =>
      _pickWeighted(team.onPitch.whereType<MatchPlayer>(), _creatorWeights);

  MatchPlayer? _pickShooter(_TeamRuntime team) =>
      _pickWeighted(team.onPitch.whereType<MatchPlayer>(), _shooterWeights);

  MatchPlayer? _pickAssister(
    _TeamRuntime team, {
    required MatchPlayer exclude,
  }) => _pickWeighted(
    team.onPitch.whereType<MatchPlayer>().where((p) => p != exclude),
    _creatorWeights,
  );

  MatchPlayer? _pickDefender(_TeamRuntime team) => _pickWeighted(
    team.onPitch.whereType<MatchPlayer>(),
    _defenderWeights,
    // A booked player eases off challenges so he does not see a second
    // yellow (the real-world 'playing on a card' behaviour): his foul
    // weight drops to a third. This is what keeps card volume realistic
    // — without it the same defensive core commits every foul and
    // second-yellow reds explode once yellow frequency is calibrated.
    weightAdjust: (p) => p.yellowCards > 0 ? 0.35 : 1.0,
  );

  // -------------------------------------------------------------------------
  // Stamina
  // -------------------------------------------------------------------------

  void _drainStamina() {
    for (final side in MatchSide.values) {
      final rt = _runtimeOf(side);
      final styleStamina =
          rt.tactics.modifiers.stamina *
          rt.mentalityFx.stamina *
          _activeActionModifiersOf(side).stamina;
      for (final p in rt.onPitch.whereType<MatchPlayer>()) {
        final drain = staminaDrainForMinute(
          config: config.staminaConfig,
          position: p.position,
          styleStamina: styleStamina,
          mentalityStamina: 1.0,
          involvedInEvent: _involvedThisMinute.contains(p.playerId),
        );
        p.stamina = (p.stamina - drain).clamp(0, 100);
        p.minutesPlayed++;
      }
      // Bench players don't consume match stamina (GDD 11.3).
    }
  }

  // -------------------------------------------------------------------------
  // Commands and AI
  // -------------------------------------------------------------------------

}
