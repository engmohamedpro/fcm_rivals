/// FCM Rivals — matchday build-up screen (GDD 13 pre-match + 15.1 pep talk).
///
/// The full-screen experience before a fixture:
///
///   1. Opponent header — the rival under the microscope: crest, league
///      position and last-five form in one compact strip.
///   2. Analysis phase — win/draw/loss probabilities (a neutral
///      Monte-Carlo over BOTH full squad lists: starting XI, bench and
///      reserves, no tactics or condition), side-by-side strength bars
///      and the opponent's top three players as collection-style cards,
///      each staggering in. Widgets live in `pre_match_analysis.dart`.
///   3. Tactics phase  — the SAME tactics screen as the Team tab
///      (formation, custom tactics and mentality with visible
///      percentage effects, pitch with stamina bars, bench and reserves),
///      except the changes apply to THIS MATCH ONLY: the club's saved
///      default setup is never touched (GDD 10.4 match-specific setup).
///   4. Pep talk phase — one motivational choice (GDD 15.1) with its
///      visible percentage effects; selecting one plays a short confirm
///      burst. Phase widgets live in `pre_match_phases.dart`
///      (task `2026-11-05_app-structure_split-pre-match-screen`).
///   5. Kick-off       — hands the prepared selection to the caller.
///
/// The screen owns no session data: [onKickOff] receives the chosen talk
/// and the match-only tactic selection so the caller builds the session
/// exactly as before (FR-043: no ads).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import 'match_forecast.dart';
import 'pre_match_analysis.dart';
import 'pre_match_phases.dart';
import 'pre_match_tactics_selection.dart';
export 'pre_match_tactics_selection.dart' show PreMatchTacticSelection;
import 'tactics.dart';

/// Full-screen matchday build-up: analysis → tactics → pep talk → kick-off.
class PreMatchScreen extends StatefulWidget {
  const PreMatchScreen({
    super.key,
    required this.data,
    required this.onKickOff,
    this.loading = false,
    this.error,
    this.onTacticsSelected,
    this.onExit,
  });

  final PreMatchData data;

  /// Receives the match-only tactic selection and the chosen pep talk
  /// (null = no talk), then pops.
  final void Function(MatchPepTalk? talk) onKickOff;

  /// True while the caller prepares the session (kick-off pressed).
  final bool loading;

  /// Error text from session preparation, shown inline.
  final String? error;

  /// Receives the tactic selections made in the tactics phase. The caller
  /// decides what they mean; on this screen they are match-only overrides
  /// that must NOT be persisted.
  final ValueChanged<PreMatchTacticSelection>? onTacticsSelected;

  /// Leaves the matchday build-up from the analysis phase before anything
  /// is committed — the fixture stays unplayed. Defaults to popping the
  /// route; hosts that wrap the screen pass their own pop.
  final VoidCallback? onExit;

  @override
  State<PreMatchScreen> createState() => _PreMatchScreenState();
}

class _PreMatchScreenState extends State<PreMatchScreen> {
  int _phase = 0; // 0 analysis, 1 tactics, 2 pep talk
  MatchPepTalk? _selectedTalk;
  late String _formationCode = widget.data.userFormationCode;
  late TeamTactics _tactics = widget.data.userTactics;
  late Mentality _mentality = widget.data.userMentality;

  void _nextPhase() {
    HapticFeedback.selectionClick();
    setState(() => _phase++);
  }

  void _selectTalk(MatchPepTalk? talk) {
    HapticFeedback.mediumImpact();
    setState(() => _selectedTalk = talk);
  }

  void _kickOff() {
    HapticFeedback.heavyImpact();
    widget.onTacticsSelected?.call(
      PreMatchTacticSelection(
        formationCode: _formationCode,
        tactics: _tactics,
        mentality: _mentality,
      ),
    );
    widget.onKickOff(_selectedTalk);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final phase = _phase;
    return Scaffold(
      backgroundColor: FcmColors.night,
      body: FcmBackdrop(
        tint: FcmColors.gold,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: switch (phase) {
                    0 => AnalysisPhase(
                      key: const ValueKey('analysis'),
                      data: d,
                    ),
                    1 => TacticsPhase(
                      key: const ValueKey('tactics'),
                      data: d,
                      formationCode: _formationCode,
                      tactics: _tactics,
                      mentality: _mentality,
                      onFormation: (code) =>
                          setState(() => _formationCode = code),
                      onTactics: (t) => setState(() => _tactics = t),
                      onMentality: (m) => setState(() => _mentality = m),
                      // T-0118: the matchday Auto Pick — the projection
                      // is deterministic (saved squad + fitness-aware
                      // policy), so the tap re-asserts the fittest legal
                      // XI for the CURRENT shape and replays the swap
                      // animation. Nothing persists: the club's saved
                      // setup is never touched from the matchday flow.
                      onAutoPick: () {
                        HapticFeedback.selectionClick();
                        setState(() {});
                      },
                    ),
                    _ => PepTalkPhase(
                      key: const ValueKey('pep'),
                      selected: _selectedTalk,
                      onSelect: _selectTalk,
                    ),
                  },
                ),
              ),
              BottomBar(
                phase: phase,
                selectedTalk: _selectedTalk,
                loading: widget.loading,
                error: widget.error,
                onPrimary: phase == 2 ? _kickOff : _nextPhase,
                // Later phases step back through the build-up; the
                // analysis phase's BACK leaves the matchday (and the
                // fixture unplayed) via onExit — defaulting to a plain
                // pop when no host callback is given.
                onBack: _phase > 0
                    ? () {
                        HapticFeedback.selectionClick();
                        setState(() => _phase--);
                      }
                    : (widget.onExit ?? () => Navigator.of(context).maybePop()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
