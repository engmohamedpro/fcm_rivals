/// FCM Rivals — Player Database Engine (GDD 4, FR-002..FR-008).
///
/// Owns the global player registry: importing datasets, validating required
/// fields, applying update rules (regenerating Base Stats only when Market
/// Value or Position changed) and detecting removed players so the caller can
/// compensate owners with the normal selling formula.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/domain/base_stats_generator.dart';
import '../../core/domain/players.dart';

/// Raw player row as found in the importable dataset:
/// [playerId, name, position, nationality, marketValueEur].
@immutable
class PlayerDatasetRow {
  const PlayerDatasetRow({
    required this.playerId,
    required this.name,
    required this.position,
    required this.nationality,
    required this.marketValueEur,
  });

  factory PlayerDatasetRow.fromList(List<dynamic> row) => PlayerDatasetRow(
    playerId: row[0] as int,
    name: row[1] as String,
    position: Position.fromCode(row[2] as String),
    nationality: row[3] as String,
    marketValueEur: row[4] as int,
  );

  final int playerId;
  final String name;
  final Position position;
  final String nationality;
  final int marketValueEur;
}

/// A parsed player dataset file. Validation (including duplicate ids) is
/// performed by [PlayerDatabase.validate] before anything is applied.
class PlayerDataset {
  PlayerDataset({
    required this.version,
    required this.asOf,
    this.digest = '',
    List<PlayerDatasetRow> rows = const [],
  }) : _rows = List.unmodifiable(rows);

  final int version;
  final String asOf;
  final String digest;
  final List<PlayerDatasetRow> _rows;

  int get count => _rows.length;
  Iterable<PlayerDatasetRow> get rows => _rows;

  static PlayerDataset fromJson(String jsonText) {
    final map = json.decode(jsonText) as Map<String, dynamic>;
    if (map['format'] != 'fcm-rivals-players') {
      throw const FormatException('unsupported player dataset format');
    }
    final rows = (map['players'] as List)
        .map((r) => PlayerDatasetRow.fromList(r as List))
        .toList();
    return PlayerDataset(
      version: map['version'] as int,
      asOf: map['asOf'] as String,
      digest: (map['digest'] ?? '') as String,
      rows: rows,
    );
  }
}

/// Outcome of applying a dataset: new records, updated records, regenerated
/// stats, and removed records needing owner compensation (GDD 4.8).
class ImportResult {
  const ImportResult({
    required this.added,
    required this.updated,
    required this.regenerated,
    required this.unchanged,
    required this.removed,
  });

  /// New players introduced by this dataset.
  final List<BasePlayer> added;

  /// Existing players whose mutable facts changed (name/nationality/...).
  final List<BasePlayer> updated;

  /// Players whose Base Stats were regenerated (value or position changed).
  final List<BasePlayer> regenerated;

  /// Existing players with no change at all.
  final int unchanged;

  /// Players present before but absent from the new dataset.
  final List<BasePlayer> removed;
}

/// Thrown when a dataset fails validation (FR-002: validate before applying).
class DatasetValidationException implements Exception {
  const DatasetValidationException(this.problems);

  /// Human-readable validation problems.
  final List<String> problems;

  @override
  String toString() => 'DatasetValidationException(${problems.join("; ")})';
}

/// The registry of global (base) players.
class PlayerDatabase {
  PlayerDatabase({this.generator = const BaseStatsGenerator()});

  final BaseStatsGenerator generator;
  final Map<int, BasePlayer> _players = {};
  int _datasetVersion = 0;

  int get datasetVersion => _datasetVersion;
  int get count => _players.length;

  BasePlayer? operator [](int playerId) => _players[playerId];
  Iterable<BasePlayer> get all => _players.values;

  /// Validates [dataset] without touching the registry (FR-002).
  ///
  /// Checks required fields, positive ids, plausible market value, known
  /// position codes and duplicate ids. Throws
  /// [DatasetValidationException] listing every problem found.
  void validate(PlayerDataset dataset) {
    final problems = <String>[];
    final seenIds = <int>{};
    for (final row in dataset.rows) {
      final tag = 'player ${row.playerId}';
      if (row.playerId <= 0) {
        problems.add('$tag: id must be positive');
      }
      if (seenIds.contains(row.playerId)) {
        problems.add('$tag: duplicate id');
      }
      seenIds.add(row.playerId);
      if (row.name.trim().isEmpty) problems.add('$tag: missing name');
      if (row.nationality.trim().isEmpty) {
        problems.add('$tag: missing nationality');
      }
      if (row.marketValueEur <= 0) problems.add('$tag: missing market value');
      if (row.marketValueEur > 1_000_000_000) {
        problems.add('$tag: implausible market value');
      }
    }
    if (problems.isNotEmpty) throw DatasetValidationException(problems);
  }

  /// Applies a validated dataset (FR-004..FR-008).
  ///
  /// Update rules (GDD 4.6):
  /// - name/nationality changes are plain field updates;
  /// - Market Value or Position change regenerates Base Stats;
  /// - unchanged value+position keeps Base Stats byte-for-byte;
  /// - dropped players are reported for owner compensation (GDD 4.8);
  /// - upgrades live on owned instances and are untouched here (GDD 8.3).
  ImportResult importDataset(PlayerDataset dataset) {
    validate(dataset);

    final added = <BasePlayer>[];
    final updated = <BasePlayer>[];
    final regenerated = <BasePlayer>[];
    var unchanged = 0;

    final newIds = dataset.rows.map((r) => r.playerId).toSet();

    for (final row in dataset.rows) {
      final existing = _players[row.playerId];
      // Seeded with the player id: the probabilistic layer gives each
      // player his own stat shape while regeneration stays stable across
      // dataset updates (GDD 4.6 — same value + position rebuilds the
      // same stats).
      final stats = generator.generate(
        row.position,
        row.marketValueEur,
        seed: row.playerId,
      );
      if (existing == null) {
        final player = _toPlayer(row, stats);
        _players[row.playerId] = player;
        added.add(player);
        continue;
      }

      final statsChanged =
          existing.marketValueEur != row.marketValueEur ||
          existing.position != row.position;
      if (statsChanged) {
        final player = _toPlayer(row, stats);
        _players[row.playerId] = player;
        regenerated.add(player);
        if (_mutableFactsChanged(existing, row)) updated.add(player);
      } else if (_mutableFactsChanged(existing, row)) {
        final player = existing.copyWith(
          name: row.name,
          nationality: row.nationality,
        );
        _players[row.playerId] = player;
        updated.add(player);
      } else {
        unchanged++;
      }
    }

    final removed = <BasePlayer>[];
    for (final id in _players.keys.toList()) {
      if (!newIds.contains(id)) {
        removed.add(_players.remove(id)!);
      }
    }

    _datasetVersion = dataset.version;
    return ImportResult(
      added: added,
      updated: updated,
      regenerated: regenerated,
      unchanged: unchanged,
      removed: removed,
    );
  }

  /// Applies an already-parsed dataset; convenience for tests.
  ImportResult importDatasetFromJson(String jsonText) =>
      importDataset(PlayerDataset.fromJson(jsonText));

  bool _mutableFactsChanged(BasePlayer existing, PlayerDatasetRow row) =>
      existing.name != row.name || existing.nationality != row.nationality;

  BasePlayer _toPlayer(PlayerDatasetRow row, BaseStats stats) => BasePlayer(
    playerId: row.playerId,
    name: row.name,
    position: row.position,
    nationality: row.nationality,
    marketValueEur: row.marketValueEur,
    baseStats: stats,
  );
}
