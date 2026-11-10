part of 'match_engine.dart';

/// Simulation privates of [MatchEngine] (extracted, app-structure review
/// task `2026-11-05_app-structure_split-match-engine`): segment-count
/// draws, segment simulation, urgency and defensive openness, turnovers,
/// cards, corners, chance creation and the shot pipeline, through command
/// application. Pure relocation — bodies unchanged.
extension _MatchEngineSim on MatchEngine {
  int _drawSegmentCount() {
    final roll = _random.nextDouble();
    final w = config.segmentWeights;
    if (roll < w[0]) return 0;
    if (roll < w[0] + w[1]) return 1;
    return 2;
  }

  List<MatchEvent> _simulateSegment(int minute) {
    final produced = <MatchEvent>[];

    // 1. Possession (GDD 12.3 step 1): support-based, biased by tactics.
    //    A POWER competition, not a ratio: weaker support loses the ball
    //    disproportionately more, but the exponent (1.4) bounds it — a
    //    20-support-point gap swings possession ~61/39, never 90/10,
    //    mirroring how real mismatches dominate without absurdity. The
    //    softer exponent (was 1.6) keeps a dominated minnow touching the
    //    ball often enough to register real shot volume of its own.
    final homeTotals = totalsOf(MatchSide.home);
    final awayTotals = totalsOf(MatchSide.away);
    final homePoss = math.pow(
      homeTotals.support * _home.tactics.modifiers.possession,
      1.4,
    );
    final awayPoss = math.pow(
      awayTotals.support * _away.tactics.modifiers.possession,
      1.4,
    );
    final attackerSide = _random.chance(homePoss / (homePoss + awayPoss))
        ? MatchSide.home
        : MatchSide.away;
    final att = _runtimeOf(attackerSide);
    final def = _runtimeOf(
      attackerSide == MatchSide.home ? MatchSide.away : MatchSide.home,
    );
    final attTotals = attackerSide == MatchSide.home ? homeTotals : awayTotals;
    final defTotals = attackerSide == MatchSide.home ? awayTotals : homeTotals;

    // Possession event carries pass volume for the statistics module.
    // The pocket's fate is decided by the build-up draw below; on a
    // turnover only the ball-playing before the loss counts, at the
    // team's support-driven accuracy — so failed pockets contribute
    // fewer attempts than kept ones (GDD 13.2 stat realism: real teams
    // complete 75-85%).
    final passesAttempted = 3 + _random.nextInt(8);
    final possessionAccuracy =
        ((attTotals.support / 100) * att.tactics.modifiers.passAccuracy).clamp(
          0.40,
          0.92,
        );
    var passesCompleted = (passesAttempted * possessionAccuracy).round();

    // 2-3. Build-up: passing and progression vs defensive pressure.
    final supportRatio =
        attTotals.support / (attTotals.support + defTotals.defence * 0.85);
    final passSuccess =
        (config.buildUpBase + config.buildUpScale * supportRatio).clamp(
          0.15,
          0.88,
        );
    if (!_random.chance(passSuccess)) {
      // Turnover: the pocket died — only a fraction of the passes got
      // away before the loss (a real dispossessed move is 1-3 passes,
      // not a full 3-10-pass pocket). Deterministic from the pocket's
      // own volume: no extra random draw, so the engine's random stream
      // (and every calibrated distribution) is unchanged.
      final lostAttempted = (passesAttempted ~/ 3).clamp(1, 3);
      passesCompleted = (lostAttempted * possessionAccuracy).round();
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.possession,
          side: attackerSide,
          metadata: {
            'passesAttempted': lostAttempted,
            'passesCompleted': passesCompleted,
          },
        ),
      );
      produced.addAll(_turnover(minute, attackerSide, att, def));
      return produced;
    }

    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.possession,
        side: attackerSide,
        metadata: {
          'passesAttempted': passesAttempted,
          'passesCompleted': passesCompleted,
        },
      ),
    );

    // Offside during progression.
    if (_random.chance(config.offsideChance)) {
      final striker = _pickAttacker(att)!;
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.offside,
          side: attackerSide,
          primaryPlayerId: striker.playerId,
        ),
      );
      _involvedThisMinute.add(striker.playerId);
      return produced;
    }

    // 4-5. Chance creation (score/time context: urgency, GDD 12.4).
    //    SATURATING strength response: the attack-minus-defence edge
    //    drives a logistic curve, not a ratio. Real football's
    //    favourite still only creates chances at ~1.6x the rate of the
    //    underdog's own, because defenders congest space and convert
    //    superiority into half-chances, not penalties. The mid/steepness
    //    pair sets where the curve bends: ±10 engine points ≈ the
    //    crossing region, +20 is near-saturation.
    final attackEdge = attTotals.attack - defTotals.defence;
    final urgency = _urgencyBoost(attackerSide, minute);
    final edgeFactor =
        1 /
        (1 +
            math.exp(
              -config.chanceSigmoidSteepness *
                  (attackEdge - config.chanceSigmoidMid),
            ));
    // One chance roll per possession pocket (one attacker pocket per
    // minute), so the Fast Counter bonus can never stack on consecutive
    // recovered balls — each recovery starts exactly one pocket.
    final chanceP =
        (config.chanceBase +
                config.chanceScale *
                    edgeFactor *
                    att.tactics.modifiers.chance *
                    urgency *
                    _defensiveOpenness(attackerSide, minute))
            .clamp(0.05, config.chanceMax);
    if (!_random.chance(chanceP)) {
      // Retained possession: completed passes, maybe a cross or dribble.
      // A share of these pockets end in a LOW-QUALITY shot — a snatched
      // long-range effort, a cross shanked goalwards — which is how real
      // matches reach 11-13 shots per team while clear chances stay
      // rare. Quality stays 'normal' so conversion treats them as
      // half-chances.
      if (_random.chance(config.speculativeShotChance)) {
        produced.addAll(
          _shoot(minute, attackerSide, att, def, ChanceQuality.normal),
        );
        return produced;
      }
      final passAccuracy =
          (attTotals.support / 100) * att.tactics.modifiers.passAccuracy;
      final completed = (passesAttempted * passAccuracy.clamp(0.40, 0.92))
          .round();
      final md = <String, dynamic>{
        'passesAttempted': passesAttempted,
        'passesCompleted': completed,
      };
      if (_random.chance(0.22)) md['cross'] = true;
      if (_random.chance(0.18)) md['dribble'] = true;
      final creator = _pickAttacker(att);
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.passMove,
          side: attackerSide,
          primaryPlayerId: creator?.playerId,
          metadata: md,
        ),
      );
      if (creator != null) _involvedThisMinute.add(creator.playerId);

      // Deep crosses can win corners (GDD 13.2 corners).
      if (md['cross'] == true && _random.chance(config.cornerFromCross)) {
        produced.addAll(
          _corner(minute, attackerSide, att, headerChance: false),
        );
      }
      return produced;
    }

    // 6-8. Shot selection, accuracy, goalkeeper reaction.
    produced.addAll(_attackChance(minute, attackerSide, att, def, defTotals));
    return produced;
  }

  /// Losing teams push harder late (GDD 12.4: match score + time).
  /// The urgency multiplier rises per goal chased from minute 55 and
  /// caps at 1.18 — a two-goal deficit from the hour mark is a real
  /// push, not a token one.
  double _urgencyBoost(MatchSide side, int minute) {
    final diff = side == MatchSide.home
        ? _scoreHome - _scoreAway
        : _scoreAway - _scoreHome;
    if (diff < 0 && minute > 55) return 1 + (0.06 * -diff).clamp(0, 0.18);
    return 1.0;
  }

  /// Late-game chance-creation escalation (GDD 12.4): a PURE TIME term —
  /// the clock opens matches up, players do not (fatigue-decoupling owner
  /// decision 2026-11-07: stamina never feeds performance, GDD 11.2/12.2;
  /// a drained defence is exactly as good as a fresh one and both concede
  /// on the same time curve). The quadratic weight through the second
  /// half is what moves real football's goal share into the last fifteen
  /// minutes without inflating the total — it is held by a knob
  /// ([TuningOverrides.lateGameOpen]), not by player exhaustion. The
  /// pressBill term is keyed to the COMPOSED style/mentality/action/
  /// pep-talk stamina DRAIN, not to stamina LEVELS: high press pays a
  /// late-match defensive bill — a tactics trade-off, not player fatigue.
  double _defensiveOpenness(MatchSide attackerSide, int minute) {
    final t = minute / _fullTimeMinute;
    // Cold-start ramp over the opening quarter: teams feel their way
    // into a match before it opens up (real football's 1-15 minute
    // goal share is the LOWEST of the six buckets).
    final coldStart = minute < 15 ? 0.70 + 0.30 * (minute / 15) : 1.0;
    // Phase-3 late-match press bill, BASELINE-RELATIVE (fatigue-decoupling
    // review, task `2026-11-06_match-engine_fatigue-decoupling`): the
    // bill is keyed to the COMPOSED stamina bundle's excess over the
    // identity baseline, not to the raw pressing instruction constant.
    // Under the old raw-constant read, raising the pressing side's
    // stamina anchor above 1.30 silently killed the gegenpress
    // late-goals bill (measured: hpStamina 1.32/1.34 -> late goals
    // 110%, matrix worst 60.9) while the press-side singles demanded
    // the opposite move — one knob pulling two opposing constraint
    // families. Baseline-relative: a single high press (1.30 over
    // baseline) pays the same shipped bill as before (production
    // bit-identical at identity + PressingIntensity.high), while a
    // stack of stamina costs composes through `operator *` and pays
    // the bill on its composed excess — the drain side and the bill
    // side become independent knobs for the tuning sweep.
    final def = _runtimeOf(
      attackerSide == MatchSide.home ? MatchSide.away : MatchSide.home,
    );
    final styleDrain = def.tactics.modifiers.stamina *
        def.mentality.staminaMod *
        _activeActionModifiersOf(
          attackerSide == MatchSide.home ? MatchSide.away : MatchSide.home,
        ).stamina *
        def.pepTalkModifiers.stamina;
    final pressBill = styleDrain > 1.0
        ? (styleDrain - 1.0) * TuningOverrides.current.pressBillSlope
        : 0.0;
    return coldStart *
        lateGameOpenFactor(
          minute,
          _fullTimeMinute,
          TuningOverrides.current.lateGameOpen,
        ) *
        (1 + pressBill * (t * t));
  }

  List<MatchEvent> _turnover(
    int minute,
    MatchSide attackerSide,
    _TeamRuntime att,
    _TeamRuntime def,
  ) {
    final produced = <MatchEvent>[];
    final loser = _pickAttacker(att)!;
    _involvedThisMinute.add(loser.playerId);

    // Per-side foul rate (phase 2): the defending team's tackling
    // aggression scales the emission probability — aggressive
    // defending fouls more, clean defending less. inBoxFoulChance
    // scales identically: aggressive defending concedes more
    // penalties, the real cost of the option.
    final foulScale = def.tactics.outOfPossession.foulScale;
    if (_random.chance(config.foulOnTurnover * foulScale)) {
      // Foul by the defending side (GDD 13.1 free kicks / penalties).
      final fouler = _pickDefender(def)!;
      _involvedThisMinute.add(fouler.playerId);
      // A foul lands in the box ~1.3% of the time (Europe's top
      // divisions award 0.25-0.30 penalties/match from ~20 fouls) —
      // the old 7% produced ~5x the real award rate.
      final inBox = _random.chance(config.inBoxFoulChance * foulScale);
      final finalThird = !inBox && _random.chance(0.30);
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.foul,
          side: _opposite(attackerSide),
          primaryPlayerId: fouler.playerId,
          secondaryPlayerId: loser.playerId,
          metadata: {
            'fouledTeam': attackerSide == MatchSide.home
                ? _home.teamId
                : _away.teamId,
            'inBox': inBox,
            'finalThird': finalThird,
          },
        ),
      );
      // Cards (GDD 13.1) — per-side yellow rate scaled by the
      // defending team's tackling aggression.
      if (_random.chance(
        config.yellowCardChance *
            def.tactics.outOfPossession.yellowScale,
      )) {
        produced.addAll(
          _issueCard(
            minute,
            _opposite(attackerSide),
            def,
            fouler,
            straightRed: false,
          ),
        );
      } else if (_random.chance(config.straightRedChance)) {
        produced.addAll(
          _issueCard(
            minute,
            _opposite(attackerSide),
            def,
            fouler,
            straightRed: true,
          ),
        );
      }
      if (inBox) {
        produced.add(
          _emit(
            minute: minute,
            type: MatchEventType.penaltyAwarded,
            side: attackerSide,
            primaryPlayerId: loser.playerId,
            secondaryPlayerId: fouler.playerId,
          ),
        );
        produced.addAll(
          _shoot(
            minute,
            attackerSide,
            att,
            def,
            ChanceQuality.penalty,
            // The designated taker: a striker's job, not the CAM the
            // creator weights would hand it to (a CAM was ~2.5x more
            // likely to take a penalty than an ST).
            shooterOverride: _pickShooter(att),
          ),
        );
        return produced;
      }
      if (finalThird && _random.chance(0.12)) {
        produced.addAll(
          _shoot(
            minute,
            attackerSide,
            att,
            def,
            ChanceQuality.freeKick,
            shooterOverride: _pickAttacker(att)!,
          ),
        );
      }
      return produced;
    }

    // Clean turnover: tackle or interception (GDD 13.2).
    final winner = _pickDefender(def)!;
    _involvedThisMinute.add(winner.playerId);
    produced.add(
      _emit(
        minute: minute,
        type: MatchEventType.dispossessed,
        side: _opposite(attackerSide),
        primaryPlayerId: winner.playerId,
        secondaryPlayerId: loser.playerId,
        metadata: _random.chance(0.45)
            ? {'interception': true}
            : {'tackle': true},
      ),
    );
    return produced;
  }

}
