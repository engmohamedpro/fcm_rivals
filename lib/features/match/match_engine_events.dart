part of 'match_engine.dart';

/// Player picking, stamina drain, runtime helpers and event emission
/// privates of [MatchEngine] (extracted, app-structure review task
/// `2026-11-05_app-structure_split-match-engine`). Pure relocation —
/// bodies unchanged.
extension _MatchEngineEvents on MatchEngine {
  List<MatchEvent> _applyDueCommands(int minute) {
    final produced = <MatchEvent>[];
    final due = _pending.where((c) => c.atMinute <= minute).toList()
      ..sort((a, b) => a.atMinute.compareTo(b.atMinute));
    for (final command in due) {
      _pending.remove(command);
      final event = _applyCommand(command, minute);
      if (event != null) produced.add(event);
    }
    return produced;
  }

  MatchEvent? _applyCommand(MatchCommand command, int minute) {
    final rt = _runtimeOf(command.side);
    MatchEvent? event;
    switch (command) {
      case ChangeFormationCommand(:final formationCode):
        rt.changeFormation(formationByCode(formationCode), _random);
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'formation', 'value': formationCode},
        );
      case ChangeTacticsCommand(:final tactics):
        rt.tactics = tactics;
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'tactics', 'value': 'custom'},
        );
      case ChangeMentalityCommand(:final mentality):
        rt.mentality = mentality;
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'mentality', 'value': mentality.name},
        );
      case SubstitutionCommand(:final outPlayerId, :final inPlayerId):
        rt.substitute(outPlayerId, inPlayerId, config.maxSubstitutions);
        event = _event(
          minute: minute,
          type: MatchEventType.substitution,
          side: command.side,
          primaryPlayerId: outPlayerId,
          secondaryPlayerId: inPlayerId,
        );
      case LiveActionCommand(:final action):
        rt.activeAction = action;
        rt.actionExpiresMinute = minute + config.liveActionDuration;
        event = _event(
          minute: minute,
          type: MatchEventType.liveAction,
          side: command.side,
          metadata: {'action': action.name},
        );
      case PepTalkCommand(:final talk):
        rt.pepTalkModifiers = talk.modifiers;
        event = _event(
          minute: minute,
          type: MatchEventType.tacticalChange,
          side: command.side,
          metadata: {'change': 'pepTalk', 'value': talk.id},
        );
    }
    if (event != null) _events.add(event);
    _applied.add(command);
    return event;
  }

  /// Rule-based AI adaptation (GDD 12.6): tactical reasons, never constant
  /// flip-flopping (bounded count, spacing, score/time triggers).
  List<MatchEvent> _maybeAdaptAi(MatchSide side, int minute) {
    final rt = _runtimeOf(side);
    if (!rt.aiControlled) return const [];
    final produced = <MatchEvent>[];

    // Substitutions first (GDD 10.5): an AI side refreshes tired legs
    // from its bench — the same rotation pressure the user's squad has.
    // Starters below the age-dependent band (80 after 65', 72 after 80')
    // come off for the best compatible bench body, and a trailing side
    // gambles with an attacker after 70', so AI clubs rotate when
    // fitness or the scoreline demands it.
    produced.addAll(_maybeAiSubstitutions(side, rt, minute));

    if (rt.aiChanges >= config.aiMaxChanges) return produced;
    if (minute < 55) return produced;
    if (minute - rt.lastAiChangeMinute < config.aiMinMinutesBetweenChanges) {
      return produced;
    }
    final diff = side == MatchSide.home
        ? _scoreHome - _scoreAway
        : _scoreAway - _scoreHome;
    final index = rt.mentality.index;
    final last = Mentality.values.length - 1;
    String? reason;
    Mentality? next;
    if (diff <= -2 && index < last) {
      reason = 'trailing by two or more';
      next = rt.mentality.moreAttacking();
    } else if (diff == -1 && minute >= 75 && index < last) {
      reason = 'chasing an equaliser late';
      next = rt.mentality.moreAttacking();
    } else if (diff >= 2 && index > 0) {
      reason = 'protecting a lead';
      next = rt.mentality.moreDefensive();
    }
    if (next == null || next == rt.mentality) return produced;
    rt.mentality = next;
    rt.aiChanges++;
    rt.lastAiChangeMinute = minute;
    final event = _event(
      minute: minute,
      type: MatchEventType.tacticalChange,
      side: side,
      metadata: {
        'change': 'mentality',
        'value': next.name,
        'ai': true,
        'reason': reason,
      },
    );
    _events.add(event);
    produced.add(event);
    return produced;
  }

  /// AI substitutions (GDD 10.5/11): the outgoing player stops draining
  /// stamina the moment he is off (bench never drains), the substitute
  /// drains only from his entrance — the engine runtime already models
  /// this; here the AI just decides WHEN. The gates must intersect the
  /// REAL stamina curve: a balanced full-match starter finishes near 70,
  /// so the tired bands sit at 80 (from 65') and 72 (from 80') — the old
  /// 40/30 gates never triggered and AI subs were dead code. A team
  /// trailing after 70' also gambles with a defender-for-attacker swap
  /// (GDD 12.6). At most one AI change per team per 5 minutes, so the
  /// window budget is spread through the final third like real matches.
  List<MatchEvent> _maybeAiSubstitutions(
    MatchSide side,
    _TeamRuntime rt,
    int minute,
  ) {
    if (rt.substitutionsUsed >= config.maxSubstitutions) return const [];
    if (rt.bench.isEmpty) return const [];
    if (minute < 65) return const [];
    if (minute - rt.lastAiSubMinute < 12) return const [];
    final produced = <MatchEvent>[];

    // Chasing the game (GDD 12.6) FIRST — it is the stronger signal and
    // must claim the window (and the bench attacker) before rotation
    // does: a trailing side throws an attacker on for a defender after
    // 70', even when nobody is exhausted.
    final diff = side == MatchSide.home
        ? _scoreHome - _scoreAway
        : _scoreAway - _scoreHome;
    if (diff < 0 &&
        minute >= 70 &&
        !rt.aiChaseSubDone &&
        rt.substitutionsUsed < config.maxSubstitutions) {
      final event = _aiChaseSubstitution(side, rt, minute);
      if (event != null) produced.add(event);
    }

    // Tired threshold sinks as the match ages: 76 after 65', 70 after 80'.
    final threshold = minute >= 80 ? 70 : 76;
    final onPitch = rt.onPitch.whereType<MatchPlayer>().toList()
      ..sort((a, b) => a.stamina.compareTo(b.stamina));
    for (final tired in onPitch) {
      if (rt.substitutionsUsed >= config.maxSubstitutions) break;
      if (tired.position == Position.gk) continue;
      if (tired.stamina >= threshold) {
        break; // sorted ascending: nobody left is tired
      }
      final slotIndex = rt.onPitch.indexWhere(
        (p) => p?.playerId == tired.playerId,
      );
      if (slotIndex == -1) continue;
      final slotPosition = slotIndex < rt.formation.slots.length
          ? rt.formation.slots[slotIndex].position
          : tired.position;
      final bestIn = _bestBenchForSlot(rt, slotPosition);
      if (bestIn == null) continue;
      final event = _applyAiSubstitution(
        side: side,
        rt: rt,
        minute: minute,
        outgoing: tired,
        incoming: bestIn,
        reason: 'tired',
      );
      if (event != null) {
        produced.add(event);
        break; // one change per window: subs spread like real matches
      }
    }
    return produced;
  }

  /// Best remaining bench body for [slotPosition]: slot compatibility
  /// first, then overall quality, with freshness as the tiebreaker.
  MatchPlayer? _bestBenchForSlot(_TeamRuntime rt, Position slotPosition) {
    MatchPlayer? best;
    var bestScore = -1.0;
    for (final candidate in rt.bench) {
      final compat = const SquadEngine().compatibilityOf(
        candidate.position,
        slotPosition,
      );
      if (compat <= 0.1) continue;
      // Freshness tiebreaker for SUB MANAGEMENT only (AI substitution
      // decisions stay stamina-driven; performance never does, see
      // T-0052): a fully fresh sub scores 1.00, an empty tank 0.75 —
      // linear in stamina (0.75 + a quarter of the stamina percent),
      // written as one division by 400.
      final score =
          compat *
          (candidate.attack + candidate.support + candidate.defence) *
          (0.75 + candidate.stamina / 400);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  // -------------------------------------------------------------------------
  // Injuries (T-0054, GDD 11.7)
  // -------------------------------------------------------------------------

  /// Per-minute injury rolls for every on-pitch player of BOTH sides
  /// (GDD 11.7). Fixed iteration order — home slots then away slots, in
  /// formation order — keeps the derived injury stream deterministic:
  /// the same seed always sustains the same injuries in the same
  /// minute, while the football stream stays byte-identical per seed.
  List<MatchEvent> _rollInjuries(int minute) {
    final produced = <MatchEvent>[];
    for (final side in MatchSide.values) {
      produced.addAll(_rollTeamInjuries(side, minute));
    }
    return produced;
  }

  List<MatchEvent> _rollTeamInjuries(MatchSide side, int minute) {
    final rt = _runtimeOf(side);
    final produced = <MatchEvent>[];
    final cap = config.injuryConfig.maxInjuriesPerTeamPerMatch;
    for (var slot = 0; slot < rt.onPitch.length; slot++) {
      if (rt.injuriesThisMatch >= cap) break;
      final player = rt.onPitch[slot];
      if (player == null) continue;
      final chance = injuryChanceForMinute(
        config: config.injuryConfig,
        stamina: player.stamina,
        position: player.position,
        medicalCentreLevel: rt.medicalCentreLevel,
      );
      final injury = rollInjury(
        config: config.injuryConfig,
        chancePerMinute: chance,
        draw: _injuryRandom.nextDouble,
      );
      if (injury == null) continue;
      rt.injuriesThisMatch++;
      // Forced replacement while the shared substitution cap allows:
      // best-fit by the AI's compatibility×rating score. The swap is
      // NOT a tactical choice — it leaves the AI's windows
      // (lastAiSubMinute / aiChaseSubDone) untouched, but
      // [substitutionsUsed] increments like any other sub. Without a
      // candidate the team plays short, mirroring a red card.
      final slotPosition = slot < rt.formation.slots.length
          ? rt.formation.slots[slot].position
          : player.position;
      final incoming = rt.substitutionsUsed < config.maxSubstitutions
          ? _bestBenchForSlot(rt, slotPosition)
          : null;
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.injury,
          side: side,
          primaryPlayerId: player.playerId,
          metadata: {
            'kind': injury.kind.name,
            'matchesOut': injury.matchesOut,
            'playsShort': incoming == null,
          },
        ),
      );
      if (incoming != null) {
        rt.substitute(
          player.playerId,
          incoming.playerId,
          config.maxSubstitutions,
        );
        produced.add(
          _emit(
            minute: minute,
            type: MatchEventType.substitution,
            side: side,
            primaryPlayerId: player.playerId,
            secondaryPlayerId: incoming.playerId,
            metadata: {'reason': 'injury'},
          ),
        );
      } else {
        // Same empty-slot mechanism a red card uses (plays short).
        rt.onPitch[slot] = null;
        rt.offPitch.add(player);
      }
    }
    return produced;
  }

  /// Executes one AI swap and emits the corresponding event.
  MatchEvent? _applyAiSubstitution({
    required MatchSide side,
    required _TeamRuntime rt,
    required int minute,
    required MatchPlayer outgoing,
    required MatchPlayer incoming,
    required String reason,
  }) {
    if (!rt.bench.any((p) => p.playerId == incoming.playerId)) return null;
    rt.substitute(
      outgoing.playerId,
      incoming.playerId,
      config.maxSubstitutions,
    );
    rt.lastAiSubMinute = minute;
    final event = _event(
      minute: minute,
      type: MatchEventType.substitution,
      side: side,
      primaryPlayerId: outgoing.playerId,
      secondaryPlayerId: incoming.playerId,
      metadata: {'ai': true, 'reason': reason},
    );
    _events.add(event);
    return event;
  }

  /// Chasing-game gamble (GDD 12.6): the best bench attacker takes the
  /// defensive slot that compromises him least — the weariest defender
  /// makes way when the options are otherwise equal.
  MatchEvent? _aiChaseSubstitution(
    MatchSide side,
    _TeamRuntime rt,
    int minute,
  ) {
    MatchPlayer? outDefender;
    MatchPlayer? inAttacker;
    var bestScore = -1.0;
    for (var slot = 0; slot < rt.onPitch.length; slot++) {
      final defender = rt.onPitch[slot];
      if (defender == null) continue;
      final slotPosition = slot < rt.formation.slots.length
          ? rt.formation.slots[slot].position
          : defender.position;
      const defenders = {Position.cb, Position.lb, Position.rb, Position.cdm};
      if (!defenders.contains(slotPosition)) continue;
      for (final attacker in rt.bench) {
        const attackers = {Position.st, Position.lw, Position.rw, Position.cam};
        if (!attackers.contains(attacker.position)) continue;
        final compat = const SquadEngine().compatibilityOf(
          attacker.position,
          slotPosition,
        );
        if (compat <= 0.1) continue;
        final score =
            compat * attacker.attack + (100 - defender.stamina) * 0.05;
        if (score > bestScore) {
          bestScore = score;
          outDefender = defender;
          inAttacker = attacker;
        }
      }
    }
    if (outDefender == null || inAttacker == null) return null;
    rt.aiChaseSubDone = true;
    return _applyAiSubstitution(
      side: side,
      rt: rt,
      minute: minute,
      outgoing: outDefender,
      incoming: inAttacker,
      reason: 'chasing',
    );
  }

  ActionModifiers _activeActionModifiersOf(MatchSide side) {
    final rt = _runtimeOf(side);
    final action = rt.activeAction;
    if (action == null || _minute > rt.actionExpiresMinute) {
      return const ActionModifiers(attack: 1, defence: 1, stamina: 1);
    }
    return action.modifiers;
  }

  // -------------------------------------------------------------------------
  // Plumbing
  // -------------------------------------------------------------------------

  _TeamRuntime _runtimeOf(MatchSide side) =>
      side == MatchSide.home ? _home : _away;

  _TeamRuntime _oppositeRuntime(MatchSide side) =>
      side == MatchSide.home ? _away : _home;

  MatchSide _opposite(MatchSide side) =>
      side == MatchSide.home ? MatchSide.away : MatchSide.home;

  MatchEvent _event({
    required int minute,
    required MatchEventType type,
    required MatchSide side,
    int? primaryPlayerId,
    int? secondaryPlayerId,
    ShotOutcome? shotOutcome,
    ChanceQuality? quality,
    double? xg,
    Map<String, dynamic> metadata = const {},
  }) {
    // Second-half minutes are displayed relative to 45 (GDD 13.3 timeline).
    final displayMinute = minute <= _halfTimeMinute
        ? minute
        : minute - _firstHalfStoppage;
    return MatchEvent(
      eventId: _eventId++,
      minute: displayMinute,
      second: _random.nextInt(60),
      type: type,
      side: side,
      teamId: side == MatchSide.home ? _home.teamId : _away.teamId,
      primaryPlayerId: primaryPlayerId,
      secondaryPlayerId: secondaryPlayerId,
      shotOutcome: shotOutcome,
      quality: quality,
      xg: xg,
      metadata: metadata,
    );
  }

  MatchEvent _emit({
    required int minute,
    required MatchEventType type,
    required MatchSide side,
    int? primaryPlayerId,
    int? secondaryPlayerId,
    ShotOutcome? shotOutcome,
    ChanceQuality? quality,
    double? xg,
    Map<String, dynamic> metadata = const {},
  }) {
    final event = _event(
      minute: minute,
      type: type,
      side: side,
      primaryPlayerId: primaryPlayerId,
      secondaryPlayerId: secondaryPlayerId,
      shotOutcome: shotOutcome,
      quality: quality,
      xg: xg,
      metadata: metadata,
    );
    _events.add(event);
    return event;
  }
}
