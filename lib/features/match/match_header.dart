/// FCM Rivals — live match header family (GDD 13): the compact
/// scoreboard header, its controls and the momentum bar.
///
/// Split out of `live_match_views.dart` (task
/// `2026-11-05_app-structure_split-live-match-views`), which re-exports
/// this library so consumer imports never churn. Kept separate from
/// [MatchScreen]'s flow logic: the screen rebuilds once per match minute
/// and none of these own per-minute animation controllers beyond the
/// self-repainting [_LiveDot].
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';

/// Compact live header: one tight panel fusing scoreboard, clock and
/// controls. Team crest chips and score on the first row, the 90-minute
/// progress bar with the live minute under it, and the play/pause +
/// 1x–3x speed + tactics controls in the last row — roughly half the
/// vertical space of the old stack (scoreboard panel, then a separate
/// controls row), which is vertical budget the commentary feed now owns.
///
/// Momentum lives in its own bar between this header and the feed —
/// [MomentumBar] — not inside the header: the up/down spike reading
/// needs more height than a compact scoreboard can spare.
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
  });

  final String home;
  final String away;
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

  @override
  Widget build(BuildContext context) {
    final progress = (minute / 90).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: FcmPanel(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        accent: FcmColors.bronze,
        glow: true,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _TeamChip(name: home, isUser: userIsHome),
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
                  child: _TeamChip(name: away, isUser: !userIsHome),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Match clock: the 90-minute progress bar with the live
            // minute riding at its right end.
            Row(
              children: [
                const _LiveDot(),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 5,
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: fullTime ? 1.0 : progress,
                            ),
                            duration: const Duration(milliseconds: 400),
                            builder: (context, f, _) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: f,
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: FcmColors.goldGradient,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: FitText(
                    fullTime ? 'FT' : "$minute'",
                    align: Alignment.center,
                    style: TextStyle(
                      color: fullTime ? FcmColors.gold : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
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

/// Round crest chip + club name, one per side of the score. Horizontal —
/// the old vertical column (crest over name) paid two lines for what
/// this says in one.
class _TeamChip extends StatelessWidget {
  const _TeamChip({required this.name, required this.isUser});

  final String name;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isUser ? FcmColors.goldGradient : FcmColors.steelGradient,
            border: Border.all(color: Colors.white24),
          ),
          child: FitText(
            initials,
            align: Alignment.center,
            style: TextStyle(
              color: isUser ? FcmColors.ink : FcmColors.goldSoft,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
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

/// The spike colour of the side the user does NOT manage: dimmed white,
/// so the user's crest colour always owns the reading at first glance.
const Color opponentMomentumColor = Color(0xD9FFFFFF);

/// The live momentum bar (GDD 13.2 live feel): a horizontal baseline
/// with one vertical line per minute played — home pressure rises ABOVE
/// the line, away pressure hangs BELOW it, and the taller side is the
/// team on top. Each minute's reading is the same trailing-window share
/// [computeMomentumSeries] gives, so the bar can never contradict the
/// events (GDD 13.1). Dead level at kick-off: no spikes, just the line.
///
/// The team names sit at the two ends of the label row so the sides are
/// unmistakable, painted as ONE CustomPainter — the match screen
/// rebuilds once per minute and the whole history repaints in a single
/// pass, no per-minute widgets and no animation controllers (the
/// repaint-per-minute philosophy that keeps the live screen jank-free).
class MomentumBar extends StatelessWidget {
  const MomentumBar({
    super.key,
    required this.series,
    required this.homeTeamName,
    required this.awayTeamName,
    this.homeColor = FcmColors.gold,
    this.awayColor = opponentMomentumColor,
    this.graphHeight = 56,
  });

  /// Per-minute HOME momentum share (0..1, 0.5 = dead level), index 0 =
  /// minute 1 — [computeMomentumSeries] output. Empty before kick-off.
  final List<double> series;

  final String homeTeamName;
  final String awayTeamName;

  /// Spike colour of the home side above the baseline (the user's crest
  /// colour when they manage it).
  final Color homeColor;

  /// Spike colour of the away side below the baseline.
  final Color awayColor;

  /// Height of the spike area itself (the label row adds ~16dp).
  final double graphHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FitText(
                homeTeamName,
                align: Alignment.centerLeft,
                style: TextStyle(
                  color: homeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Text(
              'MOMENTUM',
              style: TextStyle(
                color: FcmColors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            Expanded(
              child: FitText(
                awayTeamName,
                align: Alignment.centerRight,
                style: TextStyle(
                  color: awayColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: graphHeight,
          child: CustomPaint(
            painter: _MomentumPainter(
              series: series,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the baseline plus one vertical line per played minute: up
/// (home colour) when the home share is past dead level, down (away
/// colour) when under it, the length proportional to the pressure.
class _MomentumPainter extends CustomPainter {
  const _MomentumPainter({
    required this.series,
    required this.homeColor,
    required this.awayColor,
  });

  final List<double> series;
  final Color homeColor;
  final Color awayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..strokeWidth = 1,
    );

    final n = series.length;
    if (n == 0) return;
    final step = size.width / n;
    final line = Paint()
      ..strokeWidth = (step * 0.55).clamp(1.2, 3.0).toDouble()
      ..strokeCap = StrokeCap.round;
    // A little breathing room either side of the baseline.
    final half = mid - 3;
    for (var i = 0; i < n; i++) {
      final d = (series[i].clamp(0.0, 1.0) - 0.5) * 2; // -1..1, + = home
      if (d.abs() < 0.04) continue; // dead-level minute: no spike
      final x = step * (i + 0.5);
      final len = d.abs() * half;
      line.color = d > 0 ? homeColor : awayColor;
      canvas.drawLine(
        Offset(x, mid),
        Offset(x, d > 0 ? mid - len : mid + len),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(_MomentumPainter old) =>
      old.series != series ||
      old.homeColor != homeColor ||
      old.awayColor != awayColor;
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
