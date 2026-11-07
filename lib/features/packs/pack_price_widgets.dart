/// FCM Rivals — pack store price widgets.
///
/// [PricePlate] and [ViewPlayersButton], split verbatim out of
/// `packs_screen.dart` (T-0041).
library;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../l10n/app_localizations.dart';

/// The price plate under the pack: one premium silhouette shared by the
/// coin price and the FREE ×N claim. The coin price is the top bar's
/// balance chip in miniature — dark chip, gold rim, soft gold glow and
/// the same C coin — so the currency reads as one language everywhere;
/// red metal replaces the gold when the price is out of reach. Owned
/// stacks swap the gold for the success-green "costs nothing" metal of
/// the claim actions, keeping the identical plate shape.
class PricePlate extends StatelessWidget {
  const PricePlate({
  super.key,
    required this.isFree,
    required this.ownedCount,
    required this.price,
    required this.affordable,
  });

  final bool isFree;
  final int ownedCount;
  final int price;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    if (isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          gradient: FcmColors.successGradient,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: FcmColors.success.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: FcmColors.success.withValues(alpha: 0.25),
              blurRadius: 10,
            ),
          ],
        ),
        child: Text(
          'FREE ×$ownedCount',
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(
            color: FcmColors.ink,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      );
    }
    final metal = affordable ? FcmColors.gold : FcmColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: metal.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: metal.withValues(alpha: 0.16), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FcmCoinGlyph(size: 13, color: affordable ? null : metal),
          const SizedBox(width: 4),
          FitText(
            FcmCoinChip.compact(price, l10n: AppLocalizations.of(context)),
            style: TextStyle(
              color: metal,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact ghost pill that ends a scope section's title row: the one
/// entry into that scope's contents list. Icon-only — the tooltip
/// carries the label. Sized to sit inside the title row without
/// inflating it.
class ViewPlayersButton extends StatelessWidget {
  const ViewPlayersButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'View players',
      child: FcmPressable(
        onTap: onPressed,
        scale: 0.94,
        child: Container(
          height: 30,
          width: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
          ),
          child: const Icon(
            Icons.people_outline_rounded,
            size: 16,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
