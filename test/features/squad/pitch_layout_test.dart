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
      expect(shape('4-4-2'), [1, 4, 4, 2]);
      expect(shape('4-3-3'), [1, 4, 3, 3]);
      expect(shape('4-2-3-1'), [1, 4, 2, 3, 1]);
      expect(shape('4-1-4-1'), [1, 4, 5, 1]);
      expect(shape('4-5-1'), [1, 4, 5, 1]);
      expect(shape('4-4-1-1'), [1, 4, 4, 1, 1]);
      expect(shape('4-2-2-2'), [1, 4, 2, 2, 2]);
      expect(shape('4-1-2-1-2'), [1, 4, 3, 1, 2]);
      expect(shape('4-3-2-1'), [1, 4, 3, 2, 1]);
      expect(shape('3-5-2'), [1, 3, 5, 2]);
      expect(shape('3-4-3'), [1, 3, 4, 3]);
      expect(shape('3-4-1-2'), [1, 3, 4, 1, 2]);
      expect(shape('5-3-2'), [1, 5, 3, 2]);
      expect(shape('5-4-1'), [1, 5, 4, 1]);
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

  group('horizontal centring', () {
    // The formation data is symmetric about x=50; the rendered line must
    // sit centred on the pitch whatever the card size and however much
    // the spacing pass had to move the cards.
    test('every symmetric formation renders centred', () {
      for (final f in formations) {
        for (final width in _widths) {
          for (final extras in [false, true]) {
            final layout = computePitchLayout(
              formation: f,
              width: width,
              height: width / 0.66,
              showStats: extras,
              showStamina: extras,
            );
            for (final row in layout.rows) {
              if (row.length < 2) continue;
              final first = layout.boxes[row.first];
              final last = layout.boxes[row.last];
              final edgeLeft = first.left;
              final edgeRight = width - last.right;
              expect(
                (edgeLeft - edgeRight).abs(),
                lessThan(1.0),
                reason: '${f.code} on ${width}px: the line from '
                    '${first.left.toStringAsFixed(1)} to '
                    '${last.right.toStringAsFixed(1)} is off-centre by '
                    '${(edgeLeft - edgeRight).abs().toStringAsFixed(1)}px',
              );
            }
          }
        }
      }
    });
  });

  group('role depth on the pitch', () {
    // Card-centre height: the middle of the rendered card (top + half
    // the footprint), the fairest read of "who stands where".
    double cardMidY(PitchLayout layout, int i) =>
        layout.boxes[i].top + layout.boxes[i].height / 2;

    test('a CDM stands clearly deeper than a CM, in every shape', () {
      for (final f in formations) {
        final cdm = f.slots
            .indexWhere((s) => s.position.code == 'CDM');
        if (cdm < 0) continue;
        for (final width in [362.0, 900.0]) {
          final layout = computePitchLayout(
              formation: f, width: width, height: width / 0.66);
          for (var i = 0; i < f.slots.length; i++) {
            if (f.slots[i].position.code != 'CM') continue;
            expect(cardMidY(layout, cdm),
                greaterThan(cardMidY(layout, i) + 4),
                reason: '${f.code} on ${width}px: the CDM must read '
                    'deeper than the CM beside him');
          }
        }
      }
    });

    test('a CAM stands clearly higher than a CM, in every shape', () {
      for (final f in formations) {
        final cam = f.slots.indexWhere((s) => s.position.code == 'CAM');
        if (cam < 0) continue;
        for (final width in [362.0, 900.0]) {
          final layout = computePitchLayout(
              formation: f, width: width, height: width / 0.66);
          for (var i = 0; i < f.slots.length; i++) {
            if (f.slots[i].position.code != 'CM') continue;
            expect(cardMidY(layout, cam), lessThan(cardMidY(layout, i) - 4),
                reason: '${f.code} on ${width}px: the CAM must read '
                    'higher than the CM behind him');
          }
        }
      }
    });

    test('full backs stand clearly ahead of the centre backs', () {
      // A back four's LB/RB (and a back five's WBs) must read AHEAD of
      // the CB line — "a bit forward", never in line with it.
      for (final f in formations) {
        final fbCodes = ['4-4-2', '4-3-3', '4-2-3-1', '4-1-4-1', '4-5-1',
            '4-4-1-1', '4-2-2-2', '4-1-2-1-2', '4-3-2-1'];
        if (!fbCodes.contains(f.code)) continue;
        for (final width in [362.0, 900.0]) {
          final layout = computePitchLayout(
              formation: f, width: width, height: width / 0.66);
          double top(int i) => layout.boxes[i].top;
          for (var i = 0; i < f.slots.length; i++) {
            final code = f.slots[i].position.code;
            if (code != 'LB' && code != 'RB') continue;
            for (var j = 0; j < f.slots.length; j++) {
              if (f.slots[j].position.code != 'CB') continue;
              expect(top(i) + 6, lessThan(top(j)),
                  reason: '${f.code} on ${width}px: the $code must read '
                      'ahead of the CB line');
            }
          }
        }
      }
    });

    test('wing backs of a back five read ahead of the CBs', () {
      for (final code in ['5-3-2', '5-4-1']) {
        final f = formationByCode(code);
        for (final width in [362.0, 900.0]) {
          final layout = computePitchLayout(
              formation: f, width: width, height: width / 0.66);
          double top(int i) => layout.boxes[i].top;
          for (var i = 0; i < f.slots.length; i++) {
            final p = f.slots[i].position.code;
            if (p != 'LB' && p != 'RB') continue;
            for (var j = 0; j < f.slots.length; j++) {
              if (f.slots[j].position.code != 'CB') continue;
              expect(top(i) + 6, lessThan(top(j)),
                  reason: '$code on ${width}px: the $p must read ahead '
                      'of the CB line');
            }
          }
        }
      }
    });
  });

  group('the catalogue', () {
    test('has the classic set', () {
      const expected = [
        '4-3-3', '4-4-2', '4-2-3-1', '4-1-4-1', '4-5-1', '4-4-1-1',
        '4-2-2-2', '4-1-2-1-2', '4-3-2-1', '3-5-2', '3-4-3', '3-4-1-2',
        '5-3-2', '5-4-1',
      ];
      expect(formations.map((f) => f.code), expected);
    });

    test('every formation is valid and x-symmetric about 50', () {
      for (final f in formations) {
        expect(f.isValid, isTrue, reason: '${f.code}: 11 slots, GK first');
        // Symmetric shapes: for every slot at x there is one at 100-x
        // (allowing the same slot when x == 50).
        final xs = [for (final s in f.slots) s.x]..sort();
        for (final x in xs) {
          expect(xs.contains(100 - x), isTrue,
              reason: '${f.code}: x $x has no mirror at ${100 - x}');
        }
      }
    });
  });
}
