/// FCM Rivals — one tactic slider as a single row (GDD 10.2).
///
///     WIDTH   55  ───────●─────────────
///                       [ Standard ]      ← what 55 means, above the thumb
///
/// The axis name, its number (0–99) and the slider share one row; the
/// gold pill riding above the thumb describes what the current number
/// means ("Very narrow", "Standard", "Very wide"…), live while dragging.
/// The branded [FcmScaleSlider] does the sliding (RTL-aware); this row
/// adds the name, the readout and the wording of the axis.
///
/// One commit per gesture: [onCommit] fires when the finger lifts (or
/// on a tap) with the final value — persist there, not on every tick.
library;

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/ui/fcm_scale_slider.dart';
import 'tactic_axis_copy.dart';
import 'tactic_sliders.dart';

class TacticSliderRow extends StatefulWidget {
  const TacticSliderRow({
    super.key,
    required this.axis,
    required this.value,
    required this.onCommit,
  });

  final TacticAxisId axis;

  /// The committed position, 0–99.
  final int value;

  /// The gesture's final position.
  final ValueChanged<int> onCommit;

  @override
  State<TacticSliderRow> createState() => _TacticSliderRowState();
}

class _TacticSliderRowState extends State<TacticSliderRow> {
  /// The live position: the committed value at rest, the finger's
  /// position during a drag (the number and the pill follow it).
  late int _live = widget.value;

  @override
  void didUpdateWidget(TacticSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the owner's committed value unless it is just echoing our
    // own release back at us.
    if (widget.value != oldWidget.value && widget.value != _live) {
      _live = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final copy = kTacticAxisCopy[widget.axis]!;
    final name = copy.name(arabic: arabic);
    return Row(
      // The name and number sit level with the TRACK (the bottom band);
      // the pill floats above, in the slider's own top band.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 92,
          height: 24,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              name.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          height: 24,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '$_live',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        Expanded(
          child: FcmScaleSlider(
            value: _live,
            max: kScaleMax,
            valueLabel: (v) => copy.band(v, arabic: arabic),
            semanticsLabel: name,
            onChanged: (v) => setState(() => _live = v),
            onChangeEnd: (v) {
              setState(() => _live = v);
              widget.onCommit(v);
            },
          ),
        ),
      ],
    );
  }
}
