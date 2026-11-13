// The pack-reveal sound design: every one of the three timelines gets its
// own escalating track, locked to the marks the visuals and haptics use.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/audio/fcm_sfx.dart';
import 'package:fcm_rivals/features/packs/pack_reveal_timeline.dart';
import 'package:fcm_rivals/features/packs/pack_soundtrack.dart';

final _timelines = <String, RevealTimeline>{
  'normal': RevealTimeline.normalTimeline,
  'legendary': RevealTimeline.legendaryTimeline,
  'premium': RevealTimeline.premiumTimeline,
};

SfxEvent _one(List<SfxEvent> ev, bool Function(SfxCue) test) =>
    ev.singleWhere((e) => test(e.cue));

void main() {
  test('each timeline maps to its own tier', () {
    expect(
      packSoundTierFor(RevealTimeline.normalTimeline),
      PackSoundTier.normal,
    );
    expect(
      packSoundTierFor(RevealTimeline.legendaryTimeline),
      PackSoundTier.legendary,
    );
    expect(
      packSoundTierFor(RevealTimeline.premiumTimeline),
      PackSoundTier.premium,
    );
  });

  for (final entry in _timelines.entries) {
    group('${entry.key} soundtrack', () {
      final tl = entry.value;
      final ev = packSoundtrackFor(tl);

      test('is sorted and inside the timeline', () {
        for (var i = 0; i < ev.length; i++) {
          expect(ev[i].at, inInclusiveRange(0.0, 1.0));
          if (i > 0) expect(ev[i].at, greaterThanOrEqualTo(ev[i - 1].at));
        }
      });

      test('a thud never doubles another cue on the same beat', () {
        for (final t in ev.where((e) => e.cue == SfxCue.thud)) {
          for (final o in ev.where((e) => e != t)) {
            expect((o.at - t.at).abs(), greaterThanOrEqualTo(0.004));
          }
        }
      });

      test('the riser ends exactly on the burst', () {
        final riser = _one(
          ev,
          (c) => c.name.startsWith('packRiser'),
        );
        final burst = _one(ev, (c) => c.name.startsWith('packBurst'));
        final seconds = tl.duration.inMilliseconds / 1000;
        expect(riser.cutOnDispose, isTrue);
        expect(
          riser.at + riser.cue.seconds / seconds,
          closeTo(burst.at, 0.002),
        );
      });

      test('the name sting lands when the name appears', () {
        final name = _one(ev, (c) => c.name.startsWith('packName'));
        expect(name.at, tl.nameIn.begin);
      });

      test('the stat ticks climb in pitch', () {
        final ticks = ev.where((e) => e.cue == SfxCue.tick).toList();
        expect(ticks.length, tl.tick.length);
        for (var i = 1; i < ticks.length; i++) {
          expect(ticks[i].rate, greaterThan(ticks[i - 1].rate));
        }
      });

      test('the card flip has its whoosh', () {
        expect(
          ev.any((e) => e.cue == SfxCue.whoosh && e.at == tl.flip.begin),
          isTrue,
        );
      });
    });
  }

  test('finale fanfare: none ordinary, once legendary, twice premium', () {
    int finales(RevealTimeline t) =>
        packSoundtrackFor(t).where((e) => e.cue == SfxCue.packFinale).length;
    expect(finales(RevealTimeline.normalTimeline), 0);
    expect(finales(RevealTimeline.legendaryTimeline), 1);
    expect(finales(RevealTimeline.premiumTimeline), 2);
    final second = packSoundtrackFor(
      RevealTimeline.premiumTimeline,
    ).where((e) => e.cue == SfxCue.packFinale).last;
    expect(second.rate, lessThan(1.0), reason: 'heavier, not brighter');
  });

  test('the burst and name sting escalate with the tier', () {
    SfxCue burst(RevealTimeline t) => _one(
      packSoundtrackFor(t),
      (c) => c.name.startsWith('packBurst'),
    ).cue;
    expect(burst(RevealTimeline.normalTimeline), SfxCue.packBurstNormal);
    expect(burst(RevealTimeline.legendaryTimeline), SfxCue.packBurstLegend);
    expect(burst(RevealTimeline.premiumTimeline), SfxCue.packBurstPremium);
  });

  test('every sound cue has its asset file on disk', () {
    for (final cue in SfxCue.values) {
      expect(
        File('assets/${cue.asset}').existsSync(),
        isTrue,
        reason: '${cue.name} -> assets/${cue.asset}',
      );
    }
  });

  test('the premium charge pulses build in volume', () {
    final thuds = packSoundtrackFor(RevealTimeline.premiumTimeline)
        .where((e) => e.cue == SfxCue.thud && e.at < 0.16)
        .toList();
    expect(thuds.length, greaterThanOrEqualTo(3));
    for (var i = 1; i < thuds.length; i++) {
      expect(thuds[i].volume, greaterThan(thuds[i - 1].volume));
    }
  });
}
