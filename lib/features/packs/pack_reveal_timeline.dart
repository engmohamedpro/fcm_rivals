/// FCM Rivals — pack reveal timeline spec (extracted from
/// `pack_opening_screen.dart`, app-structure review task
/// `2026-11-05_app-structure_split-pack-reveal-widgets`): the
/// keyframe timeline that drives the standard and legendary reveal
/// animations. Pure relocation — values unchanged.
library;

import 'package:flutter/animation.dart';

const Duration kStandardRevealDuration = Duration(milliseconds: 8000);

/// Length of the legendary reveal timeline — more than twice the
/// standard one.
const Duration kLegendaryRevealDuration = Duration(milliseconds: 17000);

/// Legendary timeline: the name starts typing in at this fraction…
const double kLegendaryNameStart = 0.89;

/// …and the buttons are offered at this fraction.
const double kLegendaryDone = 0.975;

/// One reveal timeline: every mark as a fraction of its master
/// controller, plus the controller's length. Rare and epic pulls share
/// [normal]; legendary pulls run [legendary].
class RevealTimeline {
  const RevealTimeline({
    required this.duration,
    required this.chargeEnd,
    required this.flashStart,
    required this.flashPeak,
    required this.flashFade,
    required this.burstStart,
    required this.burstEnd,
    required this.packBurst,
    required this.packFade,
    required this.packGone,
    required this.raysIn,
    required this.walkoutStart,
    required this.flagIn,
    required this.posIn,
    required this.infoOut,
    required this.flip,
    required this.shine,
    required this.stats,
    required this.done,
    required this.nameIn,
    required this.heavy,
    required this.medium,
    required this.tick,
    this.mysteryIn,
    this.finale,
    this.bannerIn,
  });

  final Duration duration;
  final double chargeEnd;
  final double flashStart;
  final double flashPeak;

  /// Fraction of the timeline the flash takes to fade after its peak.
  final double flashFade;
  final double burstStart;
  final double burstEnd;

  /// The sealed pack swelling as it bursts, then fading out.
  final Interval packBurst;
  final Interval packFade;

  /// The pack scene ends here.
  final double packGone;
  final Interval raysIn;

  /// Where the sequence restarts for the 2nd+ player (no pack scene).
  final double walkoutStart;
  final Interval flagIn;
  final Interval posIn;
  final Interval infoOut;
  final Interval flip;
  final Interval shine;
  final Interval stats;

  /// Buttons are offered at this mark.
  final double done;

  /// Name reveal: starts exactly when the stats finish counting — the
  /// last thing the user learns is WHO the player is.
  final Interval nameIn;

  /// Haptic marks.
  final List<double> heavy;
  final List<double> medium;
  final List<double> tick;

  // Legendary-only phases (null on the standard timeline).
  final Interval? mysteryIn;
  final Interval? finale;
  final Interval? bannerIn;

  bool get isLegend => mysteryIn != null;

  static const normalTimeline = RevealTimeline(
    duration: kStandardRevealDuration,
    chargeEnd: 0.20,
    flashStart: 0.18,
    flashPeak: 0.22,
    flashFade: 0.08,
    burstStart: 0.21,
    burstEnd: 0.46,
    packBurst: Interval(0.19, 0.24),
    packFade: Interval(0.20, 0.24),
    packGone: 0.24,
    raysIn: Interval(0.22, 0.36),
    walkoutStart: 0.25,
    flagIn: Interval(0.25, 0.33, curve: Curves.easeOutBack),
    posIn: Interval(0.32, 0.40, curve: Curves.easeOutBack),
    infoOut: Interval(0.50, 0.55, curve: Curves.easeIn),
    flip: Interval(0.50, 0.64, curve: Curves.easeOutCubic),
    shine: Interval(0.60, 0.80, curve: Curves.easeInOut),
    stats: Interval(0.64, 0.88, curve: Curves.easeOut),
    done: 0.88,
    nameIn: Interval(0.88, 0.97, curve: Curves.easeOutBack),
    heavy: [0.20, 0.88],
    medium: [0.50],
    tick: [0.70, 0.78, 0.86],
  );

  static const legendaryTimeline = RevealTimeline(
    duration: kLegendaryRevealDuration,
    chargeEnd: 0.17,
    flashStart: 0.145,
    flashPeak: 0.175,
    flashFade: 0.07,
    burstStart: 0.175,
    burstEnd: 0.42,
    packBurst: Interval(0.15, 0.19),
    packFade: Interval(0.16, 0.19),
    packGone: 0.19,
    raysIn: Interval(0.18, 0.34),
    walkoutStart: 0.19,
    flagIn: Interval(0.30, 0.37, curve: Curves.easeOutBack),
    posIn: Interval(0.385, 0.455, curve: Curves.easeOutBack),
    infoOut: Interval(0.585, 0.63, curve: Curves.easeIn),
    flip: Interval(0.60, 0.72, curve: Curves.easeInOutCubic),
    shine: Interval(0.72, 0.90, curve: Curves.easeInOut),
    stats: Interval(0.73, 0.88, curve: Curves.easeOut),
    done: kLegendaryDone,
    nameIn: Interval(kLegendaryNameStart, 0.95),
    heavy: [0.03, 0.07, 0.11, 0.145, 0.175, 0.66, 0.89, 0.95],
    medium: [0.30, 0.385, 0.60],
    tick: [0.74, 0.77, 0.80, 0.83, 0.86],
    mysteryIn: Interval(0.20, 0.29, curve: Curves.easeOutBack),
    finale: Interval(0.95, 1.0),
    bannerIn: Interval(0.95, 0.985, curve: Curves.easeOutBack),
  );
}

/// Everything the reveal needs to offer OPEN ANOTHER straight from the
/// card: the same shelf slot's next price, the club's balance and how
/// many owned (free) packs of that slot remain. The caller computes it
/// before the push; the reveal only renders it and pops with `true`
/// when the player wants to chain. Null hides the action.
