/// FCM Rivals — the daily streak providers.
///
/// The profile's streak card state layer: a one-shot snapshot of the
/// club's run (claim button enabled, next/tomorrow rewards, broken
/// state), plus an invalidation hook the claim path fires so the
/// card — and every coin-reading surface — refreshes after a claim.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show databaseProvider;
import '../economy/streak_store.dart';

/// The user's streak view — null when no club exists (onboarding).
final streakSnapshotProvider = FutureProvider<StreakSnapshot?>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  final rows = await (database.select(database.clubs)
        ..where((c) => c.isUser))
      .get();
  if (rows.isEmpty) return null;
  final club = rows.first;
  return StreakStore(database).snapshot(club.id);
});
