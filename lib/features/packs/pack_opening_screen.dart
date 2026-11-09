/// FCM Rivals — cinematic pack opening (GDD 5.6).
///
/// Sequence for each drawn player (rare and epic pulls, ~8s):
///   1. Sealed foil pack floats — in the same tier metal as the store
///      cell — then tears itself open immediately (the first frame
///      renders sealed, the charge starts the moment that frame lands);
///      no separate tap-to-open step, no wait.
///   2. Pack charges (shakes, cracks, glows in the card's rarity colour).
///   3. Flash + particle burst.
///   4. Walkout: nationality flag → position.
///   5. The card flips over, then rating and attributes count up.
///   6. The player's NAME is revealed only when the stats have finished
///      counting up — the suspense runs to the very end.
/// Rarer pulls get more particles, stronger rays and a longer glow.
///
/// LEGENDARY pulls run their own, much longer sequence (~17s) built to
/// make the player wonder who it is for as long as possible:
///   1. A slow, heartbeat charge — the screen darkens around the pack
///      while it shudders harder and harder.
///   2. A golden burst with shock rings, then the stage goes dark and a
///      MYSTERY silhouette of the card rises, breathing, with a "?" on it.
///   3. Clues land one at a time on the silhouette: the nationality flag,
///      then the position. The rating is NOT shown here — it appears only
///      on the card itself, counting up after the flip.
///   4. The card flips slowly with a burst of light at the edge-on moment.
///   5. Attributes count up in slow motion while the camera pushes in and
///      the name slot sits redacted, pulsing.
///   6. The NAME is typed onto the card letter by letter — who the player
///      is arrives last — followed by a finale: flash, shock rings, a
///      second spark burst and the LEGENDARY PULL! banner.
///
/// One master [AnimationController] drives each timeline through
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
import '../economy/economy_engine.dart';
import '../../l10n/l10n_context.dart';
import 'pack_effects.dart';
import 'pack_opening_widgets.dart';
import 'pack_reveal_timeline.dart';
import 'pack_stagecraft.dart';

export 'pack_reveal_timeline.dart';

part 'pack_opening_screen_reveal.dart';

/// Haptics are garnish: a platform failure must never break the reveal.
void _haptic(Future<void> Function() fn) {
  try {
    fn().catchError((Object _) {});
  } catch (_) {}
}

/// Length of the standard (rare / epic) reveal timeline.
class PackChainInfo {
  const PackChainInfo({
    required this.price,
    required this.balance,
    required this.ownedCount,
    this.title,
  });

  /// Coin price of the next pack of the same shelf slot. Unused while
  /// [ownedCount] packs remain — those open for free.
  final int price;

  /// The club's balance at push time. After a mid-reveal sale the reveal
  /// re-asks the caller for a fresh value through its `queryBalance`
  /// callback, so the capsule never shows a stale figure.
  final int balance;

  /// Owned unopened packs of the same shelf slot — the next of these
  /// opens without touching the balance.
  final int ownedCount;

  /// Display name of the next pack, e.g. 'Rare Global Pack'.
  final String? title;

  /// Free when the club still owns packs of this slot.
  bool get isFree => ownedCount > 0;

  /// The chain action is offered only when the next pack is within reach:
  /// an owned pack, or a balance that covers the price.
  bool get affordable => isFree || balance >= price;

  /// Coins missing for the next purchase (0 when affordable).
  int get shortfall => isFree ? 0 : price - balance;
}

class PackOpeningScreen extends StatefulWidget {
  const PackOpeningScreen({
    super.key,
    required this.players,
    this.packTint,
    this.packStars = 3,
    this.ownedIds = const [],
    this.onSell,
    this.chainInfo,
    this.queryBalance,
  });

  final List<BasePlayer> players;

  /// The pack's tier metal — the exact colour the sealed pack wore in
  /// the store cell. Null keeps the classic charcoal leather (previews
  /// that are not a real store pack).
  final Color? packTint;

  /// Rarity stars on the sealed pack — the same count the shelf
  /// stamped: 3 rare, 4 epic, 5 legendary.
  final int packStars;

  /// Owned-player row ids of the drawn players, index-aligned with
  /// [players] — SELL straight from the reveal sells through the caller.
  final List<int> ownedIds;

  /// Sells the currently revealed player. Null (or a player without an
  /// owned id) hides the SELL button — e.g. key-man previews.
  final Future<void> Function(int ownedId)? onSell;

  /// Quick-chain data for OPEN ANOTHER on the last revealed card: open
  /// the next pack of the same shelf slot with no purchase dialog. Null
  /// hides the action — previews, and slots that cannot repeat.
  final PackChainInfo? chainInfo;

  /// Live balance source so the chain capsule re-checks affordability
  /// after a sale credits coins mid-reveal. Null keeps the snapshot
  /// balance from [chainInfo].
  final int? Function()? queryBalance;

  @override
  State<PackOpeningScreen> createState() => _PackOpeningScreenState();
}

class _PackOpeningScreenState extends State<PackOpeningScreen>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _idle;
  late final AnimationController _spin;

  int _index = 0;
  bool _selling = false;
  bool _chaining = false;

  /// Balance re-read from the caller after a mid-reveal sale — the
  /// snapshot in [PackChainInfo] predates any SELL credit.
  int? _liveBalance;
  double _lastT = 0;
  late List<Spark> _sparks;
  late List<Spark> _finaleSparks;

  BasePlayer get _player => widget.players[_index];

  /// The presentation-level class axis (T-0049): a 90+ pull is premium.
  CardClass get _cardClass =>
      CardClass.fromOverall(_player.baseStats.overall);

  bool get _isPremium => _cardClass == CardClass.premium;

  /// The reveal-show intensity (T-0050): premium escalates one notch
  /// above the legendary 2.0 through the same mechanisms.
  double get _intensity =>
      _isPremium ? kPremiumRevealIntensity : _rarity.intensity;

  /// The effective accent: the premium red for 90+ pulls, the rarity's
  /// jewel otherwise — one colour source for charge, rays and sparks.
  Color get _accent => _isPremium ? _cardClass.accent : _rarity.accent;

  /// The timeline the current player runs on: premium (90+) gets the red
  /// escalation, legendary (80-89) the golden one, rare/epic the
  /// ordinary one.
  RevealTimeline get _tl =>
      RevealTimeline.revealTimelineFor(_rarity, _cardClass);

  /// SELL exists only when the caller wired the sale and this draw has an
  /// owned id — preview draws (key men) have nothing to sell.
  bool get _canSell => widget.onSell != null && _index < widget.ownedIds.length;

  /// Sells the revealed player, then advances exactly like KEEP.
  Future<void> _sell() async {
    if (_selling) return;
    setState(() => _selling = true);
    _haptic(HapticFeedback.lightImpact);
    try {
      await widget.onSell!(widget.ownedIds[_index]);
      // The sale just credited coins: re-read the balance so the chain
      // capsule judges affordability on the fresh figure.
      _liveBalance = widget.queryBalance?.call();
    } catch (_) {
      // Selling failed upstream (e.g. player somehow in the squad): stay
      // on the card so the player sees the error and can KEEP instead.
      if (mounted) setState(() => _selling = false);
      return;
    }
    if (!mounted) return;
    _next();
  }

  /// OPEN ANOTHER on the last card: the card is kept (it is already
  /// owned — keeping needs no store call), the action bar morphs into a
  /// handoff line, then the screen pops with `true` and the caller
  /// acquires and reveals the next pack of the same shelf slot — no
  /// YES/NO in between.
  Future<void> _chain() async {
    if (_chaining || _selling) return;
    _haptic(HapticFeedback.mediumImpact);
    setState(() => _chaining = true);
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// The chain capsule lives on the last card only: earlier cards of a
  /// multi-draw must be resolved (sold or kept) first.
  bool get _showChain =>
      widget.chainInfo != null && _index == widget.players.length - 1;

  /// Balance the capsule shows and judges: the fresh figure after a sale,
  /// the push-time snapshot otherwise.
  int get _chainBalance => _liveBalance ?? widget.chainInfo?.balance ?? 0;

  bool get _chainAffordable {
    final info = widget.chainInfo;
    if (info == null) return false;
    return info.isFree || _chainBalance >= info.price;
  }

  /// Same rating → rarity rule as the collection and squad, so a card looks
  /// identical everywhere in the game.
  CardRarity get _rarity => CardRarity.fromOverall(_player.baseStats.overall);

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(vsync: this, duration: _tl.duration)
      ..addListener(_onTick);
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _makeSparks();
    // The pack tears itself open immediately: the timeline runs from the
    // first frame, so the sealed foil is on screen for exactly that one
    // frame before the charge — no wait, no tap-to-open step.
    _haptic(HapticFeedback.lightImpact);
    _playFrom(0);
  }

  void _makeSparks() {
    final r = math.Random(_player.playerId * 31 + _index);
    _sparks = List.generate((60 * _intensity).round(), (_) => Spark(r));
    // The premium wave re-fires the finale set a second time — a bounded
    // richer burst (worst case 156 + 120 = 276 particles, printed by the
    // timeline test).
    _finaleSparks = List.generate(_isPremium ? 120 : 90, (_) => Spark(r));
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
    final tl = _tl;
    final t = _seq.value;
    bool crossed(double mark) => _lastT < mark && t >= mark;
    for (final m in tl.heavy) {
      if (crossed(m)) _haptic(HapticFeedback.heavyImpact);
    }
    for (final m in tl.medium) {
      if (crossed(m)) _haptic(HapticFeedback.mediumImpact);
    }
    for (final m in tl.tick) {
      if (crossed(m)) _haptic(HapticFeedback.selectionClick);
    }
    _lastT = t;
  }

  /// Runs the current player's timeline from [from] — each rarity has
  /// its own length, so the controller's duration is set per run.
  void _playFrom(double from) {
    _seq.duration = _tl.duration;
    _lastT = from;
    _seq.forward(from: from);
  }

  void _next() {
    if (_index < widget.players.length - 1) {
      setState(() {
        _index++;
        _makeSparks();
      });
      _playFrom(_tl.walkoutStart);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarity = _rarity;
    return Scaffold(
      backgroundColor: FcmColors.night,
      body: AnimatedBuilder(
        animation: Listenable.merge([_seq, _idle, _spin]),
        builder: (context, _) => _buildStage(context, rarity),
      ),
    );
  }

  Widget _buildStage(BuildContext context, CardRarity rarity) {
    final tl = _tl;
    final legend = tl.isLegend;
    final premium = _isPremium;
    final accent = _accent;
    final t = _seq.value;
    final size = MediaQuery.sizeOf(context);
    final isFirst = _index == 0;
    // For the 2nd+ player the pack scene is skipped entirely.
    final showPack = isFirst && t < tl.packGone;
    final charge = isFirst
        ? Interval(0.0, tl.chargeEnd, curve: Curves.easeIn).transform(t)
        : 1.0;

    // Finale progress (legendary only): 0 until the name has landed, 1
    // once the sequence ends.
    final fin = legend ? tl.finale!.transform(t) : 0.0;
    // The premium escalation beat (T-0050): the SECOND, harder wave
    // right after the first one — same sparks, same rings, replayed.
    final fin2 = premium ? tl.finale2!.transform(t) : 0.0;

    // Flash: ramps up to the burst, then fades.
    double flash = 0;
    if (isFirst) {
      flash = t < tl.flashPeak
          ? ((t - tl.flashStart) / (tl.flashPeak - tl.flashStart)).clamp(
              0.0,
              1.0,
            )
          : (1 - (t - tl.flashPeak) / tl.flashFade).clamp(0.0, 1.0);
    }
    if (legend && fin > 0 && fin < 1) {
      // The finale's flash: a hard white-gold pop as the name completes.
      final pop = fin < 0.12
          ? fin / 0.12
          : (1 - (fin - 0.12) / 0.4).clamp(0.0, 1.0);
      flash = math.max(flash, 0.85 * pop);
    }
    if (premium && fin2 > 0) {
      // The second wave pops harder than the first.
      final pop2 = fin2 < 0.10 ? fin2 / 0.10 : (1 - (fin2 - 0.10) / 0.3).clamp(0.0, 1.0);
      flash = math.max(flash, 0.95 * pop2);
    }

    var raysStrength =
        tl.raysIn.transform(t) * (0.55 + 0.25 * _intensity);
    if (legend) {
      // Light leaks around the pack while it charges, and the rays flare
      // again for the finale — twice on the premium reveal.
      raysStrength =
          math.max(raysStrength, 0.35 * charge) + 0.35 * fin + 0.40 * fin2;
    }
    // The charge glow starts from the pack's own tier metal and moves
    // toward the drawn card's rarity colour as the pack heats up.
    // The glow then CLIMBS the rarity ladder (amethyst → sapphire → gold
    // → crimson) and stops on the rung of the card inside; lower pulls
    // flash the next rung for a beat (a near miss) before settling.
    final rank = revealRank(rarity, _cardClass);
    final glowTint = Color.lerp(
      widget.packTint ?? FcmColors.goldSoft,
      chargeGlowColor(charge: charge, rank: rank),
      math.min(1.0, charge * 4),
    )!;

    final burst = ((t - tl.burstStart) / (tl.burstEnd - tl.burstStart)).clamp(
      0.0,
      1.0,
    );

    // Camera shake: the burst's impact decays over the burst, and the
    // golden / red finales add their own hits — harder the rarer the pull.
    final impact = (isFirst && t >= tl.burstStart) ? (1 - burst) : 0.0;
    final kick =
        math.sin(math.pi * fin.clamp(0.0, 1.0)) * 6 +
        math.sin(math.pi * fin2.clamp(0.0, 1.0)) * 9;
    final shakeAmp = (2.0 + 2.5 * _intensity) * impact * impact + kick;
    final shake = Offset(
      math.sin(t * 900) * shakeAmp,
      math.cos(t * 740) * shakeAmp,
    );

    // Red-pull lightning: crackles around the charging pack and on both
    // finale waves.
    final lightning = premium
        ? math.max(
            showPack ? 0.55 * charge : 0.0,
            math.max(
              0.8 * math.sin(math.pi * fin.clamp(0.0, 1.0)),
              math.sin(math.pi * fin2.clamp(0.0, 1.0)),
            ),
          )
        : 0.0;

    // Ambient particles around the finished card, flavoured per rarity.
    final ambientStyle = switch (rank) {
      1 => AmbientStyle.crystals,
      2 => AmbientStyle.goldDust,
      3 => AmbientStyle.embers,
      _ => AmbientStyle.motes,
    };
    final ambientCount = switch (rank) {
      1 => 22,
      2 => 34,
      3 => 46,
      _ => 14,
    };

    final done = t >= tl.done;
    final flipT = tl.flip.transform(t);
    final infoFade = 1 - tl.infoOut.transform(t);

    final cardWidth = math.min(
      math.min(size.width * 0.74, 320.0),
      size.height * 0.52 * kPlayerCardAspect,
    );

    // Legendary stagecraft: a vignette that closes in while the mystery
    // builds and lifts as the name lands, plus the shock rings.
    var vignette = 0.0;
    var shock = 0.0;
    if (legend) {
      final close = Interval(0.0, tl.chargeEnd).transform(t);
      final open = tl.nameIn.transform(t);
      vignette = (close * 0.85 * (1 - 0.65 * open)).clamp(0.0, 1.0);
      shock = Interval(tl.burstStart, tl.burstStart + 0.14).transform(t);
    }

    // Camera push-in while the stats count and the name waits.
    final push = legend ? 1.0 + 0.10 * Interval(0.73, 0.95).transform(t) : 1.0;
    final edge = math.sin(flipT * math.pi);

    final bannerT = legend ? tl.bannerIn!.transform(t) : tl.stats.transform(t);

    final stage = Stack(
      fit: StackFit.expand,
      children: [
        // Background: night sky with a rarity-tinted glow behind the action.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.1),
              radius: 1.1,
              colors: [
                Color.lerp(
                  FcmColors.surface,
                  accent,
                  0.30 * (isFirst ? charge : 1.0),
                )!,
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
            rays: premium ? 26 : (legend ? 22 : 14),
          ),
        ),

        // Energy ring orbiting the sealed pack while it charges.
        if (showPack)
          IgnorePointer(
            child: CustomPaint(
              painter: ChargeRingPainter(
                charge: charge,
                rotation: _spin.value,
                color: glowTint,
                dots: 8 + 4 * rank,
                radius: math.min(size.width * 0.52, 230.0) / kPackAspect / 2,
              ),
            ),
          ),

        // Legendary vignette: the room goes dark around the action.
        if (legend && vignette > 0)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.1),
                  radius: 1.0,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.78 * vignette),
                  ],
                  stops: const [0.42, 1.0],
                ),
              ),
            ),
          ),

        // Sealed pack.
        if (showPack) Center(child: _buildPack(t, charge, glowTint, size, tl)),

        // Shock rings: the burst's pressure wave, and again at the finale
        // — twice on the premium reveal (the second wave hits harder).
        if (legend)
          IgnorePointer(
            child: CustomPaint(
              painter: ShockwavePainter(progress: shock, color: accent),
            ),
          ),
        if (legend)
          IgnorePointer(
            child: CustomPaint(
              painter: ShockwavePainter(
                progress: fin,
                color: accent,
                rings: premium ? 5 : 4,
              ),
            ),
          ),
        if (premium && fin2 > 0)
          IgnorePointer(
            child: CustomPaint(
              painter: ShockwavePainter(
                progress: fin2,
                color: accent,
                rings: 3,
              ),
            ),
          ),

        // Ordinary pulls get the burst's own pressure ring too — one for a
        // rare, two for an epic (the legendary reveal owns its rings above).
        if (!legend && isFirst)
          IgnorePointer(
            child: CustomPaint(
              painter: ShockwavePainter(
                progress: Interval(
                  tl.burstStart,
                  tl.burstStart + 0.12,
                ).transform(t),
                color: accent,
                rings: rarity == CardRarity.epic ? 2 : 1,
              ),
            ),
          ),

        // Sparks.
        IgnorePointer(
          child: CustomPaint(
            painter: ParticleBurstPainter(
              progress: (isFirst || legend) ? burst : 0,
              sparks: _sparks,
              color: accent,
            ),
          ),
        ),
        if (legend)
          IgnorePointer(
            child: CustomPaint(
              painter: ParticleBurstPainter(
                progress: fin,
                sparks: _finaleSparks,
                color: accent,
              ),
            ),
          ),
        if (premium && fin2 > 0)
          IgnorePointer(
            child: CustomPaint(
              painter: ParticleBurstPainter(
                progress: fin2,
                sparks: _finaleSparks,
                color: accent,
              ),
            ),
          ),

        if (premium && lightning > 0)
          IgnorePointer(
            child: CustomPaint(
              painter: LightningPainter(
                strength: lightning.clamp(0.0, 1.0),
                time: t,
                color: accent,
              ),
            ),
          ),

        // Legendary mystery: the card's silhouette rising out of the
        // dark, breathing, "?" on its face — the clues land on top of it.
        if (legend && t >= tl.mysteryIn!.begin && flipT < 0.2)
          Align(
            alignment: const Alignment(0, -0.12),
            child: _buildMystery(t, cardWidth, rarity, tl),
          ),

        // Walkout: flag → position.
        if (t >= tl.walkoutStart && infoFade > 0)
          Opacity(
            opacity: infoFade.clamp(0.0, 1.0),
            child: Align(
              alignment: const Alignment(0, -0.12),
              child: _buildWalkout(t, rarity, tl),
            ),
          ),

        // The flip's edge-on moment: a burst of light behind the card.
        if (legend && flipT > 0 && flipT < 1)
          IgnorePointer(
            child: Align(
              alignment: const Alignment(0, -0.12),
              child: Container(
                width: cardWidth * 1.9,
                height: cardWidth * 1.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.6 * edge),
                      accent.withValues(alpha: 0.28 * edge),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Ambient particles drifting around the finished card.
        if (flipT > 0)
          IgnorePointer(
            child: CustomPaint(
              painter: AmbientPainter(
                time: _spin.value,
                style: ambientStyle,
                color: accent,
                strength: flipT.clamp(0.0, 1.0),
                count: ambientCount,
              ),
            ),
          ),

        // The card.
        if (flipT > 0)
          Align(
            alignment: const Alignment(0, -0.12),
            child: Transform.scale(
              scale: push,
              child: _buildCard(t, flipT, cardWidth, rarity, tl),
            ),
          ),

        // Legendary suspense captions, above the card.
        if (legend)
          Align(alignment: const Alignment(0, -0.86), child: _buildCaption(t)),

        // Pull banner for epic / legendary cards.
        if (rarity != CardRarity.rare && bannerT > 0)
          Align(
            alignment: const Alignment(0, -0.86),
            child: Opacity(
              opacity: bannerT.clamp(0.0, 1.0),
              child: Transform.scale(
                scale:
                    (0.8 + 0.2 * bannerT) *
                    (legend ? 1.0 + 0.04 * pulse(_idle.value, cycles: 2) : 1.0),
                child: Text(
                  premium
                      ? l10nOf(context).revealBannerPremium
                      : rarity == CardRarity.legendary
                      ? 'LEGENDARY PULL!'
                      : 'EPIC PULL!',
                  style: TextStyle(
                    color: accent,
                    fontSize: legend ? 26 : 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                        color: accent.withValues(alpha: 0.9),
                        blurRadius: legend ? 30 : 22,
                      ),
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
              color: Color.lerp(
                FcmColors.goldSoft,
                accent,
                0.25,
              )!.withValues(alpha: flash),
            ),
          ),

        // The action bar once the stats have counted up: SELL and KEEP
        // resolve the card, and on the last card OPEN ANOTHER chains
        // straight into the next pack of the same shelf slot — no
        // purchase dialog between foils.
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _chaining
                        ? ChainHandoffLine(
                            key: const ValueKey('chain-handoff'),
                            title: widget.chainInfo?.title,
                          )
                        : Column(
                            key: const ValueKey('reveal-actions'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  if (_canSell)
                                    Expanded(
                                      child: FcmButton(
                                        style: FcmButtonStyle.steel,
                                        // The coin value the caller pays for THIS
                                        // player — a fresh pack draw is unupgraded —
                                        // shown with the same C coin as the top bar.
                                        label: 'SELL',
                                        coinValue: EconomyEngine().sellPriceOf(
                                          _player,
                                        ),
                                        loading: _selling,
                                        onPressed: _selling ? null : _sell,
                                      ),
                                    ),
                                  if (_canSell) const SizedBox(width: 10),
                                  Expanded(
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
                                ],
                              ),
                              if (_showChain) ...[
                                const SizedBox(height: 10),
                                ChainButton(
                                  affordable: _chainAffordable,
                                  isFree: widget.chainInfo!.isFree,
                                  ownedCount: widget.chainInfo!.ownedCount,
                                  price: widget.chainInfo!.price,
                                  shortfall: widget.chainInfo!.shortfall,
                                  balance: _chainBalance,
                                  accent: widget.packTint,
                                  onPressed: _chain,
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return Transform.translate(offset: shake, child: stage);
  }
}
