/// FCM Rivals — shared premium UI kit: the branded tactic scale
/// slider.
///
/// A 0–100 scale with a centre tick, a gold marker and the
/// position's meaning floating above it — every scale in the game
/// (mentalities today, pressing intensity or line height tomorrow)
/// reads and slides the same.
library;

import 'package:flutter/material.dart';

import 'fcm_style.dart';


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
