/// FCM Rivals — custom tactics sections scaffold (GDD 10.2).
///
/// Phase 0 UI: the three instruction groups — In Possession, Out of
/// Possession, Transitions — rendered as section headers with their
/// current state. The instruction controls arrive with phases 1-3,
/// each phase adding its segmented rows to its section here. Every
/// section header and state line is localized EN + AR (the removed
/// playing-style display names never were — these labels must be).
///
/// Used by the tactic options sheet (Team tab), the pre-match tactics
/// phase and the live tactics screen — one surface, three hosts.
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_scale_slider.dart';
import '../../l10n/l10n_context.dart';
import 'tactics.dart';

/// The three-section tactics scaffold bound to a [TeamTactics].
///
/// [onChanged] fires with the full updated tactics object on every
/// instruction change (phases 1-3); phase 0 renders the default state
/// of each section and never fires.
class TacticsGroupScaffold extends StatelessWidget {
  const TacticsGroupScaffold({
    super.key,
    required this.tactics,
    required this.onChanged,
  });

  final TeamTactics tactics;
  final ValueChanged<TeamTactics> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          icon: Icons.sports_soccer_rounded,
          title: l10n.tacticsInPossessionTitle,
          child: _InPossessionControls(tactics: tactics, onChanged: onChanged),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.shield_rounded,
          title: l10n.tacticsOutOfPossessionTitle,
          child: _OutOfPossessionControls(
            tactics: tactics,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.swap_horiz_rounded,
          title: l10n.tacticsTransitionsTitle,
          child: _TransitionsControls(tactics: tactics, onChanged: onChanged),
        ),
      ],
    );
  }
}

/// One section: icon + localized header, then the instruction
/// controls the phases add. Names only — the always-on effect
/// summaries are gone (owner decision 2026-11-09, GDD 10.3 update).
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// In Possession instruction controls (phase 1): four segmented rows —
/// build-up, tempo, width, final-third approach — each option carrying
/// readout that updates as options change.
class _InPossessionControls extends StatelessWidget {
  const _InPossessionControls({required this.tactics, required this.onChanged});

  final TeamTactics tactics;
  final ValueChanged<TeamTactics> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final ip = tactics.inPossession;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SliderRow<BuildUpStyle>(
          label: l10n.tacticsBuildUp,
          values: BuildUpStyle.values,
          selected: ip.buildUp,
          display: (v) => switch (v) {
            BuildUpStyle.playOut => l10n.buildUpPlayOut,
            BuildUpStyle.mixed => l10n.buildUpMixed,
            BuildUpStyle.longBall => l10n.buildUpLongBall,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(inPossession: ip.copyWith(buildUp: v)),
          ),
        ),
        const SizedBox(height: 8),
        _SliderRow<AttackTempo>(
          label: l10n.tacticsTempo,
          values: AttackTempo.values,
          selected: ip.tempo,
          display: (v) => switch (v) {
            AttackTempo.slow => l10n.tempoSlow,
            AttackTempo.standard => l10n.tempoStandard,
            AttackTempo.fast => l10n.tempoFast,
          },
          onSelect: (v) =>
              onChanged(tactics.copyWith(inPossession: ip.copyWith(tempo: v))),
        ),
        const SizedBox(height: 8),
        _SliderRow<AttackWidth>(
          label: l10n.tacticsWidth,
          values: AttackWidth.values,
          selected: ip.width,
          display: (v) => switch (v) {
            AttackWidth.narrow => l10n.widthNarrow,
            AttackWidth.standard => l10n.widthStandardWidth,
            AttackWidth.wide => l10n.widthWide,
          },
          onSelect: (v) =>
              onChanged(tactics.copyWith(inPossession: ip.copyWith(width: v))),
        ),
        const SizedBox(height: 8),
        _SegmentedRow<FinalThirdApproach>(
          label: l10n.tacticsFinalThird,
          values: FinalThirdApproach.values,
          selected: ip.finalThird,
          display: (v) => switch (v) {
            FinalThirdApproach.workBallIntoBox => l10n.finalThirdWorkBall,
            FinalThirdApproach.balanced => l10n.finalThirdBalanced,
            FinalThirdApproach.earlyCrosses => l10n.finalThirdEarlyCrosses,
            FinalThirdApproach.shootOnSight => l10n.finalThirdShootOnSight,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(inPossession: ip.copyWith(finalThird: v)),
          ),
        ),
      ],
    );
  }
}

/// One labelled segmented-control row: label + chips for every
/// option — names only (owner decision 2026-11-09).
class _SegmentedRow<T extends Enum> extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.display,
    required this.onSelect,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) display;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final v in values)
              _OptionChip(
                label: display(v),
                selected: v == selected,
                onTap: () => onSelect(v),
              ),
          ],
        ),
      ],
    );
  }
}


/// One ordered-instruction axis as a stepped scale slider (T-0064):
/// the axis label and the shared branded slider with one named step
/// per enum value — names only (owner decision 2026-11-09). Scale-0 is
/// the safe end,
/// scale-100 the aggressive end (the T-0063 polarity table) — `values`
/// order IS that polarity, so `values.first` labels the minimum end and
/// `values.last` the maximum.
///
/// One commit per gesture: `onChangeEnd` fires the owner's [onSelect]
/// with the full updated tactics object; intermediate ticks only move
/// the marker, the pill. Categorical axes
/// (`FinalThirdApproach`) and bools (the offside trap) are NOT scales —
/// they keep their chip row / toggle.
class _SliderRow<T extends Enum> extends StatefulWidget {
  const _SliderRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.display,
    required this.onSelect,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) display;
  final ValueChanged<T> onSelect;

  @override
  State<_SliderRow<T>> createState() => _SliderRowState<T>();
}

class _SliderRowState<T extends Enum> extends State<_SliderRow<T>> {
  /// The row's live scale position — the committed step at rest, the
  /// finger's snapped step during a drag (the pill under the track
  /// follows it live).
  late int _scale = enumToScale(widget.values, widget.selected);

  @override
  void didUpdateWidget(_SliderRow<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the owner's committed step unless it is just echoing our
    // own release back at us (the slider guards the same seam).
    if (widget.selected != oldWidget.selected) {
      final committed = enumToScale(widget.values, widget.selected);
      if (committed != _scale) _scale = committed;
    }
  }

  void _onChanged(int v) => setState(() => _scale = v);

  void _onCommit(int v) {
    setState(() => _scale = v);
    widget.onSelect(enumFromScale(widget.values, v));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        FcmScaleSlider(
          value: enumToScale(widget.values, widget.selected),
          steps: widget.values.length,
          valueLabel: (v) => widget.display(
            enumFromScale(widget.values, v),
          ),
          minLabel: widget.display(widget.values.first),
          maxLabel: widget.display(widget.values.last),
          semanticsLabel: widget.label,
          onChanged: _onChanged,
          onChangeEnd: _onCommit,
        ),
      ],
    );
  }
}

/// A compact selectable chip matching the app's tactic-option look.
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Out of Possession instruction controls (phase 2): three segmented
/// rows plus the offside-trap toggle. The toggle WARNS when the
/// defensive line is Deep — a deep trap has no benefit, only risk, and
/// the UI must teach that trade-off (GDD 10.3).
class _OutOfPossessionControls extends StatelessWidget {
  const _OutOfPossessionControls({
    required this.tactics,
    required this.onChanged,
  });

  final TeamTactics tactics;
  final ValueChanged<TeamTactics> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final oop = tactics.outOfPossession;
    final deepLine = oop.defensiveLine == DefensiveLine.deep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SliderRow<DefensiveLine>(
          label: l10n.tacticsDefensiveLine,
          values: DefensiveLine.values,
          selected: oop.defensiveLine,
          display: (v) => switch (v) {
            DefensiveLine.deep => l10n.lineDeep,
            DefensiveLine.standard => l10n.lineStandard,
            DefensiveLine.high => l10n.lineHigh,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(outOfPossession: oop.copyWith(defensiveLine: v)),
          ),
        ),
        const SizedBox(height: 8),
        _SliderRow<PressingIntensity>(
          label: l10n.tacticsPressing,
          values: PressingIntensity.values,
          selected: oop.pressing,
          display: (v) => switch (v) {
            PressingIntensity.low => l10n.pressLow,
            PressingIntensity.mid => l10n.pressMid,
            PressingIntensity.high => l10n.pressHigh,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(outOfPossession: oop.copyWith(pressing: v)),
          ),
        ),
        const SizedBox(height: 8),
        _SliderRow<TacklingAggression>(
          label: l10n.tacticsTackling,
          values: TacklingAggression.values,
          selected: oop.tackling,
          display: (v) => switch (v) {
            TacklingAggression.clean => l10n.tackleClean,
            TacklingAggression.balanced => l10n.tackleBalanced,
            TacklingAggression.aggressive => l10n.tackleAggressive,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(outOfPossession: oop.copyWith(tackling: v)),
          ),
        ),
        const SizedBox(height: 8),
        // The offside trap toggle with its trade-off warning.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.tacticsOffsideTrap,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            _OptionChip(
              label: oop.offsideTrap ? l10n.trapOn : l10n.trapOff,
              selected: oop.offsideTrap,
              onTap: () => onChanged(
                tactics.copyWith(
                  outOfPossession: oop.copyWith(offsideTrap: !oop.offsideTrap),
                ),
              ),
            ),
          ],
        ),
        if (deepLine && oop.offsideTrap)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.trapDeepWarning,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Transitions instruction controls (phase 3): counter-press, attack
/// on recovery and rest defence — names only (owner decision
/// 2026-11-09).
class _TransitionsControls extends StatelessWidget {
  const _TransitionsControls({required this.tactics, required this.onChanged});

  final TeamTactics tactics;
  final ValueChanged<TeamTactics> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final tr = tactics.transitions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SliderRow<CounterPress>(
          label: l10n.tacticsCounterPress,
          values: CounterPress.values,
          selected: tr.counterPress,
          display: (v) => switch (v) {
            CounterPress.retreat => l10n.cpRetreat,
            CounterPress.balanced => l10n.cpBalanced,
            CounterPress.immediate => l10n.cpImmediate,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(transitions: tr.copyWith(counterPress: v)),
          ),
        ),
        const SizedBox(height: 8),
        _SliderRow<AttackOnRecovery>(
          label: l10n.tacticsAttackOnRecovery,
          values: AttackOnRecovery.values,
          selected: tr.attackOnRecovery,
          display: (v) => switch (v) {
            AttackOnRecovery.patient => l10n.arPatient,
            AttackOnRecovery.balanced => l10n.arBalanced,
            AttackOnRecovery.fast => l10n.arFast,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(transitions: tr.copyWith(attackOnRecovery: v)),
          ),
        ),
        const SizedBox(height: 8),
        _SliderRow<RestDefence>(
          label: l10n.tacticsRestDefence,
          values: RestDefence.values,
          selected: tr.restDefence,
          display: (v) => switch (v) {
            RestDefence.conservative => l10n.rdConservative,
            RestDefence.standard => l10n.rdStandard,
            RestDefence.aggressive => l10n.rdAggressive,
          },
          onSelect: (v) => onChanged(
            tactics.copyWith(transitions: tr.copyWith(restDefence: v)),
          ),
        ),
      ],
    );
  }
}
