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
          child: const _PhasePlaceholder(key: ValueKey('inPossessionControls')),
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
