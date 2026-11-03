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

/// Stamina percent → colour (GDD 11): fresh legs green, tiring gold, heavy
/// legs amber, exhausted red. Used by the stamina bars under player cards.
Color staminaColor(num v) {
  if (v >= 75) return FcmColors.success;
  if (v >= 50) return FcmColors.gold;
  if (v >= 30) return const Color(0xFFE08A2E);
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
    vsync: this,
    duration: const Duration(seconds: 26),
  );

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
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final w = size.width, h = size.height;
    final base = math.max(w, h);
    orb(
      Offset(w * (0.2 + 0.1 * math.sin(t)), h * (0.12 + 0.05 * math.cos(t))),
      base * 0.55,
      FcmColors.gold,
      0.11,
    );
    orb(
      Offset(
        w * (0.85 + 0.08 * math.cos(t * 2)),
        h * (0.35 + 0.06 * math.sin(t)),
      ),
      base * 0.42,
      tint,
      0.07,
    );
    orb(
      Offset(
        w * (0.5 + 0.12 * math.sin(t * 1.5)),
        h * (1.0 + 0.03 * math.cos(t)),
      ),
      base * 0.55,
      FcmColors.pitch,
      0.12,
    );

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
        return Text(
          format != null ? format!(n) : '$n',
          maxLines: 1,
          softWrap: false,
          style: style,
        );
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
          format: compact,
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

// -----------------------------------------------------------------------------
// Dropdown
// -----------------------------------------------------------------------------

/// One entry of an [FcmDropdown]: a value plus the label shown in the
/// closed field and the effect summary rendered under it in the sheet.
class FcmDropdownItem<T> {
  const FcmDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;

  /// Secondary line (effect summaries) shown in the picker sheet.
  final String? subtitle;
}

/// Brand-styled dropdown for tactic selectors (GDD 10). The closed field
/// looks like a steel [FcmButton]; tapping opens a bottom sheet listing
/// every option with its visible percentage effects, the selected one
/// highlighted in gold. [onChanged] is skipped when the picked value
/// equals the current one.
class FcmDropdown<T> extends StatelessWidget {
  const FcmDropdown({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.hint,
    this.icon,
  });

  final List<FcmDropdownItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Field label rendered inside the closed field when nothing matches.
  final String? hint;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final item = items.firstWhere(
      (i) => i.value == selected,
      orElse: () => FcmDropdownItem(value: selected, label: hint ?? '—'),
    );
    return FcmPressable(
      onTap: () => _openSheet(context),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: FcmColors.steelGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FcmColors.bronze.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: FcmColors.goldSoft, size: 18),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FitText(
                item.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: FcmColors.goldSoft,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    fcmTick();
    final picked = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: FcmColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(top: 8, bottom: 6),
                decoration: BoxDecoration(
                  color: FcmColors.bronze.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final i in items)
                      _SheetTile(
                        item: i,
                        selected: i.value == selected,
                        onTap: () => Navigator.pop(sheetContext, i.value),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == selected) return;
    fcmTick();
    onChanged(picked);
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FcmDropdownItem<dynamic> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FcmPressable(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: item.subtitle != null ? 11 : 13,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? FcmColors.goldGradient
                : FcmColors.steelGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? FcmColors.goldSoft.withValues(alpha: 0.6)
                  : FcmColors.bronze.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? FcmColors.ink : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? FcmColors.ink.withValues(alpha: 0.85)
                              : FcmColors.textDim,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_rounded, color: FcmColors.ink, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Navigation
// -----------------------------------------------------------------------------

/// The brand's light seam: a hairline of gradient gold with a soft bloom
/// falling to one side. The AppBar caps itself with the bloom rising
/// into the bar, the bottom nav mirrors it with the bloom falling into
/// the nav — the two chrome edges read as one lit system.
class FcmGoldSeam extends StatelessWidget {
  const FcmGoldSeam({
    super.key,
    this.bloomBelow = false,
    this.bloomHeight = 3.8,
  });

  /// When true the line sits on top and the bloom falls below it (bottom
  /// nav); otherwise the bloom rises above the line (AppBar bottom edge).
  final bool bloomBelow;

  final double bloomHeight;

  @override
  Widget build(BuildContext context) {
    final line = Container(
      height: 1.2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x3D6E5426),
            FcmColors.goldSoft,
            FcmColors.gold,
            Color(0x3D6E5426),
          ],
        ),
      ),
    );
    final bloom = Container(
      height: bloomHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bloomBelow
              ? [FcmColors.gold.withValues(alpha: 0.22), Colors.transparent]
              : [Colors.transparent, FcmColors.gold.withValues(alpha: 0.22)],
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: bloomBelow ? [line, bloom] : [bloom, line],
    );
  }
}

class FcmNavItem {
  const FcmNavItem(this.label, this.icon, {this.badge});

  final String label;
  final IconData icon;

  /// Optional notification badge (hidden when null or zero) — e.g. the
  /// number of unopened packs waiting on the Store tab.
  final int? badge;
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
      // Same chrome language as the AppBar: a deep vertical gradient
      // capped by the gold light seam — line on the top edge, bloom
      // falling into the nav.
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0A0E), Color(0xFF141319)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FcmGoldSeam(bloomBelow: true),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Borderless: the selected tab is lit, not boxed — a soft gold
          // wash falling from above plus a glow under it, no stroke that
          // would read as a button outline.
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    FcmColors.gold.withValues(alpha: 0.16),
                    FcmColors.gold.withValues(alpha: 0.04),
                  ],
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: FcmColors.gold.withValues(alpha: 0.20),
                    blurRadius: 14,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: selected ? 1.18 : 1.0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: selected ? FcmColors.gold : Colors.white60,
                  ),
                ),
                if ((item.badge ?? 0) > 0)
                  Positioned(
                    top: -7,
                    right: -13,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: FcmColors.goldGradient,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: FcmColors.ink, width: 1.5),
                      ),
                      child: FitText(
                        (item.badge! > 99) ? '99+' : '${item.badge}',
                        align: Alignment.center,
                        style: const TextStyle(
                          color: FcmColors.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FitText(
                item.label,
                align: Alignment.center,
                style: TextStyle(
                  fontSize: 10,
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

/// A branded 0–100 tactic scale slider: a slim track with a centre tick
/// at the scale's default (50), a round gold marker that follows the
/// finger, and the position's MEANING floating in a gold pill above the
/// marker. The owner names positions through [valueLabel] — mentalities
/// today, any future tactic option (pressing intensity, line height…)
/// tomorrow — so every scale in the game reads and slides the same.
///
/// [onChanged] streams every intermediate position (the pill follows the
/// drag live), [onChangeEnd] commits the gesture's final value — persist
/// there, once per drag, not on every tick.
class FcmScaleSlider extends StatefulWidget {
  const FcmScaleSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.valueLabel,
    this.onChangeEnd,
    this.minLabel,
    this.maxLabel,
    this.semanticsLabel = 'Scale',
  });

  /// Current position, 0–100; the centre (50) is the default.
  final int value;

  /// Continuous updates while the marker slides (tap-to-set included).
  final ValueChanged<int> onChanged;

  /// The gesture's commit — fires once per drag/tap with the final
  /// position. The value to persist.
  final ValueChanged<int>? onChangeEnd;

  /// Names a position ('Balanced', 'Very Attacking'…): the text of the
  /// pill above the marker.
  final String Function(int value) valueLabel;

  /// Caption under the track's left end — the scale's minimum meaning.
  final String? minLabel;

  /// Caption under the track's right end — the maximum meaning.
  final String? maxLabel;

  /// Screen-reader name of the whole control.
  final String semanticsLabel;

  @override
  State<FcmScaleSlider> createState() => _FcmScaleSliderState();
}

class _FcmScaleSliderState extends State<FcmScaleSlider> {
  static const double _thumbRadius = 10;
  static const double _trackHeight = 8;
  static const double _pillBandHeight = 22;
  static const double _bandHeight = 24;

  static const TextStyle _pillTextStyle = TextStyle(
    color: FcmColors.ink,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
    height: 1.1,
  );

  late int _value = widget.value;

  @override
  void didUpdateWidget(FcmScaleSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the owner's position unless it is just echoing our own
    // drag back at us.
    if (widget.value != oldWidget.value && widget.value != _value) {
      _value = widget.value;
    }
  }

  /// Maps a touch x to the 0–100 position and reports it. [commit] marks
  /// the gesture's end (tap release) — a drag commits via its own end
  /// callback with [_value].
  void _updateFromDx(double dx, double width, {required bool commit}) {
    final span = width - _thumbRadius * 2;
    final v = (((dx - _thumbRadius) / span) * 100).round().clamp(0, 100);
    if (v == _value) {
      if (commit) widget.onChangeEnd?.call(v);
      return;
    }
    setState(() => _value = v);
    widget.onChanged(v);
    if (commit) widget.onChangeEnd?.call(v);
  }

  /// Width of the label pill (text + padding), for clamping it inside
  /// the slider's bounds.
  double _pillWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _pillTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = painter.size.width + 16;
    painter.dispose();
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.valueLabel(_value);
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      value: '$_value of 100',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final f = _value / 100;
          final thumbX = _thumbRadius + f * (w - _thumbRadius * 2);

          // The pill rides above the marker, clamped inside the track so
          // long names never spill off the slider's ends.
          final pillW = _pillWidth(label);
          final pillCenter = thumbX.clamp(pillW / 2, w - pillW / 2).toDouble();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The floating label above the marker.
              SizedBox(
                height: _pillBandHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: pillCenter,
                      top: 0,
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: FcmColors.goldGradient,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: FcmColors.night,
                              width: 1.5,
                            ),
                          ),
                          child: Text(label, style: _pillTextStyle),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // The track band: gesture surface, track, centre tick, thumb.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) =>
                    _updateFromDx(d.localPosition.dx, w, commit: true),
                onHorizontalDragStart: (d) =>
                    _updateFromDx(d.localPosition.dx, w, commit: false),
                onHorizontalDragUpdate: (d) =>
                    _updateFromDx(d.localPosition.dx, w, commit: false),
                onHorizontalDragEnd: (_) => widget.onChangeEnd?.call(_value),
                child: SizedBox(
                  height: _bandHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Base track.
                      Positioned(
                        left: 0,
                        right: 0,
                        top: (_bandHeight - _trackHeight) / 2,
                        height: _trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(
                              _trackHeight / 2,
                            ),
                          ),
                        ),
                      ),
                      // Filled track up to the marker.
                      Positioned(
                        left: 0,
                        width: thumbX,
                        top: (_bandHeight - _trackHeight) / 2,
                        height: _trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [FcmColors.goldSoft, FcmColors.gold],
                            ),
                            borderRadius: BorderRadius.circular(
                              _trackHeight / 2,
                            ),
                          ),
                        ),
                      ),
                      // Centre tick: the scale's default mark.
                      Positioned(
                        left: w / 2 - 1,
                        width: 2,
                        top: (_bandHeight - 12) / 2,
                        height: 12,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      // The marker.
                      Positioned(
                        left: thumbX - _thumbRadius,
                        top: (_bandHeight - _thumbRadius * 2) / 2,
                        width: _thumbRadius * 2,
                        height: _thumbRadius * 2,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: FcmColors.goldGradient,
                            border: Border.all(
                              color: FcmColors.night,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: FcmColors.gold.withValues(alpha: 0.35),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.minLabel != null || widget.maxLabel != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.minLabel != null)
                      Text(
                        widget.minLabel!,
                        style: const TextStyle(
                          color: FcmColors.textDim,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    if (widget.maxLabel != null)
                      Text(
                        widget.maxLabel!,
                        style: const TextStyle(
                          color: FcmColors.textDim,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
