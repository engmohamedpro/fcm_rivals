/// FCM Rivals — shared premium UI kit: {title}.
///
/// Split out of the original single-file kit so each widget
/// family evolves independently; `fcm_widgets.dart` re-exports
/// everything, so existing imports are untouched.
library;

import 'package:flutter/material.dart';
import 'fcm_style.dart';
import 'fcm_motion.dart';


/// Glass panel with a soft gradient, hairline border and optional glow.
class FcmPanel extends StatelessWidget {
  const FcmPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent,
    this.glow = false,
    this.radius = 20,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final bool glow;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = accent;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              FcmColors.surfaceHigh,
              a ?? FcmColors.surfaceHigh,
              a != null ? 0.18 : 0,
            )!,
            FcmColors.surface,
          ],
        ),
        border: Border.all(
          color: a != null
              ? a.withValues(alpha: 0.55)
              : FcmColors.bronze.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          if (glow && a != null)
            BoxShadow(color: a.withValues(alpha: 0.28), blurRadius: 26),
        ],
      ),
      child: child,
    );
    return onTap == null
        ? box
        : FcmPressable(onTap: onTap, scale: 0.98, child: box);
  }
}

/// Section heading: gold bar + spaced caps label + optional trailing widget.
class FcmSectionTitle extends StatelessWidget {
  const FcmSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: FcmColors.goldGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FitText(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Glowing circular icon badge.
class FcmIconBadge extends StatelessWidget {
  const FcmIconBadge({
    super.key,
    required this.icon,
    this.color = FcmColors.gold,
    this.size = 72,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.35),
            color.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// Friendly empty state with an icon, title, message and optional action.
class FcmEmptyState extends StatelessWidget {
  const FcmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: FcmEntrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FcmIconBadge(icon: icon),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: FcmColors.textDim),
              ),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}
