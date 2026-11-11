// Chemistry links: one line per chemistry point, joining the closest
// same-nationality players (minimum spanning tree per nationality).
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/chemistry.dart';
import 'package:fcm_rivals/features/match/chemistry_links.dart';

({double x, double y}) _p(double x, double y) => (x: x, y: y);

void main() {
  test('distinct nationalities produce no links', () {
    final links = chemistryLinks(
      nationalities: {0: 'Egypt', 1: 'Brazil', 2: 'Spain'},
      centres: {0: _p(0, 0), 1: _p(1, 0), 2: _p(2, 0)},
    );
    expect(links, isEmpty);
  });

  test('a pair is joined by one link', () {
    final links = chemistryLinks(
      nationalities: {0: 'Egypt', 1: 'Egypt', 2: 'Spain'},
      centres: {0: _p(0, 0), 1: _p(5, 0), 2: _p(9, 9)},
    );
    expect(links.length, 1);
    expect(links.single.a, 0);
    expect(links.single.b, 1);
    expect(links.single.nationality, 'Egypt');
  });

  test('a group of three links the two shortest hops', () {
    final links = chemistryLinks(
      nationalities: {0: 'Brazil', 1: 'Brazil', 2: 'Brazil'},
      centres: {0: _p(0, 0), 1: _p(1, 0), 2: _p(3, 0)},
    );
    final pairs = {for (final l in links) '${l.a}-${l.b}'};
    expect(pairs, {'0-1', '1-2'});
  });

  test('link count always equals the chemistry percentage', () {
    final nationalities = <int, String?>{
      0: 'Egypt',
      1: 'Egypt',
      2: 'Brazil',
      3: 'Brazil',
      4: 'Brazil',
      5: 'Brazil',
      6: 'France',
      7: 'Spain',
      8: 'Italy',
      9: 'Chile',
      10: 'Japan',
    };
    final centres = {
      for (var i = 0; i < 11; i++) i: _p(i * 10.0, (i % 3) * 7.0),
    };
    final links = chemistryLinks(
      nationalities: nationalities,
      centres: centres,
    );
    expect(links.length, chemistryPercentOf(nationalities.values));
    expect(links.length, 4);
  });

  test('null, empty and unplaced slots are ignored', () {
    final links = chemistryLinks(
      nationalities: {0: null, 1: '', 2: 'Egypt', 3: 'Egypt'},
      centres: {0: _p(0, 0), 1: _p(1, 0), 2: _p(2, 0)},
    );
    expect(links, isEmpty);
  });
}
