/// FCM Rivals — shared premium UI kit: {title}.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'package:flutter/material.dart';
import 'fcm_style.dart';
import 'fcm_motion.dart';

import 'fcm_widgets_helpers.dart';

/// Small coloured number pill (ratings, levels).
class FcmPill extends StatelessWidget {
  const FcmPill(
    this.text, {
    super.key,
    this.color = FcmColors.gold,
    this.filled = true,
  });

  final String text;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          color: filled ? FcmColors.ink : color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Selectable option chip used by the tactic selectors (playing style,
/// mentality, formation): gold when selected, steel otherwise. An optional
/// [subtitle] line renders under the label for effect summaries.
class FcmOptionChip extends StatelessWidget {
  const FcmOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final String? subtitle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    return FcmPressable(
      onTap: enabled ? onTap : null,
      scale: 0.95,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: subtitle != null ? 12 : 14,
          vertical: subtitle != null ? 8 : 9,
        ),
        decoration: BoxDecoration(
          gradient: active ? FcmColors.goldGradient : FcmColors.steelGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? FcmColors.goldSoft.withValues(alpha: 0.6)
                : FcmColors.bronze.withValues(alpha: enabled ? 0.45 : 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active
                    ? FcmColors.ink
                    : (enabled ? Colors.white : Colors.white38),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? FcmColors.ink.withValues(alpha: 0.85)
                      : FcmColors.textDim,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal attribute bar that fills on first build and when the value
/// changes. [bonus] shows the part gained from upgrades in gold.
class FcmStatBar extends StatelessWidget {
  const FcmStatBar({
    super.key,
    required this.label,
    required this.value,
    this.bonus = 0,
    this.compact = false,
  });

  final String label;
  final int value;
  final int bonus;

  /// Bar only: no label column, tighter padding — for inline rows such as
  /// the pre-match stamina list.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = ratingColor(value);
    if (compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
          height: 8,
          child: Stack(
            children: [
              Container(color: Colors.white.withValues(alpha: 0.08)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, f, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: f,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.65), color],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: FitText(
              label,
              style: const TextStyle(
                color: FcmColors.textDim,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.08)),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (value / 99).clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, f, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: f,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color.withValues(alpha: 0.65), color],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: FitText(
              bonus > 0 ? '$value  +$bonus' : '$value',
              align: Alignment.centerRight,
              style: TextStyle(
                color: bonus > 0 ? FcmColors.gold : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
