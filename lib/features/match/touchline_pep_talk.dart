/// FCM Rivals — touchline pep-talk family (GDD 15.2): the half-time
/// talk rendered as an overlay on the live match, its chooser sheet
/// rows and the shared option row.
///
/// Split out of `live_match_views.dart` (task
/// `2026-11-05_app-structure_split-live-match-views`), which re-exports
/// this library so consumer imports never churn.
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import 'tactics.dart';

Future<MatchPepTalk?> showPepTalkChooser({
  required BuildContext context,
  required String title,
  required String subtitle,
  required List<MatchPepTalk> talks,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<MatchPepTalk>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: FcmColors.textDim,
            ),
          ),
          const SizedBox(height: 12),
          for (final talk in talks)
            SheetOption(
              title: talk.label,
              subtitle: '${talk.effectSummary}\n${talk.description}',
              icon: Icons.record_voice_over_rounded,
              onTap: () => Navigator.pop(sheetContext, talk),
            ),
          SheetOption(
            title: 'Skip',
            subtitle: 'No pep talk',
            icon: Icons.block_rounded,
            muted: true,
            onTap: () => Navigator.pop(sheetContext),
          ),
        ],
      ),
    ),
  );
}

/// The touchline pep-talk card (GDD 15.2): the half-time talk rendered
/// as an overlay ON the live match — a manager's note held over the
/// pitch for the few seconds the decision takes, not a modal sheet
/// that takes the match away.
///
/// The options are compact rows (label + effect summary — GDD 15:
/// effects must be visible) with a "say nothing" escape. The card is
/// NOT dismissible by tapping outside it: a decision (talk, skip, or
/// edit-then-decide) must be made before the second half kicks off.
class TouchlinePepTalkCard extends StatelessWidget {
  const TouchlinePepTalkCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.talks,
    required this.onChoose,
    required this.onSkip,
    this.scoreHeader,
    this.onEditTactics,
  });

  final String title;
  final String subtitle;
  final List<MatchPepTalk> talks;
  final ValueChanged<MatchPepTalk> onChoose;
  final VoidCallback onSkip;

  /// Optional half-time score banner: 'HOME 1 – 0 AWAY'. Present only on
  /// the half-time card — it must be unmistakable that this is HALF TIME,
  /// not a random pause.
  final String? scoreHeader;

  /// Opens the live tactics editor mid-break (half-time only): the same
  /// 'Edit tactics' entry the live header offers, so the manager can
  /// rethink the setup before the second half kicks off.
  final VoidCallback? onEditTactics;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        // The scrim blocks taps on the frozen match behind the card —
        // deliberately inert: an accidental tap outside must NOT skip
        // the talk. The decision has to be one of the card's options.
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: FcmPanel(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          accent: FcmColors.bronze,
          glow: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.record_voice_over_rounded,
                    color: FcmColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FitText(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (scoreHeader != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: FcmColors.gold.withValues(alpha: 0.10),
                    border: Border(
                      top: BorderSide(
                        color: FcmColors.gold.withValues(alpha: 0.5),
                      ),
                      bottom: BorderSide(
                        color: FcmColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  child: Text(
                    scoreHeader!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              for (final talk in talks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _PepTalkOption(
                    talk: talk,
                    onTap: () => onChoose(talk),
                  ),
                ),
              if (onEditTactics != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FcmButton(
                    compact: true,
                    icon: Icons.tune_rounded,
                    label: 'EDIT TACTICS',
                    onPressed: onEditTactics,
                  ),
                ),
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Say nothing — back to the match',
                  style: TextStyle(color: FcmColors.textDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pep-talk row inside the touchline card: the label over the
/// effect summary, the summary's signed percentages in gold.
class _PepTalkOption extends StatelessWidget {
  const _PepTalkOption({required this.talk, required this.onTap});

  final MatchPepTalk talk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPressable(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    talk.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    talk.effectSummary,
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: FcmColors.textDim,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Option row used by the pep-talk and recovery sheets.
class SheetOption extends StatelessWidget {
  const SheetOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.accent,
    this.muted = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color? accent;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? Colors.white38 : (accent ?? FcmColors.gold);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FcmPanel(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        accent: accent,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: muted ? Colors.white60 : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: FcmColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
