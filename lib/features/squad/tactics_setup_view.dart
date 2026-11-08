/// FCM Rivals — tactics setup surface (GDD 10/11).
///
/// The setup column (the control card and the tactic options sheet),
/// split verbatim out of `squad_view.dart` (T-0042); the pitch family
/// lives in `squad_pitch_view.dart` and `squad_view.dart` re-exports
/// both.
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../match/tactics.dart';
import '../match/tactics_sections.dart';
import 'formations.dart';
import 'squad_drag.dart';
import 'squad_engine.dart';
import 'squad_pitch_view.dart';
import 'squad_swap.dart' show SquadZone;

/// The whole tactical setup column: the control card (the setup row —
/// formation, playing style, mentality — closed by the team rating, with
/// the Auto Pick and TACTICS actions under it), the pitch with the
/// starting XI (stamina bars and stat rows only when [showStamina] /
/// [showStats] ask for them), then the bench and reserves strips.
class TacticsSetupView extends StatelessWidget {
  const TacticsSetupView({
    super.key,
    required this.formationCode,
    required this.tactics,
    required this.mentality,
    required this.xi,
    required this.bench,
    required this.reserves,
    required this.onFormation,
    required this.onTactics,
    required this.onMentality,
    this.onAutoPick,
    this.showStamina = true,
    this.showStats = true,
    this.showReserves = true,
    this.onPlayerTap,
    this.swapping,
  });

  /// Currently selected formation code (e.g. '4-3-3').
  final String formationCode;

  /// Current custom tactics / mentality selections (GDD 10.2/10.3).
  final TeamTactics tactics;
  final Mentality mentality;

  /// Starting XI assignments: slot index → card.
  final Map<int, PlayerCard> xi;

  /// Bench and reserves cards, best-first.
  final List<PlayerCard> bench;
  final List<PlayerCard> reserves;

  /// Tactic change callbacks — the owner defines whether they persist
  /// (Team tab) or apply to one match only (pre-match phase).
  final ValueChanged<String> onFormation;
  final ValueChanged<TeamTactics> onTactics;
  final ValueChanged<Mentality> onMentality;

  /// Shows the Auto Pick button (GDD 6.3) when non-null — the Team tab
  /// persists a re-picked squad; pre-match hides it.
  final VoidCallback? onAutoPick;

  /// Whether cards carry their stamina bar. The pre-match and live
  /// tactics surfaces show match-day fitness; the Team tab hides it —
  /// the saved setup is about identity, not current match state.
  final bool showStamina;

  /// Whether cards carry their three-column stat row (ATT/SUP/DEF …).
  /// No surface shows it today — the setup surfaces stay about shape,
  /// not attributes; kept for callers that opt in.
  final bool showStats;

  /// Whether the reserves strip renders at all. The Team tab and the
  /// pre-match phase show the full 23-man surface; the LIVE tactics
  /// editor hides it — a match day squad has nobody beyond the bench.
  final bool showReserves;

  /// Opens the player detail sheet; null makes the cards non-tappable.
  final void Function(PlayerCard card)? onPlayerTap;

  /// Enables hold-and-drag swapping between the pitch, the bench and the
  /// reserves (Team tab). Null leaves every card as a plain, non-draggable
  /// card — the pre-match and live surfaces.
  final SquadSwapping? swapping;

  @override
  Widget build(BuildContext context) {
    final teamRating = xi.isEmpty
        ? 0
        : (xi.values.fold<int>(0, (a, c) => a + c.overall) / xi.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FcmEntrance(
          child: _ControlCard(
            teamRating: teamRating,
            formationCode: formationCode,
            tactics: tactics,
            mentality: mentality,
            onFormation: onFormation,
            onAutoPick: onAutoPick,
            onTactics: () => showTacticsOptionsSheet(
              context,
              tactics: tactics,
              mentality: mentality,
              onTactics: onTactics,
              onMentality: onMentality,
            ),
          ),
        ),
        const SizedBox(height: 14),
        // The pitch and both strips share one drag scope when swapping is
        // on, so a card can be carried from any of them onto any other.
        _maybeSwapScope(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (swapping != null) const SquadSwapHint(),
              FcmEntrance(
                index: 1,
                child: SquadPitch(
                  formation: formationByCode(formationCode),
                  assignments: xi,
                  showStamina: showStamina,
                  showStats: showStats,
                  onPlayerTap: onPlayerTap,
                ),
              ),
              // Bench and reserves never hide: the sections stay with
              // their full quota of slots, unassigned ones rendered as
              // empty cards (GDD 11 — the 23-man surface is always
              // visible as a whole).
              FcmSectionTitle('Bench (${bench.length}/${Formation.benchSize})'),
              SquadCardRow(
                cards: bench,
                emptySlots: Formation.benchSize - bench.length,
                zone: SquadZone.bench,
                showStamina: showStamina,
                showStats: showStats,
                onPlayerTap: onPlayerTap,
              ),
              if (showReserves) ...[
                FcmSectionTitle(
                  'Reserves (${reserves.length}/${Formation.reservesSize})',
                ),
                SquadCardRow(
                  cards: reserves,
                  emptySlots: Formation.reservesSize - reserves.length,
                  zone: SquadZone.reserves,
                  showStamina: showStamina,
                  showStats: showStats,
                  onPlayerTap: onPlayerTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _maybeSwapScope(Widget child) => swapping == null
      ? child
      : SquadDragHost(swapping: swapping!, child: child);
}

/// The single control card of the tactics screen. Its top row carries
/// the setup summary — playing style, mentality — and closes with the
/// team rating on the right; every block shrinks to fit, so the row
/// never overflows. Under it the formation dropdown sits DIRECTLY on the
/// card (one tap switches shape; the pitch below re-picks its slots),
/// and the Auto Pick (when the surface owns squad persistence) and
/// TACTICS buttons close the card on a full-width row.
class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.teamRating,
    required this.formationCode,
    required this.tactics,
    required this.mentality,
    required this.onFormation,
    required this.onTactics,
    this.onAutoPick,
  });

  final int teamRating;
  final String formationCode;
  final TeamTactics tactics;
  final Mentality mentality;
  final ValueChanged<String> onFormation;
  final VoidCallback onTactics;
  final VoidCallback? onAutoPick;

  @override
  Widget build(BuildContext context) {
    final formation = formationByCode(formationCode);
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _info('TACTICS', tactics.label)),
              const SizedBox(width: 12),
              Flexible(child: _info('MENTALITY', mentality.displayName)),
              const Spacer(),
              _rating(),
            ],
          ),
          const SizedBox(height: 8),
          // The formation picker, directly on the setup card: the closed
          // field shows the live shape ('4-3-3'), tapping lists every
          // formation — no detour into the tactic options sheet.
          FcmDropdown<String>(
            icon: Icons.grid_on_rounded,
            items: [
              for (final f in formations)
                FcmDropdownItem(value: f.code, label: f.name),
            ],
            selected: formation.code,
            onChanged: onFormation,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (onAutoPick != null) ...[
                Expanded(
                  child: FcmButton(
                    compact: true,
                    style: FcmButtonStyle.steel,
                    icon: Icons.auto_awesome,
                    label: 'Auto Pick',
                    onPressed: onAutoPick,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: FcmButton(
                  compact: true,
                  icon: Icons.tune_rounded,
                  label: 'TACTICS',
                  onPressed: onTactics,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One labelled setup value of the control card's top row: a dim
  /// mini-label over the value, shrinking to fit its share of the row.
  Widget _info(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      FitText(
        label,
        style: const TextStyle(
          color: FcmColors.textDim,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 2),
      FitText(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  /// The team rating closing the setup row: dim label over the big
  /// colour-coded number, right-aligned.
  Widget _rating() => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'TEAM RATING',
        textAlign: TextAlign.end,
        style: TextStyle(
          color: FcmColors.textDim,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 2),
      FcmCountUp(
        value: teamRating,
        style: TextStyle(
          color: ratingColor(teamRating),
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    ],
  );
}

/// Opens the tactic options sheet (GDD 10): the custom-tactics sections
/// and the mentality scale slider — every option listing its visible
/// percentage effects. The formation lives directly on the control
/// card, not here. Selections apply immediately through the owner's
/// callbacks (mentality commits on drag release); DONE closes the sheet.
Future<void> showTacticsOptionsSheet(
  BuildContext context, {
  required TeamTactics tactics,
  required Mentality mentality,
  required ValueChanged<TeamTactics> onTactics,
  required ValueChanged<Mentality> onMentality,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FcmColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TacticsOptionsSheet(
      initialTactics: tactics,
      initialMentality: mentality,
      onTactics: onTactics,
      onMentality: onMentality,
    ),
  );
}

class _TacticsOptionsSheet extends StatefulWidget {
  const _TacticsOptionsSheet({
    required this.initialTactics,
    required this.initialMentality,
    required this.onTactics,
    required this.onMentality,
  });

  final TeamTactics initialTactics;
  final Mentality initialMentality;
  final ValueChanged<TeamTactics> onTactics;
  final ValueChanged<Mentality> onMentality;

  @override
  State<_TacticsOptionsSheet> createState() => _TacticsOptionsSheetState();
}

class _TacticsOptionsSheetState extends State<_TacticsOptionsSheet> {
  late TeamTactics _tactics = widget.initialTactics;
  late int _mentalityScale = mentalityToScale(widget.initialMentality);

  /// The last mentality handed to the owner — drags that land back on
  /// the same step never re-commit it. Mutable: it moves with every
  /// committed drag.
  late Mentality _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.initialMentality;
  }

  /// A released drag commits the step it landed on — one callback per
  /// gesture, never per intermediate tick.
  void _commitMentality(int scale) {
    final m = mentalityFromScale(scale);
    if (m == _committed) return;
    _committed = m;
    widget.onMentality(m);
  }

  @override
  Widget build(BuildContext context) {
    final mentality = mentalityFromScale(_mentalityScale);
    // The three instruction sections plus the mentality scale can grow
    // past the viewport (phases 1-3 add controls), so the sheet scrolls
    // inside a height cap instead of overflowing.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: FcmColors.bronze.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'TACTIC OPTIONS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FcmColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              TacticsGroupScaffold(
                tactics: _tactics,
                onChanged: (t) => setState(() {
                  _tactics = t;
                  widget.onTactics(t);
                }),
              ),
              const SizedBox(height: 12),
              // Mentality as a 0–100 scale: Very Defensive at 0, Very
              // Attacking at 100, Balanced dead centre — the marker's
              // label names the step it rides on, and the effect summary
              // under the track updates as steps are crossed (GDD 10.3:
              // effects must be visible).
              _labeledRow(
                label: 'MENTALITY',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FcmScaleSlider(
                      value: _mentalityScale,
                      // Stepped mode (T-0062): the seven mentalities are
                      // the scale's named steps — the marker follows the
                      // finger but only ever commits/rests on a step,
                      // and the reported scale is always a step
                      // position, so mentalityFromScale(scale) maps
                      // exactly as before.
                      steps: Mentality.values.length,
                      valueLabel: (v) => mentalityFromScale(v).displayName,
                      minLabel: Mentality.veryDefensive.displayName,
                      maxLabel: Mentality.veryAttacking.displayName,
                      semanticsLabel: 'Mentality',
                      onChanged: (v) => setState(() => _mentalityScale = v),
                      onChangeEnd: _commitMentality,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      mentality.effectSummary,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FcmColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FcmButton(
                icon: Icons.check_rounded,
                label: 'DONE',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labeledRow({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FcmColors.textDim,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
