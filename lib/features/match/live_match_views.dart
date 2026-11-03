/// FCM Rivals — live match widgets (GDD 13): compact scoreboard header,
/// the live stats strip and the commentary feed.
///
/// Kept separate from [MatchScreen]'s flow logic so every widget here is
/// a plain stateless row: the screen rebuilds once per match minute and
/// none of these own animation controllers — the old per-row entrance
/// animations were the jank source at top speed, not the simulation.
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import 'match_report.dart';
import 'tactics.dart';

/// Compact live header: one tight panel fusing scoreboard, clock and
/// controls. Team crest chips and score on the first row, the 90-minute
/// progress bar with the live minute under it, and the play/pause +
/// 1x–3x speed + tactics controls in the last row — roughly half the
/// vertical space of the old stack (scoreboard panel, then a separate
/// controls row), which is vertical budget the commentary feed now owns.
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
    this.momentum,
    this.userTeamColor = FcmColors.gold,
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

  /// Live momentum share of the HOME side, 0..1 (null before kick-off —
  /// the bar opens at the dead-level 50/50 split).
  final double? momentum;

  /// The user's crest colour — fills the user's half of the momentum
  /// bar (the opponent's half stays white). Defaults to brand gold.
  final Color userTeamColor;

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
                            builder: (context, f, _) =>
                                FractionallySizedBox(
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
            // Momentum bar (GDD 13.2 live feel): the tug-of-war strip —
            // the user's crest colour vs white, dead level 50/50 at
            // kick-off and pushed by whoever is on top in the last
            // minutes.
            MomentumBar(
              homeShare: momentum ?? 0.5,
              userIsHome: userIsHome,
              userTeamColor: userTeamColor,
            ),
            const SizedBox(height: 8),
            // Controls fused into the same panel: play/pause, 1x–3x
            // speed, tactics. One compact row instead of a second
            // floating block below the scoreboard.
            Row(
              children: [
                _HeaderIconButton(
                  icon: paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
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
            gradient:
                isUser ? FcmColors.goldGradient : FcmColors.steelGradient,
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

/// The live momentum tug-of-war bar: the user's half of the strip fills
/// with their crest colour, the opponent's half stays white, and the
/// divide slides toward whoever is on top. Dead level (50/50) at
/// kick-off — the split only moves once the match has events.
///
/// The fill re-tweens over 600ms so each match minute nudges the divide
/// smoothly instead of snapping; a neutral tick mark pins the centre so
/// "who has the momentum" reads at a glance against dead level.
class MomentumBar extends StatelessWidget {
  const MomentumBar({
    super.key,
    required this.homeShare,
    required this.userIsHome,
    this.userTeamColor = FcmColors.gold,
  });

  /// Momentum share of the HOME side, 0..1 (0.5 = dead level).
  final double homeShare;

  /// Which half belongs to the user: their crest colour fills it, the
  /// opponent's half is white.
  final bool userIsHome;

  /// The user's crest colour (brand gold by default).
  final Color userTeamColor;

  @override
  Widget build(BuildContext context) {
    final clamped = homeShare.clamp(0.0, 1.0);
    final userShare = userIsHome ? clamped : 1 - clamped;
    final userColor = userTeamColor;
    // The opponent's white is dimmed a touch so it reads as a strip,
    // not a searchlight, against the dark panel.
    final opponentColor = Colors.white.withValues(alpha: 0.85);

    return SizedBox(
      height: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            // Full-width opponent white: the user's colour slides over
            // it from the left (or right when the user is away), so the
            // divide IS the momentum reading.
            ColoredBox(color: opponentColor),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: userShare),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (context, f, _) => Align(
                alignment: userIsHome
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: f,
                  child: ColoredBox(color: userColor),
                ),
              ),
            ),
            // Centre tick: the dead-level mark the divide fights over.
            const Align(
              alignment: Alignment.center,
              child: Center(
                child: VerticalDivider(
                  width: 2,
                  thickness: 2,
                  color: Colors.black26,
                ),
              ),
            ),
          ],
        ),
      ),
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
              color: FcmColors.danger
                  .withValues(alpha: 0.3 + 0.5 * _c.value),
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

/// One live statistic row: home value — label — away value with a share
/// bar between them. Plain stateless; numbers update in place (no
/// tweening per minute — the bar animating on every one of 90 rebuilds
/// was pure churn).
class _LiveStatsRow extends StatelessWidget {
  const _LiveStatsRow({
    required this.label,
    required this.homeText,
    required this.awayText,
    required this.homeShare,
  });

  final String label;
  final String homeText;
  final String awayText;
  final double homeShare;

  @override
  Widget build(BuildContext context) {
    final left = (homeShare * 1000).round().clamp(1, 999);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FitText(
                  homeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: FitText(
                  label,
                  align: Alignment.center,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: FitText(
                  awayText,
                  align: Alignment.centerRight,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  Expanded(
                    flex: left,
                    child: const DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: FcmColors.goldGradient),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 1000 - left,
                    child: const DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: FcmColors.steelGradient),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live match statistics strip (GDD 13.2): possession, shots and shots
/// on target, recomputed from the event timeline every match minute.
/// Always visible above the commentary feed — the numbers the manager
/// glances at between key moments, never a tap away.
class LiveMatchStatsPanel extends StatelessWidget {
  const LiveMatchStatsPanel({
    super.key,
    required this.stats,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  final MatchStatsReport stats;
  final String homeTeamName;
  final String awayTeamName;

  static String _pct(double v) => '${(100 * v).round()}%';

  @override
  Widget build(BuildContext context) {
    final h = stats.home;
    final a = stats.away;
    final totalPossession = h.possessionMinutes + a.possessionMinutes;
    final possH = totalPossession == 0
        ? 0.5
        : h.possessionMinutes / totalPossession;
    final possTextH =
        totalPossession == 0 ? '—' : _pct(possH);
    final possTextA =
        totalPossession == 0 ? '—' : _pct(1 - possH);
    final totalShots = h.shots + a.shots;
    final totalOnTarget = h.shotsOnTarget + a.shotsOnTarget;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: FcmPanel(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        accent: FcmColors.bronze,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.query_stats_rounded,
                  size: 16,
                  color: FcmColors.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FitText(
                    homeTeamName,
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const Text(
                  'Match stats',
                  style: TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.query_stats_rounded,
                  size: 16,
                  color: FcmColors.gold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FitText(
                    awayTeamName,
                    align: Alignment.centerRight,
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _LiveStatsRow(
              label: 'Possession',
              homeText: possTextH,
              awayText: possTextA,
              homeShare: possH,
            ),
            _LiveStatsRow(
              label: 'Shots',
              homeText: '${h.shots}',
              awayText: '${a.shots}',
              homeShare: totalShots == 0
                  ? 0.5
                  : h.shots / totalShots,
            ),
            _LiveStatsRow(
              label: 'On target',
              homeText: '${h.shotsOnTarget}',
              awayText: '${a.shotsOnTarget}',
              homeShare: totalOnTarget == 0
                  ? 0.5
                  : h.shotsOnTarget / totalOnTarget,
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual identity for one commentary kind: the icon it is badged with
/// and its accent colour. Goals and penalties burn gold, cards carry
/// their colour, saves cool green — the feed reads at a glance.
_KindStyle _styleOf(CommentaryKind kind) => switch (kind) {
      CommentaryKind.goal => _KindStyle(
          icon: Icons.sports_soccer_rounded,
          color: FcmColors.gold,
          label: 'GOAL',
          big: true,
        ),
      CommentaryKind.penalty => _KindStyle(
          icon: Icons.adjust_rounded,
          color: FcmColors.gold,
          label: 'PENALTY',
          big: true,
        ),
      CommentaryKind.redCard => _KindStyle(
          icon: Icons.style_rounded,
          color: FcmColors.danger,
          label: 'RED CARD',
          big: true,
        ),
      CommentaryKind.yellowCard => _KindStyle(
          icon: Icons.style_rounded,
          color: FcmColors.goldSoft,
        ),
      CommentaryKind.save => _KindStyle(
          icon: Icons.sports_handball_rounded,
          color: FcmColors.success,
        ),
      CommentaryKind.substitution => _KindStyle(
          icon: Icons.swap_horiz_rounded,
          color: FcmColors.silver,
        ),
      CommentaryKind.tactical => _KindStyle(
          icon: Icons.tune_rounded,
          color: FcmColors.silver,
        ),
      CommentaryKind.order => _KindStyle(
          icon: Icons.campaign_rounded,
          color: FcmColors.gold,
        ),
      CommentaryKind.kickoff => _KindStyle(
          icon: Icons.sports_rounded,
          color: FcmColors.silver,
        ),
      CommentaryKind.halfTime => _KindStyle(
          icon: Icons.sports_rounded,
          color: FcmColors.gold,
        ),
      CommentaryKind.fullTime => _KindStyle(
          icon: Icons.flag_rounded,
          color: FcmColors.gold,
        ),
      CommentaryKind.foul => _KindStyle(
          icon: Icons.sports_rounded,
          color: FcmColors.textDim,
        ),
      CommentaryKind.offside => _KindStyle(
          icon: Icons.flag_rounded,
          color: FcmColors.textDim,
        ),
      CommentaryKind.corner => _KindStyle(
          icon: Icons.sports_soccer_rounded,
          color: FcmColors.textDim,
        ),
      CommentaryKind.none => _KindStyle(
          icon: Icons.circle_rounded,
          color: FcmColors.textDim,
        ),
    };

class _KindStyle {
  const _KindStyle({
    required this.icon,
    required this.color,
    this.label,
    this.big = false,
  });

  final IconData icon;

  /// Accent colour for the chip, the border and the header.
  final Color color;

  /// Header label on big cards ('GOAL', 'RED CARD'); null on chips.
  final String? label;

  /// Whether this kind earns the full-width key-moment card.
  final bool big;
}

/// One commentary line in the broadcast feed. Every key moment is
/// badged with its own icon and accent colour — a goal is a gold card
/// with the scoreline under it, a red card burns danger-red, a booking
/// shows the yellow — so the feed feels like a match broadcast, not a
/// text log. Plain stateless row: no entrance animation, entries
/// render in place and the history scrolls up naturally.
class CommentaryRow extends StatelessWidget {
  const CommentaryRow({super.key, required this.line});

  final CommentaryLine line;

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(line.kind);
    if (style.big) return _KeyMomentCard(line: line, style: style);
    if (line.importance == 0) return _FillerRow(line: line);
    return _EventRow(line: line, style: style);
  }
}

/// The full-width card for the moments that stop the match: gold
/// gradient wash, glowing border, icon badge, the running scoreline
/// under a goal.
class _KeyMomentCard extends StatelessWidget {
  const _KeyMomentCard({required this.line, required this.style});

  final CommentaryLine line;
  final _KindStyle style;

  @override
  Widget build(BuildContext context) {
    final accent = style.color;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.26),
            FcmColors.surface,
            FcmColors.surface,
          ],
          stops: const [0, 0.45, 1],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.85), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: accent == FcmColors.gold
                  ? FcmColors.goldGradient
                  : null,
              color: accent == FcmColors.gold ? null : accent,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1),
            ),
            child: Icon(
              style.icon,
              color: accent == FcmColors.gold ? FcmColors.ink : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        style.label ?? '',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                    Text(
                      "${line.minute}'",
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  line.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (line.detail != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                      border: Border(
                        left: BorderSide(color: accent, width: 2.5),
                      ),
                    ),
                    child: Text(
                      line.detail!,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One notable event line: solid panel so it reads clearly over the
/// stadium backdrop, coloured icon chip at its left, minute at right.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.line, required this.style});

  final CommentaryLine line;
  final _KindStyle style;

  @override
  Widget build(BuildContext context) {
    final accent = style.color;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
      decoration: BoxDecoration(
        color: FcmColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: accent.withValues(alpha: 0.45), width: 1),
            ),
            child: Icon(style.icon, color: accent, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              line.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              "${line.minute}'",
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filler narration (full record only): a quiet dim line, no chrome.
class _FillerRow extends StatelessWidget {
  const _FillerRow({required this.line});

  final CommentaryLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              "${line.minute}'",
              style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              line.text,
              style: const TextStyle(
                color: FcmColors.textDim,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pep-talk chooser sheet (GDD 15): one optional choice, ad-free (FR-043).
/// Returns null when skipped or dismissed.
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
                  const Icon(Icons.record_voice_over_rounded,
                      color: FcmColors.gold, size: 20),
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
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: FcmColors.gold.withValues(alpha: 0.10),
                    border: Border(
                        top: BorderSide(
                            color: FcmColors.gold.withValues(alpha: 0.5)),
                        bottom: BorderSide(
                            color: FcmColors.gold.withValues(alpha: 0.5))),
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
                  style:
                      TextStyle(color: FcmColors.textDim, fontSize: 12),
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
            const Icon(Icons.chevron_right_rounded,
                color: FcmColors.textDim, size: 20),
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
