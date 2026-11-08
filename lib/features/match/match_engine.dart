/// FCM Rivals — Match Engine (GDD 12, GDD 26, FR-024..FR-029).
///
/// Simulates football through a structured event pipeline (GDD 12.3):
/// possession → build-up → progression → defensive pressure → chance
/// creation → shot selection → accuracy → goalkeeper reaction → outcome.
/// Goals emerge from these events only.
///
/// v2 — calibrated against real football distributions (see
/// test/features/match/engine_calibration_test.dart): ~2.7 goals/match
/// at even strength with the real share of 0-0s and 1-0s, 11-13 shots
/// per team at a 33-39% on-target share, 8-11 corners, 3.5-5.5 offsides,
/// 3-4 yellows with rare reds, big chances converting near 30%, and a
/// goal-timing curve that opens up late (19-25% of goals in the final
/// fifteen minutes) through a bounded pure-time escalation term
/// (`lateGameOpenFactor` — fatigue decoupling, owner decision
/// 2026-11-07: stamina never affects performance, GDD 11.2/12.2). The
/// strength response SATURATES: chance creation follows a logistic
/// curve in attack-minus-defence (a 17-point class gap is a ~80%
/// favourite, not a 9-1) and shot conversion moves only a few points
/// per edge, so blowouts stay as rare as they are in real leagues. A
/// speculative-shot layer puts real-world shot volume under the
/// tactical chance layer.
///
/// Pure Dart, widget-independent (GDD development rule 4) and shaped for a
/// future authoritative server port (GDD 29): inputs are plain values, the
/// PRNG is a seeded single stream (GDD 12.5) and user commands are applied
/// chronologically without recalculating completed events (GDD 26.4).
///
/// File layout (app-structure review, task
/// `2026-11-05_app-structure_split-match-engine`): event records and
/// engine inputs live in `match_event.dart`, the command hierarchy in
/// `match_commands.dart`, runtime types (totals, snapshot, PRNG,
/// per-team runtime, role weights) in `match_engine_runtime.dart`, and
/// the engine's private simulation / AI / emission methods in the part
/// files `match_engine_simulation.dart`, `match_engine_setpieces.dart`
/// and `match_engine_events.dart`. This file re-exports the public
/// surface so existing imports are unaffected.
library;

import 'dart:math' as math;

import '../../core/domain/players.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import 'injury.dart';
import 'stamina.dart';
import 'tactics.dart';
import 'match_event.dart';
import 'match_commands.dart';

export 'match_event.dart';
export 'match_commands.dart';

part 'match_engine_runtime.dart';
part 'match_engine_simulation.dart';
part 'match_engine_setpieces.dart';
part 'match_engine_events.dart';

/// Engine identity for deterministic replay records (GDD 12.5). Bumped
/// 2 → 3 (T-0052 review 1): the fatigue decoupling changed engine
/// behavior materially for the same seed — replays of pre-decoupling
/// records must be labeled with the old version. Bumped 3 → 4 (T-0054):
/// injuries join the match — the same seed now also produces the same
/// injuries, drawn from the derived injury stream (see
/// [MatchEngine.injuryStreamOffset]) so the football stream itself stays
/// byte-identical per seed.
const int matchEngineVersion = 4;

/// Derives the injury stream from the match seed (T-0054): every seeded
/// engine gets a second [MatchRandom] at `seed + injuryStreamOffset` so
/// the per-minute injury rolls never touch the football stream — every
/// pre-injury calibrated distribution (the whole GDD §31 profile) holds
/// BY CONSTRUCTION for the same seed, and injuries remain fully
/// deterministic. The offset is a fixed part of the engine contract
/// (replay records carry only the seed).
const int injuryStreamOffset = 7919;

/// The deterministic match simulator.
class MatchEngine {
  MatchEngine({
    required MatchTeamInput home,
    required MatchTeamInput away,
    required int seed,
    this.config = defaultMatchEngineConfig,
  }) : _home = _TeamRuntime.from(home),
       _away = _TeamRuntime.from(away),
       _random = MatchRandom(seed),
       _injuryRandom = MatchRandom(seed + injuryStreamOffset) {
    // Stoppage deterministically drawn once at setup (GDD 12.5: one seed,
    // one stream — stoppage is part of that stream).
    _firstHalfStoppage = 1 + _random.nextInt(3);
    _secondHalfStoppage = 1 + _random.nextInt(4);
    _halfTimeMinute = 45 + _firstHalfStoppage;
    _fullTimeMinute = 90 + _secondHalfStoppage + _firstHalfStoppage;
  }

  final MatchEngineConfig config;
  final MatchRandom _random;
  final MatchRandom _injuryRandom;
  final _TeamRuntime _home;
  final _TeamRuntime _away;

  late final int _firstHalfStoppage;
  late final int _secondHalfStoppage;
  late final int _halfTimeMinute;
  late final int _fullTimeMinute;

  int _minute = 0;
  int _eventId = 0;
  bool _finished = false;
  bool _halfTimeReached = false;
  int _scoreHome = 0;
  int _scoreAway = 0;
  final List<MatchEvent> _events = [];
  final List<MatchCommand> _pending = [];
  final List<MatchCommand> _applied = [];
  final Set<int> _involvedThisMinute = {};

  /// All events so far (GDD 26.4: the single source for commentary,
  /// statistics and ratings).
  List<MatchEvent> get events => List.unmodifiable(_events);

  /// Commands actually applied, in order — the replay record (GDD 12.5).
  List<MatchCommand> get appliedCommands => List.unmodifiable(_applied);

  MatchState get state => MatchState(
    minute: _minute,
    scoreHome: _scoreHome,
    scoreAway: _scoreAway,
    isFinished: _finished,
    isHalfTime: _halfTimeReached && _minute == _halfTimeMinute,
    substitutionsHome: _home.substitutionsUsed,
    substitutionsAway: _away.substitutionsUsed,
  );

  bool get isFinished => _finished;
  int get seed => _random.initialSeed;

  /// Total football-stream PRNG draws consumed so far — the determinism
  /// audit counter (GDD 12.5). Injuries draw from their own derived
  /// stream ([injuryDrawCount]) and never touch this one.
  int get randomDrawCount => _random.drawCount;

  /// Injury-stream draws (T-0054): one roll per player-minute plus the
  /// severity draws on a hit — O(on-pitch players) per minute.
  int get injuryDrawCount => _injuryRandom.drawCount;

  /// The team's Medical Centre level as wired into this match (T-0055)
  /// — the store-level test asserts the campus wiring through it.
  int medicalCentreLevelOf(MatchSide side) =>
      _runtimeOf(side).medicalCentreLevel;

  /// Effective team totals for one side at this instant.
  TeamTotals totalsOf(MatchSide side) => _runtimeOf(side).computeTotals(
    isHome: side == MatchSide.home,
    homeAdvantage: config.homeAdvantage,
    actionModifiers: _activeActionModifiersOf(side),
  );

  /// Every player of one side with final (live) state — for post-match
  /// stamina persistence, ratings and recovery.
  List<MatchPlayer> playersOf(MatchSide side) {
    final rt = _runtimeOf(side);
    return [
      for (final p in rt.onPitch.whereType<MatchPlayer>()) p,
      ...rt.bench,
      ...rt.offPitch,
    ];
  }

  /// Players currently on the pitch for [side], formation-slot order —
  /// for the live substitution UI. Empty slots (sent off) are skipped.
  List<MatchPlayer> onPitchOf(MatchSide side) {
    final rt = _runtimeOf(side);
    return [for (final p in rt.onPitch.whereType<MatchPlayer>()) p];
  }

  /// Bench players for [side] still available to come on.
  List<MatchPlayer> benchOf(MatchSide side) => [..._runtimeOf(side).bench];

  /// Substitutions used so far by [side] (of config.maxSubstitutions).
  int substitutionsUsedOf(MatchSide side) => _runtimeOf(side).substitutionsUsed;

  /// Current formation code of [side] — the live tactics UI marks the
  /// active choice.
  String formationOf(MatchSide side) => _runtimeOf(side).formation.code;

  /// Current custom tactics of [side] (GDD 10.2).
  TeamTactics tacticsOf(MatchSide side) => _runtimeOf(side).tactics;

  /// Current mentality of [side] (GDD 10.3).
  Mentality mentalityOf(MatchSide side) => _runtimeOf(side).mentality;

  /// Queues a command; it is applied at the next minute boundary with
  /// atMinute <= that minute (GDD 10.4: changes affect future events
  /// immediately, never past ones).
  void queueCommand(MatchCommand command) {
    if (_finished) {
      throw StateError('The match is finished');
    }
    _pending.add(command);
  }

  /// Simulates one match minute and returns the events it produced.
  List<MatchEvent> advanceMinute() {
    if (_finished) {
      throw StateError('The match is finished');
    }
    final minute = _minute + 1;
    final produced = <MatchEvent>[];
    // Commands first: their events belong to the minute that applies them.
    produced.addAll(_applyDueCommands(minute));
    _minute = minute;
    _involvedThisMinute.clear();

    if (minute == 1) {
      produced.add(
        _emit(minute: 0, type: MatchEventType.kickoff, side: MatchSide.home),
      );
    } else if (minute == _halfTimeMinute + 1) {
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.kickoff,
          side: MatchSide.away,
          metadata: {'secondHalf': true},
        ),
      );
    }

    // Attack segments this minute (GDD 12.3 steps 1-9).
    final segments = _drawSegmentCount();
    for (var s = 0; s < segments; s++) {
      produced.addAll(_simulateSegment(minute));
    }

    // Stamina drain for everyone on the pitch (GDD 11.3: bench doesn't
    // consume; GDD 11.4: dynamic workload).
    _drainStamina();

    // Injuries (T-0054, GDD 11.7): every on-pitch player of BOTH sides
    // rolls against his post-drain stamina — the gameplay bite of the
    // fatigue decoupling made visible: a drained squad starts losing
    // players.
    produced.addAll(_rollInjuries(minute));

    // AI adaptation (GDD 12.6) — reasoning recorded as events.
    produced.addAll(_maybeAdaptAi(MatchSide.home, minute));
    produced.addAll(_maybeAdaptAi(MatchSide.away, minute));

    if (minute == _halfTimeMinute) {
      _halfTimeReached = true;
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.halfTime,
          side: MatchSide.home,
        ),
      );
    }
    if (minute >= _fullTimeMinute) {
      _finished = true;
      produced.add(
        _emit(
          minute: minute,
          type: MatchEventType.fullTime,
          side: MatchSide.home,
        ),
      );
    }
    return produced;
  }

  /// Runs the match to full time (live UI drives advanceMinute instead).
  List<MatchEvent> simulateToEnd() {
    final all = <MatchEvent>[];
    while (!_finished) {
      all.addAll(advanceMinute());
    }
    return all;
  }

  // -------------------------------------------------------------------------
  // Segment pipeline
  // -------------------------------------------------------------------------
}
