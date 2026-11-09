// Pack opening stagecraft: the charge-colour ladder and the extra layers
// (energy ring, ambient particles, red lightning) that give each rarity
// its own opening on top of the shared reveal timeline.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/features/packs/pack_stagecraft.dart';

void _paint(CustomPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), size);
  recorder.endRecording();
}

void main() {
  group('charge ladder', () {
    final ladder = chargeLadder();

    test('the ladder runs amethyst, sapphire, gold, crimson', () {
      expect(ladder.length, 4);
      expect(ladder[0], CardRarity.rare.accent);
      expect(ladder[1], CardRarity.epic.accent);
      expect(ladder[2], CardRarity.legendary.accent);
      expect(ladder[3], CardClass.premium.accent);
    });

    test('revealRank maps the rarity and the 90+ class', () {
      expect(revealRank(CardRarity.rare, CardClass.standard), 0);
      expect(revealRank(CardRarity.epic, CardClass.standard), 1);
      expect(revealRank(CardRarity.legendary, CardClass.standard), 2);
      expect(revealRank(CardRarity.legendary, CardClass.premium), 3);
    });

    test('every pull ends the charge exactly on its own rung', () {
      for (var rank = 0; rank < ladder.length; rank++) {
        expect(
          chargeGlowColor(charge: 1.0, rank: rank),
          ladder[rank],
          reason: 'rank $rank',
        );
      }
    });

    test('a legendary pull climbs through the lower rungs on the way', () {
      final early = chargeGlowColor(charge: 0.0, rank: 2);
      final mid = chargeGlowColor(charge: 0.25, rank: 2);
      expect(early, ladder[0]);
      expect(mid, isNot(ladder[0]));
      expect(mid, isNot(ladder[2]));
    });

    test('lower pulls flash the next rung mid-charge; a red pull never '
        'teases', () {
      final rare = chargeGlowColor(charge: 0.72, rank: 0);
      expect(rare, isNot(ladder[0]), reason: 'near-miss lean toward epic');
      final red = chargeGlowColor(charge: 0.72, rank: 3);
      expect(red, ladder[3]);
    });

    test('out-of-range inputs are clamped, never throw', () {
      expect(chargeGlowColor(charge: -1, rank: 0), ladder[0]);
      expect(chargeGlowColor(charge: 5, rank: 99), ladder[3]);
      expect(chargeGlowColor(charge: 0.5, rank: -4), isA<Color>());
    });
  });

  group('stagecraft painters', () {
    const size = Size(390, 844);

    test('ambient particles paint for every style and strength', () {
      for (final style in AmbientStyle.values) {
        for (final t in [0.0, 0.37, 1.0]) {
          _paint(
            AmbientPainter(
              time: t,
              style: style,
              color: Colors.amber,
              strength: 1,
              count: 46,
            ),
            size,
          );
        }
      }
      // Zero strength draws nothing and must not throw.
      _paint(
        AmbientPainter(
          time: 0.5,
          style: AmbientStyle.embers,
          color: Colors.red,
          strength: 0,
        ),
        size,
      );
    });

    test('charge ring and lightning paint across their full range', () {
      for (final c in [0.0, 0.3, 0.99, 1.0]) {
        _paint(
          ChargeRingPainter(
            charge: c,
            rotation: 0.42,
            color: Colors.blue,
            dots: 20,
            radius: 160,
          ),
          size,
        );
      }
      for (final t in [0.0, 0.2, 0.55, 0.99]) {
        _paint(
          LightningPainter(strength: 1, time: t, color: Colors.redAccent),
          size,
        );
      }
    });

    test('repaint rules follow the animated inputs', () {
      final a = AmbientPainter(
        time: 0.1,
        style: AmbientStyle.motes,
        color: Colors.white,
        strength: 1,
      );
      final b = AmbientPainter(
        time: 0.2,
        style: AmbientStyle.motes,
        color: Colors.white,
        strength: 1,
      );
      expect(a.shouldRepaint(b), isTrue);
      expect(a.shouldRepaint(a), isFalse);
    });
  });
}
