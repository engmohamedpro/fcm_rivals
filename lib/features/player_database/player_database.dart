/// FCM Rivals — Player Database Engine (GDD 4, FR-002..FR-008).
///
/// Owns the global player registry: importing datasets, validating required
/// fields, applying update rules (regenerating Base Stats only when Market
/// Value or Position changed) and detecting removed players so the caller can
/// compensate owners with the normal selling formula. Pure Dart: no Flutter
/// imports — the registry runs under plain `dart run` (the T-0060 probe).
library;

import 'dart:convert';

import '../../core/domain/base_stats_generator.dart';
import '../../core/domain/players.dart';

/// Local stand-in for Flutter's `@immutable` (analyzer-only annotation):
/// `@ImmutableMarker()` — const, zero runtime effect, keeps this file
/// pure Dart so it runs under plain `dart run`.
class ImmutableMarker {
  final List<String> fields;
  const ImmutableMarker([this.fields = const <String>[]]);
}

/// Club facts from the dataset's `clubs` map (dataset v3): display name,
/// crest link and domestic league code ('' when the source tracks none).
typedef PlayerDatasetClub = ({String name, String crestUrl, String leagueCode});

/// League facts from the dataset's `leagues` map (dataset v3): display
/// name and logo link.
typedef PlayerDatasetLeague = ({String name, String logoUrl});

/// Raw player row as found in the importable dataset:
/// [playerId, name, position, nationality, marketValueEur] — the five
/// fields every format version shares — optionally extended by dataset
/// v3 to [..., clubId, imageUrl]. The club/league names and links are
/// resolved against the dataset's `clubs`/`leagues` maps when present;
/// every presentation field defaults to 'none' on legacy 5-field rows.
@ImmutableMarker()
class PlayerDatasetRow {
  const PlayerDatasetRow({
    required this.playerId,
    required this.name,
    required this.position,
    required this.nationality,
    required this.marketValueEur,
    this.clubId = 0,
    this.clubName = '',
    this.clubCrestUrl = '',
    this.leagueName = '',
    this.leagueLogoUrl = '',
    this.imageUrl = '',
    this.isIcon = false,
  });

  factory PlayerDatasetRow.fromList(
    List<dynamic> row, {
    Map<String, PlayerDatasetClub> clubs = const {},
    Map<String, PlayerDatasetLeague> leagues = const {},
  }) {
    final clubId = row.length > 5 ? row[5] as int : 0;
    final club = clubs['$clubId'];
    final league = leagues[club?.leagueCode ?? ''];
    return PlayerDatasetRow(
      playerId: row[0] as int,
      name: row[1] as String,
      position: Position.fromCode(row[2] as String),
      nationality: row[3] as String,
      marketValueEur: row[4] as int,
      clubId: clubId,
      clubName: club?.name ?? '',
      clubCrestUrl: club?.crestUrl ?? '',
      leagueName: league?.name ?? '',
      leagueLogoUrl: league?.logoUrl ?? '',
      imageUrl: row.length > 6 ? row[6] as String : '',
      isIcon: row.length > 11 ? row[11] as bool : false,
    );
  }

  final int playerId;
  final String name;
  final Position position;
  final String nationality;
  final int marketValueEur;

  /// Presentation facts (dataset v3); defaults keep legacy 5-field rows
  /// and rows built from persisted data valid everywhere.
  final int clubId;
  final String clubName;
  final String clubCrestUrl;
  final String leagueName;
  final String leagueLogoUrl;
  final String imageUrl;

  /// Icon players (owner request 2026-11-12): true for the rows rebuilt
  /// from `tm-icons.json`. Rows from the legacy v3 compact format keep
  /// the false default, so persisted reimports stay stable.
  final bool isIcon;
}

/// A parsed player dataset file. Validation (including duplicate ids) is
/// performed by [PlayerDatabase.validate] before anything is applied.
class PlayerDataset {
  PlayerDataset({
    required this.version,
    required this.asOf,
    this.digest = '',
    List<PlayerDatasetRow> rows = const [],
    this.clubs = const {},
    this.leagues = const {},
  }) : _rows = List.unmodifiable(rows);

  final int version;
  final String asOf;
  final String digest;
  final List<PlayerDatasetRow> _rows;

  /// Shared club facts keyed by Transfermarkt club id (dataset v3; empty
  /// on legacy files). Rows resolve their club/league presentation fields
  /// against these maps at parse time.
  final Map<String, PlayerDatasetClub> clubs;

  /// Shared league facts keyed by league code (dataset v3; empty on
  /// legacy files).
  final Map<String, PlayerDatasetLeague> leagues;

  int get count => _rows.length;
  Iterable<PlayerDatasetRow> get rows => _rows;

  static PlayerDataset fromJson(String jsonText) {
    final map = json.decode(jsonText) as Map<String, dynamic>;
    if (map['format'] != 'fcm-rivals-players') {
      throw const FormatException('unsupported player dataset format');
    }
    final clubs = <String, PlayerDatasetClub>{};
    final rawClubs = map['clubs'];
    if (rawClubs is Map<String, dynamic>) {
      rawClubs.forEach((key, value) {
        final facts = value as List;
        if (facts.length >= 3) {
          clubs[key] = (
            name: facts[0] as String,
            crestUrl: facts[1] as String,
            leagueCode: facts[2] as String,
          );
        }
      });
    }
    final leagues = <String, PlayerDatasetLeague>{};
    final rawLeagues = map['leagues'];
    if (rawLeagues is Map<String, dynamic>) {
      rawLeagues.forEach((key, value) {
        final facts = value as List;
        if (facts.length >= 2) {
          leagues[key] = (
            name: facts[0] as String,
            logoUrl: facts[1] as String,
          );
        }
      });
    }
    final rows = (map['players'] as List)
        .map(
          (r) => PlayerDatasetRow.fromList(
            r as List,
            clubs: clubs,
            leagues: leagues,
          ),
        )
        .toList();
    return PlayerDataset(
      version: map['version'] as int,
      asOf: map['asOf'] as String,
      digest: (map['digest'] ?? '') as String,
      rows: rows,
      clubs: clubs,
      leagues: leagues,
    );
  }

  /// Parses the shipped tm-file bundle (owner request 2026-11-12): the
  /// four `tm-*.json` assets as sent — players, icons, clubs and
  /// leagues — into the same [PlayerDataset] the whole game already
  /// consumes. The FILES are never rewritten; every adaptation happens
  /// here:
  /// - Transfermarkt long position names map onto the game's codes
  ///   ('Centre-Forward' → ST, 'Sweeper' → CB, …); rows with any other
  ///   position are dropped, as are rows without a name, a nationality
  ///   or a usable market value — the v3 pipeline's validation rules,
  ///   applied at parse so [PlayerDatabase.validate] never sees them.
  /// - String ids become ints; club/league presentation facts resolve
  ///   through the clubs/leagues maps (logo links carry a `?lm=`
  ///   timestamp — kept verbatim, they stay valid CDN URLs).
  /// - Icon rows (tm-icons.json, no clubId) import with [isIcon] true;
  ///   the five ids that appear in BOTH files (Messi, Ronaldo, Neymar,
  ///   Modrić, Suárez) resolve to their icon row — the legend wins over
  ///   the active player.
  ///
  /// Pure parsing, no validation: [PlayerDatabase.importDataset] keeps
  /// its single validation path for every source.
  static PlayerDataset fromTmBundle({
    required String playersJson,
    required String iconsJson,
    required String clubsJson,
    required String leaguesJson,
  }) {
    final clubs = <String, PlayerDatasetClub>{};
    for (final c in (json.decode(clubsJson) as List)) {
      final m = c as Map<String, dynamic>;
      final id = '${m['id']}';
      clubs[id] = (
        name: '${m['title']}',
        crestUrl: '${m['logo']}',
        leagueCode: '${m['leagueId'] ?? ''}',
      );
    }
    final leagues = <String, PlayerDatasetLeague>{};
    for (final l in (json.decode(leaguesJson) as List)) {
      final m = l as Map<String, dynamic>;
      leagues['${m['id']}'] = (
        name: '${m['title']}',
        logoUrl: '${m['logo']}',
      );
    }

    final rows = <PlayerDatasetRow>[];
    final iconIds = <int>{};
    for (final p in (json.decode(iconsJson) as List)) {
      final m = p as Map<String, dynamic>;
      final position = _tmPosition('${m['position'] ?? ''}');
      if (position == null) continue;
      final marketValue = m['marketValue'];
      final value = marketValue is int ? marketValue : null;
      final name = '${m['name'] ?? ''}'.trim();
      final nationality = '${m['nationality'] ?? ''}'.trim();
      if (name.isEmpty || nationality.isEmpty || value == null || value <= 0) {
        continue;
      }
      final id = int.tryParse('${m['id']}');
      if (id == null) continue;
      iconIds.add(id);
      rows.add(PlayerDatasetRow(
        playerId: id,
        name: name,
        position: position,
        nationality: nationality,
        marketValueEur: value,
        clubId: 0,
        clubName: '',
        clubCrestUrl: '',
        leagueName: '',
        leagueLogoUrl: '',
        imageUrl: '${m['image'] ?? ''}',
        isIcon: true,
      ));
    }

    for (final p in (json.decode(playersJson) as List)) {
      final m = p as Map<String, dynamic>;
      final id = int.tryParse('${m['id']}');
      if (id == null || iconIds.contains(id)) continue;
      final position = _tmPosition('${m['position'] ?? ''}');
      if (position == null) continue;
      final marketValue = m['marketValue'];
      final value = marketValue is int ? marketValue : null;
      final name = '${m['name'] ?? ''}'.trim();
      final nationality = '${m['nationality'] ?? ''}'.trim();
      if (name.isEmpty || nationality.isEmpty || value == null || value <= 0) {
        continue;
      }
      final clubId = int.tryParse('${m['clubId'] ?? ''}') ?? 0;
      final club = clubs['$clubId'];
      final league = leagues[club?.leagueCode ?? ''];
      rows.add(PlayerDatasetRow(
        playerId: id,
        name: name,
        position: position,
        nationality: nationality,
        marketValueEur: value,
        clubId: clubId,
        clubName: club?.name ?? '',
        clubCrestUrl: club?.crestUrl ?? '',
        leagueName: league?.name ?? '',
        leagueLogoUrl: league?.logoUrl ?? '',
        imageUrl: '${m['image'] ?? ''}',
      ));
    }

    return PlayerDataset(
      version: tmBundleVersion,
      asOf: '2026-11-12',
      digest: 'tm-bundle-2026-11-12',
      rows: rows,
      clubs: clubs,
      leagues: leagues,
    );
  }

  /// The dataset bundle version shipped since the 2026-11-12 tm-files
  /// swap: version 4 re-imports over any install still holding the v3
  /// compact file (players_v1.json is GONE — `importBundledDataset`
  /// skips only when the persisted version is >= this one).
  static const int tmBundleVersion = 4;

  /// Transfermarkt long position names → the game's [Position] codes.
  /// Returns null for anything else (null positions, 'Mittelfeld' and
  /// other umbrella labels) — those rows are dropped, exactly the rows
  /// the v3 validation rejected.
  static Position? _tmPosition(String tm) => switch (tm) {
    'Goalkeeper' => Position.gk,
    'Centre-Back' => Position.cb,
    'Sweeper' => Position.cb,
    'Left-Back' => Position.lb,
    'Right-Back' => Position.rb,
    'Defensive Midfield' => Position.cdm,
    'Central Midfield' => Position.cm,
    'Attacking Midfield' => Position.cam,
    'Left Midfield' => Position.lm,
    'Right Midfield' => Position.rm,
    'Left Winger' => Position.lw,
    'Right Winger' => Position.rw,
    'Centre-Forward' => Position.st,
    'Second Striker' => Position.st,
    _ => null,
  };
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
      // Perf pass 2026-11-12: generate() ONLY where its result is
      // consumed. It used to run unconditionally before the checks —
      // a math.Random construction + ~9 draws + allocations for every
      // one of the ~40-51k rows on EVERY warm start, even though the
      // entire registry falls into the `unchanged` branch. Seeded with
      // the player id either way: the probabilistic layer gives each
      // player his own stat shape while regeneration stays stable
      // across dataset updates (GDD 4.6 — same value + position
      // rebuilds the same stats).
      if (existing == null) {
        final stats = generator.generate(
          row.position,
          row.marketValueEur,
          seed: row.playerId,
        );
        final player = _toPlayer(row, stats);
        _players[row.playerId] = player;
        added.add(player);
        continue;
      }

      final statsChanged =
          existing.marketValueEur != row.marketValueEur ||
          existing.position != row.position;
      if (statsChanged) {
        final stats = generator.generate(
          row.position,
          row.marketValueEur,
          seed: row.playerId,
        );
        final player = _toPlayer(row, stats);
        _players[row.playerId] = player;
        regenerated.add(player);
        if (_mutableFactsChanged(existing, row)) updated.add(player);
      } else if (_mutableFactsChanged(existing, row)) {
        final player = existing.copyWith(
          name: row.name,
          nationality: row.nationality,
          clubId: row.clubId,
          clubName: row.clubName,
          clubCrestUrl: row.clubCrestUrl,
          leagueName: row.leagueName,
          leagueLogoUrl: row.leagueLogoUrl,
          imageUrl: row.imageUrl,
          isIcon: row.isIcon,
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

  /// Presentation facts (name, nationality, club/league identity, image)
  /// update in place; they never regenerate Base Stats — only Market Value
  /// or Position do (GDD 4.6). The icon flag rides along: it is a fact of
  /// the dataset the row came from, not a mutable player fact.
  bool _mutableFactsChanged(BasePlayer existing, PlayerDatasetRow row) =>
      existing.name != row.name ||
      existing.nationality != row.nationality ||
      existing.clubId != row.clubId ||
      existing.clubName != row.clubName ||
      existing.clubCrestUrl != row.clubCrestUrl ||
      existing.leagueName != row.leagueName ||
      existing.leagueLogoUrl != row.leagueLogoUrl ||
      existing.imageUrl != row.imageUrl ||
      existing.isIcon != row.isIcon;

  BasePlayer _toPlayer(PlayerDatasetRow row, BaseStats stats) => BasePlayer(
    playerId: row.playerId,
    name: row.name,
    position: row.position,
    nationality: row.nationality,
    marketValueEur: row.marketValueEur,
    baseStats: stats,
    clubId: row.clubId,
    clubName: row.clubName,
    clubCrestUrl: row.clubCrestUrl,
    leagueName: row.leagueName,
    leagueLogoUrl: row.leagueLogoUrl,
    imageUrl: row.imageUrl,
    isIcon: row.isIcon,
  );
}
