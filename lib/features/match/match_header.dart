/// FCM Rivals — live match header family (GDD 13): the compact
/// scoreboard header and its controls.
///
/// Split out of `live_match_views.dart` (task
/// `2026-11-05_app-structure_split-live-match-views`), which re-exports
/// this library so consumer imports never churn. Kept separate from
/// [MatchScreen]'s flow logic: the screen rebuilds once per match minute
/// and none of these own per-minute animation controllers beyond the
/// self-repainting [_LiveTag]. The momentum meter lives in
/// `momentum_bar.dart`.
///
/// Owner request 2026-11-13 — the Bein-Sports broadcast bug: the
/// team-vs-team block reads like a TV scoreline, compact in ONE row.
/// The first row carries the competition column ('D1' over 'Round 2')
/// at its start and ends with the game's crest (logo.webp), a tiny red
/// LIVE tag sitting just above that crest. Under it, the scoreline row
/// in broadcast order: home crest, home abbreviation, home goals –
/// away goals, away abbreviation, away crest, then the match clock.
/// The momentum bar keeps its own row exactly as it was, and the last
/// row holds the play/pause and speed controls only (the tactics entry
/// moved out of the header — the live tactics panel below and the
/// half-time card keep it one tap away).
library;

import 'package:flutter/material.dart';

import '../../core/domain/crest.dart' show CrestSpec;
import '../../core/ui/fcm_club_badge.dart';
import '../../core/ui/fcm_logo.dart' show FcmWordmark;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import 'momentum_bar.dart';

/// Compact live header: one tight panel fusing the broadcast scoreline,
/// clock, momentum and controls — roughly half the vertical space of the
/// old stack, which is vertical budget the commentary feed now owns.
///
/// The momentum bar (`MomentumTugBar`, `momentum_bar.dart`) sits alone in
/// its own row under the scoreline: no text, no numbers — the home side's
/// colour presses in from the left, the away side's from the right, and
/// the knob slides as the pressure swings.
class MatchHeader extends StatelessWidget {
  const MatchHeader({
    super.key,
    required this.home,
    required this.away,
    required this.scoreHome,
    required this.scoreAway,
    required this.minute,
    required this.fullTime,
    required this.userIsHome,
    required this.paused,
    required this.speed,
    required this.onTogglePause,
    required this.onSetSpeed,
    this.momentumShare = 0.5,
    this.homeColor = FcmColors.gold,
    this.awayColor = opponentMomentumColor,
    this.fixtureLabel,
    this.homeCrest,
    this.awayCrest,
  });

  final String home;
  final String away;

  /// The clubs' crests, shown instead of initials; null falls back to
  /// the initials circle.
  final CrestSpec? homeCrest;
  final CrestSpec? awayCrest;
  final int scoreHome;
  final int scoreAway;
  final int minute;
  final bool fullTime;
  final bool userIsHome;
  final bool paused;
  final int speed;
  final VoidCallback onTogglePause;
  final ValueChanged<int> onSetSpeed;

  /// The home side's momentum share, 0..1 (0.5 = level).
  final double momentumShare;

  /// Colour of the home side's half of the momentum bar.
  final Color homeColor;

  /// Colour of the away side's half of the momentum bar.
  final Color awayColor;

  /// The broadcast competition tag (owner request 2026-11-13), e.g.
  /// 'D1 · Round 3' — split on the '·' into the header's opening
  /// column: 'D1' over 'Round 3'. Null (or empty) renders no column
  /// and the strip centres on the scoreline alone.
  final String? fixtureLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: FcmPanel(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        accent: FcmColors.bronze,
        glow: true,
        child: Column(
          children: [
            _BroadcastStrip(
              fixtureLabel: fixtureLabel,
              fullTime: fullTime,
            ),
            const SizedBox(height: 6),
            _ScorelineRow(
              home: home,
              away: away,
              homeCrest: homeCrest,
              awayCrest: awayCrest,
              scoreHome: scoreHome,
              scoreAway: scoreAway,
              minute: minute,
              fullTime: fullTime,
              userIsHome: userIsHome,
            ),
            const SizedBox(height: 8),
            MomentumTugBar(
              share: momentumShare,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
            const SizedBox(height: 8),
            // Controls fused into the same panel: play/pause and the
            // 1x–3x speed selector — nothing else (owner request
            // 2026-11-13: the tactics button left the header card).
            Row(
              children: [
                _HeaderIconButton(
                  icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  gold: !paused,
                  tooltip: paused ? 'Resume' : 'Pause',
                  onTap: onTogglePause,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SpeedSelector(speed: speed, onSelect: onSetSpeed),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The top strip of the broadcast bug, compact in one row: the
/// competition column ('D1' over 'Round 2') at the start, and at the
/// row's end the game's crest with the tiny red LIVE tag sitting just
/// above it.
class _BroadcastStrip extends StatelessWidget {
  const _BroadcastStrip({this.fixtureLabel, required this.fullTime});

  final String? fixtureLabel;
  final bool fullTime;

  @override
  Widget build(BuildContext context) {
    final label = fixtureLabel;
    final hasColumn = label != null && label.isNotEmpty;

    // Split the tag into its two lines: 'D1 · Round 3' → 'D1' over
    // 'Round 3'. Anything without the separator renders whole on one
    // line, vertically centred like the column's first line.
    final (top, bottom) = hasColumn
        ? switch (label.split('·').map((s) => s.trim()).toList()) {
            final parts when parts.length >= 2 =>
              (parts.first, parts.sublist(1).join(' · ')),
            final parts => (parts.first, null),
          }
        : (null, null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Start of the row: the competition column — division on top,
        // round beneath, both small and dim like a bug's corner tag.
        if (hasColumn) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                top!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FcmColors.goldSoft,
                  fontSize: 12,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              if (bottom != null && bottom.isNotEmpty)
                Text(
                  bottom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 9,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
        ],
        const Spacer(),
        // End of the row: the tiny red LIVE tag directly above the
        // game's crest (logo.webp) — the broadcast channel mark. The
        // fixed-height tag slot keeps the crest from jumping when LIVE
        // disappears at full time.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 10,
              child: fullTime
                  ? null
                  : const RepaintBoundary(child: _LiveTag()),
            ),
            const FcmWordmark(size: 16),
          ],
        ),
      ],
    );
  }
}

/// The scoreline row, in broadcast order (owner request 2026-11-13):
/// home crest, home abbreviation, home goals – away goals, away
/// abbreviation, away crest, then the match clock. Abbreviations are
/// the first three characters of each club's name; the user's side
/// reads gold.
class _ScorelineRow extends StatelessWidget {
  const _ScorelineRow({
    required this.home,
    required this.away,
    required this.homeCrest,
    required this.awayCrest,
    required this.scoreHome,
    required this.scoreAway,
    required this.minute,
    required this.fullTime,
    required this.userIsHome,
  });

  final String home;
  final String away;
  final CrestSpec? homeCrest;
  final CrestSpec? awayCrest;
  final int scoreHome;
  final int scoreAway;
  final int minute;
  final bool fullTime;
  final bool userIsHome;

  /// Broadcast abbreviation: the club's first three characters —
  /// spaces and punctuation skipped, so 'FC Rivals' reads 'FCR' and
  /// 'Liverpool' reads 'LIV' ('Al Ahly' → 'ALA').
  static String abbrevOf(String name) {
    final letters = name.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (letters.isEmpty) return '—';
    return (letters.length <= 3 ? letters : letters.substring(0, 3))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Directionality(
            // The scoreline is a TV graphic, not prose: home reads from
            // the left in every locale, so an RTL body never mirrors
            // the sides or the score order.
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FcmClubBadge(
                  name: home,
                  crest: homeCrest,
                  size: 24,
                  isUser: userIsHome,
                ),
                const SizedBox(width: 7),
                Text(
                  abbrevOf(home),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: userIsHome ? FcmColors.gold : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: CurvedAnimation(
                      parent: anim,
                      curve: Curves.easeOutBack,
                    ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    '$scoreHome - $scoreAway',
                    key: ValueKey('$scoreHome-$scoreAway'),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  abbrevOf(away),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: !userIsHome ? FcmColors.gold : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 7),
                FcmClubBadge(
                  name: away,
                  crest: awayCrest,
                  size: 24,
                  isUser: !userIsHome,
                ),
                const SizedBox(width: 12),
                // Match clock at the row's end: the minute (FT in gold
                // once the whistle has gone).
                FitText(
                  fullTime ? 'FT' : "$minute'",
                  align: Alignment.center,
                  style: TextStyle(
                    color: fullTime ? FcmColors.gold : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Pulsing red "LIVE" tag — the one animated widget in the strip, and
/// it repaints only itself.
class _LiveTag extends StatefulWidget {
  const _LiveTag();

  @override
  State<_LiveTag> createState() => _LiveTagState();
}

class _LiveTagState extends State<_LiveTag>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Text(
        'LIVE',
        style: TextStyle(
          color: FcmColors.danger.withValues(alpha: 0.55 + 0.45 * _c.value),
          fontSize: 8,
          height: 1,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
          shadows: [
            Shadow(
              color: FcmColors.danger.withValues(alpha: 0.3 + 0.5 * _c.value),
              blurRadius: 4 + 6 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented 1x / 2x / 3x speed selector, compressed to sit inside the
/// header panel. The selected segment is gold with ink text.
class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.speed, required this.onSelect});

  static const speeds = [1, 2, 3];

  final int speed;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: FcmColors.steelGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FcmColors.bronze.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          for (final s in speeds)
            Expanded(
              child: FcmPressable(
                onTap: () => onSelect(s),
                scale: 0.96,
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: s == speed ? FcmColors.goldGradient : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      color: s == speed ? FcmColors.ink : FcmColors.textDim,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Square icon button for the header control row (play/pause).
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.gold = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FcmPressable(
        onTap: onTap,
        scale: 0.94,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: gold ? FcmColors.goldGradient : FcmColors.steelGradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: gold
                  ? FcmColors.goldSoft.withValues(alpha: 0.5)
                  : FcmColors.bronze.withValues(alpha: 0.55),
            ),
          ),
          child: Icon(
            icon,
            color: gold ? FcmColors.ink : FcmColors.goldSoft,
            size: 24,
          ),
        ),
      ),
    );
  }
}
