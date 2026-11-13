/// FCM Rivals — buy-squad-slots control (Team tab).
///
/// The compact gold pill beside the 'All players' title ('+5 [C] 8K')
/// and the YES/NO confirmation it opens. Coins are the game's hard
/// currency, so — like a pack purchase — a slot purchase always passes an
/// explicit confirmation with the price and an affordability check; the
/// store still validates atomically.
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';

/// The pill: '+[slots]' and the coin price of the next block.
class SquadSlotsButton extends StatelessWidget {
  const SquadSlotsButton({
    super.key,
    required this.slots,
    required this.price,
    required this.onTap,
    this.canAfford = true,
  });

  /// Slots the purchase adds.
  final int slots;

  /// Coins the purchase costs.
  final int price;

  /// When false the pill dims; a tap still opens the confirmation, which
  /// says why it cannot go through.
  final bool canAfford;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: FcmColors.ink,
      fontWeight: FontWeight.w900,
      fontSize: 13,
      letterSpacing: 0.4,
    );
    return Semantics(
      button: true,
      label: 'Buy $slots more squad slots for $price coins',
      excludeSemantics: true,
      child: Opacity(
        opacity: canAfford ? 1 : 0.55,
        child: FcmPressable(
          onTap: onTap,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: FcmColors.goldGradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FcmColors.goldSoft.withValues(alpha: 0.5)),
              boxShadow: canAfford
                  ? [
                      BoxShadow(
                        color: FcmColors.gold.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 16, color: FcmColors.ink),
                Text('$slots', style: textStyle),
                const SizedBox(width: 8),
                const FcmCoinGlyph(size: 14),
                const SizedBox(width: 3),
                Text(FcmCoinChip.compact(price), style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The YES/NO confirmation: what is bought, its price and — when the
/// balance falls short — why YES is off. Resolves to true on YES.
Future<bool?> showBuySquadSlotsDialog(
  BuildContext context, {
  required int slots,
  required int price,
  required int? coins,
}) {
  final canAfford = coins == null || coins >= price;
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: FcmColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Buy $slots more player slots?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FcmCoinGlyph(size: 22),
              const SizedBox(width: 8),
              Text(
                FcmCoinChip.compact(price),
                style: const TextStyle(
                  color: FcmColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (!canAfford) ...[
            const SizedBox(height: 10),
            const Text(
              'Not enough coins',
              style: TextStyle(
                color: FcmColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
      actions: [
        SizedBox(
          width: 110,
          child: FcmButton(
            compact: true,
            style: FcmButtonStyle.steel,
            label: 'NO',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: FcmButton(
            compact: true,
            label: 'YES',
            onPressed: canAfford
                ? () => Navigator.of(dialogContext).pop(true)
                : null,
          ),
        ),
      ],
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
    ),
  );
}
