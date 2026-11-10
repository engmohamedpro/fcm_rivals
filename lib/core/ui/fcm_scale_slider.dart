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
///
/// Stepped mode (T-0062, [steps]): for N named steps the marker follows
/// the finger while dragging but both callbacks only ever report snapped
/// step positions (`round(raw * (steps-1) / 100)` — the
/// `mentalityFromScale` math, half away from zero), and on release the
/// marker settles (~150 ms, interruptible by a new drag) onto the step.
/// `steps: null` keeps the free continuous mode byte-identical.
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
    this.steps,
    this.max = 100,
  }) : assert(steps == null || steps >= 2, 'a scale needs >= 2 steps'),
       assert(max >= 2, 'a scale needs a range'),
       assert(
         steps == null || max == 100,
         'stepped mode is defined on the 0–100 scale',
       );

  /// Current position, 0–[max]; 50 is the default (its tick is drawn
  /// there).
  final int value;

  /// The top of the free scale: 100 by default, 99 for the 0–99 tactic
  /// sliders. Stepped mode always runs on 0–100.
  final int max;

  /// Named-step count for stepped mode (3 → 0/50/100, 7 → the mentality
  /// positions); null keeps the free continuous mode.
  final int? steps;

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

class _FcmScaleSliderState extends State<FcmScaleSlider>
    with SingleTickerProviderStateMixin {
  static const double _thumbRadius = 10;
  static const double _trackHeight = 8;
  static const double _pillBandHeight = 22;
  static const double _bandHeight = 24;

  /// How long the marker takes to settle onto the snapped step after a
  /// release (T-0062) — short enough to feel crisp, long enough to read
  /// as a settle.
  static const Duration _settleDuration = Duration(milliseconds: 150);

  static const TextStyle _pillTextStyle = TextStyle(
    color: FcmColors.ink,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
    height: 1.1,
  );

  /// The last REPORTED position — snapped in stepped mode, raw in free
  /// mode. What [widget.onChanged]/[widget.onChangeEnd] speak.
  late int _value = widget.steps == null
      ? widget.value
      : _snapToStep(widget.value);

  /// The marker's geometric position (0–100, fractional): follows the
  /// finger while dragging, rides the settle animation on release, and
  /// rests on the (snapped) value otherwise.
  late double _display = _value.toDouble();

  /// Drives the post-release settle; a new drag stops it mid-flight
  /// (interruptible by design).
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: _settleDuration,
  );
  double _settleFrom = 0;
  double _settleTo = 0;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      final eased = Curves.easeOut.transform(_settle.value);
      setState(() {
        _display = _settleFrom + (_settleTo - _settleFrom) * eased;
      });
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  /// The ambient text direction, resolved once per dependency change —
  /// every horizontal position and the gesture mapping mirror in RTL
  /// (T-0061): the minimum end sits at the RIGHT, like Flutter's own
  /// `Slider`, so the Arabic mentality slider reads and slides the way
  /// the platform teaches.
  TextDirection _direction = TextDirection.ltr;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _direction = Directionality.of(context);
  }

  bool get _isRtl => _direction == TextDirection.rtl;

  @override
  void didUpdateWidget(FcmScaleSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the owner's position unless it is just echoing our own
    // drag back at us. Stepped mode snaps incoming values so an
    // off-step external value can never park the marker between steps.
    if (widget.value != oldWidget.value && widget.value != _value) {
      _value = widget.steps == null
          ? widget.value
          : _snapToStep(widget.value);
      _display = _value.toDouble();
    }
  }

  /// The snapped step position for a raw 0–100 position in stepped
  /// mode — the exact `mentalityFromScale` math (Dart `.round()`, half
  /// away from zero, never truncation): 3 steps → 0/50/100, 7 steps →
  /// 0/17/33/50/67/83/100.
  int _snapToStep(int raw) {
    final steps = widget.steps!;
    final index = (raw.clamp(0, 100) * (steps - 1) / 100).round();
    return (index * 100 / (steps - 1)).round();
  }

  /// Animates the marker onto [target] after a release; a new drag
  /// start stops the controller mid-flight and takes over [_display].
  void _settleOnto(double target) {
    if (widget.steps == null) return;
    _settleFrom = _display;
    _settleTo = target;
    if (_settleFrom == _settleTo) return;
    _settle.forward(from: 0);
  }

  /// Maps a touch x to the 0–100 position and reports it. [commit] marks
  /// the gesture's end (tap release) — a drag commits via its own end
  /// callback with [_value]. [jumpToRaw] lets taps settle from the
  /// marker's current spot instead of flashing at the raw tap position.
  void _updateFromDx(
    double dx,
    double width, {
    required bool commit,
    bool jumpToRaw = true,
  }) {
    final span = width - _thumbRadius * 2;
    // RTL mirrors the gesture axis: x measured from the RIGHT edge, so
    // dragging towards the left INCREASES the value.
    final effective = _isRtl ? width - dx : dx;
    final raw = (((effective - _thumbRadius) / span) * widget.max)
        .clamp(0.0, widget.max.toDouble());

    // Free continuous mode — today's behaviour, byte-identical.
    if (widget.steps == null) {
      final v = raw.round();
      if (v == _value) {
        if (commit) widget.onChangeEnd?.call(v);
        return;
      }
      setState(() {
        _value = v;
        _display = v.toDouble();
      });
      widget.onChanged(v);
      if (commit) widget.onChangeEnd?.call(v);
      return;
    }

    // Stepped mode: the marker follows the finger (raw) but the value
    // — and both callbacks — only ever land on step positions.
    final v = _snapToStep(raw.round());
    final valueChanged = v != _value;
    final displayChanged = jumpToRaw && _display != raw;
    if (valueChanged || displayChanged) {
      setState(() {
        if (valueChanged) _value = v;
        if (jumpToRaw) _display = raw;
      });
      if (valueChanged) widget.onChanged(v);
    }
    if (commit) {
      widget.onChangeEnd?.call(v);
      _settleOnto(v.toDouble());
    }
  }

  /// Width of the label pill (text + padding), for clamping it inside
  /// the slider's bounds.
  double _pillWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _pillTextStyle),
      // Measure with the ambient direction so Arabic pill text lays
      // out correctly (T-0061 requirement 3).
      textDirection: _direction,
    )..layout();
    final w = painter.size.width + 16;
    painter.dispose();
    return w;
  }

  /// The track x for a 0–1 fraction, mirroring in RTL (T-0061 seam):
  /// the fraction's LTR x, flipped around the centre when the ambient
  /// direction is RTL.
  double _xFor(double fraction, double width) {
    final ltr = _thumbRadius + fraction * (width - _thumbRadius * 2);
    return _isRtl ? width - ltr : ltr;
  }

  /// The snapped step positions of stepped mode, 0–100 — with 3 steps
  /// [0, 50, 100], with 7 the mentality positions [0, 17, 33, 50, 67,
  /// 83, 100] (`round(index * 100 / (steps-1))`).
  List<int> get _stepPositions => [
    for (var i = 0; i < widget.steps!; i++)
      (i * 100 / (widget.steps! - 1)).round(),
  ];

  @override
  Widget build(BuildContext context) {
    final label = widget.valueLabel(_value);
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      value: '$_value of ${widget.max}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          // The marker's live position — the finger's raw position while
          // dragging, the settle animation in flight, the snapped value
          // at rest (stepped mode); the raw value at rest (free mode).
          final f = _display / widget.max;
          // LTR geometry, computed once; the RTL positions below mirror
          // it around the track's centre (T-0061): min at the right,
          // fill growing right-to-left, pill clamped the same way.
          final thumbX = _thumbRadius + f * (w - _thumbRadius * 2);
          final rtlThumbX = w - thumbX;
          final markerLeft =
              (_isRtl ? rtlThumbX : thumbX) - _thumbRadius;
          final fillLeft = _isRtl ? rtlThumbX : 0.0;
          final fillWidth =
              _isRtl ? w - rtlThumbX : thumbX.toDouble();

          // The pill rides above the marker, clamped inside the track so
          // long names never spill off the slider's ends.
          final pillW = _pillWidth(label);
          final pillCenterAnchor = _isRtl ? rtlThumbX : thumbX;
          final pillCenter = pillCenterAnchor
              .clamp(pillW / 2, w - pillW / 2)
              .toDouble();

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
              // The track band: gesture surface, track, ticks, thumb.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) =>
                    _updateFromDx(d.localPosition.dx, w, commit: true),
                onHorizontalDragStart: (d) {
                  // A new drag interrupts any settle mid-flight — the
                  // finger takes the marker over from wherever it is.
                  _settle.stop();
                  _updateFromDx(
                    d.localPosition.dx,
                    w,
                    commit: false,
                    jumpToRaw: false,
                  );
                },
                onHorizontalDragUpdate: (d) =>
                    _updateFromDx(d.localPosition.dx, w, commit: false),
                onHorizontalDragEnd: (_) {
                  if (widget.steps == null) {
                    // Free mode: today's commit, no animation.
                    widget.onChangeEnd?.call(_value);
                    return;
                  }
                  // Stepped mode: commit the snapped step, then settle
                  // the marker onto it.
                  widget.onChangeEnd?.call(_value);
                  _settleOnto(_value.toDouble());
                },
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
                      // Filled track up to the marker — from the min
                      // end (left in LTR, RIGHT in RTL) to the marker.
                      Positioned(
                        left: fillLeft,
                        width: fillWidth,
                        top: (_bandHeight - _trackHeight) / 2,
                        height: _trackHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: _isRtl
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              end: _isRtl
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              colors: const [
                                FcmColors.goldSoft,
                                FcmColors.gold,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              _trackHeight / 2,
                            ),
                          ),
                        ),
                      ),
                      // Step ticks: one small mark at every named step
                      // position (stepped mode) — 3 steps → 0/50/100,
                      // 7 → the mentality positions. The centre (50) is
                      // always among them, replacing the free mode's
                      // lone centre tick.
                      if (widget.steps != null) ...[
                        for (final s in _stepPositions)
                          Positioned(
                            left: _xFor(s / 100, w) - 1,
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
                      ] else
                        // Default tick: the free scale's default mark,
                        // at 50 (dead centre on the 0–100 scale, a hair
                        // right of it on 0–99).
                        Positioned(
                          left: _xFor(50 / widget.max, w) - 1,
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
                        left: markerLeft,
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
