/// FCM Rivals — the profile providers (T-0111).
///
/// The screen's state layer: the SAME career metrics derivation the
/// achievements hub reads (one derivation, many surfaces) and the
/// season history rows (the seasons the derivation already counts —
/// composed here as the profile's list shape).
library;

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show databaseProvider;
import '../../core/database/app_database.dart' as db;
import '../achievements/achievement_progress.dart' show CareerMetrics;

export '../achievements/achievement_progress.dart' show CareerMetrics;

/// Alias so the screen imports one name for the derivation snapshot
/// regardless of surface.
typedef CareerMetricsView = CareerMetrics;

/// The user's club row for the identity header — a one-shot read
/// (identity data is stable; no live stream needed under the shell's
/// fake-clock tests, and the achievements refresh re-derives it).
final profileClubProvider = FutureProvider<db.Club?>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return _userClub(database);
});

/// The completed seasons of the user's club, newest first — the
/// season-history list's row shape.
final seasonHistoryProvider = FutureProvider<List<SeasonHistoryRow>>((
  ref,
) async {
  final database = await ref.watch(databaseProvider.future);
  final club = await _userClub(database);
  if (club == null) return const [];

  final rows = await (database.select(database.seasons)
        ..where((s) => s.userClubId.equals(club.id))
        ..orderBy([
          (s) => OrderingTerm.desc(s.ordinal),
        ]))
      .get();
  return [
    for (final s in rows)
      if (s.status == 'completed')
        SeasonHistoryRow(
          ordinal: s.ordinal,
          division: s.division,
          finalPosition: s.finalPosition,
          outcome: s.outcome,
        ),
  ];
});

/// One history row: the season's identity + outcome.
class SeasonHistoryRow {
  const SeasonHistoryRow({
    required this.ordinal,
    required this.division,
    required this.finalPosition,
    required this.outcome,
  });

  /// The global season ordinal (GDD 9.2).
  final int ordinal;

  /// The division the season played in.
  final int division;

  /// The club's final position (1 = champions).
  final int? finalPosition;

  /// promoted | stayed | relegated | null (incomplete).
  final String? outcome;
}

Future<db.Club?> _userClub(db.AppDatabase database) async {
  final rows = await (database.select(database.clubs)
        ..where((c) => c.isUser))
      .get();
  return rows.isEmpty ? null : rows.first;
}
