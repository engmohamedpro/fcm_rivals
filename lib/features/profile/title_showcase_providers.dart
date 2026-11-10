/// FCM Rivals — the showcase providers (T-0112).
///
/// The cabinet resolution (one domain function, both headers + the
/// gallery consume) and the equip flow (setEquippedTitle through
/// T-0106's repository, providers invalidated — instant, free,
/// unlimited).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart' show databaseProvider;
import '../achievements/achievement_claims_repository.dart';
import '../achievements/achievements_providers.dart'
    show careerMetricsProvider, claimsProvider, equippedTitleProvider;
import 'title_domain.dart';

/// The resolved title cabinet: both families, ownership per the
/// two-way rule, the equipped id AFTER the fallback.
final titleCabinetProvider = FutureProvider<TitleCabinet>((ref) async {
  final metrics = await ref.watch(careerMetricsProvider.future);
  final claims = await ref.watch(claimsProvider.future);
  final stored = await ref.watch(equippedTitleProvider.future);
  return resolveTitleCabinet(
    metrics: metrics,
    claimedKeys: claims,
    storedEquippedId: stored,
  );
});

/// The equip flow: tap → setEquippedTitle (T-0106 repository) →
/// invalidate the cabinet + the raw equipped providers → both headers
/// re-render. Direct manipulation, no dialog (the repo's favour).
typedef EquipTitle = Future<void> Function(String? titleId);

/// The equip call the gallery's toggle invokes (a provider so tests
/// can override the repository layer with the in-memory database).
final equipTitleProvider = Provider<EquipTitle>((ref) {
  return (String? titleId) async {
    final database = await ref.watch(databaseProvider.future);
    await AchievementClaimsRepository(database).setEquippedTitle(titleId);
    // Re-read everywhere the equipped id surfaces: the settings
    // column is the state — both headers and the cabinet re-resolve.
    ref.invalidate(equippedTitleProvider);
    ref.invalidate(titleCabinetProvider);
  };
});
