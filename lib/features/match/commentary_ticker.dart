/// FCM Rivals — live commentary ticker.
///
/// The live match screen (GDD 13) shows the commentary as ONE moment
/// at a time, Football Manager style: a single lower-third bar that
/// swaps to the newest line as each match minute lands, instead of a
/// scrolling history feed. Every moment wears the SAME uniform — one
/// fixed height, one text size, one line of text (ellipsis, never
/// wraps) — and differs only in its dressing:
///
/// - the side the line is about tints the whole bar: home lines on the
///   home half's colour, away lines on the away half's, the referee's
///   whistle moments (kick-off, half time, full time) on neutral
///   bronze — so who the moment belongs to reads before a word does;
/// - each event kind carries its own icon in the bar's badge;
/// - a goal gets its own flash: a light sweep rides across the bar
///   while it pulses and glows — no other moment does that.
///
/// RTL-safe: the bar uses directional padding and start/end alignment
/// so it mirrors cleanly in Arabic.
///
/// Performance: one AnimationController exists only while a goal flash
/// is on screen and is disposed on swap; every other moment is a plain
/// stateless paint. The bar never wraps or grows — text is one line —
/// so a swap never re-measures the layout, and the flash layers are
/// clipped inside the bar's rounded rect (no saveLayer).
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import 'commentary_style.dart' show CardChip, MomentStyle, momentStyleOf;
import 'match_engine.dart' show MatchSide;
import 'match_report.dart';

/// One live moment, lower-third style. [line] is the newest commentary
/// line; [homeColor]/[awayColor] are the two halves' colours — the live
/// screen passes the user's crest colour for their side and a dimmed
/// steel for the opponent, exactly like the momentum bar.
class CommentaryTicker extends StatefulWidget {
  const CommentaryTicker({
    super.key,
    required this.line,
    required this.homeColor,
    required this.awayColor,
  });

  final CommentaryLine line;

  /// The home half's colour — home moments wear it.
  final Color homeColor;

  /// The away half's colour — away moments wear it.
  final Color awayColor;

  @override
  State<CommentaryTicker> createState() => _CommentaryTickerState();
}

class _CommentaryTickerState extends State<CommentaryTicker>
    with TickerProviderStateMixin {
  AnimationController? _flash;

  /// Keys the running flash to its goal so a repeated build of the
  /// SAME goal does not restart the sweep mid-way.
  int? _flashMinute;
  int? _flashSecond;

  /// The goal flash: 1400ms, one sweep, then rest.
  static const Duration _flashDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    // The very first mount may already be a goal (the screen builds the
    // ticker with the newest line) — it deserves its flash too, not
    // only swaps.
    _applyLine(widget.line);
  }

  @override
  void didUpdateWidget(CommentaryTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyLine(widget.line);
  }

  /// Fires or retires the flash for [line]; every widget-lifecycle
  /// entry point funnels here so a goal never misses its flash.
  void _applyLine(CommentaryLine line) {
    if (line.kind != CommentaryKind.goal) {
      // Only a goal flashes; the moment before it may have been mid-
      // flash — retire it and paint the new moment plain.
      _retireFlash();
      return;
    }
    if (_flash != null &&
        _flashMinute == line.minute &&
        _flashSecond == line.second) {
      return; // Same goal still on screen — the flash keeps running.
    }
    _retireFlash();
    final flash = AnimationController(vsync: this, duration: _flashDuration)
      ..forward(from: 0);
    // The flash ends itself: the bar returns to its resting state (no
    // sweep layer, no glow) instead of freezing on the last flash
    // frame forever.
    flash.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _retireFlash();
        if (mounted) setState(() {});
      }
    });
    _flash = flash;
    _flashMinute = line.minute;
    _flashSecond = line.second;
  }

  void _retireFlash() {
    _flash?.dispose();
    _flash = null;
    _flashMinute = null;
    _flashSecond = null;
  }

  @override
  void dispose() {
    _retireFlash();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final style = momentStyleOf(line.kind);
    final side = line.side;
    final Color teamColor;
    if (side == null) {
      teamColor = style.accent;
    } else if (side == MatchSide.home) {
      teamColor = widget.homeColor;
    } else {
      teamColor = widget.awayColor;
    }
    final flash = _flash;
    if (flash != null) {
      return AnimatedBuilder(
        animation: flash,
        builder: (context, _) => _buildBar(
          context,
          line,
          style,
          teamColor,
          sweep: Curves.easeOutCubic.transform(flash.value),
          pulse: flash.value,
        ),
      );
    }
    return _buildBar(context, line, style, teamColor);
  }

  /// The bar itself: [sweep] is the light sweep's eased progress; the
  /// flash is off unless both are provided.
  Widget _buildBar(
    BuildContext context,
    CommentaryLine line,
    MomentStyle style,
    Color teamColor, {
    double sweep = -1,
    double pulse = -1,
  }) {
    final flashing = sweep >= 0 && pulse >= 0;
    // Goal flash: the bar breathes ±1.5px around its base height while
    // the sweep runs.
    final height = 46.0 + (flashing ? 1.5 * _pulseCurve(pulse) : 0.0);

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            if (flashing)
              BoxShadow(
                color: teamColor.withValues(alpha: 0.45 * (1 - pulse)),
                blurRadius: 14 + 10 * (1 - pulse),
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              // Team wash: the side's colour grades into the dark bar.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      // Directional: the tint starts at the reading
                      // edge and fades toward the far end — mirrors
                      // with the layout direction.
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        teamColor.withValues(alpha: 0.34),
                        teamColor.withValues(alpha: 0.10),
                        FcmColors.night,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
              ),
              // Goal flash, layer 1: the glow band riding across.
              if (flashing)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GoalSweepPainter(progress: sweep),
                  ),
                ),
              // The moment's content: minute, badge, one-line text.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(
                          "${line.minute}'",
                          maxLines: 1,
                          style: TextStyle(
                            color: teamColor.withValues(alpha: 0.95),
                            fontSize: 13,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: teamColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: teamColor.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: style.card != null
    ? CardChip(color: style.card!, size: 18)
    : Icon(style.icon, color: teamColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          line.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.1,
                            fontWeight: line.importance == 2
                                ? FontWeight.w900
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // The running score after a goal — the broadcast
                      // detail, right at the reading edge.
                      if (line.detail != null)
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: teamColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: teamColor.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            line.detail!,
                            maxLines: 1,
                            style: TextStyle(
                              color: teamColor,
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The bar's breathing during a goal flash: a tent over the flash
  /// lifetime — 0 at the start, +1 at the midpoint, back to 0 at the
  /// end, so the bar never freezes off its baseline.
  static double _pulseCurve(double t) {
    final tent = t < 0.5 ? t / 0.5 : (1 - t) / 0.5;
    return tent.clamp(0.0, 1.0);
  }
}

/// The goal flash's light band: a soft white-gold sweep that rides
/// across the bar once. Pure math on a ShaderMask-free path — a
/// rounded-rect gradient band painted at the sweep position, clipped
/// to the bar by the widget tree.
class _GoalSweepPainter extends CustomPainter {
  const _GoalSweepPainter({required this.progress});

  /// Eased sweep progress, 0 → 1 across the flash.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    // The band's centre travels from -0.25 to 1.25 of the width so the
    // sweep fully enters and exits the bar.
    final cx = (progress * 1.5 - 0.25) * size.width;
    final bandWidth = size.width * 0.38;
    final rect = Rect.fromCenter(
      center: Offset(cx, size.height / 2),
      width: bandWidth,
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
        // The sweep band is a physical light sweep, not text: it rides
        // left-to-right in both locales (a stadium light does not
        // mirror), so plain Alignment — no Directionality needed.
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0),
          Color.lerp(
            Colors.white,
            FcmColors.gold,
            0.35,
          )!.withValues(alpha: 0.38 * edge),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GoalSweepPainter old) => old.progress != progress;
}
