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
          subtitle: l10n.tacticsInPossessionSubtitle,
          summary: tactics.inPossession.effectSummary,
          child: _InPossessionControls(tactics: tactics, onChanged: onChanged),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.shield_rounded,
          title: l10n.tacticsOutOfPossessionTitle,
          subtitle: l10n.tacticsOutOfPossessionSubtitle,
          summary: tactics.outOfPossession.effectSummary,
          child: const _PhasePlaceholder(
            key: ValueKey('outOfPossessionControls'),
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.swap_horiz_rounded,
          title: l10n.tacticsTransitionsTitle,
          subtitle: l10n.tacticsTransitionsSubtitle,
          summary: tactics.transitions.effectSummary,
          child: const _PhasePlaceholder(key: ValueKey('transitionsControls')),
        ),
      ],
    );
  }
}

/// One section: icon + localized header, the group's visible effect
/// summary (GDD 10.3), then the instruction controls the phases add.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String summary;
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
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            summary,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
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
/// its visible effect summary (GDD 10.3), plus the estimated-possession
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
        _SegmentedRow<BuildUpStyle>(
          label: l10n.tacticsBuildUp,
          values: BuildUpStyle.values,
          selected: ip.buildUp,
          display: (v) => switch (v) {
            BuildUpStyle.playOut => l10n.buildUpPlayOut,
            BuildUpStyle.mixed => l10n.buildUpMixed,
            BuildUpStyle.longBall => l10n.buildUpLongBall,
          },
          summary: (v) => v.modifiers.effectSummary,
          onSelect: (v) => onChanged(
            tactics.copyWith(inPossession: ip.copyWith(buildUp: v)),
          ),
        ),
        const SizedBox(height: 8),
        _SegmentedRow<AttackTempo>(
          label: l10n.tacticsTempo,
          values: AttackTempo.values,
          selected: ip.tempo,
          display: (v) => switch (v) {
            AttackTempo.slow => l10n.tempoSlow,
            AttackTempo.standard => l10n.tempoStandard,
            AttackTempo.fast => l10n.tempoFast,
          },
          summary: (v) => v.modifiers.effectSummary,
          onSelect: (v) =>
              onChanged(tactics.copyWith(inPossession: ip.copyWith(tempo: v))),
        ),
        const SizedBox(height: 8),
        _SegmentedRow<AttackWidth>(
          label: l10n.tacticsWidth,
          values: AttackWidth.values,
          selected: ip.width,
          display: (v) => switch (v) {
            AttackWidth.narrow => l10n.widthNarrow,
            AttackWidth.standard => l10n.widthStandardWidth,
            AttackWidth.wide => l10n.widthWide,
          },
          summary: (v) => v.modifiers.effectSummary,
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
          summary: (v) => v.modifiers.effectSummary,
          onSelect: (v) => onChanged(
            tactics.copyWith(inPossession: ip.copyWith(finalThird: v)),
          ),
        ),
        const SizedBox(height: 8),
        // The honest possession estimate (GDD 10.3): the share the
        // engine's power competition actually produces.
        Text(
          l10n.tacticsEstPossession(
            tactics.inPossession.estimatedPossessionShare,
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// One labelled segmented-control row: label, chips for every option,
/// and the SELECTED option's effect summary underneath.
class _SegmentedRow<T extends Enum> extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.display,
    required this.summary,
    required this.onSelect,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) display;
  final String Function(T) summary;
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
        const SizedBox(height: 4),
        Text(
          summary(selected),
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
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

/// The phase-0 placeholder row: the group's default state. Each phase
/// replaces one of these with its real instruction controls.
class _PhasePlaceholder extends StatelessWidget {
  const _PhasePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final theme = Theme.of(context);
    return Text(
      l10n.tacticsSectionDefault,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        fontSize: 11,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
