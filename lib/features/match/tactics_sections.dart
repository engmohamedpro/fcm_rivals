/// FCM Rivals — custom tactics sections scaffold (GDD 10.2).
///
/// The three instruction groups — In Possession, Out of Possession,
/// Transitions — each a stack of continuous 0–99 sliders (name, number
/// and slider in one row, a pill above the thumb saying what the number
/// means) so every player can shape a unique custom tactic. Section
/// headers are localized EN + AR; the slider wording lives in
/// `tactic_axis_copy.dart`.
///
/// Used by the tactic options sheet (Team tab), the pre-match tactics
/// phase and the live tactics screen — one surface, three hosts.
library;

import 'package:flutter/material.dart';

import '../../l10n/l10n_context.dart';
import 'tactic_slider_row.dart';
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
          child: InPossessionControls(tactics: tactics, onChanged: onChanged),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.shield_rounded,
          title: l10n.tacticsOutOfPossessionTitle,
          child: OutOfPossessionControls(
            tactics: tactics,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.swap_horiz_rounded,
          title: l10n.tacticsTransitionsTitle,
          child: TransitionsControls(tactics: tactics, onChanged: onChanged),
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

/// In Possession instruction controls: build-up, tempo, width, final
/// third and crossing — five 0–99 sliders.
class InPossessionControls extends StatelessWidget {
  const InPossessionControls({required this.tactics, required this.onChanged});

  final TeamTactics tactics;
  final ValueChanged<TeamTactics> onChanged;

  @override
  Widget build(BuildContext context) {
    final ip = tactics.inPossession;
    return _SliderStack(
      rows: [
        for (final axis in InPossessionTactics.axes)
          TacticSliderRow(
            key: ValueKey(axis),
            axis: axis,
            value: ip.scaleOf(axis),
            onCommit: (v) => onChanged(
              tactics.copyWith(inPossession: ip.withScale(axis, v)),
            ),
          ),
      ],
    );
  }
}

/// Rows with the section's standard vertical rhythm.
class _SliderStack extends StatelessWidget {
  const _SliderStack({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          rows[i],
        ],
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

/// Out of Possession instruction controls: defensive line, pressing and
/// tackling sliders plus the offside-trap switch. The switch WARNS when
/// the defensive line is Deep — a deep trap has no benefit, only risk,
/// and the UI must teach that trade-off (GDD 10.3). The trap is on or
/// off, not a scale, so it stays a switch.
class OutOfPossessionControls extends StatelessWidget {
  const OutOfPossessionControls({
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
        _SliderStack(
          rows: [
            for (final axis in OutOfPossessionTactics.axes)
              TacticSliderRow(
                key: ValueKey(axis),
                axis: axis,
                value: oop.scaleOf(axis),
                onCommit: (v) => onChanged(
                  tactics.copyWith(outOfPossession: oop.withScale(axis, v)),
                ),
              ),
          ],
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

/// Transitions instruction controls: counter-press, attack on recovery
/// and rest defence — three 0–99 sliders.
class TransitionsControls extends StatelessWidget {
  const TransitionsControls({required this.tactics, required this.onChanged});

  final TeamTactics tactics;
  final ValueChanged<TeamTactics> onChanged;

  @override
  Widget build(BuildContext context) {
    final tr = tactics.transitions;
    return _SliderStack(
      rows: [
        for (final axis in TransitionTactics.axes)
          TacticSliderRow(
            key: ValueKey(axis),
            axis: axis,
            value: tr.scaleOf(axis),
            onCommit: (v) => onChanged(
              tactics.copyWith(transitions: tr.withScale(axis, v)),
            ),
          ),
      ],
    );
  }
}
