/// FCM Rivals — live match header family (GDD 13): the compact
/// scoreboard header and its controls.
///
/// Split out of `live_match_views.dart` (task
/// `2026-11-05_app-structure_split-live-match-views`), which re-exports
/// this library so consumer imports never churn. Kept separate from
/// [MatchScreen]'s flow logic: the screen rebuilds once per match minute
/// and none of these own per-minute animation controllers beyond the
/// self-repainting [_LiveDot]. The momentum meter lives in
/// `momentum_bar.dart`.
library;

import 'package:flutter/material.dart';

import '../../core/domain/crest.dart' show CrestSpec;
import '../../core/ui/fcm_club_badge.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import 'momentum_bar.dart';

/// Compact live header: one tight panel fusing scoreboard, clock and
/// controls. Team crest chips and score on the first row, the momentum
/// bar with the live minute under it, and the play/pause +
/// 1x–3x speed + tactics controls in the last row — roughly half the
/// vertical space of the old stack (scoreboard panel, then a separate
/// controls row), which is vertical budget the commentary feed now owns.
///
/// The momentum bar (`MomentumTugBar`, `momentum_bar.dart`) sits alone in
/// its own row under the centred clock: no text, no numbers — the home side's
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
    required this.onTactics,
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
  final VoidCallback onTactics;

  /// The home side's momentum share, 0..1 (0.5 = level).
  final double momentumShare;

  /// Colour of the home side's half of the momentum bar.
  final Color homeColor;

  /// Colour of the away side's half of the momentum bar.
  final Color awayColor;

  /// The fixture whisper (T-0114), e.g. 'League · Round 3' — one dim
  /// caption line at the very top of the panel, replacing the ~56px
  /// AppBar that held the same string. Null (or empty) renders NO
  /// caption row at all — no fallback text, no phantom row.
  final String? fixtureLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: FcmPanel(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        accent: FcmColors.bronze,
        glow: true,
        child: Column(
          children: [
            // The fixture whisper (T-0114): the label that used to own
            // a full AppBar band now reads as one dim caption line —
            // a whisper above the scoreboard, not a row of chrome.
            if (fixtureLabel != null && fixtureLabel!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 7),
                child: Text(
                  fixtureLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 9.5,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _TeamChip(
                    name: home,
                    crest: homeCrest,
                    isUser: userIsHome,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedSwitcher(
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
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _TeamChip(
                    name: away,
                    crest: awayCrest,
                    isUser: !userIsHome,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Match clock: the live dot and the minute, centred ...
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RepaintBoundary(child: _LiveDot()),
                const SizedBox(width: 6),
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
            const SizedBox(height: 6),
            // ... and the momentum bar alone in the row beneath it.
            MomentumTugBar(
              share: momentumShare,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
            const SizedBox(height: 8),
            // Controls fused into the same panel: play/pause, 1x–3x
            // speed, tactics. One compact row instead of a second
            // floating block below the scoreboard.
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
                const SizedBox(width: 8),
                _HeaderIconButton(
                  icon: Icons.tune_rounded,
                  gold: false,
                  tooltip: 'Tactics',
                  onTap: onTactics,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Club crest + club name, one per side of the score. Horizontal —
/// the old vertical column (crest over name) paid two lines for what
/// this says in one.
class _TeamChip extends StatelessWidget {
  const _TeamChip({
    required this.name,
    required this.crest,
    required this.isUser,
  });

  final String name;
  final CrestSpec? crest;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FcmClubBadge(name: name, crest: crest, size: 34, isUser: isUser),
        const SizedBox(width: 6),
        Flexible(
          child: FitText(
            name,
            style: TextStyle(
              color: isUser ? FcmColors.gold : Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pulsing red "live" indicator — the one animated widget in the
/// header, and it repaints only itself.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
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
      builder: (context, _) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: FcmColors.danger,
          boxShadow: [
            BoxShadow(
              color: FcmColors.danger.withValues(alpha: 0.3 + 0.5 * _c.value),
              blurRadius: 4 + 8 * _c.value,
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmented 1x / 2x / 3x speed selector, compressed to sit inside
/// the header panel. The selected segment is gold with ink text.
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

/// Square icon button for the header control row (play/pause, tactics).
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
