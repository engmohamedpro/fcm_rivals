/// FCM Rivals — pre-match tactics and bottom-bar phases
/// (GDD 10.4 match-only setup; the 15.1 pep-talk phase was removed —
/// owner request 2026-11-14: no pep talks anywhere in the game).
///
/// Split out of `pre_match_screen.dart` (task
/// `2026-11-05_app-structure_split-pre-match-screen`); the screen
/// imports this file directly.
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../squad/formations.dart';
import '../squad/squad_engine.dart';
import '../squad/squad_view.dart';
import 'match_forecast.dart';
import 'tactics.dart';

/// Set up how this match is played (GDD 10.4): the SAME tactics screen as
/// the Team tab — formation and custom tactics with their visible
/// percentage effects, the pitch with per-player stamina bars (GDD 11),
/// bench and reserves — with one difference: the changes apply to THIS
/// MATCH ONLY and never touch the club's saved default setup. The
/// starting XI is re-picked for the chosen shape in memory, so the pitch
/// previews the exact team that kicks off. The mentality is not edited
/// here (owner request 2026-11-13) — it stays whatever the club saved
/// and whatever the live panel changes mid-match.
class TacticsPhase extends StatelessWidget {
  const TacticsPhase({
    super.key,
    required this.data,
    required this.formationCode,
    required this.tactics,
    required this.onFormation,
    required this.onTactics,
    this.onAutoPick,
  });

  final PreMatchData data;
  final String formationCode;
  final TeamTactics tactics;
  final ValueChanged<String> onFormation;
  final ValueChanged<TeamTactics> onTactics;

  /// T-0118: the matchday Auto Pick — re-projects the XI/bench/
  /// reserves in memory with the fitness-aware rules (injured and
  /// suspended excluded, stamina band then rating). Match-only by
  /// construction: it never touches the club's saved setup.
  final VoidCallback? onAutoPick;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final squad = d.userSquad;

    // Starting XI, bench and reserves for the SELECTED shape: a changed
    // formation re-picks the XI in memory (same rules as the Team tab's
    // Auto Pick) so what the user sees is the team that will kick off.
    final (xi, bench, reserves) = _squadFor(formationCode, squad);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        // T-0132 (owner request 2026-11-13): the intro text block is
        // GONE — no title, no explainer, no fitness warning. The
        // phase opens straight onto the Team tab's own surface.
        // Same shared surface as the Team tab, with one difference:
        // match-day fitness. Stamina on, stat rows off, full 23-man
        // strip including reserves — and the same compact control
        // card (no setup summary row) as the Team tab.
        TacticsSetupView(
          formation: formationOfCode(formationCode),
          tactics: tactics,
          xi: xi,
          bench: bench,
          reserves: reserves,
          onFormation: onFormation,
          onTactics: onTactics,
          showStamina: true,
          showStats: false,
          // Matchday fitness IS the point of the duplicate screen
          // (T-0117/T-0118): injuries and stamina show here.
          showCondition: true,
          showReserves: true,
          // T-0132: identical control card to the Team tab (T-0092
          // ruled the summary row off the Team tab; match-day follows).
          showSetupSummary: false,
          onAutoPick: onAutoPick,
        ),
      ],
    );
  }
}

/// XI / bench / reserves for the selected formation: the persisted squad
/// re-projected onto the new shape with the Squad Engine's MATCHDAY
/// Auto Pick rules (GDD 6.3 + T-0118), purely in memory — nothing is
/// written back. Injured players (and, one day, suspended ones) are
/// excluded from the XI AND the bench; every slot ranks by stamina
/// band then slot rating, so what the user sees is the FITTEST team
/// that will kick off — the duplicate screen's whole difference from
/// the Team tab's merit-eleven.
(Map<int, PlayerCard>, List<PlayerCard>, List<PlayerCard>) _squadFor(
  String formationCode,
  Map<int, PlayerCard> squad,
) {
  final cards = squad.values.toList();
  final assignment = const SquadEngine().autoPick(
    cards,
    formationOfCode(formationCode),
    // The matchday policy (T-0118): exclude the injured, rank by
    // fitness band then quality. suspendedPlayerIds stays empty —
    // the red-card HOOK exists, the suspension STATE does not yet.
    excludeInjured: true,
    staminaFirst: true,
  );
  final byId = {for (final c in cards) c.ownedId: c};

  final xi = <int, PlayerCard>{};
  final bench = <PlayerCard>[];
  final reserves = <PlayerCard>[];
  for (final e in assignment.entries) {
    final card = byId[e.value]!;
    if (e.key < Formation.startingXiSize) {
      xi[e.key] = card;
    } else if (e.key < Formation.startingXiSize + Formation.benchSize) {
      bench.add(card);
    } else {
      reserves.add(card);
    }
  }
  return (xi, bench, reserves);
}

/// The matchday build-up's bottom bar: phase-aware primary action
/// (CONTINUE / KICK OFF), the BACK affordance and the
/// inline session-preparation error.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.phase,
    required this.loading,
    required this.error,
    required this.onPrimary,
    this.onBack,
  });

  /// 0 analysis, 1 tactics (the dressing-room pep-talk phase is gone —
  /// owner request 2026-11-14).
  final int phase;
  final bool loading;
  final String? error;
  final VoidCallback onPrimary;

  /// Steps back one phase; on the analysis phase it leaves the matchday
  /// build-up (the fixture stays unplayed).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = switch (phase) {
      0 => 'CONTINUE',
      _ => 'KICK OFF',
    };
    final primaryIcon = switch (phase) {
      0 => Icons.groups_rounded,
      _ => Icons.play_circle_fill_rounded,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FcmColors.danger, fontSize: 12),
              ),
            ),
          Row(
            children: [
              if (onBack != null) ...[
                Expanded(
                  flex: 2,
                  child: FcmButton(
                    style: FcmButtonStyle.ghost,
                    label: 'BACK',
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 3,
                child: FcmButton(
                  label: primaryLabel,
                  icon: primaryIcon,
                  loading: loading,
                  onPressed: onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
