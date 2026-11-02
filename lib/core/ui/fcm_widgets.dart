/// FCM Rivals — shared premium UI kit.
///
/// Small, composable building blocks used by every screen so the whole game
/// has one look and one motion language:
///
/// * [FcmBackdrop]   — animated stadium-night background (drifting light).
/// * [FcmEntrance]   — staggered fade + slide-in for list items.
/// * [FcmPressable]  — tactile press-scale with haptic tick.
/// * [FcmButton]     — gold / steel / ghost gradient buttons.
/// * [FcmPanel]      — glass card with accent border and glow.
/// * [FcmCountUp]    — numbers that roll to their new value.
/// * [FcmStatBar]    — animated attribute bar.
/// * [FitText]       — text that shrinks to fit instead of wrapping/clipping.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fcm_style.dart';

/// Rating → colour used by bars and pills (champagne elite → ember weak),
/// desaturated to sit inside the brand's gold-on-black palette.
Color ratingColor(num v) {
  if (v >= 80) return FcmColors.success;
  if (v >= 65) return FcmColors.gold;
  if (v >= 45) return const Color(0xFFC89A5B);
  return FcmColors.danger;
}

/// Light haptic that can never throw.
void fcmTick() {
  try {
    HapticFeedback.selectionClick().catchError((Object _) {});
  } catch (_) {}
}

// -----------------------------------------------------------------------------
// Backdrop
// -----------------------------------------------------------------------------

/// Animated stadium-night background. Honours the system "reduce motion"
/// setting by freezing the drift.
class FcmBackdrop extends StatefulWidget {
  const FcmBackdrop({super.key, this.child, this.tint});

  final Widget? child;

  /// Optional accent that colours one of the light orbs.
  final Color? tint;

  @override
  State<FcmBackdrop> createState() => _FcmBackdropState();
}

class _FcmBackdropState extends State<FcmBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 26));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _BackdropPainter(_c, widget.tint ?? FcmColors.gold),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.anim, this.tint) : super(repaint: anim);

  final Animation<double> anim;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final t = anim.value * 2 * math.pi;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF151318), FcmColors.night, Color(0xFF09080C)],
        ).createShader(rect),
    );

    void orb(Offset c, double r, Color color, double alpha) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final w = size.width, h = size.height;
    final base = math.max(w, h);
    orb(Offset(w * (0.2 + 0.1 * math.sin(t)), h * (0.12 + 0.05 * math.cos(t))),
        base * 0.55, FcmColors.gold, 0.11);
    orb(Offset(w * (0.85 + 0.08 * math.cos(t * 2)), h * (0.35 + 0.06 * math.sin(t))),
        base * 0.42, tint, 0.07);
    orb(Offset(w * (0.5 + 0.12 * math.sin(t * 1.5)), h * (1.0 + 0.03 * math.cos(t))),
        base * 0.55, FcmColors.pitch, 0.12);

    // Faint stadium-light diagonals.
    final line = Paint()
      ..color = FcmColors.goldSoft.withValues(alpha: 0.016)
      ..strokeWidth = 26;
    for (var i = -3; i < 8; i++) {
      final x = w * i / 5 + math.sin(t) * 14;
      canvas.drawLine(Offset(x, 0), Offset(x + h * 0.6, h), line);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.tint != tint;
}

// -----------------------------------------------------------------------------
// Motion helpers
// -----------------------------------------------------------------------------

/// Fade + slide-in with a stagger by [index]. Plays once when first built.
/// Uses a single controller with an [Interval] delay (no timers).
class FcmEntrance extends StatefulWidget {
  const FcmEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.dx = 0,
    this.dy = 22,
    this.duration = const Duration(milliseconds: 480),
    this.stagger = const Duration(milliseconds: 60),
    this.maxStaggered = 10,
  });

  final Widget child;
  final int index;
  final double dx;
  final double dy;
  final Duration duration;
  final Duration stagger;
  final int maxStaggered;

  @override
  State<FcmEntrance> createState() => _FcmEntranceState();
}

class _FcmEntranceState extends State<FcmEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.stagger * math.min(widget.index, widget.maxStaggered);
    final total = widget.duration + delay;
    _c = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _c,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1.0,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1 - v) * widget.dx, (1 - v) * widget.dy),
            child: child,
          ),
        );
      },
    );
  }
}

/// Press-scale feedback with a haptic tick. Pass `onTap: null` to disable.
class FcmPressable extends StatefulWidget {
  const FcmPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<FcmPressable> createState() => _FcmPressableState();
}

class _FcmPressableState extends State<FcmPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        if (widget.haptic) fcmTick();
        widget.onTap!();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Number that rolls to its new value whenever [value] changes.
class FcmCountUp extends StatelessWidget {
  const FcmCountUp({
    super.key,
    required this.value,
    this.style,
    this.format,
    this.duration = const Duration(milliseconds: 900),
  });

  final int value;
  final TextStyle? style;
  final String Function(int)? format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final n = v.round();
        return Text(format != null ? format!(n) : '$n',
            maxLines: 1, softWrap: false, style: style);
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Text
// -----------------------------------------------------------------------------

/// Single-line text that scales down to fit its box instead of wrapping,
/// clipping or overflowing — the default for numbers, labels and names.
class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    this.style,
    this.align = Alignment.centerLeft,
  });

  final String text;
  final TextStyle? style;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: align,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
  }
}

// -----------------------------------------------------------------------------
// Buttons & panels
// -----------------------------------------------------------------------------

enum FcmButtonStyle { gold, steel, ghost }

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
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final FcmButtonStyle style;
  final bool compact;

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
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
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
                  child: Text(label,
                      maxLines: 1, softWrap: false, style: textStyle),
                ),
              ),
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
            Color.lerp(FcmColors.surfaceHigh, a ?? FcmColors.surfaceHigh,
                a != null ? 0.18 : 0)!,
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
    return onTap == null ? box : FcmPressable(onTap: onTap, scale: 0.98, child: box);
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
          if (trailing != null) trailing!,
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
        gradient: RadialGradient(colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.08),
        ]),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: size * 0.4),
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
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: FcmColors.textDim)),
              if (action != null) ...[const SizedBox(height: 22), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small coloured number pill (ratings, levels).
class FcmPill extends StatelessWidget {
  const FcmPill(this.text, {super.key, this.color = FcmColors.gold, this.filled = true});

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

/// Horizontal attribute bar that fills on first build and when the value
/// changes. [bonus] shows the part gained from upgrades in gold.
class FcmStatBar extends StatelessWidget {
  const FcmStatBar({
    super.key,
    required this.label,
    required this.value,
    this.bonus = 0,
  });

  final String label;
  final int value;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    final color = ratingColor(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: FitText(label,
                style: const TextStyle(
                    color: FcmColors.textDim,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1)),
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
                            gradient: LinearGradient(colors: [
                              color.withValues(alpha: 0.65),
                              color,
                            ]),
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

/// Gold coin chip with a rolling balance, used in the top bar.
class FcmCoinChip extends StatelessWidget {
  const FcmCoinChip({super.key, required this.coins});

  final int coins;

  static String compact(int coins) {
    if (coins >= 1000000) {
      final v = coins / 1000000;
      return '${v >= 10 ? v.round() : v.toStringAsFixed(1)}M';
    }
    if (coins >= 10000) return '${(coins / 1000).round()}k';
    return '$coins';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: FcmColors.gold.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: FcmColors.gold.withValues(alpha: 0.18), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: FcmColors.goldGradient,
            ),
            child: const Text('C',
                style: TextStyle(
                    color: FcmColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
          const SizedBox(width: 8),
          FcmCountUp(
            value: coins,
            format: compact,
            style: const TextStyle(
              color: FcmColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Navigation
// -----------------------------------------------------------------------------

class FcmNavItem {
  const FcmNavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Bottom navigation: animated gold pill behind the selected item.
class FcmBottomNav extends StatelessWidget {
  const FcmBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<FcmNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE121014),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    selected: i == index,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FcmNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPressable(
      onTap: onTap,
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: selected
              ? FcmColors.gold.withValues(alpha: 0.14)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? FcmColors.gold.withValues(alpha: 0.45)
                : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Icon(
                item.icon,
                size: 24,
                color: selected ? FcmColors.gold : Colors.white60,
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FitText(
                item.label,
                align: Alignment.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: selected ? FcmColors.gold : Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
