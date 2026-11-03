/// FCM Rivals — full-card view for the Team tab.
///
/// Tapping a player anywhere in the tactical setup (pitch, bench or
/// reserves) opens this full-screen moment instead of a detail sheet:
/// the full-size card zooms in face-up over light rays in the rarity
/// colour, sparks burst as it settles, the foil sweeps once and the
/// glow keeps pulsing while idle. Unlike the pack opening (GDD 5.6)
/// there is NO reveal suspense — this is the user's own player, so the
/// name, rating, attributes and upgrade badge are fully visible from
/// the moment the face arrives: no card back, no counting, no masked
/// name. Tap anywhere to dismiss.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/player_card.dart' show FcmPlayerCard, pulse;
import '../collection/player_detail_sheet.dart'
    show cardStatsOf, rarityOf;
import '../packs/pack_effects.dart'
    show LightRaysPainter, ParticleBurstPainter, Spark;
import 'squad_engine.dart' show PlayerCard;

/// Haptics are garnish: a platform failure must never break the view.
void _haptic(Future<void> Function() fn) {
  try {
    fn().catchError((Object _) {});
  } catch (_) {}
}

/// Timeline marks, as fractions of the master controller.
class _T {
  static const enter = Interval(0.04, 0.42, curve: Curves.easeOutCubic);
  static const burst = Interval(0.28, 0.56);
  static const shine = Interval(0.30, 0.54, curve: Curves.easeInOut);
  static const hintIn = Interval(0.68, 0.86, curve: Curves.easeOut);
  static const done = 0.56;
}

/// Opens the full-card view for [card] as a full-screen route.
Future<void> showPlayerCardReveal(
  BuildContext context, {
  required PlayerCard card,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      // The card carries its own entrance (the zoom); the route only
      // needs a quick dim, and the same fade runs in reverse on dismiss.
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => PlayerCardReveal(card: card),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full-screen card view itself: scrim, rotating rays, the zooming
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
        vsync: this, duration: const Duration(milliseconds: 1500))
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
    if (crossed(0.28)) _haptic(HapticFeedback.lightImpact);
    if (crossed(0.42)) _haptic(HapticFeedback.mediumImpact);
    _lastT = t;
  }

  @override
  Widget build(BuildContext context) {
    final rarity = rarityOf(widget.card);
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
                    child: _buildCard(t, _T.enter.transform(t), cardWidth, rarity),
                  ),
                  // Sparks fly OVER the card as it settles.
                  CustomPaint(
                    painter: ParticleBurstPainter(
                      progress: _T.burst.transform(t),
                      sparks: _sparks,
                      color: rarity.accent,
                    ),
                  ),
                  // Dismiss hint once the entrance has finished.
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

  /// The card itself: zooms in FACE-UP — quick fade, easeOutBack scale,
  /// upward drift and a small 3D turn-in. No card back and no
  /// statProgress/nameProgress, so the identity and attributes are
  /// rendered in full from the first frame of the face: the user knows
  /// this player already, this is a showcase, not a reveal.
  Widget _buildCard(
      double t, double enterT, double cardWidth, CardRarity rarity) {
    final card = widget.card;
    final e = Curves.easeOutBack.transform(enterT.clamp(0.0, 1.0));
    final fade = Curves.easeOut.transform(((t - 0.02) / 0.16).clamp(0.0, 1.0));

    // Foil: one sweep as the card settles, then a gentle loop.
    final done = t >= _T.done;
    final double? shine = done
        ? _idle.value
        : (t >= _T.shine.begin ? _T.shine.transform(t) : null);

    final rot = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY((1 - e) * 0.55);

    return Opacity(
      opacity: fade,
      child: Transform.translate(
        offset: Offset(0, (1 - e) * 46),
        child: Transform.scale(
          scale: 0.62 + 0.38 * e,
          child: Transform(
            alignment: Alignment.center,
            transform: rot,
            child: FcmPlayerCard(
              player: card.base,
              rarity: rarity,
              width: cardWidth,
              overall: card.overall,
              stats: cardStatsOf(card),
              upgradeLevel: card.upgradeLevel,
              shine: shine,
              glow: (0.55 + 0.45 * pulse(_idle.value)) *
                  enterT.clamp(0.0, 1.0) *
                  (0.6 + 0.2 * rarity.intensity),
            ),
          ),
        ),
      ),
    );
  }
}
