/// FCM Rivals — the duplicate-merge moment.
///
/// After a merge succeeds, this full-screen sequence plays: the two copies
/// fly in from either side of the screen, charge toward each other with a
/// growing glow and tremor, collide in a flash and shockwave, and the
/// upgraded card pops out of the light with its numbers counting up from
/// the old values to the new ones. Tap to close once the collision has
/// happened.
///
/// The merge is already saved when this plays: it is purely presentation.
/// It reuses the rays and spark painters of the pack opening so the two
/// big moments of the game share one visual language.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/player_card.dart' show FcmPlayerCard, pulse;
import '../packs/pack_effects.dart'
    show LightRaysPainter, ParticleBurstPainter, Spark;
import '../squad/squad_engine.dart' show PlayerCard;
import 'player_detail_sheet.dart' show cardStatsOf, rarityOf;

/// Haptics are garnish: a platform failure must never break the view.
void _haptic(Future<void> Function() fn) {
  try {
    fn().catchError((Object _) {});
  } catch (_) {}
}

/// Timeline marks, as fractions of the master controller.
class _T {
  static const enter = Interval(0.04, 0.34, curve: Curves.easeOutCubic);
  static const charge = Interval(0.34, 0.50);
  static const impact = 0.50;
  static const flash = Interval(0.495, 0.64, curve: Curves.easeOut);
  static const wave = Interval(0.50, 0.80, curve: Curves.easeOutCubic);
  static const burst = Interval(0.50, 0.80);
  static const burst2 = Interval(0.56, 0.92);
  static const pop = Interval(0.50, 0.72, curve: Curves.easeOutBack);
  static const popFade = Interval(0.50, 0.54);
  static const count = Interval(0.60, 0.82, curve: Curves.easeOut);
  static const shine = Interval(0.66, 0.88, curve: Curves.easeInOut);
  static const label = Interval(0.74, 0.90, curve: Curves.easeOut);
  static const done = 0.90;
}

/// The card [target] gained [newLevel] by consuming [duplicate].
///
Future<void> showCardMergeAnimation(
  BuildContext context, {
  required PlayerCard target,
  required PlayerCard duplicate,
  required int newLevel,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => CardMergeAnimation(
        target: target,
        duplicate: duplicate,
        newLevel: newLevel,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class CardMergeAnimation extends StatefulWidget {
  const CardMergeAnimation({
    super.key,
    required this.target,
    required this.duplicate,
    required this.newLevel,
  });

  final PlayerCard target;
  final PlayerCard duplicate;
  final int newLevel;

  @override
  State<CardMergeAnimation> createState() => _CardMergeAnimationState();
}

class _CardMergeAnimationState extends State<CardMergeAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _idle;
  late final AnimationController _spin;
  late final PlayerCard _after;
  late final List<Spark> _sparks;
  late final List<Spark> _sparks2;
  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    final t = widget.target;
    _after = PlayerCard(
      ownedId: t.ownedId,
      base: t.base,
      upgradeLevel: widget.newLevel,
      staminaPercent: t.staminaPercent,
      injuryMatchesRemaining: t.injuryMatchesRemaining,
      injuryKind: t.injuryKind,
    );
    _seq = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )
      ..addListener(_onTick)
      ..forward();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
    final r = math.Random(t.ownedId * 31 + widget.newLevel);
    final k = rarityOf(_after).intensity;
    _sparks = List.generate((60 * k).round(), (_) => Spark(r));
    _sparks2 = List.generate((30 * k).round(), (_) => Spark(r));
  }

  @override
  void dispose() {
    _seq.dispose();
    _idle.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Fires haptics exactly once when the timeline crosses a mark.
  void _onTick() {
    final t = _seq.value;
    bool crossed(double mark) => _lastT < mark && t >= mark;
    if (crossed(0.30)) _haptic(HapticFeedback.lightImpact);
    if (crossed(0.42)) _haptic(HapticFeedback.mediumImpact);
    if (crossed(_T.impact)) _haptic(HapticFeedback.heavyImpact);
    _lastT = t;
  }

  /// Horizontal offset of one incoming card: fly in, then charge inward.
  double _x(double t, int side, double cardW, double screenW) {
    final far = side * (screenW / 2 + cardW);
    final rest = side * cardW * 0.58;
    final meet = side * cardW * 0.04;
    if (t < _T.charge.begin) {
      return far + (rest - far) * _T.enter.transform(t);
    }
    final c = Curves.easeInCubic.transform(_T.charge.transform(t));
    // A tremor that grows as the cards are drawn together.
    final shake = math.sin(t * 220) * cardW * 0.012 * c;
    return rest + (meet - rest) * c + shake;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final smallW = math.min(size.width * 0.44, 190.0);
    final bigW = math.min(size.width * 0.62, 280.0);
    final accent = rarityOf(_after).accent;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Ignore taps until the collision has happened so a stray double
        // tap on the Merge button cannot skip the whole moment.
        onTap: () {
          if (_seq.value >= _T.impact) Navigator.of(context).pop();
        },
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: Listenable.merge([_seq, _idle, _spin]),
            builder: (context, _) {
              final t = _seq.value;
              final merged = t >= _T.impact;
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Scrim with the slowly turning rays; they swell with
                  // the charge and flare at the impact.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.9),
                    ),
                    child: CustomPaint(
                      painter: LightRaysPainter(
                        rotation: _spin.value,
                        color: accent,
                        strength: (0.12 +
                                0.30 * _T.charge.transform(t) +
                                0.25 * (merged ? 1 : 0) +
                                0.10 * pulse(_idle.value)) *
                            Curves.easeOut.transform(
                              ((t - 0.02) / 0.2).clamp(0.0, 1.0),
                            ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: _ShockwavePainter(
                      progress: _T.wave.transform(t),
                      color: accent,
                    ),
                  ),
                  if (!merged) ...[
                    _flyer(t, widget.duplicate, 1, smallW, size.width),
                    _flyer(t, widget.target, -1, smallW, size.width),
                  ] else
                    Align(
                      alignment: const Alignment(0, -0.08),
                      child: _mergedCard(t, bigW),
                    ),
                  // White-gold flash at the moment of impact.
                  IgnorePointer(
                    child: Opacity(
                      opacity: t < _T.flash.begin
                          ? 0
                          : (1 - _T.flash.transform(t)).clamp(0.0, 1.0) * 0.9,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0, -0.08),
                            radius: 0.9,
                            colors: [
                              Colors.white,
                              FcmColors.goldSoft,
                              Color(0x00D9B871),
                            ],
                            stops: [0, 0.35, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  CustomPaint(
                    painter: ParticleBurstPainter(
                      progress: _T.burst.transform(t),
                      sparks: _sparks,
                      color: accent,
                    ),
                  ),
                  CustomPaint(
                    painter: ParticleBurstPainter(
                      progress: _T.burst2.transform(t),
                      sparks: _sparks2,
                      color: FcmColors.goldSoft,
                    ),
                  ),
                  if (merged) _levelLabel(t),
                  if (t >= _T.done)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 42),
                        child: Opacity(
                          opacity: ((t - _T.done) / 0.06).clamp(0.0, 1.0),
                          child: const Text(
                            'TAP TO CONTINUE',
                            style: TextStyle(
                              color: FcmColors.textDim,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// One of the two copies flying in and charging toward the centre.
  Widget _flyer(double t, PlayerCard card, int side, double w, double screenW) {
    final enter = _T.enter.transform(t);
    final charge = _T.charge.transform(t);
    final rot = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(side * 0.55 * (1 - enter));
    return Align(
      alignment: const Alignment(0, -0.08),
      child: Opacity(
        opacity: Curves.easeOut.transform((t / 0.10).clamp(0.0, 1.0)),
        child: Transform.translate(
          offset: Offset(_x(t, side, w, screenW), 0),
          child: Transform.scale(
            scale: 1 + 0.10 * charge,
            child: Transform(
              alignment: Alignment.center,
              transform: rot,
              child: RepaintBoundary(
                child: FcmPlayerCard(
                  player: card.base,
                  rarity: rarityOf(card),
                  width: w,
                  overall: card.overall,
                  stats: cardStatsOf(card),
                  upgradeLevel: card.upgradeLevel,
                  shine: charge > 0 ? charge : null,
                  glow: 0.25 * enter + 0.75 * charge,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The upgraded card bursting out of the collision, numbers counting
  /// from the old values to the new ones.
  Widget _mergedCard(double t, double w) {
    final pop = _T.pop.transform(t);
    final p = _T.count.transform(t);
    final before = widget.target;
    final beforeStats = cardStatsOf(before);
    final afterStats = cardStatsOf(_after);
    int lerp(int a, int b) => (a + (b - a) * p).round();
    final stats = [
      for (var i = 0; i < afterStats.length; i++)
        (
          label: afterStats[i].label,
          value: lerp(beforeStats[i].value, afterStats[i].value),
        ),
    ];
    final done = t >= _T.done;
    final double? shine = done
        ? _idle.value
        : (t >= _T.shine.begin ? _T.shine.transform(t) : null);
    return Opacity(
      opacity: _T.popFade.transform(t),
      child: Transform.scale(
        scale: 0.5 + 0.5 * pop,
        child: RepaintBoundary(
          child: FcmPlayerCard(
            player: _after.base,
            rarity: rarityOf(_after),
            width: w,
            overall: lerp(before.overall, _after.overall),
            stats: stats,
            upgradeLevel: _after.upgradeLevel,
            shine: shine,
            glow: (0.6 + 0.4 * pulse(_idle.value)) *
                (0.6 + 0.2 * rarityOf(_after).intensity),
          ),
        ),
      ),
    );
  }

  /// "LEVEL +N" and what it did, rising in beneath the card.
  Widget _levelLabel(double t) {
    final a = _T.label.transform(t);
    final gained = widget.newLevel - widget.target.upgradeLevel;
    return Align(
      alignment: const Alignment(0, 0.74),
      child: Opacity(
        opacity: a,
        child: Transform.translate(
          offset: Offset(0, (1 - a) * 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'LEVEL +${widget.newLevel}',
                style: const TextStyle(
                  color: FcmColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ALL STATS +${widget.newLevel}%'
                '  ·  OVR ${widget.target.overall} → ${_after.overall}'
                '${gained > 1 ? '  ·  +$gained LEVELS' : ''}',
                style: const TextStyle(
                  color: FcmColors.silver,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two expanding rings leaving the point of impact.
class _ShockwavePainter extends CustomPainter {
  _ShockwavePainter({required this.progress, required this.color});

  /// 0..1 since the impact; 0 draws nothing.
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final c = Offset(size.width / 2, size.height * 0.46);
    for (var k = 0; k < 2; k++) {
      final p = ((progress - k * 0.14) / (1 - k * 0.14)).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final r = size.shortestSide * 0.12 + size.longestSide * 0.55 * p;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * (1 - p) + 1
          ..color = (k == 0 ? FcmColors.goldSoft : color).withValues(
            alpha: (1 - p) * 0.85,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_ShockwavePainter old) =>
      old.progress != progress || old.color != color;
}
