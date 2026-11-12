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

import '../../core/ui/fcm_button.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/player_card.dart' show FcmPlayerCard, pulse;
import '../../l10n/l10n_context.dart';
import '../collection/player_detail_sheet.dart' show cardStatsOf, rarityOf;
import '../packs/pack_effects.dart'
    show ParticleBurstPainter, Spark;
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
///
/// T-0090: the view manages the card in place — [onSell] runs the
/// squad-aware sale, [onUpgrade] merges the first duplicate; both are
/// optional (a showcase-only caller passes neither and the view keeps
/// its tap-anywhere dismiss). [duplicates] is the other owned copies of
/// the same player: it drives UPGRADE's enabled state and its merge
/// target.
Future<void> showPlayerCardReveal(
  BuildContext context, {
  required PlayerCard card,
  List<PlayerCard> duplicates = const [],
  Future<void> Function()? onSell,
  Future<void> Function(PlayerCard duplicate)? onUpgrade,
  void Function(
    void Function(PlayerCard card, List<PlayerCard> duplicates),
  )?
  onRefreshRegistered,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      // The card carries its own entrance (the zoom); the route only
      // needs a quick dim, and the same fade runs in reverse on dismiss.
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => PlayerCardReveal(
        card: card,
        duplicates: duplicates,
        onSell: onSell,
        onUpgrade: onUpgrade,
        onRefreshRegistered: onRefreshRegistered,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full-screen card view itself: scrim, rotating rays, the zooming
/// card and the spark burst, all driven by one master timeline.
class PlayerCardReveal extends StatefulWidget {
  const PlayerCardReveal({
    super.key,
    required this.card,
    this.duplicates = const [],
    this.onSell,
    this.onUpgrade,
    this.onRefreshRegistered,
  });

  final PlayerCard card;

  /// The player's OTHER owned copies (T-0090): non-empty enables
  /// UPGRADE — merging with the first; the action disables once the
  /// copies run out (the merge consumes them).
  final List<PlayerCard> duplicates;

  /// Squad-aware sell (clears + re-picks an XI slot, then sells).
  /// Null hides the whole action bar — showcase-only callers.
  final Future<void> Function()? onSell;

  /// Merge-with-first-duplicate upgrade. Null hides the bar.
  final Future<void> Function(PlayerCard duplicate)? onUpgrade;

  /// Handed the state's in-place refresh (T-0090 Requirement 4) once
  /// the state exists — the caller uses it after a merge to re-render
  /// the stronger card without re-opening.
  final void Function(
    void Function(PlayerCard card, List<PlayerCard> duplicates),
  )?
  onRefreshRegistered;

  @override
  State<PlayerCardReveal> createState() => _PlayerCardRevealState();
}

class _PlayerCardRevealState extends State<PlayerCardReveal>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _idle;
  late List<Spark> _sparks;
  double _lastT = 0;

  /// The card as it is NOW (T-0090): an upgrade re-renders this in
  /// place instead of re-opening — the view refreshes to the stronger
  /// card and stays open.
  late PlayerCard _card;
  List<PlayerCard> _duplicates = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _duplicates = widget.duplicates;
    widget.onRefreshRegistered?.call(refreshCard);
    _seq =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1500),
          )
          ..addListener(_onTick)
          ..forward();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    // Perf pass 2026-11-12: the 24s `_spin` controller was merged into
    // the AnimatedBuilder but never read by any painter — a dead 60fps
    // ticker for the view's whole lifetime. Removed.
    _respark();
  }

  /// Rebuilds the spark burst for the card currently on show — an
  /// upgrade re-runs it over the stronger card.
  void _respark() {
    final r = math.Random(_card.ownedId * 31 + 7);
    _sparks = List.generate(
      (40 * rarityOf(_card).intensity).round(),
      (_) => Spark(r),
    );
  }

  @override
  void dispose() {
    _seq.dispose();
    _idle.dispose();
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
    final rarity = rarityOf(_card);
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
            animation: Listenable.merge([_seq, _idle]),
            builder: (context, _) {
              final t = _seq.value;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Scrim: deep immersive radial gradient tinted by the rarity glow (same style as pack opening).
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.15),
                        radius: 1.1,
                        colors: [
                          Color.lerp(
                            FcmColors.surface,
                            rarity.accent,
                            0.30,
                          )!,
                          FcmColors.night,
                        ],
                      ),
                    ),
                  ),
                  // The card, slightly above centre where the rays and
                  // the burst converge.
                  Align(
                    alignment: const Alignment(0, -0.08),
                    child: _buildCard(
                      t,
                      _T.enter.transform(t),
                      cardWidth,
                      rarity,
                    ),
                  ),
                  // Sparks fly OVER the card as it settles.
                  CustomPaint(
                    painter: ParticleBurstPainter(
                      progress: _T.burst.transform(t),
                      sparks: _sparks,
                      color: rarity.accent,
                    ),
                  ),
                  // Action bar once the entrance has finished
                  // (T-0090): BACK / SELL / UPGRADE — UPGRADE is the
                  // gold primary. Showcase-only callers (no callbacks)
                  // keep the plain TAP TO CLOSE hint.
                  if (t >= _T.done)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: EdgeInsets.only(
                          bottom: 42,
                          left: 18,
                          right: 18,
                        ),
                        child: Opacity(
                          opacity: _T.hintIn.transform(t),
                          child: _hasActions
                              ? _buildActionBar(context)
                              : const Text(
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
    double t,
    double enterT,
    double cardWidth,
    CardRarity rarity,
  ) {
    final card = _card;
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
              glow:
                  (0.55 + 0.45 * pulse(_idle.value)) *
                  enterT.clamp(0.0, 1.0) *
                  (0.6 + 0.2 * rarity.intensity),
            ),
          ),
        ),
      ),
    );
  }

  /// Whether this view manages the card: SELL or UPGRADE wired — else
  /// it stays the plain showcase with the TAP TO CLOSE hint.
  bool get _hasActions =>
      widget.onSell != null || widget.onUpgrade != null;

  /// BACK (ghost, leading) · SELL (steel, price) · UPGRADE (gold,
  /// primary) — the T-0090 bottom bar. UPGRADE disables when no other
  /// copy remains; every button keeps the tap-anywhere dismiss off
  /// (its hit area stays inside the bar).
  Widget _buildActionBar(BuildContext context) {
    final l10n = l10nOf(context);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: FcmButton(
            key: const ValueKey('reveal-back'),
            label: l10n.revealBack,
            style: FcmButtonStyle.ghost,
            compact: true,
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: FcmButton(
            key: const ValueKey('reveal-sell'),
            label: l10n.revealSell,
            icon: Icons.sell_outlined,
            style: FcmButtonStyle.steel,
            compact: true,
            onPressed: _busy || widget.onSell == null
                ? null
                : _runSell,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: FcmButton(
            key: const ValueKey('reveal-upgrade'),
            label: l10n.revealUpgrade,
            icon: Icons.merge_type,
            style: FcmButtonStyle.gold,
            compact: true,
            onPressed: _busy || _duplicates.isEmpty
                ? null
                : _runUpgrade,
          ),
        ),
      ],
    );
  }

  /// SELL: hands the CURRENT card to the caller's squad-aware sale —
  /// the caller pops the view when it reports success (the sold row
  /// no longer exists). Failures keep the view open with a snackbar.
  Future<void> _runSell() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSell?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// UPGRADE: merges the first other copy — the caller runs the merge
  /// and its animation, then reports the NEW stronger card and the
  /// remaining copies; the view re-renders in place and stays open
  /// (Requirement 5).
  Future<void> _runUpgrade() async {
    if (_busy || _duplicates.isEmpty) return;
    setState(() => _busy = true);
    try {
      await widget.onUpgrade?.call(_duplicates.first);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  /// The caller refreshed the card after a merge: adopt it, re-spark
  /// the burst for the stronger man and drop the consumed copy.
  void refreshCard(PlayerCard newCard, List<PlayerCard> duplicates) {
    if (!mounted) return;
    setState(() {
      _card = newCard;
      _duplicates = duplicates;
    });
    _respark();
  }
}
