/// FCM Rivals — the live commentary feed (GDD 13).
///
/// Sits under the momentum meter on the live match screen. Two layers,
/// like a broadcast graphics package:
///
/// - the FEATURED MOMENT: the newest line on a premium card — a big
///   minute badge, the event's icon and name in small caps, the
///   commentary itself (up to three lines, never truncated to one), the
///   running score after a goal. The card wears the colour of the side
///   the moment belongs to (referee moments wear neutral gold/bronze),
///   slides in as each minute lands, and a GOAL gets its own flash — a
///   light sweep rides the card while its glow pulses out;
/// - the TIMELINE under it: the moments before, newest first, on a thin
///   rail with a dot per moment in its side's colour, fading with age —
///   enough context to follow the match without a scrolling history.
///
/// No scrolling: how many timeline rows show is computed from the room
/// the screen leaves (a short phone shows fewer, a tall one more), and
/// the column is clipped, never overflowed — the report at full time
/// keeps the complete record.
///
/// An injury moment takes the featured slot with its own red banner
/// ([InjuryLiveBanner], T-0056).
///
/// RTL-safe: directional padding, alignment and gradients, so the feed
/// mirrors cleanly in Arabic.
///
/// Performance: the screen rebuilds once per match minute. The only
/// animations are the featured card's swap (one AnimatedSwitcher) and
/// the goal flash (one TweenAnimationBuilder that exists only while a
/// goal is on screen); timeline rows are plain stateless paint.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import 'commentary.dart';
import 'commentary_style.dart'
    show CardChip, MomentStyle, momentStyleOf;
import 'injury_live_banner.dart';
import 'match_engine.dart' show MatchSide;

/// The dressing of one event kind: badge icon, small-caps name and the

/// The live commentary feed: featured moment + fading timeline.
class LiveCommentaryFeed extends StatelessWidget {
  const LiveCommentaryFeed({
    super.key,
    required this.lines,
    required this.homeColor,
    required this.awayColor,
    this.maxHistory = 6,
  });

  /// Every commentary moment so far, oldest first; the last is featured.
  final List<CommentaryLine> lines;

  /// The home half's colour — home moments wear it.
  final Color homeColor;

  /// The away half's colour — away moments wear it.
  final Color awayColor;

  /// Most timeline rows ever shown under the featured moment.
  final int maxHistory;

  // Layout budget (logical px) used to decide how many timeline rows
  // fit: the label row, the featured card (three text lines at most)
  // and one timeline row.
  static const double _labelHeight = 26;
  static const double _featuredHeight = 100;
  static const double _gap = 8;
  static const double _rowHeight = 38;

  Color _colorOf(CommentaryLine line) {
    final side = line.side;
    if (side == null) return momentStyleOf(line.kind).accent;
    return side == MatchSide.home ? homeColor : awayColor;
  }

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final latest = lines.last;

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxHeight.isFinite
            ? constraints.maxHeight - _labelHeight - _featuredHeight - _gap
            : double.infinity;
        final rows = room.isFinite
            ? (room / _rowHeight).floor().clamp(0, maxHistory).toInt()
            : maxHistory;
        final before = lines.length - 1;
        final from = math.max(0, before - rows);
        // Newest first, directly under the featured card.
        final history = lines.sublist(from, before).reversed.toList();

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FeedLabel(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.18),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topCenter,
                    children: [...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${latest.minute}:${latest.second}:'
                      '${latest.kind.name}:${latest.text.hashCode}',
                    ),
                    child: latest.kind == CommentaryKind.injury
                        ? InjuryLiveBanner(line: latest)
                        : _FeaturedMoment(
                            line: latest,
                            color: _colorOf(latest),
                          ),
                  ),
                ),
                if (history.isNotEmpty) ...[
                  const SizedBox(height: _gap),
                  _Timeline(
                    moments: [
                      for (final line in history)
                        (line: line, color: _colorOf(line)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small section label with a hairline that fades out to the far edge.
class _FeedLabel extends StatelessWidget {
  const _FeedLabel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: LiveCommentaryFeed._labelHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: FcmColors.gold,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'LIVE COMMENTARY',
              style: TextStyle(
                color: FcmColors.textDim,
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: AlignmentDirectional.centerStart,
                    end: AlignmentDirectional.centerEnd,
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The kind's event-identity badge: its unique icon, or the literal
/// booking card chip for the two card kinds. Event identity only —
/// never the team colour (T-0115's two-channel contract).
Widget _kindBadge(MomentStyle moment, Color accent, double size) {
  if (moment.card != null) {
    return CardChip(color: moment.card!, size: size);
  }
  return Icon(moment.icon, size: size, color: accent);
}

/// The featured moment card. A goal runs the flash: one sweep of light
/// across the card while a glow pulses out around it.
class _FeaturedMoment extends StatelessWidget {
  const _FeaturedMoment({required this.line, required this.color});

  final CommentaryLine line;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final moment = momentStyleOf(line.kind);
    if (line.kind != CommentaryKind.goal) {
      return _card(moment, flash: -1);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1500),
      builder: (context, t, _) => _card(moment, flash: t),
    );
  }

  /// [flash] is the goal flash's progress 0..1, or -1 when off.
  Widget _card(MomentStyle moment, {required double flash}) {
    final flashing = flash >= 0 && flash < 1;
    final glow = flashing ? (1 - flash) : 0.0;
    const radius = 18.0;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          // Directional: the team wash starts at the reading edge.
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            color.withValues(alpha: 0.32),
            FcmColors.surfaceHigh.withValues(alpha: 0.97),
            FcmColors.surface,
          ],
          stops: const [0, 0.5, 1],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.5 + 0.3 * glow),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (flashing)
            BoxShadow(
              color: color.withValues(alpha: 0.5 * glow),
              blurRadius: 14 + 18 * glow,
            ),
        ],
      ),
      child: Row(
        children: [
          _MinuteBadge(minute: line.minute, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _kindBadge(moment, moment.accent, 13),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        moment.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: moment.accent,
                          fontSize: 10.5,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  line.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.28,
                    fontWeight: line.importance == 2
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (line.detail != null) ...[
            const SizedBox(width: 10),
            _ScorePill(text: line.detail!, color: color),
          ],
        ],
      ),
    );

    if (!flashing) return content;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SweepPainter(
                  progress: Curves.easeOutCubic.transform(flash),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The big minute chip at the card's reading edge.
class _MinuteBadge extends StatelessWidget {
  const _MinuteBadge({required this.minute, required this.color});

  final int minute;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.34),
            color.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$minute'",
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'MIN',
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontSize: 8,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// The running score after a goal, at the card's far edge.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: color,
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// The timeline under the featured card: a thin rail, one dot per
/// moment in its side's colour, rows fading with age.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.moments});

  /// Newest first.
  final List<({CommentaryLine line, Color color})> moments;

  // Rail x (from the reading edge): minute column + gap + dot centre.
  static const double _minuteWidth = 38;
  static const double _gapToDot = 10;
  static const double _dot = 9;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
      child: Stack(
        children: [
          PositionedDirectional(
            start: _minuteWidth + _gapToDot + _dot / 2 - 0.75,
            top: 4,
            bottom: 4,
            child: Container(
              width: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < moments.length; i++)
                _TimelineRow(
                  line: moments[i].line,
                  color: moments[i].color,
                  // Fades with age: 1.0 right under the card, floor 0.4.
                  strength: math.max(0.4, 1 - i * 0.14),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.line,
    required this.color,
    required this.strength,
  });

  final CommentaryLine line;
  final Color color;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final moment = momentStyleOf(line.kind);
    return SizedBox(
      height: LiveCommentaryFeed._rowHeight,
      child: Row(
        children: [
          SizedBox(
            width: _Timeline._minuteWidth,
            child: Text(
              "${line.minute}'",
              maxLines: 1,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: FcmColors.textDim.withValues(alpha: strength),
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: _Timeline._gapToDot),
          Container(
            width: _Timeline._dot,
            height: _Timeline._dot,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: strength),
              border: Border.all(color: FcmColors.night, width: 1.5),
            ),
          ),
          const SizedBox(width: 10),
          Opacity(
            opacity: 0.9 * strength,
            child: _kindBadge(moment, moment.accent, 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92 * strength),
                fontSize: 12.5,
                height: 1.1,
                fontWeight: line.importance == 2
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
          if (line.detail != null) ...[
            const SizedBox(width: 8),
            Text(
              line.detail!,
              maxLines: 1,
              style: TextStyle(
                color: color.withValues(alpha: strength),
                fontSize: 11,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The goal flash's light band: a soft white-gold sweep that rides
/// across the card once, clipped to it by the widget tree. It is a
/// physical light sweep, not text, so it travels left-to-right in both
/// locales.
class _SweepPainter extends CustomPainter {
  const _SweepPainter({required this.progress});

  /// Eased sweep progress, 0 → 1 across the flash.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    // The band's centre travels from -0.25 to 1.25 of the width so the
    // sweep fully enters and exits the card.
    final cx = (progress * 1.5 - 0.25) * size.width;
    final rect = Rect.fromCenter(
      center: Offset(cx, size.height / 2),
      width: size.width * 0.38,
      height: size.height * 1.6,
    );
    // Alpha ramps in over the first 20% and out over the last 20%.
    final edge = progress < 0.2
        ? progress / 0.2
        : progress > 0.8
        ? (1 - progress) / 0.2
        : 1.0;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Color.lerp(
            Colors.white,
            FcmColors.gold,
            0.35,
          )!.withValues(alpha: 0.4 * edge),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) => old.progress != progress;
}
