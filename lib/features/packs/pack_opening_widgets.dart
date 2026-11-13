/// FCM Rivals — pack opening widgets (extracted from
/// `pack_opening_screen.dart`, app-structure review task
/// `2026-11-05_app-structure_split-pack-reveal-widgets`): the mystery
/// card painter and the chain link / handoff widgets.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';

/// The legendary mystery card: a dark silhouette in the card outline with
/// a breathing rarity aura, rim and a large "?".
class MysteryPainter extends CustomPainter {
  MysteryPainter({required this.accent, required this.breath});

  final Color accent;

  /// 0..1 breathing phase.
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = cardPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.25 + 0.30 * breath)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1822), Color(0xFF050507)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, w * 0.014)
        ..strokeJoin = StrokeJoin.round
        ..color = accent.withValues(alpha: 0.65 + 0.35 * breath),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          color: accent.withValues(alpha: 0.30 + 0.30 * breath),
          fontSize: w * 0.55,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.46 - tp.height / 2));
  }

  @override
  bool shouldRepaint(MysteryPainter old) =>
      old.breath != breath || old.accent != accent;
}

/// The OPEN ANOTHER capsule under the revealed card: a tier-metal glow
/// pill that keeps the streak going — bolt mark, price (or the success
/// green FREE ×N when the club owns packs of this slot), then the live
/// balance behind a hairline. When the balance falls short the pill dims
/// into a 'NEED X MORE' state instead of vanishing, so the player always
/// sees why the chain stopped.
class ChainButton extends StatelessWidget {
  const ChainButton({
    super.key,
    required this.affordable,
    required this.isFree,
    required this.ownedCount,
    required this.price,
    required this.shortfall,
    required this.balance,
    required this.onPressed,
    this.accent,
  });

  final bool affordable;
  final bool isFree;
  final int ownedCount;
  final int price;
  final int shortfall;
  final int balance;
  final VoidCallback? onPressed;

  /// The next pack's tier metal — the foil the chain tears open next.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final metal = accent ?? FcmColors.goldSoft;
    return Opacity(
      opacity: affordable ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: affordable ? onPressed : null,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  metal.withValues(alpha: affordable ? 0.16 : 0.07),
                  Colors.black.withValues(alpha: 0.55),
                ],
              ),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: metal.withValues(alpha: affordable ? 0.65 : 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: metal.withValues(alpha: affordable ? 0.28 : 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: metal, size: 20),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'OPEN ANOTHER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                if (isFree)
                  // Same success-green metal the store's claim plates wear.
                  Text(
                    'FREE ×$ownedCount',
                    style: const TextStyle(
                      color: FcmColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  )
                else if (affordable) ...[
                  const FcmCoinGlyph(size: 14),
                  const SizedBox(width: 4),
                  Text(
                    FcmCoinChip.compact(price),
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ] else
                  Text(
                    'NEED ${FcmCoinChip.compact(shortfall)} MORE',
                    style: const TextStyle(
                      color: FcmColors.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 18,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                const SizedBox(width: 10),
                Text(
                  FcmCoinChip.compact(balance),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The chain's morph target: the moment OPEN ANOTHER lands, the action
/// bar collapses into one quiet line — card kept, next foil tearing
/// open — and the screen hands off to the next reveal.
class ChainHandoffLine extends StatelessWidget {
  const ChainHandoffLine({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: FcmColors.gold,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title == null
                ? 'Kept — tearing open the next foil…'
                : 'Kept — tearing open another $title…',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
