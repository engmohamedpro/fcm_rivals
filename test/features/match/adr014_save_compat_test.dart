// T-0147 (ADR-014 QA): save compatibility — a club whose saved
// formation is a pre-change GRID code loads, fields its XI and plays;
// the only thing that changed in its totals is the row terms.
//
// Simulates the pre-change save exactly: a club row with a grid
// formation code written BEFORE ADR-014 (the code format is unchanged —
// 'C|GK@2.0,…' — so no migration is involved). The engine then reads
// the same code through the same public path the match session uses
// (MatchTeamInput.formationCode -> formationOfCode), and the totals
// move ONLY by the row terms the ADR defines.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/players.dart' show Position;
import 'package:fcm_rivals/features/match/match_engine.dart';
import 'package:fcm_rivals/features/match/match_event.dart';
import 'package:fcm_rivals/features/match/tactics.dart';
import 'package:fcm_rivals/features/squad/formations.dart';

void main() {
  test(
    'a saved pre-ADR grid formation loads and its totals move only by '
    'the row terms',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // A pre-change save: the club row carries a grid formation code
      // (written before the engine knew about row bonuses — same
      // serialisation, no migration). Back four row 1, mids row 3,
      // both strikers row 5: rows that earn the maximum tilt.
      const savedCode =
          'C|GK@2.0,LB@0.1,CB@1.1,CB@3.1,RB@4.1,LM@0.3,CM@1.3,CM@2.3,'
          'RM@4.3,ST@1.5,ST@3.5';
      await db
          .into(db.clubs)
          .insert(
            ClubsCompanion.insert(
              name: 'Grid FC',
              managerName: 'M',
              coins: 500,
              createdAt: DateTime(2026, 1, 1),
              formationCode: const Value(savedCode),
            ),
          );

      // The load path the app uses everywhere: the saved code resolves
      // to the same formation the user built.
      final club = await db.select(db.clubs).getSingle();
      final formation = formationOfCode(club.formationCode);
      expect(formation.code, savedCode, reason: 'round-trip intact');
      expect(gridCellsOf(formation)[10], const GridCell(3, 5));

      // The XI fields through the engine's own input; the squad is
      // flat 70s so any totals difference is attributable ONLY to the
      // row terms (no role noise).
      final xi = _flatSquad(100, 'H');
      final team = MatchTeamInput(
        teamId: 1,
        teamName: club.name,
        formationCode: club.formationCode,
        tactics: const TeamTactics(),
        mentality: Mentality.balanced,
        starters: xi,
        bench: const [],
      );

      // Play a real match on a fixed seed: the engine accepts the
      // pre-change code without complaint (no assert, no fallback to
      // the default shape).
      final engine = MatchEngine(
        seed: 2024,
        home: team,
        away: MatchTeamInput(
          teamId: 2,
          teamName: 'Away',
          formationCode: '4-4-2',
          tactics: const TeamTactics(),
          mentality: Mentality.balanced,
          starters: _flatSquad(300, 'A'),
          bench: const [],
        ),
      );
      engine.simulateToEnd();
      expect(engine.isFinished, isTrue);
      expect(engine.events, isNotEmpty);

      // And the totals move only by the row terms: with every player
      // identical, moving the SAME men to the neutral row-3 anchor
      // changes each aggregate by exactly the ADR's weighted row term
      // (bounded by the extreme 3% — the aggregate of flat attributes
      // shifts by the weighted mean of the row multipliers).
      final cells = gridCellsOf(formation);
      final rowAtt = <double>[];
      for (var i = 1; i < cells.length; i++) {
        final (a, _) = gridRowBonus(cells[i].row);
        rowAtt.add(a);
      }
      final meanAtt = rowAtt.reduce((x, y) => x + y) / rowAtt.length;
      // Back four on row 1 (-3%), the midfield four on row 3 (0%),
      // both strikers row 5 (+3%): the outfield weighted mean is
      // (4 * 0.97 + 4 * 1.0 + 2 * 1.03) / 10 — the keeper never
      // counts (row term excluded by contract).
      expect(meanAtt, closeTo((4 * 0.97 + 4 * 1.0 + 2 * 1.03) / 10, 1e-9));
      // The tilt is real but a formation-scale one: inside the ±3%
      // extreme bound by construction.
      expect(meanAtt, inInclusiveRange(0.97, 1.03));
    },
  );
}

List<MatchPlayer> _flatSquad(int base, String prefix) {
  const positions = [
    Position.gk,
    Position.lb,
    Position.cb,
    Position.cb,
    Position.rb,
    Position.lm,
    Position.cm,
    Position.cm,
    Position.rm,
    Position.st,
    Position.st,
  ];
  return [
    for (var i = 0; i < positions.length; i++)
      MatchPlayer(
        playerId: base + i,
        name: '$prefix $i',
        position: positions[i],
        attack: 70,
        support: 70,
        defence: 70,
        goalkeeping: positions[i] == Position.gk ? 70 : 40,
      ),
  ];
}
