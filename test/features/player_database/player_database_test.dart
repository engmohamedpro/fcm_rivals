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

  group('dataset v3: club, league and portrait facts', () {
    // A v3-shaped payload: 7-field rows + the shared clubs/leagues maps.
    String v3Json(
      List<List<dynamic>> rows, {
      Map<String, dynamic>? clubs,
      Map<String, dynamic>? leagues,
    }) => json.encode({
      'format': 'fcm-rivals-players',
      'version': 3,
      'asOf': '2026-11-11',
      'digest': 'test',
      'clubs': ?clubs,
      'leagues': ?leagues,
      'players': rows,
    });

    const v3Clubs = {
      '281': ['Manchester City', 'https://tm.test/wappen/head/281.png', 'GB1'],
      '515': ['Free Agent', '', ''],
    };
    const v3Leagues = {
      'GB1': ['Premier League', 'https://tm.test/logo/header/gb1.png'],
    };

    test('7-field rows resolve club, league and portrait via the maps', () {
      final db = PlayerDatabase();
      db.importDataset(
        PlayerDataset.fromJson(
          v3Json(
            [
              [1, 'Player One', 'ST', 'Egypt', 5_000_000, 281, 'https://tm.test/p/1.png'],
            ],
            clubs: v3Clubs,
            leagues: v3Leagues,
          ),
        ),
      );

      final p = db[1]!;
      expect(p.clubId, 281);
      expect(p.clubName, 'Manchester City');
      expect(p.clubCrestUrl, 'https://tm.test/wappen/head/281.png');
      expect(p.leagueName, 'Premier League');
      expect(p.leagueLogoUrl, 'https://tm.test/logo/header/gb1.png');
      expect(p.imageUrl, 'https://tm.test/p/1.png');
    });

    test('legacy 5-field rows default every presentation fact', () {
      final dataset = PlayerDataset.fromJson(v3Json(baseRows));
      expect(dataset.rows, isNotEmpty);
      for (final row in dataset.rows) {
        expect(row.clubId, 0);
        expect(row.clubName, '');
        expect(row.clubCrestUrl, '');
        expect(row.leagueName, '');
        expect(row.leagueLogoUrl, '');
        expect(row.imageUrl, '');
      }
      final db = PlayerDatabase();
      db.importDataset(dataset);
      expect(db[1]!.imageUrl, '');
    });

    test('free agents carry the club convention and no crest', () {
      final db = PlayerDatabase();
      db.importDataset(
        PlayerDataset.fromJson(
          v3Json(
            [
              [2, 'Player Two', 'CB', 'Brazil', 1_000_000, 515, ''],
            ],
            clubs: v3Clubs,
            leagues: v3Leagues,
          ),
        ),
      );
      final p = db[2]!;
      expect(p.clubId, 515);
      expect(p.clubName, 'Free Agent');
      expect(p.clubCrestUrl, '');
      expect(p.leagueName, '');
      expect(p.leagueLogoUrl, '');
    });

    test('image-only change updates in place without regenerating stats',
        () {
      final db = PlayerDatabase();
      db.importDataset(
        PlayerDataset.fromJson(
          v3Json(
            [
              [1, 'Player One', 'ST', 'Egypt', 5_000_000, 281, 'https://tm.test/p/1.png'],
            ],
            clubs: v3Clubs,
            leagues: v3Leagues,
          ),
        ),
      );
      final before = db[1]!.baseStats;

      final result = db.importDataset(
        PlayerDataset.fromJson(
          v3Json(
            [
              [1, 'Player One', 'ST', 'Egypt', 5_000_000, 281, 'https://tm.test/p/1-new.png'],
            ],
            clubs: v3Clubs,
            leagues: v3Leagues,
          ),
        ),
      );

      expect(result.regenerated, isEmpty);
      expect(result.updated.single.playerId, 1);
      expect(db[1]!.imageUrl, 'https://tm.test/p/1-new.png');
      expect(db[1]!.baseStats, before);
    });

    test('club move (transfer) updates the club facts without a regen', () {
      final db = PlayerDatabase();
      db.importDataset(
        PlayerDataset.fromJson(
          v3Json(
            [
              [1, 'Player One', 'ST', 'Egypt', 5_000_000, 281, 'https://tm.test/p/1.png'],
            ],
            clubs: v3Clubs,
            leagues: v3Leagues,
          ),
        ),
      );
      final before = db[1]!.baseStats;

      final result = db.importDataset(
        PlayerDataset.fromJson(
          v3Json(
            [
              [1, 'Player One', 'ST', 'Egypt', 5_000_000, 515, 'https://tm.test/p/1.png'],
            ],
            clubs: v3Clubs,
            leagues: v3Leagues,
          ),
        ),
      );

      expect(result.regenerated, isEmpty);
      expect(db[1]!.clubName, 'Free Agent');
      expect(db[1]!.baseStats, before);
    });
  });
}
