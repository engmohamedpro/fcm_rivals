import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/domain/players.dart';
import 'package:fcm_rivals/features/player_database/player_database.dart';

String datasetJson(List<List<dynamic>> rows, {int version = 1}) => json.encode({
  'format': 'fcm-rivals-players',
  'version': version,
  'asOf': '2026-11-01',
  'digest': 'test',
  'players': rows,
});

// [id, name, pos, nat, mv]
const List<List<dynamic>> baseRows = [
  [1, 'Player One', 'ST', 'Egypt', 5_000_000],
  [2, 'Player Two', 'CB', 'Brazil', 1_000_000],
  [3, 'Player Three', 'GK', 'Germany', 30_000_000],
];

PlayerDataset ds(List<List<dynamic>> rows, {int version = 1}) =>
    PlayerDataset.fromJson(datasetJson(rows, version: version));

void main() {
  group('PlayerDatabase import', () {
    test('imports validated rows and generates base stats', () {
      final db = PlayerDatabase();
      final result = db.importDataset(ds(baseRows));

      expect(db.count, 3);
      expect(result.added.length, 3);
      expect(result.updated, isEmpty);
      expect(result.regenerated, isEmpty);
      expect(result.removed, isEmpty);
      expect(db.datasetVersion, 1);

      final gk = db[3]!;
      expect(gk.position, Position.gk);
      expect(gk.baseStats.goalkeeping, greaterThan(gk.baseStats.attack));
      expect(gk.nationality, 'Germany');
    });

    test('FR-002: invalid rows are rejected before applying', () {
      final db = PlayerDatabase();
      db.importDataset(ds(baseRows));
      final before = db.count;

      final bad = ds([
        [9, 'Bad Value', 'ST', 'Egypt', 0],
        [0, 'Bad Id', 'ST', 'Egypt', 5_000_000],
      ]);
      expect(
        () => db.importDataset(bad),
        throwsA(isA<DatasetValidationException>()),
      );
      expect(db.count, before); // untouched
    });

    test('duplicate ids in one dataset are rejected', () {
      final dup = ds([
        [5, 'A', 'ST', 'Egypt', 1_000_000],
        [5, 'B', 'CB', 'Egypt', 1_000_000],
      ]);
      expect(
        () => PlayerDatabase().importDataset(dup),
        throwsA(isA<DatasetValidationException>()),
      );
    });

    test(
      'GDD 4.6: name/nationality changes update fields, stats preserved',
      () {
        final db = PlayerDatabase();
        db.importDataset(ds(baseRows));
        final statsBefore = db[1]!.baseStats;

        final result = db.importDataset(
          ds([
            [1, 'Player One Renamed', 'ST', 'Mexico', 5_000_000],
            [2, 'Player Two', 'CB', 'Brazil', 1_000_000],
            [3, 'Player Three', 'GK', 'Germany', 30_000_000],
          ], version: 2),
        );

        expect(result.updated.length, 1);
        expect(result.regenerated, isEmpty);
        expect(result.unchanged, 2);
        final p = db[1]!;
        expect(p.name, 'Player One Renamed');
        expect(p.nationality, 'Mexico');
        expect(p.baseStats, statsBefore); // FR-006
      },
    );

    test('GDD 4.6: market value change regenerates base stats', () {
      final db = PlayerDatabase();
      db.importDataset(ds(baseRows));

      final result = db.importDataset(
        ds([
          [1, 'Player One', 'ST', 'Egypt', 40_000_000],
          [2, 'Player Two', 'CB', 'Brazil', 1_000_000],
          [3, 'Player Three', 'GK', 'Germany', 30_000_000],
        ], version: 2),
      );

      expect(result.regenerated.length, 1);
      expect(db[1]!.baseStats.overall, greaterThan(0));
      final st = db[1]!.baseStats;
      expect(st.attack, greaterThan(st.defence)); // still an ST profile
    });

    test('GDD 4.6: position change regenerates stats with new profile', () {
      final db = PlayerDatabase();
      db.importDataset(ds(baseRows));

      db.importDataset(
        ds([
          [1, 'Player One', 'CB', 'Egypt', 5_000_000],
          [2, 'Player Two', 'CB', 'Brazil', 1_000_000],
          [3, 'Player Three', 'GK', 'Germany', 30_000_000],
        ], version: 2),
      );

      final p = db[1]!;
      expect(p.position, Position.cb);
      expect(p.baseStats.defence, greaterThan(p.baseStats.attack));
    });

    test('GDD 4.6: unchanged value+position preserves stats byte-for-byte', () {
      final db = PlayerDatabase();
      db.importDataset(ds(baseRows));
      final before = db[2]!.baseStats;

      db.importDataset(ds(baseRows, version: 2));
      expect(db[2]!.baseStats, before);
    });

    test('GDD 4.8: removed players are reported for compensation', () {
      final db = PlayerDatabase();
      db.importDataset(ds(baseRows));

      final result = db.importDataset(
        ds([
          [1, 'Player One', 'ST', 'Egypt', 5_000_000],
          [3, 'Player Three', 'GK', 'Germany', 30_000_000],
        ], version: 2),
      );

      expect(result.removed.length, 1);
      expect(result.removed.single.playerId, 2);
      expect(db.count, 2);
      expect(db[2], isNull);
    });

    test(
      'stable ids: same player keeps id across renames and value changes',
      () {
        final db = PlayerDatabase();
        db.importDataset(ds(baseRows));
        db.importDataset(
          ds([
            [1, 'Completely New Name', 'ST', 'Egypt', 60_000_000],
            [2, 'Player Two', 'CB', 'Brazil', 1_000_000],
            [3, 'Player Three', 'GK', 'Germany', 30_000_000],
          ], version: 2),
        );
        expect(db[1]!.playerId, 1);
        expect(db[1]!.name, 'Completely New Name');
      },
    );
  });
}
