// Pitch layout solver: for EVERY formation, on phone and tablet sized
// pitches, with and without the stat row / stamina bar, the cards must
//  * never touch or overlap (names included — the footprint carries them),
//  * stay inside the pitch,
//  * sit where their role belongs (keeper lowest, attack highest, every
//    line in the formation's left-to-right order),
//  * be as big as the pitch allows (capped at the bench card size).
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/squad/formations.dart';
import 'package:fcm_rivals/features/squad/pitch_layout.dart';

/// Pitch sizes (width; height follows the pitch's 0.66 aspect): small
/// phone, common phone, large phone, tablet, big tablet.
const _widths = [332.0, 362.0, 402.0, 600.0, 900.0];

void main() {
  group('pitchRows', () {
    List<int> shape(String code) =>
        pitchRows(formationByCode(code)).map((r) => r.length).toList();

    test('groups the lines of each shape, keeper first', () {
      expect(shape('4-3-3'), [1, 4, 3, 3]);
      expect(shape('4-4-2'), [1, 4, 4, 2]);
      expect(shape('4-2-3-1'), [1, 4, 2, 3, 1]);
      expect(shape('4-1-4-1'), [1, 4, 1, 4, 1]);
      expect(shape('3-5-2'), [1, 3, 5, 2]);
      expect(shape('3-4-3'), [1, 3, 4, 3]);
      expect(shape('5-3-2'), [1, 5, 3, 2]);
      expect(shape('5-4-1'), [1, 5, 4, 1]);
      expect(shape('4-2-2-2'), [1, 4, 2, 2, 2]);
      expect(shape('4-3-2-1'), [1, 4, 3, 2, 1]);
    });

    test('every slot is in exactly one line and lines read left to right',
        () {
      for (final f in formations) {
        final rows = pitchRows(f);
        final all = [for (final r in rows) ...r]..sort();
        expect(all, List<int>.generate(11, (i) => i), reason: f.code);
        expect(rows.first, [0], reason: '${f.code}: the keeper stands alone');
        for (final row in rows) {
          for (var j = 1; j < row.length; j++) {
            expect(f.slots[row[j]].x, greaterThanOrEqualTo(f.slots[row[j - 1]].x),
                reason: '${f.code}: line ordered by x');
          }
        }
      }
    });
  });

  for (final f in formations) {
    for (final width in _widths) {
      for (final extras in [false, true]) {
        final label = '${f.code} on ${width.toInt()}px '
            '${extras ? '(stats + stamina)' : '(plain cards)'}';
        test('$label: no overlap, inside the pitch, roles in place', () {
          final height = width / 0.66;
          final layout = computePitchLayout(
            formation: f,
            width: width,
            height: height,
            showStats: extras,
            showStamina: extras,
          );
          final boxes = layout.boxes;
          expect(boxes.length, 11);

          // Inside the pitch.
          for (var i = 0; i < boxes.length; i++) {
            final b = boxes[i];
            expect(b.left, greaterThanOrEqualTo(0), reason: '$label slot $i');
            expect(b.top, greaterThanOrEqualTo(0), reason: '$label slot $i');
            expect(b.right, lessThanOrEqualTo(width + 0.01),
                reason: '$label slot $i');
            expect(b.bottom, lessThanOrEqualTo(height + 0.01),
                reason: '$label slot $i');
          }

          // No two footprints touch: separated by real air on one axis.
          for (var i = 0; i < boxes.length; i++) {
            for (var j = i + 1; j < boxes.length; j++) {
              final a = boxes[i], b = boxes[j];
              final gapX = a.left < b.left ? b.left - a.right : a.left - b.right;
              final gapY = a.top < b.top ? b.top - a.bottom : a.top - b.bottom;
              expect(gapX >= kPitchGapH - 0.01 || gapY >= kPitchGapV - 0.01,
                  isTrue,
                  reason: '$label: slots $i and $j collide '
                      '(gapX ${gapX.toStringAsFixed(1)}, '
                      'gapY ${gapY.toStringAsFixed(1)})');
            }
          }

          // Roles: the keeper is the lowest card, and lines climb the
          // pitch in the formation's order.
          final rows = layout.rows;
          double rowTop(List<int> r) =>
              r.map((i) => boxes[i].top).reduce((a, b) => a + b) / r.length;
          for (var k = 1; k < rows.length; k++) {
            expect(rowTop(rows[k]), lessThan(rowTop(rows[k - 1])),
                reason: '$label: line $k sits above line ${k - 1}');
          }
          // Inside a line: left-to-right as in the formation.
          for (final row in rows) {
            for (var j = 1; j < row.length; j++) {
              expect(boxes[row[j]].left, greaterThan(boxes[row[j - 1]].left),
                  reason: '$label: line keeps its left-to-right order');
            }
          }
          // Full-width roles: the left back is left of the right back,
          // the left winger left of the right winger, and so on.
          for (var i = 0; i < f.slots.length; i++) {
            for (var j = 0; j < f.slots.length; j++) {
              if (f.slots[i].x + 25 < f.slots[j].x &&
                  (f.slots[i].y - f.slots[j].y).abs() < 12) {
                expect(boxes[i].left, lessThan(boxes[j].left),
                    reason: '$label: slot $i is wider-left than slot $j');
              }
            }
          }
        });
      }
    }

    test('${f.code}: cards are big, never above the bench size', () {
      for (final width in _widths) {
        final plain = computePitchLayout(
            formation: f, width: width, height: width / 0.66);
        expect(plain.cardWidth, lessThanOrEqualTo(kPitchCardMaxWidth));
        expect(plain.cardWidth, greaterThanOrEqualTo(kPitchCardMinWidth));
        // The old layout topped out at 38–48px on a 362px pitch: the new
        // one is clearly bigger on every phone.
        if (width >= 362) {
          expect(plain.cardWidth, greaterThanOrEqualTo(50),
              reason: '${f.code} on $width');
        }
        // A big tablet pitch always gets the maximum card.
        if (width >= 600) {
          expect(plain.cardWidth, kPitchCardMaxWidth,
              reason: '${f.code} on $width');
        }
      }
    });
  }

  test('a wider pitch never makes the cards smaller', () {
    for (final f in formations) {
      var last = 0.0;
      for (final width in _widths) {
        final w = computePitchLayout(
                formation: f, width: width, height: width / 0.66)
            .cardWidth;
        expect(w, greaterThanOrEqualTo(last), reason: f.code);
        last = w;
      }
    }
  });

  test('cards carrying stats and stamina are never bigger than plain ones',
      () {
    for (final f in formations) {
      for (final width in _widths) {
        final h = width / 0.66;
        final plain =
            computePitchLayout(formation: f, width: width, height: h);
        final full = computePitchLayout(
            formation: f,
            width: width,
            height: h,
            showStats: true,
            showStamina: true);
        expect(full.cardWidth, lessThanOrEqualTo(plain.cardWidth),
            reason: '${f.code} on $width');
      }
    }
  });

  test('footprint height grows with the card and with the extra rows', () {
    expect(pitchFootprintHeight(60), greaterThan(pitchFootprintHeight(40)));
    expect(pitchFootprintHeight(50, showStats: true),
        greaterThan(pitchFootprintHeight(50)));
    expect(pitchFootprintHeight(50, showStats: true, showStamina: true),
        greaterThan(pitchFootprintHeight(50, showStats: true)));
  });

  test('the layout is deterministic', () {
    final a = computePitchLayout(
        formation: formationByCode('4-2-3-1'), width: 362, height: 548);
    final b = computePitchLayout(
        formation: formationByCode('4-2-3-1'), width: 362, height: 548);
    expect(a.cardWidth, b.cardWidth);
    for (var i = 0; i < 11; i++) {
      expect(a.boxes[i].left, b.boxes[i].left);
      expect(a.boxes[i].top, b.boxes[i].top);
    }
  });
}
