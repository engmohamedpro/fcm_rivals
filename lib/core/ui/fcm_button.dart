/// FCM Rivals — shared premium UI kit: {title}.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'package:flutter/material.dart';
import 'fcm_style.dart';
import 'fcm_motion.dart';
import 'fcm_coin.dart';


// -----------------------------------------------------------------------------
// Buttons & panels
// -----------------------------------------------------------------------------

enum FcmButtonStyle { gold, steel, ghost, success }

/// Premium gradient button. Labels shrink to fit; disabled when
/// [onPressed] is null or [loading].
class FcmButton extends StatelessWidget {
  const FcmButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.style = FcmButtonStyle.gold,
    this.compact = false,
    this.coinValue,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final FcmButtonStyle style;
  final bool compact;

  /// When set, renders the gold coin glyph followed by this amount
  /// (compact format) after the label — the same C coin as the top-bar
  /// balance, e.g. SELL with the player's sale price. Takes over from
  /// [icon], which stays null on coin buttons.
  final int? coinValue;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final Color fg;
    final Gradient? gradient;
    final Color? border;
    final Color glow;
    switch (style) {
      case FcmButtonStyle.gold:
        fg = FcmColors.ink;
        gradient = FcmColors.goldGradient;
        border = FcmColors.goldSoft.withValues(alpha: 0.5);
        glow = FcmColors.gold;
      case FcmButtonStyle.steel:
        fg = FcmColors.goldSoft;
        gradient = FcmColors.steelGradient;
        border = FcmColors.bronze.withValues(alpha: 0.55);
        glow = Colors.transparent;
      case FcmButtonStyle.ghost:
        fg = Colors.white;
        gradient = null;
        border = Colors.white.withValues(alpha: 0.30);
        glow = Colors.transparent;
      case FcmButtonStyle.success:
        fg = FcmColors.ink;
        gradient = FcmColors.successGradient;
        border = FcmColors.success.withValues(alpha: 0.5);
        glow = FcmColors.success;
    }
    final height = compact ? 44.0 : 54.0;
    final textStyle = TextStyle(
      color: fg,
      fontWeight: FontWeight.w900,
      fontSize: compact ? 14 : 16,
      letterSpacing: 0.8,
    );
    final content = loading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: compact ? 18 : 22),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: textStyle,
                  ),
                ),
              ),
              if (coinValue != null) ...[
                const SizedBox(width: 6),
                // The coin glyph + amount: the C coin exactly as the
                // top bar shows it, marking the number as currency.
                FcmCoinGlyph(size: compact ? 14 : 16),
                const SizedBox(width: 3),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      FcmCoinChip.compact(coinValue!),
                      maxLines: 1,
                      softWrap: false,
                      style: textStyle,
                    ),
                  ),
                ),
              ],
            ],
          );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.45,
        child: FcmPressable(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: enabled && gradient != null
                  ? [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.38),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

