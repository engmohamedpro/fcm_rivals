import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/formations.dart';

/// A fixed-attribute XI (no generator noise): every outfielder reads the
/// same 80s, so any totals movement is the ROW term and nothing else.
List<MatchPlayer> flatTeam(int base) {
  const positions = [
    Position.gk,
    Position.lb,
    Position.cb,
    Position.cb,
    Position.rb,
    Position.cm,
    Position.cm,
    Position.cm,
    Position.lw,
    Position.st,
    Position.rw,
  ];
  return [
    for (var i = 0; i < positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: 'P $i',
        position: positions[i],
        attack: 80,
        support: 80,
        defence: 80,
        goalkeeping: positions[i] == Position.gk ? 80 : 40,
      ),
  ];
}

/// Eleven natural cells: a 4-3-3 shape, everyone on his natural row —
/// GK 0, the back four row 1, the midfield trio row 3, wings row 4,
/// striker row 5.
const List<GridCell> natural = <GridCell>[
  GridCell(kGridKeeperCol, 0),
  GridCell(0, 1),
  GridCell(1, 1),
  GridCell(3, 1),
  GridCell(4, 1),
  GridCell(1, 3),
  GridCell(2, 3),
  GridCell(3, 3),
  GridCell(0, 4),
  GridCell(2, 5),
  GridCell(4, 4),
];

/// The same eleven men, same slot positions, standing on [cells] — a
/// grid formation code carries the rows, so the engine sees only the
/// row difference between two of these.
MatchEngine gridEngine(int seed, List<GridCell> cells) {
  final formation = customGridFormation(
    [
      Position.gk,
      Position.lb,
      Position.cb,
      Position.cb,
      Position.rb,
      Position.cm,
      Position.cm,
      Position.cm,
      Position.lw,
      Position.st,
      Position.rw,
    ],
    cells,
  )!;
  return MatchEngine(
    seed: seed,
    home: MatchTeamInput(
      teamId: 1,
      teamName: 'Row FC',
      formationCode: formation.code,
      tactics: const TeamTactics(),
      mentality: Mentality.balanced,
      starters: flatTeam(100),
      bench: const [],
    ),
    away: MatchTeamInput(
      teamId: 2,
      teamName: 'Foe FC',
      formationCode: '4-3-3',
      tactics: const TeamTactics(),
      mentality: Mentality.balanced,
      starters: flatTeam(300),
      bench: const [],
      aiControlled: true,
    ),
  );
}

void main() {
  group('gridRowBonus (ADR-014 curve)', () {
    test('row 3 is the neutral anchor', () {
      final (att, def) = gridRowBonus(3);
      expect(att, 1.0);
      expect(def, 1.0);
    });

    test('linear, zero-sum, 1.5 points per row-step', () {
      for (var row = 1; row < kGridRows; row++) {
        final (att, def) = gridRowBonus(row);
        final d = row - kGridNeutralRow;
        expect(att, closeTo(1 + d * 0.015, 1e-12));
        expect(def, closeTo(1 - d * 0.015, 1e-12));
        // Zero-sum: what attack gains, defence loses.
        expect(att + def, closeTo(2.0, 1e-12));
      }
    });

    test('front row 5: +3.0 attack / -3.0 defence; back row 1: mirrored', () {
      final (att5, def5) = gridRowBonus(5);
      expect(att5, closeTo(1.030, 1e-12));
      expect(def5, closeTo(0.970, 1e-12));
      final (att1, def1) = gridRowBonus(1);
      expect(att1, closeTo(0.970, 1e-12));
      expect(def1, closeTo(1.030, 1e-12));
    });
  });

  group('computeTotals row bonuses (ADR-014, T-0143)', () {
    test('dropping the striker a row lowers attack, raises defence', () {
      final base = gridEngine(42, natural);
      final dropped = gridEngine(42, [
        ...natural.take(9),
        const GridCell(2, 4), // striker: row 5 -> row 4
        ...natural.skip(10),
      ]);
      final baseT = base.totalsOf(MatchSide.home);
      final dropT = dropped.totalsOf(MatchSide.home);
      expect(dropT.attack, lessThan(baseT.attack));
      expect(dropT.defence, greaterThan(baseT.defence));
      // Support and goalkeeping are untouched by the row term.
      expect(dropT.support, closeTo(baseT.support, 1e-9));
      expect(dropT.goalkeeping, baseT.goalkeeping);
    });

    test('the midfield trio one row up: attack up, defence down', () {
      final up = gridEngine(42, [
        ...natural.take(5),
        const GridCell(1, 4),
        const GridCell(2, 4),
        const GridCell(3, 4),
        ...natural.skip(8),
      ]);
      final baseT = gridEngine(42, natural).totalsOf(MatchSide.home);
      final upT = up.totalsOf(MatchSide.home);
      expect(upT.attack, greaterThan(baseT.attack));
      expect(upT.defence, lessThan(baseT.defence));
    });

    test('the midfield trio one row down: defence up, attack down', () {
      final down = gridEngine(42, [
        ...natural.take(5),
        const GridCell(1, 2),
        const GridCell(2, 2),
        const GridCell(3, 2),
        ...natural.skip(8),
      ]);
      final baseT = gridEngine(42, natural).totalsOf(MatchSide.home);
      final downT = down.totalsOf(MatchSide.home);
      expect(downT.attack, lessThan(baseT.attack));
      expect(downT.defence, greaterThan(baseT.defence));
    });

    test('a legal extreme stays within one mentality step of neutral', () {
      // Everything movable pushed to the front: mids, wings and striker
      // all on row 5 (five DISTINCT cells — two players cannot share a
      // place), backs keeping their floor — the biggest legal tilt
      // available. Attack must stay below what Very Attacking (+18%)
      // would read on the same XI (ADR-014 design bound).
      final extreme = gridEngine(42, [
        ...natural.take(5),
        const GridCell(1, 5),
        const GridCell(2, 5),
        const GridCell(3, 5),
        const GridCell(0, 5),
        const GridCell(2, 4), // striker: centre of the front row
        const GridCell(4, 4),
      ]);
      final baseT = gridEngine(42, natural).totalsOf(MatchSide.home);
      final extT = extreme.totalsOf(MatchSide.home);
      final tilt = extT.attack / baseT.attack;
      expect(tilt, greaterThan(1.0));
      expect(tilt, lessThan(1.18));
    });

    test('the preset 4-3-3 snaps to the natural rows (baseline holds)', () {
      final preset = MatchEngine(
        seed: 42,
        home: MatchTeamInput(
          teamId: 1,
          teamName: 'Preset FC',
          formationCode: '4-3-3',
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          starters: flatTeam(100),
          bench: const [],
        ),
        away: MatchTeamInput(
          teamId: 2,
          teamName: 'Foe FC',
          formationCode: '4-3-3',
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          starters: flatTeam(300),
          bench: const [],
        ),
      );
      final naturalTotals = gridEngine(42, natural).totalsOf(
        MatchSide.home,
      );
      final presetTotals = preset.totalsOf(MatchSide.home);
      expect(
        (presetTotals.attack - naturalTotals.attack).abs(),
        lessThan(1.0),
      );
      expect(
        (presetTotals.defence - naturalTotals.defence).abs(),
        lessThan(1.0),
      );
    });
  });

  group('determinism with row bonuses (GDD 12.5)', () {
    test('same seed, same grid formation → identical event streams', () {
      final cells = [
        ...natural.take(5),
        const GridCell(1, 4),
        const GridCell(2, 4),
        const GridCell(3, 4),
        ...natural.skip(8),
      ];
      final a = gridEngine(7, cells).simulateToEnd();
      final b = gridEngine(7, cells).simulateToEnd();
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].type, b[i].type, reason: 'event $i');
        expect(a[i].minute, b[i].minute, reason: 'event $i');
        expect(a[i].side, b[i].side, reason: 'event $i');
      }
    });

    test('the row term is a pure function of the formation code', () {
      final f = customGridFormation(
        [
          Position.gk,
          Position.lb,
          Position.cb,
          Position.cb,
          Position.rb,
          Position.cm,
          Position.cm,
          Position.cm,
          Position.lw,
          Position.st,
          Position.rw,
        ],
        natural,
      )!;
      // Same code round-trips to the same cells → the same row bonuses.
      final roundTrip = formationOfCode(f.code);
      expect(gridCellsOf(roundTrip), gridCellsOf(f));
    });
  });
}
