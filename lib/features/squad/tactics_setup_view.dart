/// FCM Rivals — tactics setup surface (GDD 10/11).
///
/// The setup column (the control card and the tactic options sheet),
/// split verbatim out of `squad_view.dart` (T-0042); the pitch family
/// lives in `squad_pitch_view.dart` and `squad_view.dart` re-exports
/// both.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_context.dart';
import '../match/chemistry.dart';
import '../match/tactics.dart';
import '../match/tactic_slider_row.dart';
import '../match/tactics_sections.dart';
import 'formations.dart';
import 'squad_drag.dart';
import 'squad_engine.dart';
import 'squad_pitch_view.dart';
import 'squad_swap.dart' show SquadDropTarget, SquadZone;

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
    this.onClear,
    this.poolTitle,
    this.poolSelectedIds = const {},
    this.poolCapacity,
    this.poolTrailing,
    this.showStamina = true,
    this.showStats = true,
    this.showCondition = true,
    this.showReserves = true,
    this.showSetupSummary = true,
    this.onPlayerTap,
    this.upgradable,
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

  /// Shows the Clear button beside Auto Pick: empties the whole saved
  /// squad (XI, bench and reserves). Null hides it.
  final VoidCallback? onClear;

  /// When non-null the lower strip is the ALL-PLAYERS POOL (Team tab):
  /// [reserves] then holds every owned card outside the XI and bench,
  /// shown as a wrapping grid under this title, and doubles as the drop
  /// zone that takes a player out of the squad.
  final String? poolTitle;

  /// Owned ids already in the XI / bench: shown faded with a check in the
  /// pool strip.
  final Set<int> poolSelectedIds;

  /// The club's squad capacity: the pool title then reads
  /// 'All players (N/capacity)' instead of the bare count.
  final int? poolCapacity;

  /// Sits at the end of the pool title row (the buy-slots button).
  final Widget? poolTrailing;

  /// Whether cards carry their stamina bar. The pre-match and live
  /// tactics surfaces show match-day fitness; the Team tab hides it —
  /// the saved setup is about identity, not current match state.
  final bool showStamina;

  /// Whether cards carry their three-column stat row (ATT/SUP/DEF …).
  /// No surface shows it today — the setup surfaces stay about shape,
  /// not attributes; kept for callers that opt in.
  final bool showStats;

  /// Whether cards carry MATCH-DAY CONDITION chrome (T-0117) — the
  /// injury badge and the injured cards' inert treatment. The Team
  /// tab passes false (pure management surface); pre-match/live keep
  /// the matchday truth.
  final bool showCondition;

  /// Whether the reserves strip renders at all. The Team tab and the
  /// pre-match phase show the full 23-man surface; the LIVE tactics
  /// editor hides it — a match day squad has nobody beyond the bench.
  final bool showReserves;

  /// Whether the control card opens with the three-part setup summary
  /// row — TACTICS / MENTALITY / TEAM RATING (T-0092): the Team tab
  /// drops it (the pitch already tells the rating story), while the
  /// pre-match and live surfaces keep the default and the row.
  final bool showSetupSummary;

  /// Opens the player detail sheet; null makes the cards non-tappable.
  final void Function(PlayerCard card)? onPlayerTap;

  /// Upgradable marks (T-0089): true when the club owns a duplicate of
  /// the base player — the gold up-arrow pill on the card. Null shows
  /// no mark anywhere (pre-match and live surfaces).
  final bool Function(int playerId)? upgradable;

  /// Enables hold-and-drag swapping between the pitch, the bench and the
  /// reserves (Team tab). Null leaves every card as a plain, non-draggable
  /// card — the pre-match and live surfaces.
  final SquadSwapping? swapping;

  @override
  Widget build(BuildContext context) {
    final teamRating = xi.isEmpty
        ? 0
        : (xi.values.fold<int>(0, (a, c) => a + c.overall) / xi.length).round();
    // The XI's nationality chemistry (T-0067 formula, T-0069 display,
    // T-0080 moved to the pitch badge): the starting slots only —
    // bench/reserves never count.
    final chemistry = chemistryPercentOf([
      for (var slot = 0; slot < 11; slot++) xi[slot]?.base.nationality,
    ]);

    return _PickScope(
      builder: (context, pulse, bump) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FcmEntrance(
          child: _ControlCard(
            pickPulse: pulse,
            onClear: onClear,
            teamRating: teamRating,
            chemistry: chemistry,
            formationCode: formationCode,
            tactics: tactics,
            mentality: mentality,
            showSetupSummary: showSetupSummary,
            onFormation: onFormation,
            onAutoPick: onAutoPick == null
                ? null
                : () {
                    // Feedback first (button check + pitch sweep), then
                    // the pick itself.
                    bump();
                    onAutoPick!();
                  },
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
              FcmEntrance(
                index: 1,
                child: _PickFlash(
                  trigger: pulse,
                  child: SquadPitch(
                    formation: formationByCode(formationCode),
                    assignments: xi,
                    showChemistryLinks: true,
                    showStamina: showStamina,
                    showStats: showStats,
                    showCondition: showCondition,
                    onPlayerTap: onPlayerTap,
                    upgradable: upgradable,
                  ),
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
                showCondition: showCondition,
                onPlayerTap: onPlayerTap,
                upgradable: upgradable,
              ),
              if (showReserves && poolTitle != null) ...[
                FcmSectionTitle(
                  poolCapacity == null
                      ? '$poolTitle (${reserves.length})'
                      : '$poolTitle (${reserves.length}/$poolCapacity)',
                  trailing: poolTrailing,
                ),
                SquadDropZone(
                  target: const SquadDropTarget.emptyIn(SquadZone.reserves),
                  child: SquadCardRow(
                    cards: reserves,
                    // An empty pool keeps one ghost place so a player can
                    // still be dropped into it.
                    emptySlots: reserves.isEmpty ? 1 : 0,
                    zone: SquadZone.reserves,
                    selectedIds: poolSelectedIds,
                    showStamina: showStamina,
                    showStats: showStats,
                    onPlayerTap: onPlayerTap,
                    upgradable: upgradable,
                  ),
                ),
              ] else if (showReserves) ...[
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
                  upgradable: upgradable,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
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
    required this.chemistry,
    required this.formationCode,
    required this.tactics,
    required this.mentality,
    required this.onFormation,
    required this.onTactics,
    this.onAutoPick,
    this.showSetupSummary = true,
    this.pickPulse = 0,
    this.onClear,
  });

  final VoidCallback? onClear;

  /// Bumps on every Auto Pick tap — drives the button's "done" state.
  final int pickPulse;

  final int teamRating;

  /// The XI's nationality chemistry, 0..10 — always shown (+0% for an
  /// empty or all-distinct XI).
  final int chemistry;
  final String formationCode;
  final TeamTactics tactics;
  final Mentality mentality;
  final ValueChanged<String> onFormation;
  final VoidCallback onTactics;
  final VoidCallback? onAutoPick;

  /// See [TacticsSetupView.showSetupSummary] — the row renders only
  /// when true (T-0092).
  final bool showSetupSummary;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final formation = formationByCode(formationCode);
    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The scoreboard row, on every surface: the team rating at the
          // start, the XI's chemistry at the end.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_rating(), const Spacer(), _chemistry()],
          ),
          const SizedBox(height: 10),
          // The setup summary row (T-0092): Team tab opts out.
          if (showSetupSummary) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _info('TACTICS', tactics.label)),
              const SizedBox(width: 12),
              Flexible(
                child: _info(
                  l10n.tacticsMentality.toUpperCase(),
                  mentalityDisplayName(l10n, mentality),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ],
          // The formation picker, directly on the setup card: the closed
          // field shows the live shape ('4-3-3'), tapping lists every
          // formation — no detour into the tactic options sheet.
          // Formation picker with the TACTICS button beside it.
          Row(
            children: [
              Expanded(
                flex: 5,
                child: FcmDropdown<String>(
                  icon: Icons.grid_on_rounded,
                  items: [
                    for (final f in formations)
                      FcmDropdownItem(value: f.code, label: f.name),
                  ],
                  selected: formation.code,
                  onChanged: onFormation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: FcmButton(
                  compact: true,
                  icon: Icons.tune_rounded,
                  label: 'TACTICS',
                  onPressed: onTactics,
                ),
              ),
            ],
          ),
          if (onAutoPick != null) ...[
            const SizedBox(height: 8),
            // Clear first, Auto Pick second.
            Row(
              children: [
                if (onClear != null) ...[
                  Expanded(
                    child: FcmButton(
                      compact: true,
                      style: FcmButtonStyle.ghost,
                      icon: Icons.layers_clear_rounded,
                      label: 'Clear',
                      onPressed: onClear,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _AutoPickButton(
                    pulse: pickPulse,
                    onPressed: onAutoPick!,
                  ),
                ),
              ],
            ),
          ],
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

  /// The team rating opening the scoreboard row: dim label over the big
  /// colour-coded number, start-aligned.
  Widget _rating() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'TEAM RATING',
        textAlign: TextAlign.start,
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

  /// The XI's chemistry closing the scoreboard row: link icon + dim
  /// label over the big '+N%' (dim at 0, the rating colour ramp above),
  /// end-aligned.
  Widget _chemistry() => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_rounded, size: 12, color: FcmColors.gold),
          const SizedBox(width: 4),
          Builder(
            builder: (context) => Text(
              l10nOf(context).teamChemistry.toUpperCase(),
              maxLines: 1,
              style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      FcmCountUp(
        value: chemistry,
        format: (n) => '+$n%',
        style: TextStyle(
          color: chemistry >= 1
              ? ratingColor(70 + chemistry * 3)
              : FcmColors.textDim,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    ],
  );
}

/// A mentality's localized display name (T-0064): the seven steps read
/// their ARB names in both locales — `Mentality.displayName` stays the
/// engine-facing English constant and is no longer shown to the user.
String mentalityDisplayName(AppLocalizations l10n, Mentality m) =>
    switch (m) {
      Mentality.veryDefensive => l10n.mentalityVeryDefensive,
      Mentality.defensive => l10n.mentalityDefensive,
      Mentality.cautious => l10n.mentalityCautious,
      Mentality.balanced => l10n.mentalityBalanced,
      Mentality.positive => l10n.mentalityPositive,
      Mentality.attacking => l10n.mentalityAttacking,
      Mentality.veryAttacking => l10n.mentalityVeryAttacking,
    };

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

  /// The last mentality handed to the owner — drags that stay inside
  /// the same step never re-commit it. Mutable: it moves with every
  /// committed drag.
  late Mentality _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.initialMentality;
  }

  /// A released drag commits once: the fine position rides in the
  /// tactics, and the step it landed on goes to the mentality when it
  /// changed.
  void _commitMentality(int scale) {
    final m = mentalityOfScale(scale);
    setState(() => _tactics = _tactics.withMentalityScale(scale));
    widget.onTactics(_tactics);
    if (m == _committed) return;
    _committed = m;
    widget.onMentality(m);
  }

  @override
  Widget build(BuildContext context) {
    // The three instruction sections plus the mentality scale can grow
    // past the viewport (phases 1-3 add controls), so the sheet scrolls
    // inside a height cap instead of overflowing.
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // T-0095: a compact sheet — 62% of the screen leaves the
          // pitch context visible behind it instead of a takeover.
          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
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
              // Mentality is the first slider: 0 Very Defensive … 99 Very
              // Attacking, Balanced at 50, like every other tactic.
              TacticSliderRow(
                axis: TacticAxisId.mentality,
                value: _tactics.mentalityScaleFor(_committed),
                onCommit: _commitMentality,
              ),
              const SizedBox(height: 12),
              TacticsGroupScaffold(
                tactics: _tactics,
                onChanged: (t) => setState(() {
                  _tactics = t;
                  widget.onTactics(t);
                }),
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
}

/// Holds the Auto Pick tap counter that the button and the pitch both
/// react to (no snackbar: the feedback is the button check + the sweep
/// over the pitch).
class _PickScope extends StatefulWidget {
  const _PickScope({required this.builder});

  final Widget Function(BuildContext context, int pulse, VoidCallback bump)
  builder;

  @override
  State<_PickScope> createState() => _PickScopeState();
}

class _PickScopeState extends State<_PickScope> {
  int _pulse = 0;

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _pulse, () => setState(() => _pulse++));
}

/// The Auto Pick button: after a tap it flips to a green "Picked" with a
/// check that pops in, then settles back (an animation, not a timer, so
/// it ends cleanly with the widget).
class _AutoPickButton extends StatefulWidget {
  const _AutoPickButton({required this.pulse, required this.onPressed});

  final int pulse;
  final VoidCallback onPressed;

  @override
  State<_AutoPickButton> createState() => _AutoPickButtonState();
}

class _AutoPickButtonState extends State<_AutoPickButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didUpdateWidget(_AutoPickButton old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final done = _c.isAnimating;
        // A quick overshoot pop over the first 280ms.
        final pop = done
            ? 1.0 + 0.08 * math.sin(math.pi * (_c.value * 6.4).clamp(0.0, 1.0))
            : 1.0;
        return Transform.scale(
          scale: pop,
          child: FcmButton(
            compact: true,
            style: done ? FcmButtonStyle.success : FcmButtonStyle.steel,
            icon: done ? Icons.check_circle_rounded : Icons.auto_awesome,
            label: done ? 'Picked' : 'Auto Pick',
            onPressed: widget.onPressed,
          ),
        );
      },
    );
  }
}

/// A one-shot "applied" flourish over [child]: a gold light sweeps across
/// it and it breathes slightly, each time [trigger] changes.
class _PickFlash extends StatefulWidget {
  const _PickFlash({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_PickFlash> createState() => _PickFlashState();
}

class _PickFlashState extends State<_PickFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didUpdateWidget(_PickFlash old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        final live = _c.isAnimating;
        return Transform.scale(
          scale: 1 + 0.014 * math.sin(math.pi * _c.value),
          child: Stack(
            children: [
              child!,
              if (live)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(painter: _SweepPainter(t)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = -0.2 + 1.4 * t;
    double stop(double v) => v.clamp(0.0, 1.0);
    final fade = math.sin(math.pi * t);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -0.5),
          end: const Alignment(1, 0.5),
          colors: [
            Colors.transparent,
            FcmColors.goldSoft.withValues(alpha: 0.42 * fade),
            Colors.transparent,
          ],
          stops: [stop(centre - 0.16), stop(centre), stop(centre + 0.16)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.t != t;
}
