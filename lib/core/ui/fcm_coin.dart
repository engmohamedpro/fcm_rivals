/// FCM Rivals — shared premium UI kit: {title}.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'fcm_style.dart';
import 'fcm_motion.dart';

/// The app's currency glyph: the gold-gradient coin with the 'C' mark,
/// exactly as it appears in the top bar's balance chip. Reusable
/// wherever a coin amount is shown — e.g. the SELL price of a revealed
/// player. ONE currency icon for the whole game: nothing else (dollar
/// signs, money material icons) marks coin amounts.
class FcmCoinGlyph extends StatelessWidget {
  const FcmCoinGlyph({super.key, this.size = 16, this.color});

  /// The coin's diameter; the 'C' scales with it.
  final double size;

  /// Flat override for the coin's gold face (e.g. danger red when a
  /// price is unaffordable); null keeps the brand gold gradient.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: color == null ? FcmColors.goldGradient : null,
        color: color,
      ),
      child: Text(
        'C',
        style: TextStyle(
          color: FcmColors.ink,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.54,
        ),
      ),
    );
  }
}

/// Gold coin chip with a rolling balance, used in the top bar.
class FcmCoinChip extends StatelessWidget {
  const FcmCoinChip({super.key, required this.coins});

  final int coins;

  /// Locale-aware compact readout: the value keeps Western digits (game
  /// HUD convention) while the unit follows the active locale — 'M'/'K'
  /// in English, 'م'/'ألف' in Arabic. Callers without a context use the
  /// English form. Whole thousands (every store pack price, by
  /// construction) map 1:1 — 4,000 → '4K', 26,000 → '26K'; non-multiples
  /// keep their shortest faithful readout (27,500 → '27.5K').
  static String compact(int coins, {AppLocalizations? l10n}) {
    String m(String v) => l10n?.coinCompactMillions(v) ?? '${v}M';
    String k(String v) => l10n?.coinCompactThousands(v) ?? '${v}K';
    if (coins >= 1000000) {
      final v = coins / 1000000;
      return m(v >= 10 ? v.round().toString() : v.toStringAsFixed(1));
    }
    if (coins >= 1000) {
      final v = coins / 1000;
      return k(coins % 1000 == 0 ? '${coins ~/ 1000}' : v.toStringAsFixed(1));
    }
    return '$coins';
  }

  @override
  Widget build(BuildContext context) {
    // Naked HUD readout: the glowing coin and the count float free — no
    // pill, no border, nothing that reads as a tappable control. The
    // coin carries its own soft light; the digits sit in the bright
    // goldSoft metal with a faint bloom for legibility on any chrome.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: FcmColors.goldGradient,
            boxShadow: [
              BoxShadow(
                color: FcmColors.gold.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Text(
            'C',
            style: TextStyle(
              color: FcmColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FcmCountUp(
          value: coins,
          format: (v) => compact(v, l10n: AppLocalizations.of(context)),
          style: const TextStyle(
            color: FcmColors.goldSoft,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            shadows: [Shadow(color: Color(0x59D9B871), blurRadius: 12)],
          ),
        ),
      ],
    );
  }
}
