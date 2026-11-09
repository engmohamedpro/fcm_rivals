/// FCM Rivals — the sound design of the pack reveal.
///
/// Pure data: given a [RevealTimeline] this lists every sound cue and the
/// fraction of the timeline it fires at, so the audio is locked to the
/// same marks the haptics and visuals use and each of the three reveals
/// (ordinary, legendary, premium) gets its own escalating track:
///
///  - a charge riser timed to END exactly on the burst,
///  - thuds on the charge pulses (the legendary/premium heartbeat),
///  - the burst boom, bigger per tier,
///  - soft whooshes on the flag and position walkout and a full one on
///    the card flip,
///  - rising ticks under the stat count,
///  - the name sting when the identity lands,
///  - the fanfare finale (legendary once, premium twice — the second
///    pitched up).
library;

import '../../core/audio/fcm_sfx.dart';
import 'pack_reveal_timeline.dart';

enum PackSoundTier { normal, legendary, premium }

PackSoundTier packSoundTierFor(RevealTimeline tl) => tl.finale2 != null
    ? PackSoundTier.premium
    : tl.isLegend
    ? PackSoundTier.legendary
    : PackSoundTier.normal;

/// One sound at one point of the reveal timeline.
class SfxEvent {
  const SfxEvent(
    this.at,
    this.cue, {
    this.volume = 1.0,
    this.rate = 1.0,
    this.cutOnDispose = false,
  });

  /// Fraction (0..1) of the reveal timeline the cue fires at.
  final double at;
  final SfxCue cue;
  final double volume;
  final double rate;
  final bool cutOnDispose;
}

/// Marks closer than this (as timeline fractions) count as the same beat,
/// so a generic thud never doubles a specific cue.
const double _sameBeat = 0.004;

/// Every cue of [tl], sorted by time.
List<SfxEvent> packSoundtrackFor(RevealTimeline tl) {
  final tier = packSoundTierFor(tl);
  final seconds = tl.duration.inMilliseconds / 1000.0;
  final events = <SfxEvent>[];

  bool taken(double at) => events.any((e) => (e.at - at).abs() < _sameBeat);

  // The burst lands on the first heavy mark at or after the charge ends;
  // the riser is started early enough to finish exactly there.
  final burstAt = tl.heavy.firstWhere(
    (m) => m >= tl.chargeEnd - 0.01,
    orElse: () => tl.flashPeak,
  );
  final riser = switch (tier) {
    PackSoundTier.normal => SfxCue.packRiserNormal,
    PackSoundTier.legendary => SfxCue.packRiserLegend,
    PackSoundTier.premium => SfxCue.packRiserPremium,
  };
  final riserStart = (burstAt - riser.seconds / seconds).clamp(0.0001, 1.0);
  events.add(SfxEvent(riserStart, riser, cutOnDispose: true));

  events.add(
    SfxEvent(burstAt, switch (tier) {
      PackSoundTier.normal => SfxCue.packBurstNormal,
      PackSoundTier.legendary => SfxCue.packBurstLegend,
      PackSoundTier.premium => SfxCue.packBurstPremium,
    }),
  );

  // The name sting: the last thing the user learns is who the player is.
  events.add(
    SfxEvent(tl.nameIn.begin, switch (tier) {
      PackSoundTier.normal => SfxCue.packNameNormal,
      PackSoundTier.legendary => SfxCue.packNameLegend,
      PackSoundTier.premium => SfxCue.packNamePremium,
    }),
  );

  // Legendary and premium close on the fanfare; premium fires it twice,
  // the second wave higher and a touch louder.
  final finale = tl.finale;
  if (finale != null) {
    events.add(SfxEvent(finale.begin, SfxCue.packFinale));
  }
  final finale2 = tl.finale2;
  if (finale2 != null) {
    events.add(SfxEvent(finale2.begin, SfxCue.packFinale, rate: 1.12));
  }

  // The walkout and the flip.
  events.add(SfxEvent(tl.flagIn.begin, SfxCue.whoosh, volume: 0.5));
  events.add(SfxEvent(tl.posIn.begin, SfxCue.whoosh, volume: 0.5));
  events.add(SfxEvent(tl.flip.begin, SfxCue.whoosh));

  // The stat count: ticks climbing in pitch.
  for (var i = 0; i < tl.tick.length; i++) {
    events.add(SfxEvent(tl.tick[i], SfxCue.tick, rate: 1.0 + 0.1 * i));
  }

  // Every remaining heavy haptic mark gets a thud: the charge pulses
  // (louder as the pack nears bursting) and the beats in the reveal.
  final pulses = tl.heavy.where((m) => m < burstAt - 0.01).toList();
  for (final m in tl.heavy) {
    if (taken(m)) continue;
    final i = pulses.indexOf(m);
    final v = i >= 0 ? 0.55 + 0.35 * (i + 1) / pulses.length : 0.6;
    events.add(SfxEvent(m, SfxCue.thud, volume: v));
  }

  events.sort((a, b) => a.at.compareTo(b.at));
  return events;
}
