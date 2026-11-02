/// FCM Rivals — cinematic pack opening (GDD 5.6).
///
/// Sequence for each drawn player:
///   1. Sealed foil pack floats; tap to open.
///   2. Pack charges (shakes, cracks, glows in the card's rarity colour).
///   3. Flash + particle burst.
///   4. Walkout: nationality flag → position → name.
///   5. The card flips over, then rating and attributes count up.
/// Rarer pulls get more particles, stronger rays and a longer glow.
///
/// One master [AnimationController] drives the whole timeline through
/// [Interval]s, so skipping or replaying is just moving its value.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/domain/players.dart';
import '../../core/ui/country_flag.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import 'pack_effects.dart';

/// Haptics are garnish: a platform failure must never break the reveal.
void _haptic(Future<void> Function() fn) {
  try {
    fn().catchError((Object _) {});
  } catch (_) {}
}

/// Timeline marks, as fractions of the master controller.
class _T {
  static const chargeEnd = 0.20;
  static const flashPeak = 0.22;
  static const burstStart = 0.21;
  static const burstEnd = 0.46;
  static const flagIn = Interval(0.25, 0.33, curve: Curves.easeOutBack);
  static const posIn = Interval(0.32, 0.40, curve: Curves.easeOutBack);
  static const nameIn = Interval(0.39, 0.48, curve: Curves.easeOutBack);
  static const infoOut = Interval(0.50, 0.55, curve: Curves.easeIn);
  static const flip = Interval(0.50, 0.64, curve: Curves.easeOutCubic);
  static const shine = Interval(0.60, 0.80, curve: Curves.easeInOut);
  static const stats = Interval(0.64, 0.88, curve: Curves.easeOut);
  static const done = 0.88;
  /// Where the sequence restarts for the 2nd+ player (no pack scene).
  static const walkoutStart = 0.25;
}

class PackOpeningScreen extends StatefulWidget {
  const PackOpeningScreen({super.key, required this.players});

  final List<BasePlayer> players;

  @override
  State<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends State<PackOpeningScreen>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _idle;
  late final AnimationController _spin;

  int _index = 0;
  bool _started = false;
  double _lastT = 0;
  late List<Spark> _sparks;

  BasePlayer get _player => widget.players[_index];

  /// Same rating → rarity rule as the collection and squad, so a card looks
  /// identical everywhere in the game.
  CardRarity get _rarity =>
      CardRarity.fromOverall(_player.baseStats.overall);

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 8000))
      ..addListener(_onTick);
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    _spin = AnimationController(
        vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
    _makeSparks();
  }

  void _makeSparks() {
    final r = math.Random(_player.playerId * 31 + _index);
    _sparks = List.generate((60 * _rarity.intensity).round(), (_) => Spark(r));
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
    if (crossed(_T.chargeEnd)) _haptic(HapticFeedback.heavyImpact);
    if (crossed(0.50)) _haptic(HapticFeedback.mediumImpact);
    if (crossed(0.70) || crossed(0.78) || crossed(0.86)) {
      _haptic(HapticFeedback.selectionClick);
    }
    _lastT = t;
    // Rebuild buttons at the done mark (the AnimatedBuilder handles frames).
  }

  void _start() {
    if (_started) return;
    setState(() => _started = true);
    _haptic(HapticFeedback.lightImpact);
    _seq.forward(from: 0);
  }

  void _skip() {
    if (_seq.value < 0.50) {
      _seq.animateTo(0.50, duration: const Duration(milliseconds: 350));
    } else {
      _seq.animateTo(1.0, duration: const Duration(milliseconds: 350));
    }
  }

  void _next() {
    if (_index < widget.players.length - 1) {
      setState(() {
        _index++;
        _makeSparks();
      });
      _lastT = _T.walkoutStart;
      _seq.forward(from: _T.walkoutStart);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarity = _rarity;
    return Scaffold(
      backgroundColor: FcmColors.night,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _started ? null : _start,
        child: AnimatedBuilder(
          animation: Listenable.merge([_seq, _idle, _spin]),
          builder: (context, _) => _buildStage(context, rarity),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context, CardRarity rarity) {
    final t = _seq.value;
    final size = MediaQuery.sizeOf(context);
    final isFirst = _index == 0;
    // For the 2nd+ player the pack scene is skipped entirely.
    final showPack = isFirst && t < 0.24;
    final charge =
        isFirst ? Interval(0.0, _T.chargeEnd, curve: Curves.easeIn).transform(t) : 1.0;

    // Flash: ramps up to the burst, then fades.
    double flash = 0;
    if (isFirst) {
      flash = t < _T.flashPeak
          ? ((t - 0.18) / (_T.flashPeak - 0.18)).clamp(0.0, 1.0)
          : (1 - (t - _T.flashPeak) / 0.08).clamp(0.0, 1.0);
    }

    final raysStrength =
        Interval(0.22, 0.36).transform(t) * (0.55 + 0.25 * rarity.intensity);
    final glowTint = Color.lerp(
        FcmColors.goldSoft, rarity.accent, math.min(1.0, charge * 1.2))!;

    final burst =
        ((t - _T.burstStart) / (_T.burstEnd - _T.burstStart)).clamp(0.0, 1.0);

    final done = t >= _T.done;
    final flipT = _T.flip.transform(t);
    final infoFade = 1 - _T.infoOut.transform(t);

    final cardWidth = math.min(
        math.min(size.width * 0.74, 320.0), size.height * 0.52 * kPlayerCardAspect);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: night sky with a rarity-tinted glow behind the action.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.1),
              radius: 1.1,
              colors: [
                Color.lerp(FcmColors.surface, rarity.accent,
                    0.30 * (isFirst ? charge : 1.0))!,
                FcmColors.night,
              ],
            ),
          ),
        ),
        CustomPaint(
          painter: LightRaysPainter(
            rotation: _spin.value,
            color: glowTint,
            strength: raysStrength.clamp(0.0, 1.0),
          ),
        ),

        // Sealed pack.
        if (showPack) Center(child: _buildPack(t, charge, glowTint, size)),

        // Sparks.
        IgnorePointer(
          child: CustomPaint(
            painter: ParticleBurstPainter(
              progress: isFirst ? burst : 0,
              sparks: _sparks,
              color: rarity.accent,
            ),
          ),
        ),

        // Walkout: flag → position → name.
        if (t >= 0.25 && infoFade > 0)
          Opacity(
            opacity: infoFade.clamp(0.0, 1.0),
            child: Align(
              alignment: const Alignment(0, -0.12),
              child: _buildWalkout(t, rarity),
            ),
          ),

        // The card.
        if (flipT > 0)
          Align(
            alignment: const Alignment(0, -0.12),
            child: _buildCard(t, flipT, cardWidth, rarity),
          ),

        // Pull banner for epic / legendary cards.
        if (rarity != CardRarity.rare && _T.stats.transform(t) > 0)
          Align(
            alignment: const Alignment(0, -0.86),
            child: Opacity(
              opacity: _T.stats.transform(t).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.8 + 0.2 * _T.stats.transform(t),
                child: Text(
                  rarity == CardRarity.legendary
                      ? 'LEGENDARY PULL!'
                      : 'EPIC PULL!',
                  style: TextStyle(
                    color: rarity.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                          color: rarity.accent.withValues(alpha: 0.9),
                          blurRadius: 22),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Flash.
        if (flash > 0)
          IgnorePointer(
            child: ColoredBox(
              color: Color.lerp(FcmColors.goldSoft, rarity.accent, 0.25)!
                  .withValues(alpha: flash),
            ),
          ),

        // Tap hint.
        if (!_started)
          Align(
            alignment: const Alignment(0, 0.72),
            child: Opacity(
              opacity: 0.55 + 0.45 * pulse(_idle.value),
              child: const Text(
                'TAP TO OPEN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),

        // Top bar: close before opening, skip while it plays.
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: !_started
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : (!done
                      ? TextButton(
                          onPressed: _skip,
                          child: const Text('SKIP',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2)),
                        )
                      : const SizedBox.shrink()),
            ),
          ),
        ),

        // Keep / next button once the stats have counted up.
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: AnimatedOpacity(
                key: const ValueKey('keep-fade'),
                duration: const Duration(milliseconds: 300),
                opacity: done ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !done,
                  child: SizedBox(
                    width: double.infinity,
                    child: FcmButton(
                      onPressed: _next,
                      icon: _index < widget.players.length - 1
                          ? Icons.arrow_forward_rounded
                          : Icons.check_rounded,
                      label: _index < widget.players.length - 1
                          ? 'NEXT PLAYER  ${_index + 1}/${widget.players.length}'
                          : 'KEEP PLAYER',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPack(double t, double charge, Color glowTint, Size size) {
    final packW = math.min(size.width * 0.52, 230.0);
    final packH = packW / kPackAspect;
    // Idle float before tapping; violent shake while charging.
    final bob = _started ? 0.0 : math.sin(_idle.value * 2 * math.pi) * 10;
    final shake = math.sin(charge * 90) * 9 * charge;
    final tilt = math.sin(charge * 70) * 0.05 * charge;
    final scale = 1 + 0.14 * charge + 0.45 * Interval(0.19, 0.24).transform(t);
    final fade = 1 - Interval(0.20, 0.24).transform(t);
    return Opacity(
      opacity: fade.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(shake, bob),
        child: Transform.rotate(
          angle: tilt,
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: glowTint.withValues(alpha: 0.25 + 0.5 * charge),
                    blurRadius: 40 + 60 * charge,
                    spreadRadius: 4 + 14 * charge,
                  ),
                ],
              ),
              child: CustomPaint(
                size: Size(packW, packH),
                painter: FoilPackPainter(
                  shimmer: _idle.value,
                  charge: charge,
                  glowColor: glowTint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalkout(double t, CardRarity rarity) {
    final p = _player;
    final flag = _T.flagIn.transform(t);
    final pos = _T.posIn.transform(t);
    final name = _T.nameIn.transform(t);

    Widget pop(double v, Widget child, {double dy = 30}) => Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * dy),
            child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pop(flag, Text(flagEmojiFor(p.nationality),
            style: const TextStyle(fontSize: 88))),
        const SizedBox(height: 4),
        pop(
          flag,
          Text(
            p.nationality.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 5,
            ),
          ),
        ),
        const SizedBox(height: 18),
        pop(
          pos,
          Text(
            p.position.code,
            style: TextStyle(
              color: rarity.accent,
              fontSize: 64,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              shadows: [
                Shadow(color: rarity.accent.withValues(alpha: 0.8), blurRadius: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        pop(
          name,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              p.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(double t, double flipT, double cardWidth, CardRarity rarity) {
    final angle = (1 - flipT) * math.pi; // π (back) → 0 (front)
    final showBack = angle >= math.pi / 2;
    final scale = 0.55 + 0.45 * Curves.easeOutBack.transform(flipT.clamp(0.0, 1.0));
    final stats = _T.stats.transform(t);

    // Foil: one sweep during the reveal, then a gentle loop.
    final done = t >= _T.done;
    final double? shine = done
        ? _idle.value
        : (t >= 0.60 ? _T.shine.transform(t) : null);

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
                  player: _player,
                  rarity: rarity,
                  width: cardWidth,
                  statProgress: stats,
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
