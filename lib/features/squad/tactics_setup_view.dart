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
import '../../l10n/l10n_context.dart';
import '../match/chemistry.dart';
import '../match/tactics.dart';
import 'formations.dart';
import 'squad_drag.dart';
import 'squad_engine.dart';
import 'squad_pitch_view.dart';
import 'squad_swap.dart' show SquadDropTarget, SquadZone;
import '../match/tactic_presets.dart';
import '../match/tactics_sections.dart'
    show InPossessionControls, OutOfPossessionControls, TransitionsControls;

/// The whole tactical setup column: the control card (the setup row —
/// tactics, formation — closed by the team rating, with the Auto Pick
/// and TACTICS actions under it), the pitch with the starting XI
/// (stamina bars and stat rows only when [showStamina] / [showStats]
/// ask for them), then the bench and reserves strips.
///
/// [formation] is the RESOLVED formation object (preset or custom —
/// see formations.dart): since the custom-formation feature the shape
/// is no longer always one of the presets, so callers hand the object
/// they got from `formationOfCode(club.formationCode)`; [onFormation]
/// still speaks codes (the preset dropdown's values), and a custom
/// shape shows 'Custom' selected.
class TacticsSetupView extends StatelessWidget {
  const TacticsSetupView({
    super.key,
    required this.formation,
    required this.tactics,
    required this.xi,
    required this.bench,
    required this.reserves,
    required this.onFormation,
    required this.onTactics,
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

  /// The club's current formation — a preset or the custom shape.
  final Formation formation;

  /// Current custom tactics selection (GDD 10.2). The mentality is no
  /// longer part of the SETUP surface (owner request 2026-11-13): it
  /// stays an engine value (live panel ladder, AI, saved column) and
  /// is simply not edited here.
  final TeamTactics tactics;

  /// Starting XI assignments: slot index → card.
  final Map<int, PlayerCard> xi;

  /// Bench and reserves cards, best-first.
  final List<PlayerCard> bench;
  final List<PlayerCard> reserves;

  /// Tactic change callbacks — the owner defines whether they persist
  /// (Team tab) or apply to one match only (pre-match phase).
  final ValueChanged<String> onFormation;
  final ValueChanged<TeamTactics> onTactics;

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

  /// Whether the control card opens with the setup summary row —
  /// TACTICS / FORMATION (T-0092, mentality dropped 2026-11-13): the
  /// Team tab drops it (the pitch already tells the rating story),
  /// while the pre-match and live surfaces keep the row.
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
    // The XI's chemistry (T-0067 formula, T-0069 display, T-0080 moved
    // to the pitch badge; club half added 2026-11-11): the starting
    // slots only — bench/reserves never count.
    final chemistry = totalChemistryPercentOf(
      nationalities: [
        for (var slot = 0; slot < 11; slot++) xi[slot]?.base.nationality,
      ],
      clubs: [
        for (var slot = 0; slot < 11; slot++)
          if (xi[slot] != null)
            clubChemistryKeyOf(xi[slot]!.base.clubId, xi[slot]!.base.clubName)
          else '',
      ],
      icons: [
        for (var slot = 0; slot < 11; slot++) xi[slot]?.base.isIcon ?? false,
      ],
    );

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
            formation: formation,
            tactics: tactics,
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
              onTactics: onTactics,
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
                    formation: formation,
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
                    // The pool pads with ghost places up to the club's
                    // capacity (or one when the capacity is unknown),
                    // so an emptied pool still invites a drop and the
                    // strip shows the real number of slots owned.
                    emptySlots: _poolGhosts(reserves.length, poolCapacity),
                    zone: SquadZone.reserves,
                    selectedIds: poolSelectedIds,
                    showStamina: showStamina,
                    showStats: showStats,
                    // T-0117 closes here too: the pool strip showed
                    // injury badges on the Team tab because this call
                    // missed the flag (the pitch and bench already
                    // passed it) — caught by the purity test.
                    showCondition: showCondition,
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

  /// Ghost places for the All-players pool: enough to fill the club's
  /// capacity when known, otherwise the single inviting drop slot.
  int _poolGhosts(int players, int? capacity) => capacity == null
      ? (players == 0 ? 1 : 0)
      : (capacity - players).clamp(0, capacity);
}

/// The single control card of the tactics screen. Its top row carries
/// the setup summary — tactics, formation — and closes with the team
/// rating on the right; every block shrinks to fit, so the row never
/// overflows. Under it the formation dropdown sits DIRECTLY on the
/// card (one tap switches shape; the pitch below re-picks its slots),
/// and the Auto Pick (when the surface owns squad persistence) and
/// TACTICS buttons close the card on a full-width row.
class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.teamRating,
    required this.chemistry,
    required this.formation,
    required this.tactics,
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

  /// The club's resolved formation (preset or custom).
  final Formation formation;
  final TeamTactics tactics;
  final ValueChanged<String> onFormation;
  final VoidCallback? onTactics;
  final VoidCallback? onAutoPick;

  /// See [TacticsSetupView.showSetupSummary] — the row renders only
  /// when true (T-0092).
  final bool showSetupSummary;

  @override
  Widget build(BuildContext context) {
    final isCustom = isCustomFormationCode(formation.code);
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
          // The setup summary row (T-0092): Team tab opts out. The
          // mentality chip is gone (owner request 2026-11-13) — the
          // summary carries the tactics only, one strong block.
          if (showSetupSummary) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _info('TACTICS', tactics.label)),
              const SizedBox(width: 12),
              Flexible(child: _info('FORMATION', formation.name)),
            ],
          ),
          const SizedBox(height: 8),
          ],
          // The formation picker, directly on the setup card: the closed
          // field shows the live shape ('4-3-3' — or 'Custom' when the
          // club plays a dragged-together shape), tapping lists every
          // preset. A custom shape is NOT in the list; picking any
          // preset replaces it (the custom code lives only in the club
          // row, so switching shapes simply overwrites it).
          Row(
            children: [
              Expanded(
                flex: 5,
                child: FcmDropdown<String>(
                  icon: Icons.grid_on_rounded,
                  items: [
                    // The custom shape, when active, leads the list as
                    // a selectable read-back (its label names the mix).
                    if (isCustom)
                      FcmDropdownItem(
                        value: formation.code,
                        label: 'Custom',
                        subtitle: [
                          for (final slot in formation.slots)
                            if (slot != formation.slots.first)
                              slot.position.code,
                        ].join(' · '),
                      ),
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

/// Opens the tactic options sheet (GDD 10): the custom-tactics
/// instructions split across three tabs — In Possession, Out of
/// Possession and Transitions — every option listing its visible
/// percentage effects. The formation lives directly on the control
/// card, not here; the mentality is GONE from this sheet (owner
/// request 2026-11-13 — it stays an engine concern, set from the live
/// match panel, and no longer clutters the setup). Selections apply
/// immediately through the owner's callback; DONE closes the sheet.
Future<void> showTacticsOptionsSheet(
  BuildContext context, {
  required TeamTactics tactics,
  required ValueChanged<TeamTactics> onTactics,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: FcmColors.surface,
    isScrollControlled: true,
    // The sheet draws its own bronze handle pill below the title area;
    // the theme's Material drag handle (bottomSheetTheme.showDragHandle)
    // stacked a SECOND bar above it — the duplicated lines at the top
    // (T-0127). One handle: ours.
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TacticsOptionsSheet(
      initialTactics: tactics,
      onTactics: onTactics,
    ),
  );
}

class _TacticsOptionsSheet extends StatefulWidget {
  const _TacticsOptionsSheet({
    required this.initialTactics,
    required this.onTactics,
  });

  final TeamTactics initialTactics;
  final ValueChanged<TeamTactics> onTactics;

  @override
  State<_TacticsOptionsSheet> createState() => _TacticsOptionsSheetState();
}

class _TacticsOptionsSheetState extends State<_TacticsOptionsSheet>
    with SingleTickerProviderStateMixin {
  late TeamTactics _tactics = widget.initialTactics;

  /// The sheet's own tab controller (three tabs, no host above to
  /// supply one — a bottom sheet lives outside any Scaffold's
  /// DefaultTabController).
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _change(TeamTactics t) => setState(() {
    _tactics = t;
    widget.onTactics(t);
  });

  @override
  Widget build(BuildContext context) {
    // The three instruction groups each have their own tab now (owner
    // request 2026-11-13): a tab bar under the title, one group per
    // page, DONE closing the sheet. The sheet stays compact — one
    // group fits the cap without scrolling most of the time.
    final l10n = l10nOf(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // T-0095: a compact sheet — 62% of the screen leaves the
          // pitch context visible behind it instead of a takeover.
          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
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
                  const SizedBox(height: 8),
                  // T-0129: tappable preset combinations. One row of
                  // chips under the title — a tap applies the whole
                  // combination at once; the sliders below still allow
                  // manual fine-tuning on top.
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      itemCount: tacticPresets.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final preset = tacticPresets[i];
                        final arabic =
                            Localizations.maybeLocaleOf(context)
                                ?.languageCode ==
                            'ar';
                        final selected = _tactics == preset.tactics;
                        return _PresetChip(
                          label: preset.label(arabic: arabic),
                          blurb: preset.blurb,
                          selected: selected,
                          onTap: () => _change(preset.tactics),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            TabBar(
              // The formation and mentality are both gone from here:
              // one instruction group per tab, nothing else.
              //
              // T-0128: text-only tabs so every label fits in full —
              // the icons plus text wrapped on 360dp screens, and a
              // wrapped Tab grows the bar to ~72dp+. Without icons the
              // default bar stays at its compact 48dp height and the
              // longest label ("Out of Possession") still fits.
              controller: _tabController,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              // T-0133: TabBar has no height parameter — the per-tab
              // Tab(height:) is the supported way to a compact 44dp bar.
              tabs: [
                Tab(height: 44, text: l10n.tacticsInPossessionTitle),
                Tab(height: 44, text: l10n.tacticsOutOfPossessionTitle),
                Tab(height: 44, text: l10n.tacticsTransitionsTitle),
              ],
            ),
            // The pages: each tab shows its own group's controls in a
            // scrollable pane (a short screen still reaches every
            // slider), sharing the one live tactics object.
            Flexible(
              child: _TacticsTabPages(
                controller: _tabController,
                tactics: _tactics,
                onChanged: _change,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FcmButton(
                icon: Icons.check_rounded,
                label: 'DONE',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The tabbed body of the tactic options sheet: one instruction group
/// per page (In Possession / Out of Possession / Transitions), each in
/// its own scroll pane, all bound to the same [tactics].
class _TacticsTabPages extends StatelessWidget {
  const _TacticsTabPages({
    required this.controller,
    required this.tactics,
    required this.onChanged,
  });

  final TabController controller;
  final TeamTactics tactics;
  final ValueChanged<TeamTactics> onChanged;

  @override
  Widget build(BuildContext context) {
    // Swiping between tabs is LOCKED: every pane's tactic rows are
    // horizontal sliders, and a swipeable TabBarView would compete for
    // the same horizontal drag — on a real device the user could not
    // move a slider without dragging the tab page sideways (the drag
    // test caught exactly this: the hit landed on the TabBarView's
    // viewport, not the slider). Tab switching stays on the tab bar
    // itself, which is how this sheet is meant to be driven.
    return TabBarView(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // T-0128: no title header inside the panes — the tab itself
        // names the group now.
        _GroupPane(child: InPossessionControls(tactics: tactics, onChanged: onChanged)),
        _GroupPane(
          child: OutOfPossessionControls(
            tactics: tactics,
            onChanged: onChanged,
          ),
        ),
        _GroupPane(child: TransitionsControls(tactics: tactics, onChanged: onChanged)),
      ],
    );
  }
}

/// One tab page: the group's controls inside a scrollable, padded pane.
class _GroupPane extends StatelessWidget {
  const _GroupPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    );
  }
}

/// One preset chip of the T-0129 row: gold-filled when the current
/// tactics are exactly the preset's combination, otherwise a quiet
/// outline chip. The blurb rides the semantics label for screen
/// readers without cluttering the row.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.blurb,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String blurb;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      hint: blurb,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: selected ? FcmColors.goldGradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? FcmColors.goldSoft.withValues(alpha: 0.5)
                  : FcmColors.bronze.withValues(alpha: 0.4),
            ),
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? FcmColors.ink : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
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
