// Chemistry links: one line per chemistry point per dimension, joining
// the closest same-key players (minimum spanning tree per group), with
// the pair's shared-kind set driving the line colour (owner request
// 2026-11-11: one type → white, both types → golden).
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/chemistry.dart';
import 'package:fcm_rivals/features/match/chemistry_links.dart';

({double x, double y}) _p(double x, double y) => (x: x, y: y);

void main() {
  test('distinct keys in both dimensions produce no links', () {
    final links = chemistryLinks(
      nationalities: {0: 'Egypt', 1: 'Brazil', 2: 'Spain'},
      clubs: const {0: 'club:1', 1: 'club:2', 2: 'club:3'},
      centres: {0: _p(0, 0), 1: _p(1, 0), 2: _p(2, 0)},
    );
    expect(links, isEmpty);
  });

  test('a nationality pair is joined by one single-type link', () {
    final links = chemistryLinks(
      nationalities: {0: 'Egypt', 1: 'Egypt', 2: 'Spain'},
      clubs: const {0: 'club:1', 1: 'club:2', 2: 'club:3'},
      centres: {0: _p(0, 0), 1: _p(5, 0), 2: _p(9, 9)},
    );
    expect(links.length, 1);
    expect(links.single.a, 0);
    expect(links.single.b, 1);
    expect(links.single.kinds, {ChemistryLinkKind.nationality});
  });

  test('a club pair is joined by one single-type link', () {
    final links = chemistryLinks(
      nationalities: {0: 'Egypt', 1: 'Brazil', 2: 'Spain'},
      clubs: const {0: 'club:7', 1: 'club:7', 2: 'club:9'},
      centres: {0: _p(0, 0), 1: _p(5, 0), 2: _p(9, 9)},
    );
    expect(links.single.kinds, {ChemistryLinkKind.club});
  });

  test('a pair sharing nationality AND club is one golden (double) link', () {
    // Both dimensions link 0-1; the pair is drawn once, not twice.
    final links = chemistryLinks(
      nationalities: {0: 'Egypt', 1: 'Egypt', 2: 'Spain'},
      clubs: const {0: 'club:7', 1: 'club:7', 2: 'club:9'},
      centres: {0: _p(0, 0), 1: _p(5, 0), 2: _p(9, 9)},
    );
    expect(links.length, 1);
    expect(links.single.kinds, {
      ChemistryLinkKind.nationality,
      ChemistryLinkKind.club,
    });
  });

  test('a double-type pair is golden even when one tree skipped its edge', () {
    // All three share the nationality; only 0 and 1 share the club.
    // The nationality tree picks 0-1 and 1-2 (shortest hops), the club
    // tree picks 0-1 only — yet 0-1 must read as BOTH kinds because the
    // pair shares both attributes, and 1-2 stays nationality-only.
    final links = chemistryLinks(
      nationalities: {0: 'Egypt', 1: 'Egypt', 2: 'Egypt'},
      clubs: const {0: 'club:7', 1: 'club:7', 2: 'club:9'},
      centres: {0: _p(0, 0), 1: _p(1, 0), 2: _p(3, 0)},
    );
    final byPair = {for (final l in links) '${l.a}-${l.b}': l.kinds};
    expect(byPair.keys, {'0-1', '1-2'});
    expect(byPair['0-1'], {
      ChemistryLinkKind.nationality,
      ChemistryLinkKind.club,
    });
    expect(byPair['1-2'], {ChemistryLinkKind.nationality});
  });

  test('a group of three links the two shortest hops', () {
    final links = chemistryLinks(
      nationalities: {0: 'Brazil', 1: 'Brazil', 2: 'Brazil'},
      clubs: const {0: 'club:1', 1: 'club:2', 2: 'club:3'},
      centres: {0: _p(0, 0), 1: _p(1, 0), 2: _p(3, 0)},
    );
    final pairs = {for (final l in links) '${l.a}-${l.b}'};
    expect(pairs, {'0-1', '1-2'});
  });

  test('nationality links alone always match the nationality percentage', () {
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
      clubs: const {},
      centres: centres,
    );
    expect(links.length, chemistryPercentOf(nationalities.values));
    expect(links.length, 4);
    expect(
      links.every((l) => l.kinds.single == ChemistryLinkKind.nationality),
      isTrue,
    );
  });

  test('link count never exceeds the raw dimension points', () {
    // 4 Egypt + 4 France (6 nationality points) + club:1 ×6 and two
    // singles (5 club points): the union of the two dimensions' trees
    // can only shrink through dedup, never grow past the raw sum. (The
    // DISPLAYED chemistry caps that sum at 10 — see chemistry.dart —
    // while the lines still show every tree edge.)
    final nationalities = <int, String?>{
      0: 'Egypt',
      1: 'Egypt',
      2: 'Egypt',
      3: 'Egypt',
      4: 'France',
      5: 'France',
      6: 'France',
      7: 'France',
    };
    final clubs = <int, String?>{
      0: 'club:1',
      1: 'club:1',
      2: 'club:1',
      3: 'club:1',
      4: 'club:1',
      5: 'club:1',
      6: 'club:2',
      7: 'club:3',
    };
    final centres = {
      for (var i = 0; i < 8; i++) i: _p(i * 10.0, (i % 3) * 7.0),
    };
    final links = chemistryLinks(
      nationalities: nationalities,
      clubs: clubs,
      centres: centres,
    );
    final rawPoints =
        chemistryPercentOf(nationalities.values) +
        chemistryPercentOf(clubs.values);
    expect(rawPoints, 11);
    expect(links.length, lessThanOrEqualTo(rawPoints));
  });

  test('both-dimension overlap dedups pairs, every overlapped link is golden', () {
    // Four players share the nationality AND the club: both trees pick
    // the same three shortest hops, so three golden lines are drawn,
    // not six stacked ones.
    final same = {for (var i = 0; i < 4; i++) i: 'Same'};
    final links = chemistryLinks(
      nationalities: same,
      clubs: same,
      centres: {for (var i = 0; i < 4; i++) i: _p(i * 10.0, 0)},
    );
    expect(links.length, 3);
    expect(links.every((l) => l.kinds.length == 2), isTrue);
  });

  test('null, empty and unplaced slots are ignored', () {
    final links = chemistryLinks(
      nationalities: {0: null, 1: '', 2: 'Egypt', 3: 'Egypt'},
      clubs: const {0: null, 1: '', 2: 'club:1', 3: 'club:1'},
      centres: {0: _p(0, 0), 1: _p(1, 0), 2: _p(2, 0)},
    );
    expect(links, isEmpty);
  });
}
