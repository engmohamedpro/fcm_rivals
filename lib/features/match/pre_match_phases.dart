/// FCM Rivals — pre-match tactics, pep-talk and bottom-bar phases
/// (GDD 10.4 match-only setup + 15.1 pep talk).
///
/// Split out of `pre_match_screen.dart` (task
/// `2026-11-05_app-structure_split-pre-match-screen`); the screen
/// imports this file directly.
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
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
        FcmEntrance(
          child: Column(
            children: [
              const SizedBox(height: 4),
              const Text(
                'Set up for this match',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Same as your Team tab — but these changes last only '
                'until the final whistle. Your saved default setup is '
                'untouched.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              // T-0052 decoupling restated for the player (T-0056):
              // fitness no longer weakens play — it signals injury risk.
              const SizedBox(height: 4),
              Text(
                l10nOf(context).injuryStaminaRiskHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FcmColors.danger,
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Same shared surface as the Team tab, with one difference:
        // match-day fitness. Stamina on, stat rows off, full 23-man
        // strip including reserves.
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

/// One motivational choice (GDD 15.1) with its visible percentage
/// effects; selecting one plays a short confirm burst handled by the
/// screen's callback.
class PepTalkPhase extends StatelessWidget {
  const PepTalkPhase({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final MatchPepTalk? selected;
  final ValueChanged<MatchPepTalk?> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      children: [
        FcmEntrance(
          child: Column(
            children: [
              const SizedBox(height: 10),
              const FcmIconBadge(
                icon: Icons.record_voice_over_rounded,
                size: 76,
              ),
              const SizedBox(height: 16),
              const Text(
                'DRESSING ROOM',
                style: TextStyle(
                  color: FcmColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Deliver your team talk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'One motivational choice — its effects last the whole match '
                'and are shown as percentages (GDD 15.1).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < preMatchPepTalks.length; i++)
          FcmEntrance(
            index: i,
            duration: const Duration(milliseconds: 420),
            child: _PepTalkTile(
              talk: preMatchPepTalks[i],
              selected: selected?.id == preMatchPepTalks[i].id,
              onTap: () => onSelect(preMatchPepTalks[i]),
            ),
          ),
        const SizedBox(height: 8),
        FcmEntrance(
          index: preMatchPepTalks.length,
          duration: const Duration(milliseconds: 420),
          child: _PepTalkTile(
            talk: null,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
        ),
      ],
    );
  }
}

/// One selectable talk tile, or the "no talk" tile when [talk] is null.
class _PepTalkTile extends StatelessWidget {
  const _PepTalkTile({
    required this.talk,
    required this.selected,
    required this.onTap,
  });

  final MatchPepTalk? talk;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = talk;
    final effects = t == null ? 'No modifiers' : t.effectSummary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FcmPressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [
                      Color.lerp(FcmColors.surfaceHigh, FcmColors.gold, 0.22)!,
                      FcmColors.surface,
                    ]
                  : [FcmColors.surfaceHigh, FcmColors.surface],
            ),
            border: Border.all(
              color: selected
                  ? FcmColors.gold.withValues(alpha: 0.8)
                  : FcmColors.bronze.withValues(alpha: 0.3),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: FcmColors.gold.withValues(alpha: 0.28),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? FcmColors.gold
                      : Colors.white.withValues(alpha: 0.06),
                  border: Border.all(
                    color: selected
                        ? FcmColors.goldSoft
                        : FcmColors.bronze.withValues(alpha: 0.5),
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: FcmColors.ink,
                        size: 20,
                      )
                    : const Icon(
                        Icons.record_voice_over_rounded,
                        color: FcmColors.textDim,
                        size: 17,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t?.label ?? 'No team talk',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      effects,
                      style: TextStyle(
                        color: t == null
                            ? FcmColors.textDim
                            : FcmColors.goldSoft,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (t != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.description,
                        style: const TextStyle(
                          color: FcmColors.textDim,
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The matchday build-up's bottom bar: phase-aware primary action
/// (CONTINUE / TO DRESSING ROOM / KICK OFF), the BACK affordance and the
/// inline session-preparation error.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.phase,
    required this.selectedTalk,
    required this.loading,
    required this.error,
    required this.onPrimary,
    this.onBack,
  });

  /// 0 analysis, 1 tactics, 2 pep talk.
  final int phase;
  final MatchPepTalk? selectedTalk;
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
      1 => 'TO DRESSING ROOM',
      _ => 'KICK OFF',
    };
    final primaryIcon = switch (phase) {
      0 => Icons.groups_rounded,
      1 => Icons.record_voice_over_rounded,
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
