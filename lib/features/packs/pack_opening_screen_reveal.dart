part of 'pack_opening_screen.dart';

/// Reveal-stage view builders of the pack opening screen (extracted from
/// `_PackOpeningScreenState`, app-structure review task
/// `2026-11-06_app-structure_finish-pack-reveal-split`): the sealed pack,
/// the legendary mystery silhouette, the suspense captions, the walkout
/// and the card flip. Pure relocation — bodies unchanged; part of the
/// screen library so the private state members stay reachable.
extension _PackRevealViews on _PackOpeningScreenState {
  Widget _buildPack(
    double t,
    double charge,
    Color glowTint,
    Size size,
    RevealTimeline tl,
  ) {
    final packW = math.min(size.width * 0.52, 230.0);
    final packH = packW / kPackAspect;
    // Violent shake while charging — faster and harder the rarer the pull
    // (rare ≈ 108 / 9px, epic ≈ 122 / 11px, legendary ≈ 136 / 12px, red
    // ≈ 153 / 14px).
    final shake =
        math.sin(charge * (80 + 28 * _intensity)) *
        (6.0 + 3.2 * _intensity) *
        charge;
    final tilt =
        math.sin(charge * 70) * (0.04 + 0.014 * _intensity) * charge;
    final scale = 1 + 0.14 * charge + 0.45 * tl.packBurst.transform(t);
    final fade = 1 - tl.packFade.transform(t);
    return Opacity(
      opacity: fade.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(shake, 0),
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
                  // The store cell's exact tier metal, so the pack the
                  // player bought is the pack that tears open.
                  tint: widget.packTint,
                  stars: widget.packStars,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The legendary silhouette: a black card with a breathing rarity
  /// outline and a "?" — it rises (overshooting a little) as the dark
  /// closes in, and melts into the flip when the card turns.
  Widget _buildMystery(double t, double cardWidth, CardRarity rarity, RevealTimeline tl) {
    final rise = tl.mysteryIn!.transform(t);
    final fadeOut =
        1 - Interval(tl.flip.begin, tl.flip.begin + 0.03).transform(t);
    final opacity = (rise.clamp(0.0, 1.0) * fadeOut).clamp(0.0, 1.0);
    final scale = 0.7 + 0.3 * rise;
    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, (1 - rise.clamp(0.0, 1.0)) * 60),
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: cardWidth,
            height: cardWidth / kPlayerCardAspect,
            child: CustomPaint(
              painter: MysteryPainter(
                accent: rarity.accent,
                breath: pulse(_idle.value),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Short suspense lines above the action while the legend builds.
  Widget _buildCaption(double t) {
    // 'A LEGEND IS COMING…' while the silhouette rises and the first
    // clues land; 'WHO IS IT?' while the stats count and the name waits.
    // The second line's END tracks the ACTIVE timeline's name reveal —
    // the premium reveal (T-0050) starts its name earlier in the master
    // fraction than the golden one, so the caption must hand over to it.
    final activeNameStart = _tl.nameIn.begin;
    final a =
        Interval(0.21, 0.25).transform(t) *
        (1 - Interval(0.56, 0.60).transform(t));
    final b =
        Interval(0.76, 0.80).transform(t) *
        (1 -
            Interval(
              activeNameStart - 0.015,
              activeNameStart + 0.01,
            ).transform(t));
    Widget line(String text, double opacity) => Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
        ),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        if (a > 0) line('A LEGEND IS COMING…', a),
        if (b > 0) line('WHO IS IT?', b),
      ],
    );
  }

  Widget _buildWalkout(double t, CardRarity rarity, RevealTimeline tl) {
    final p = _player;
    final flag = tl.flagIn.transform(t);
    final pos = tl.posIn.transform(t);

    Widget pop(double v, Widget child, {double dy = 30}) => Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - v) * dy),
        child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
      ),
    );

    // No name and no rating here: the identity and the overall land on
    // the card itself, after the flip (GDD 5.6 suspense) — the walkout
    // gives flag and position only.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        pop(
          flag,
          Text(
            flagEmojiFor(p.nationality),
            style: const TextStyle(fontSize: 88),
          ),
        ),
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
                Shadow(
                  color: rarity.accent.withValues(alpha: 0.8),
                  blurRadius: 24,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCard(
    double t,
    double flipT,
    double cardWidth,
    CardRarity rarity,
    RevealTimeline tl,
  ) {
    final legend = tl.isLegend;
    final angle = (1 - flipT) * math.pi; // π (back) → 0 (front)
    final showBack = angle >= math.pi / 2;
    final scale =
        0.55 + 0.45 * Curves.easeOutBack.transform(flipT.clamp(0.0, 1.0));
    // The card 'punches' as the last stat lands and the buttons arrive.
    final punch =
        1.0 +
        0.045 *
            math.sin(
              math.pi *
                  Interval(
                    tl.done - 0.02,
                    math.min(1.0, tl.done + 0.05),
                  ).transform(t),
            );
    final stats = tl.stats.transform(t);
    // Identity lands only after the stats have counted up.
    final name = tl.nameIn.transform(t);

    // Foil: one sweep during the reveal, then a gentle loop.
    final done = t >= tl.done;
    final double? shine = done
        ? _idle.value
        : (t >= tl.shine.begin ? tl.shine.transform(t) : null);

    final rot = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(showBack ? angle - math.pi : angle);

    return Transform.translate(
      offset: Offset(0, (1 - flipT) * 50),
      child: Transform.scale(
        scale: scale * punch,
        child: Transform(
          alignment: Alignment.center,
          transform: rot,
          child: showBack
              ? FcmPlayerCardBack(
                  rarity: rarity,
                  cardClass: CardClass.fromOverall(_player.baseStats.overall),
                  width: cardWidth,
                )
              : FcmPlayerCard(
                  player: _player,
                  rarity: rarity,
                  width: cardWidth,
                  statProgress: stats,
                  nameProgress: name,
                  // Legendary: the name types in letter by letter, and
                  // a redacted bar breathes where it will land.
                  nameLetters: legend ? name : null,
                  maskName: legend,
                  maskPulse: pulse(_idle.value, cycles: 2),
                  shine: shine,
                  // Idle animation of the rarity artwork (turning rays,
                  // glints, lightning veins, rim pulse).
                  phase: _idle.value,
                  glow:
                      (0.55 + 0.45 * pulse(_idle.value)) *
                      flipT.clamp(0.0, 1.0) *
                      (0.6 + 0.2 * rarity.intensity),
                ),
        ),
      ),
    );
  }
}
