// Rarity-specific card artwork: every rarity (and the 90+ premium class)
// paints at the tiny pitch-shield size and the full reveal size, static
// and animated, and the frame details climb with the rarity.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_style.dart';
import 'package:fcm_rivals/core/ui/player_card.dart';

void main() {
  test('every rarity and the premium class paint static and animated at '
      'tiny and full size', () {
    for (final size in const [Size(56, 80), Size(320, 457)]) {
      for (final cardClass in CardClass.values) {
        for (final rarity in CardRarity.values) {
          if (cardClass == CardClass.premium &&
              rarity != CardRarity.legendary) {
            continue; // premium always rides on legendary
          }
          for (final phase in <double?>[null, 0.0, 0.37, 1.0]) {
            final recorder = ui.PictureRecorder();
            CardFacePainter(
              rarity: rarity,
              cardClass: cardClass,
              shine: 0.4,
              glow: 0.8,
              phase: phase,
            ).paint(ui.Canvas(recorder), size);
            recorder.endRecording();
          }
        }
      }
    }
  });

  test('the face repaints when the animation phase moves', () {
    final a = CardFacePainter(
      rarity: CardRarity.legendary,
      shine: null,
      phase: 0.1,
    );
    final b = CardFacePainter(
      rarity: CardRarity.legendary,
      shine: null,
      phase: 0.2,
    );
    expect(a.shouldRepaint(b), isTrue);
    expect(a.shouldRepaint(a), isFalse);
  });

}
