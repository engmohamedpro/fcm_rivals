/// FCM Rivals — the live momentum meter (GDD 13.2).
///
/// Momentum answers ONE question: who is on top right now? The old
/// minute-by-minute spike chart answered it only if you knew how to read
/// it. The meter says it three ways at once, from most to least obvious:
///
/// 1. WORDS — a status pill in plain language ("AL AHLY ON TOP", "EVEN")
///    under the MOMENTUM label, tinted with the side that has the edge;
/// 2. A TUG-OF-WAR BAR — one bar split between the two sides at the
///    current pressure share, a glowing knob riding the split. The knob
///    slides smoothly to its new place every minute, so a swing in the
///    match is something you SEE move, not something you decode;
/// 3. A TREND — the whole match so far as one smooth wave: the home
///    side's pressure fills ABOVE the baseline, the away side's BELOW
///    it, and a pulsing dot marks "now".
///
/// The big percentages are the same trailing-window share
/// `computeMomentumSeries` gives (so the meter can never contradict the
/// events, GDD 13.1), rolled smoothly between minutes.
///
/// [live] false is the full-time report variant: the same trend over the
/// whole match with just the label row — a "who is on top right now"
/// reading means nothing once the whistle has gone.
///
/// Performance: one TweenAnimationBuilder drives the knob, the numbers
/// and the leading point of the wave; the screen rebuilds once per match
/// minute and both bars repaint in a single pass each — no per-minute
/// widgets, no long-lived controllers.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';

/// The spike colour of the side the user does NOT manage: dimmed white,
/// so the user's crest colour always owns the reading at first glance.
const Color opponentMomentumColor = Color(0xD9FFFFFF);

/// Very dark crest colours (ember charcoal, oxblood) vanish on the dark
/// panel — lift them toward white until they read, leave bright ones
/// alone.
Color _legible(Color c) =>
    c.computeLuminance() < 0.14 ? Color.lerp(c, Colors.white, 0.5)! : c;

/// The live momentum meter. See the library doc for the reading model.
class MomentumBar extends StatelessWidget {
  const MomentumBar({
    super.key,
    required this.series,
    required this.homeTeamName,
    required this.awayTeamName,
    this.homeColor = FcmColors.gold,
    this.awayColor = opponentMomentumColor,
    this.graphHeight = 46,
    this.live = true,
  });

  /// Per-minute HOME momentum share (0..1, 0.5 = dead level), index 0 =
  /// minute 1 — `computeMomentumSeries` output. Empty before kick-off.
  final List<double> series;

  final String homeTeamName;
  final String awayTeamName;

  /// Colour of the home side (the user's crest colour when they manage
  /// it).
  final Color homeColor;

  /// Colour of the away side.
  final Color awayColor;

  /// Height of the trend wave itself.
  final double graphHeight;

  /// True on the live screen (percentages, status words, tug-of-war
  /// bar); false for the full-time report (label row + trend only).
  final bool live;

  /// The status in plain words, for the TARGET share (not the animated
  /// one — the words must not flicker while the knob is still sliding).
  ({String text, Color color}) _status(double target, Color home, Color away) {
    final d = (target - 0.5).abs();
    if (series.isEmpty || d < 0.06) {
      return (text: 'EVEN', color: FcmColors.silver);
    }
    final isHome = target > 0.5;
    final name = (isHome ? homeTeamName : awayTeamName).toUpperCase();
    final color = isHome ? home : away;
    if (d < 0.14) return (text: '$name EDGING', color: color);
    if (d < 0.26) return (text: '$name ON TOP', color: color);
    return (text: '$name DOMINATING', color: color);
  }

  @override
  Widget build(BuildContext context) {
    final home = _legible(homeColor);
    final away = _legible(awayColor);
    final target = series.isEmpty
        ? 0.5
        : series.last.clamp(0.0, 1.0).toDouble();
    final status = _status(target, home, away);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, share, _) {
        final homePct = (share * 100).round().clamp(0, 100).toInt();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (live) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _SideReading(
                      name: homeTeamName,
                      percent: homePct,
                      color: home,
                      alignEnd: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'MOMENTUM',
                            style: TextStyle(
                              color: FcmColors.textDim,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _StatusPill(text: status.text, color: status.color),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _SideReading(
                      name: awayTeamName,
                      percent: 100 - homePct,
                      color: away,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 14,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TugPainter(
                    share: share,
                    homeColor: home,
                    awayColor: away,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: FitText(
                      homeTeamName,
                      align: Alignment.centerLeft,
                      style: TextStyle(
                        color: home,
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
                        color: away,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              height: graphHeight,
              child: CustomPaint(
                painter: _TrendPainter(
                  series: series,
                  liveShare: share,
                  homeColor: home,
                  awayColor: away,
                  showNow: live,
                ),
              ),
            ),
            const SizedBox(height: 3),
            const SizedBox(
              height: 12,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _AxisLabel("0'"),
                  ),
                  Align(alignment: Alignment.center, child: _AxisLabel('HT')),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _AxisLabel("90'"),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The bare momentum bar: no words, no numbers — just the tug-of-war.
/// The home side fills from the left, the away side from the right, and
/// a glowing knob rides the split. When pressure swings, the knob slides
/// smoothly to its new place, so who is pushing is something you SEE.
///
/// Used inside the live match header, where it replaces the old static
/// clock bar. [share] is the HOME side's pressure share, 0..1 (0.5 = dead
/// level) — the last value of `computeMomentumSeries`.
class MomentumTugBar extends StatelessWidget {
  const MomentumTugBar({
    super.key,
    required this.share,
    this.homeColor = FcmColors.gold,
    this.awayColor = opponentMomentumColor,
    this.height = 9,
  });

  final double share;
  final Color homeColor;
  final Color awayColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final target = share.clamp(0.0, 1.0).toDouble();
    final home = _legible(homeColor);
    final away = _legible(awayColor);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TugPainter(
            share: value,
            homeColor: home,
            awayColor: away,
          ),
        ),
      ),
    );
  }
}

/// One side's reading: club name over its big pressure percentage.
class _SideReading extends StatelessWidget {
  const _SideReading({
    required this.name,
    required this.percent,
    required this.color,
    required this.alignEnd,
  });

  final String name;
  final int percent;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FitText(
          name,
          align: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 1),
        FitText(
          '$percent%',
          align: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          style: TextStyle(
            color: color,
            fontSize: 24,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/// The status in words: a small pill tinted with the leading side.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: FitText(
        text,
        align: Alignment.center,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.1,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: FcmColors.textDim.withValues(alpha: 0.8),
        fontSize: 9,
        height: 1,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// The tug-of-war bar: the home side fills from the left to the split,
/// the away side from the right, a glowing knob rides the split and a
/// faint notch marks dead level so the lean reads against a reference.
class _TugPainter extends CustomPainter {
  const _TugPainter({
    required this.share,
    required this.homeColor,
    required this.awayColor,
  });

  /// Animated home share, 0..1.
  final double share;
  final Color homeColor;
  final Color awayColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything scales with the bar's height (thin in the header,
    // fuller in the report-sized meter).
    final inset = size.height / 7;
    final trackRect = Rect.fromLTWH(
      0,
      inset,
      size.width,
      size.height - inset * 2,
    );
    final track = RRect.fromRectAndRadius(
      trackRect,
      Radius.circular(trackRect.height / 2),
    );
    canvas.drawRRect(
      track,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    final x = share.clamp(0.0, 1.0).toDouble() * size.width;
    canvas.save();
    canvas.clipRRect(track);
    // Home side: brightest at the knob, fading toward its own end.
    final homeRect = Rect.fromLTRB(0, trackRect.top, x, trackRect.bottom);
    if (homeRect.width > 0) {
      canvas.drawRect(
        homeRect,
        Paint()
          ..shader = LinearGradient(
            colors: [homeColor.withValues(alpha: 0.45), homeColor],
          ).createShader(homeRect),
      );
    }
    // Away side: mirror.
    final awayRect = Rect.fromLTRB(
      x,
      trackRect.top,
      size.width,
      trackRect.bottom,
    );
    if (awayRect.width > 0) {
      canvas.drawRect(
        awayRect,
        Paint()
          ..shader = LinearGradient(
            colors: [awayColor, awayColor.withValues(alpha: 0.45)],
          ).createShader(awayRect),
      );
    }
    // Quarter / half notches: the dead-level reference.
    final notch = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final f in const [0.25, 0.5, 0.75]) {
      canvas.drawLine(
        Offset(size.width * f, trackRect.top),
        Offset(size.width * f, trackRect.bottom),
        notch,
      );
    }
    canvas.restore();

    // The knob: a soft glow, a bright split line and a round handle.
    final kx = x.clamp(size.height * 0.36, size.width - size.height * 0.36)
        .toDouble();
    final cy = size.height / 2;
    final knob = size.height * 0.39;
    canvas.drawCircle(
      Offset(kx, cy),
      knob * 1.6,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, knob * 0.9),
    );
    canvas.drawLine(
      Offset(kx, 0),
      Offset(kx, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = size.height >= 12 ? 2 : 1.4,
    );
    canvas.drawCircle(Offset(kx, cy), knob, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset(kx, cy),
      knob,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height >= 12 ? 2 : 1.2
        ..color = FcmColors.night,
    );
  }

  @override
  bool shouldRepaint(_TugPainter old) =>
      old.share != share ||
      old.homeColor != homeColor ||
      old.awayColor != awayColor;
}

/// The trend wave: one smooth curve across the match. Home pressure
/// fills ABOVE the baseline in the home colour, away pressure BELOW it
/// in the away colour; the curve's leading point eases toward the new
/// minute's reading and wears a glowing "now" dot on the live screen.
class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.series,
    required this.liveShare,
    required this.homeColor,
    required this.awayColor,
    required this.showNow,
  });

  final List<double> series;

  /// The animated reading for the LAST minute (the leading point eases
  /// into place instead of jumping).
  final double liveShare;
  final Color homeColor;
  final Color awayColor;
  final bool showNow;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final half = mid - 4;
    final n = series.length;
    final total = math.max(n, 90);

    // Baseline and the half-time marker.
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 1,
    );
    final htX = size.width * 45 / total;
    canvas.drawLine(
      Offset(htX, 3),
      Offset(htX, size.height - 3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.09)
        ..strokeWidth = 1,
    );
    if (n == 0) return;

    final values = List<double>.of(series);
    if (showNow) values[n - 1] = liveShare;

    final step = size.width / total;
    Offset point(int i) {
      final d =
          (values[i].clamp(0.0, 1.0).toDouble() - 0.5) * 2; // -1..1, + = home
      return Offset(step * (i + 1), mid - d * half);
    }

    // Smooth curve: quadratic segments through the midpoints.
    final line = Path()..moveTo(0, mid);
    var prev = Offset(0, mid);
    for (var i = 0; i < n; i++) {
      final p = point(i);
      line.quadraticBezierTo(
        prev.dx,
        prev.dy,
        (prev.dx + p.dx) / 2,
        (prev.dy + p.dy) / 2,
      );
      prev = p;
    }
    line.lineTo(prev.dx, prev.dy);

    // The area between the curve and the baseline, closed along it.
    final area = Path.from(line)
      ..lineTo(prev.dx, mid)
      ..lineTo(0, mid)
      ..close();

    // Home: above the baseline.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, mid));
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            homeColor.withValues(alpha: 0.08),
            homeColor.withValues(alpha: 0.6),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, mid)),
    );
    canvas.restore();

    // Away: below the baseline.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, mid, size.width, size.height));
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            awayColor.withValues(alpha: 0.08),
            awayColor.withValues(alpha: 0.55),
          ],
        ).createShader(Rect.fromLTWH(0, mid, size.width, size.height - mid)),
    );
    canvas.restore();

    // The curve itself.
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.92),
    );

    // "Now": a glowing dot at the leading point, in the leading colour.
    if (showNow) {
      final lead = values[n - 1] >= 0.5 ? homeColor : awayColor;
      canvas.drawCircle(
        prev,
        8,
        Paint()
          ..color = lead.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(prev, 3.6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.series != series ||
      old.liveShare != liveShare ||
      old.homeColor != homeColor ||
      old.awayColor != awayColor ||
      old.showNow != showNow;
}
