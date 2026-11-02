/// FCM Rivals — full-card reveal for the Tactics tab.
///
/// Tapping a player anywhere in the tactical setup (pitch, bench or
/// reserves) opens this full-screen moment instead of a detail sheet:
/// the card back flips over into the full-size card, light rays sweep
/// in behind it in the rarity colour, sparks burst as the face lands,
/// then the rating and attributes count up and the name reveals last —
/// the same beats as the pack opening (GDD 5.6), compressed into a
/// two-second walkout. Tap anywhere to dismiss.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/player_card.dart' show FcmPlayerCard, FcmPlayerCardBack, pulse;
import '../collection/player_detail_sheet.dart'
    show cardStatsOf, rarityOf;
import '../packs/pack_effects.dart'
    show LightRaysPainter, ParticleBurstPainter, Spark;
import 'squad_engine.dart' show PlayerCard;

/// Haptics are garnish: a platform failure must never break the reveal.
void _haptic(Future<void> Function() fn) {
  try {
    fn().catchError((Object _) {});
  } catch (_) {}
}

/// Timeline marks, as fractions of the master controller.
class _T {
  static const flip = Interval(0.05, 0.40, curve: Curves.easeOutCubic);
  static const burst = Interval(0.34, 0.62);
  static const shine = Interval(0.36, 0.58, curve: Curves.easeInOut);
  static const stats = Interval(0.40, 0.72, curve: Curves.easeOut);
  static const nameIn = Interval(0.72, 0.88, curve: Curves.easeOutBack);
  static const hintIn = Interval(0.90, 1.0, curve: Curves.easeOut);
  static const done = 0.88;
}

/// Opens the full-card reveal for [card] as a full-screen route.
Future<void> showPlayerCardReveal(
  BuildContext context, {
  required PlayerCard card,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      // The reveal carries its own entrance (the flip); the route only
      // needs a quick dim, and the same fade runs in reverse on dismiss.
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => PlayerCardReveal(card: card),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full-screen reveal itself: scrim, rotating rays, the flipping
/// card and the spark burst, all driven by one master timeline.
class PlayerCardReveal extends StatefulWidget {
  const PlayerCardReveal({super.key, required this.card});

  final PlayerCard card;

  @override
  State<PlayerCardReveal> createState() => _PlayerCardRevealState();
}

class _PlayerCardRevealState extends State<PlayerCardReveal>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _idle;
  late final AnimationController _spin;
  late List<Spark> _sparks;
  double _lastT = 0;

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..addListener(_onTick)..forward();
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _spin = AnimationController(
        vsync: this, duration: const Duration(seconds: 24))
      ..repeat();
    final r = math.Random(widget.card.ownedId * 31 + 7);
    _sparks = List.generate(
        (40 * rarityOf(widget.card).intensity).round(), (_) => Spark(r));
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
    if (crossed(0.40)) _haptic(HapticFeedback.mediumImpact);
    if (crossed(0.50) || crossed(0.60)) {
      _haptic(HapticFeedback.selectionClick);
    }
    if (crossed(0.72)) _haptic(HapticFeedback.lightImpact);
    _lastT = t;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final rarity = rarityOf(card);
    final size = MediaQuery.sizeOf(context);
    final cardWidth = math.min(size.width * 0.68, 300.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        // The subtree is all painters and boxes: nothing claims hits on
        // its own, so the detector itself must swallow every touch.
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: Listenable.merge([_seq, _idle, _spin]),
            builder: (context, _) {
              final t = _seq.value;
              final flipT = _T.flip.transform(t);

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Scrim: near-black, tinted by the rarity glow.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.88),
                    ),
                    child: CustomPaint(
                      painter: LightRaysPainter(
                        rotation: _spin.value,
                        color: rarity.accent,
                        strength: (0.30 + 0.20 * pulse(_idle.value)) *
                            Curves.easeOut
                                .transform(((t - 0.02) / 0.20).clamp(0.0, 1.0)),
                      ),
                    ),
                  ),
                  // The card, slightly above centre where the rays and
                  // the burst converge.
                  Align(
                    alignment: const Alignment(0, -0.08),
                    child: _buildCard(t, flipT, cardWidth, rarity),
                  ),
                  // Sparks fly OVER the card as the face lands.
                  CustomPaint(
                    painter: ParticleBurstPainter(
                      progress: _T.burst.transform(t),
                      sparks: _sparks,
                      color: rarity.accent,
                    ),
                  ),
                  // Dismiss hint once the walkout has finished.
                  if (t >= _T.done)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 42),
                        child: Opacity(
                          opacity: _T.hintIn.transform(t),
                          child: const Text(
                            'TAP TO CLOSE',
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

  /// The flipping card: back → front with the pack's transform (scale
  /// easeOutBack, upward drift, 3D turn), then the rating and attributes
  /// count up and the name lands last — `statProgress` / `nameProgress`
  /// carry those beats on the card face itself.
  Widget _buildCard(
      double t, double flipT, double cardWidth, CardRarity rarity) {
    final card = widget.card;
    final angle = (1 - flipT) * math.pi; // π (back) → 0 (front)
    final showBack = angle >= math.pi / 2;
    final scale =
        0.55 + 0.45 * Curves.easeOutBack.transform(flipT.clamp(0.0, 1.0));
    final stats = _T.stats.transform(t);
    final name = _T.nameIn.transform(t);

    // Foil: one sweep during the reveal, then a gentle loop.
    final done = t >= _T.done;
    final double? shine =
        done ? _idle.value : (t >= 0.36 ? _T.shine.transform(t) : null);

    final rot = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(showBack ? angle - math.pi : angle);

    return Transform.translate(
      offset: Offset(0, (1 - flipT) * 50),
      child: Transform.scale(
        scale: scale,
        child: Transform(
          alignment: Alignment.center,
          transform: rot,
          child: showBack
              ? FcmPlayerCardBack(rarity: rarity, width: cardWidth)
              : FcmPlayerCard(
                  player: card.base,
                  rarity: rarity,
                  width: cardWidth,
                  overall: card.overall,
                  stats: cardStatsOf(card),
                  upgradeLevel: card.upgradeLevel,
                  statProgress: stats,
                  nameProgress: name,
                  shine: shine,
                  glow: (0.55 + 0.45 * pulse(_idle.value)) *
                      flipT.clamp(0.0, 1.0) *
                      (0.6 + 0.2 * rarity.intensity),
                ),
        ),
      ),
    );
  }
}
