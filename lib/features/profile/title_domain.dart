/// FCM Rivals — the prestige domain (T-0112).
///
/// The TWO-WAY ownership rule, encoded once, consumed everywhere:
/// an ACHIEVEMENT title is owned iff its source tier was CLAIMED
/// (T-0108 — grinding is not enough, the claim is the act); a
/// DIVISION-CHAMPION title is owned iff the metrics say the club
/// finished 1st in that division (T-0107 — silverware is earned the
/// moment the season completes, no claim action, it IS owned).
/// Unknown equipped ids (renamed catalog entries, edited saves) fall
/// back to unequipped — a debug log, never a crash.
library;

import '../achievements/achievement_catalog.dart';
import '../achievements/achievement_catalog_data.dart';
import '../achievements/achievement_progress.dart';

/// A resolved title with its ownership state and source line.
class OwnedTitleState {
  const OwnedTitleState({
    required this.id,
    required this.l10nKey,
    required this.owned,
    required this.sourceL10nKey,
    required this.sourceArg,
  });

  /// The title id (registry id).
  final String id;

  /// The l10n key for the title's display text.
  final String l10nKey;

  /// Whether the manager owns it.
  final bool owned;

  /// The source line's key: which achievement (and tier) or which
  /// division championship earned it.
  final String sourceL10nKey;

  /// The source argument (the tier's threshold or the division) —
  /// `titleSourceAchievement` and `titleSourceDivision` are the two
  /// parametrized keys the gallery renders.
  final int sourceArg;
}

/// The manager's whole title collection, resolved against the save.
class TitleCabinet {
  const TitleCabinet({
    required this.achievementTitles,
    required this.divisionTitles,
    required this.ownedIds,
    required this.equippedKnown,
    String? equippedId,
  }) : _equippedId = equippedId; // ignore: prefer_initializing_formals

  /// Achievement-tier titles in registry order.
  final List<OwnedTitleState> achievementTitles;

  /// Division-championship titles, seeded divisions then generated.
  final List<OwnedTitleState> divisionTitles;

  /// The ids of every owned title (both families).
  final Set<String> ownedIds;

  /// The equipped id AFTER the unknown-id fallback: the stored value
  /// if it resolves to an owned title (or at least a known one — see
  /// [equippedKnown]), else null.
  String? get equippedId => _equippedId;

  /// Whether the stored equipped id was KNOWN but not owned (a title
  /// the catalog knows but the save has not earned — the fallback
  /// keeps the chip hidden without losing the setting).
  final bool equippedKnown;
  final String? _equippedId;

  /// The display l10n key for [equippedId], or null.
  String? get equippedL10nKey {
    final id = equippedId;
    if (id == null) return null;
    for (final t in achievementTitles) {
      if (t.id == id) return t.l10nKey;
    }
    for (final t in divisionTitles) {
      if (t.id == id) return t.l10nKey;
    }
    return null;
  }
}

/// Resolves the whole cabinet: both title families, their ownership
/// per the two-way rule, and the equipped id with its fallback.
TitleCabinet resolveTitleCabinet({
  required CareerMetrics metrics,
  required Set<String> claimedKeys,
  required String? storedEquippedId,
}) {
  // ---- Achievement titles: owned iff the source tier was CLAIMED --
  final achievementStates = <OwnedTitleState>[];
  for (final t in AchievementCatalog.achievementTitles) {
    // Registry id → its definition + tier rung: 'career_wins-title1'
    // is rung 3 of career_wins (title1 confers at tier index 3).
    final dash = t.id.lastIndexOf('-title');
    final defId = t.id.substring(0, dash);
    final titleNo = int.parse(t.id.substring(dash + '-title'.length));
    final definition = AchievementCatalog.byId(defId);

    String sourceKey = 'titleSourceAchievement';
    int sourceArg = 0;
    var owned = false;
    if (definition != null) {
      // The tier index that confers this title (3 → title1, 6 → 2).
      final tierIndex = titleNo == 1 ? 3 : 6;
      final tiers = definition.tiers(AchievementCatalog.economy);
      if (tierIndex <= tiers.length) {
        final tier = tiers[tierIndex - 1];
        sourceArg = tier.threshold;
        owned = claimedKeys.contains('${definition.id}:${tier.threshold}');
      }
    }
    achievementStates.add(
      OwnedTitleState(
        id: t.id,
        l10nKey: t.l10nKey,
        owned: owned,
        sourceL10nKey: sourceKey,
        sourceArg: sourceArg,
      ),
    );
  }

  // ---- Division titles: owned iff the metrics say CHAMPION -------
  // Seeded divisions 1..5 + any division the metrics actually won a
  // title in (the on-demand generation — the ladder is endless
  // upward).
  final divisions = <int>{...DivisionTitleDefinition.seededDivisions};
  metrics.titlesByDivision.forEach((div, _) => divisions.add(div));
  final divisionStates = <OwnedTitleState>[];
  for (final div in divisions.toList()..sort()) {
    final won = metrics.titlesByDivision[div] ?? 0;
    divisionStates.add(
      OwnedTitleState(
        id: 'division_champion_$div',
        l10nKey: 'achievementDivisionChampion',
        owned: won > 0,
        sourceL10nKey: 'titleSourceDivision',
        sourceArg: div,
      ),
    );
  }

  final ownedIds = {
    for (final t in achievementStates)
      if (t.owned) t.id,
    for (final t in divisionStates)
      if (t.owned) t.id,
  };

  // ---- The equipped fallback ---------------------------------------
  String? equipped;
  var equippedKnown = false;
  final stored = storedEquippedId;
  if (stored != null) {
    final known = achievementStates.any((t) => t.id == stored) ||
        divisionStates.any((t) => t.id == stored);
    if (known) {
      equippedKnown = true;
      // Worn only when owned (a known-but-unearned title never shows).
      if (ownedIds.contains(stored)) equipped = stored;
    }
    // Unknown ids: the documented graceful fallback — dropped for
    // display, never a crash, the setting itself left untouched.
  }

  return TitleCabinet(
    achievementTitles: achievementStates,
    divisionTitles: divisionStates,
    ownedIds: ownedIds,
    equippedKnown: equippedKnown,
    equippedId: equipped,
  );
}
