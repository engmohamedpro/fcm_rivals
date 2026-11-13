/// FCM Rivals — the Achievements hub screen, premium redesign (owner
/// request 2026-11-13: "total redesign — premium and animations").
///
/// THE REDESIGN (research-grounded — trophy.so's engagement guide +
/// EA FC Champions' tier-reward patterns):
///
/// * HERO BAND instead of a flat header: the Trophy Room's identity
///   crest on a gold laurel arc, the completion as a LARGE segmented
///   progress bar (5 metal segments — bronze → legend), the
///   claimable count as the LIVE call-to-action chip. Recognition
///   leads with PROGRESS ("4 of 62 claimed"), not the badge.
/// * CATEGORY CAROUSEL instead of 10 stacked sections: the player
///   sees every room at a glance (IA: recognition-before-browsing),
///   the active category highlighted, its claimable count badged.
/// * ACHIEVEMENT CARDS rebuilt: 56px badges on a metal-tinted stage
///   (each metal reads from across the room — the research's
///   "rarity signals"), tier rungs as a segmented ladder under the
///   progress bar, the claim affordance as a full-width pulsing
///   golden bar. Claimed cards keep their light on (dimmed 55%, the
///   badge still shines) — the trophy room honours its trophies.
/// * CLAIM CELEBRATION: an overlay burst — the badge scales in on a
///   shockwave ring, coins rain, the tier metal's rays sweep. One
///   moment, ~1.2s, then it dismisses itself; tapping skips it
///   (celebratory, never a roadblock).
/// * MOTION: staggered entrances per section (the kit's FcmEntrance),
///   180ms presses, the 650ms claim flip — nothing longer than the
///   user's patience. All curves easeOutCubic / easeOutBack.
///
/// The CONTRACTS stay (T-0108/T-0110 tests lock them): claimed state
/// reads from the claims table, geometric-honest bars, claim only on
/// eligible tiers, the zero-state, RTL mirrors.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/fcm_coin.dart';
import '../../core/ui/fcm_motion.dart' show FcmEntrance;
import '../../core/ui/fcm_panel.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_button.dart';
import '../../core/ui/scene_loading.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_context.dart';
import 'achievement_catalog.dart';
import 'achievement_catalog_data.dart';
import 'achievement_progress.dart' show CareerMetrics;
import 'achievements_badge_painter.dart';
import 'achievements_claim_celebration.dart';
import 'achievements_providers.dart';
import '../economy/streak_card.dart' show StreakCard;
import '../profile/title_badge_showcase.dart'
    show EquippedTitleChip;

/// The Achievements tab screen.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(careerMetricsProvider);
    final claims = ref.watch(claimsProvider);

    return metrics.when(
      loading: () => const SceneLoadingMarker(),
      error: (e, _) => Center(child: Text('$e')),
      data: (m) => claims.when(
        loading: () => const SceneLoadingMarker(),
        error: (e, _) => Center(child: Text('$e')),
        data: (claimed) => _TrophyRoom(metrics: m, claimedKeys: claimed),
      ),
    );
  }
}

/// The whole room: hero band, streak, one category's wall at a time.
class _TrophyRoom extends StatelessWidget {
  const _TrophyRoom({required this.metrics, required this.claimedKeys});

  final CareerMetrics metrics;
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          sliver: SliverToBoxAdapter(
            child: FcmEntrance(
              child: _HeroBand(metrics: metrics, claimedKeys: claimedKeys),
            ),
          ),
        ),
        // The daily rewards streak — the rewards hub's opening act:
        // the claim surface lives beside the claimable cards.
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(14, 6, 14, 0),
          sliver: SliverToBoxAdapter(
            child: RepaintBoundary(child: StreakCard()),
          ),
        ),
        // The category carousel: every room at a glance, the claim
        // counts live, the active wall below.
        _CategoryRooms(metrics: metrics, claimedKeys: claimedKeys),
        // Bottom breathing room above the nav bar.
        const SliverPadding(
          padding: EdgeInsets.only(bottom: 24),
          sliver: SliverToBoxAdapter(child: SizedBox(height: 8)),
        ),
      ],
    );
  }
}

// ---- l10n bridge --------------------------------------------------------
// The catalog carries key NAMES; AppLocalizations exposes getters. This
// static table bridges them — one line per key, no mirrors, no dynamic
// codegen. The catalog test's EN+AR completeness lock guarantees every
// key below exists as a generated getter in BOTH locales.

/// Invokes a no-arg getter by key name on the generated localization.
String? _call(AppLocalizations l10n, String key) {
  final m = _noArgGetters[key];
  return m == null ? null : m(l10n);
}

String _categoryText(AppLocalizations l10n, String prefix, String suffix) =>
    _call(l10n, '$prefix$suffix') ?? prefix;

String _defText(AppLocalizations l10n, String key) => _call(l10n, key) ?? key;

final Map<String, String Function(AppLocalizations)> _noArgGetters = () {
  final table = <String, String Function(AppLocalizations)>{};
  void add(String k, String Function(AppLocalizations) f) => table[k] = f;
  add('achCareerTitle', (l) => l.achCareerTitle);
  add('achCareerSubtitle', (l) => l.achCareerSubtitle);
  add('achAttackTitle', (l) => l.achAttackTitle);
  add('achAttackSubtitle', (l) => l.achAttackSubtitle);
  add('achDefenceTitle', (l) => l.achDefenceTitle);
  add('achDefenceSubtitle', (l) => l.achDefenceSubtitle);
  add('achSilverwareTitle', (l) => l.achSilverwareTitle);
  add('achSilverwareSubtitle', (l) => l.achSilverwareSubtitle);
  add('achSquadTitle', (l) => l.achSquadTitle);
  add('achSquadSubtitle', (l) => l.achSquadSubtitle);
  add('achPacksTitle', (l) => l.achPacksTitle);
  add('achPacksSubtitle', (l) => l.achPacksSubtitle);
  add('achEconomyTitle', (l) => l.achEconomyTitle);
  add('achEconomySubtitle', (l) => l.achEconomySubtitle);
  add('achCampusTitle', (l) => l.achCampusTitle);
  add('achCampusSubtitle', (l) => l.achCampusSubtitle);
  add('achLoyaltyTitle', (l) => l.achLoyaltyTitle);
  add('achLoyaltySubtitle', (l) => l.achLoyaltySubtitle);
  add('achMastermindTitle', (l) => l.achMastermindTitle);
  add('achMastermindSubtitle', (l) => l.achMastermindSubtitle);
  add('achAttackGoals', (l) => l.achAttackGoals);
  add('achAttackGoalsDesc', (l) => l.achAttackGoalsDesc);
  add('achAttackGoalsSingleMatch', (l) => l.achAttackGoalsSingleMatch);
  add('achAttackGoalsSingleMatchDesc', (l) => l.achAttackGoalsSingleMatchDesc);
  add('achCampusFacilityLevels', (l) => l.achCampusFacilityLevels);
  add('achCampusFacilityLevelsDesc', (l) => l.achCampusFacilityLevelsDesc);
  add('achCampusRecoveryLevel', (l) => l.achCampusRecoveryLevel);
  add('achCampusRecoveryLevelDesc', (l) => l.achCampusRecoveryLevelDesc);
  add('achCareerAwayMatches', (l) => l.achCareerAwayMatches);
  add('achCareerAwayMatchesDesc', (l) => l.achCareerAwayMatchesDesc);
  add('achCareerDraws', (l) => l.achCareerDraws);
  add('achCareerDrawsDesc', (l) => l.achCareerDrawsDesc);
  add('achCareerHomeMatches', (l) => l.achCareerHomeMatches);
  add('achCareerHomeMatchesDesc', (l) => l.achCareerHomeMatchesDesc);
  add('achCareerLosses', (l) => l.achCareerLosses);
  add('achCareerLossesDesc', (l) => l.achCareerLossesDesc);
  add('achCareerMatches', (l) => l.achCareerMatches);
  add('achCareerMatchesDesc', (l) => l.achCareerMatchesDesc);
  add('achCareerUnbeatenStreak', (l) => l.achCareerUnbeatenStreak);
  add('achCareerUnbeatenStreakDesc', (l) => l.achCareerUnbeatenStreakDesc);
  add('achCareerWinStreak', (l) => l.achCareerWinStreak);
  add('achCareerWinStreakDesc', (l) => l.achCareerWinStreakDesc);
  add('achCareerWins', (l) => l.achCareerWins);
  add('achCareerWinsDesc', (l) => l.achCareerWinsDesc);
  add('achDefenceCleanSheets', (l) => l.achDefenceCleanSheets);
  add('achDefenceCleanSheetsDesc', (l) => l.achDefenceCleanSheetsDesc);
  add('achDefenceGoalsAgainst', (l) => l.achDefenceGoalsAgainst);
  add('achDefenceGoalsAgainstDesc', (l) => l.achDefenceGoalsAgainstDesc);
  add('achDefenceScoredFirst', (l) => l.achDefenceScoredFirst);
  add('achDefenceScoredFirstDesc', (l) => l.achDefenceScoredFirstDesc);
  add('achDefenceShutoutStreak', (l) => l.achDefenceShutoutStreak);
  add('achDefenceShutoutStreakDesc', (l) => l.achDefenceShutoutStreakDesc);
  add('achEconomyLifetimeEarned', (l) => l.achEconomyLifetimeEarned);
  add('achEconomyLifetimeEarnedDesc', (l) => l.achEconomyLifetimeEarnedDesc);
  add('achEconomyPackSpend', (l) => l.achEconomyPackSpend);
  add('achEconomyPackSpendDesc', (l) => l.achEconomyPackSpendDesc);
  add('achEconomyPlayerSales', (l) => l.achEconomyPlayerSales);
  add('achEconomyPlayerSalesDesc', (l) => l.achEconomyPlayerSalesDesc);
  add('achEconomyUpgradeSpend', (l) => l.achEconomyUpgradeSpend);
  add('achEconomyUpgradeSpendDesc', (l) => l.achEconomyUpgradeSpendDesc);
  add('achLoyaltyRelegations', (l) => l.achLoyaltyRelegations);
  add('achLoyaltyRelegationsDesc', (l) => l.achLoyaltyRelegationsDesc);
  add('achLoyaltySeasons', (l) => l.achLoyaltySeasons);
  add('achLoyaltySeasonsDesc', (l) => l.achLoyaltySeasonsDesc);
  add('achMastermindTacticsChanged', (l) => l.achMastermindTacticsChanged);
  add('achMastermindTacticsChangedDesc',
      (l) => l.achMastermindTacticsChangedDesc);
  add('achMilestoneFirstEpic', (l) => l.achMilestoneFirstEpic);
  add('achMilestoneFirstEpicDesc', (l) => l.achMilestoneFirstEpicDesc);
  add('achMilestoneFirstFacilityMax', (l) => l.achMilestoneFirstFacilityMax);
  add('achMilestoneFirstFacilityMaxDesc',
      (l) => l.achMilestoneFirstFacilityMaxDesc);
  add('achMilestoneFirstLegendary', (l) => l.achMilestoneFirstLegendary);
  add('achMilestoneFirstLegendaryDesc', (l) => l.achMilestoneFirstLegendaryDesc);
  add('achMilestoneFirstLegendaryPull', (l) => l.achMilestoneFirstLegendaryPull);
  add('achMilestoneFirstLegendaryPullDesc',
      (l) => l.achMilestoneFirstLegendaryPullDesc);
  add('achMilestoneFirstMillion', (l) => l.achMilestoneFirstMillion);
  add('achMilestoneFirstMillionDesc', (l) => l.achMilestoneFirstMillionDesc);
  add('achMilestoneFirstSeason', (l) => l.achMilestoneFirstSeason);
  add('achMilestoneFirstSeasonDesc', (l) => l.achMilestoneFirstSeasonDesc);
  add('achMilestoneFirstTitle', (l) => l.achMilestoneFirstTitle);
  add('achMilestoneFirstTitleDesc', (l) => l.achMilestoneFirstTitleDesc);
  add('achMilestoneFirstWin', (l) => l.achMilestoneFirstWin);
  add('achMilestoneFirstWinDesc', (l) => l.achMilestoneFirstWinDesc);
  add('achPacksOpened', (l) => l.achPacksOpened);
  add('achPacksOpenedDesc', (l) => l.achPacksOpenedDesc);
  add('achPacksPurchased', (l) => l.achPacksPurchased);
  add('achPacksPurchasedDesc', (l) => l.achPacksPurchasedDesc);
  add('achPacksRewarded', (l) => l.achPacksRewarded);
  add('achPacksRewardedDesc', (l) => l.achPacksRewardedDesc);
  add('achPacksStartingPacks', (l) => l.achPacksStartingPacks);
  add('achPacksStartingPacksDesc', (l) => l.achPacksStartingPacksDesc);
  add('achSilverwarePromotions', (l) => l.achSilverwarePromotions);
  add('achSilverwarePromotionsDesc', (l) => l.achSilverwarePromotionsDesc);
  add('achSilverwareTitles', (l) => l.achSilverwareTitles);
  add('achSilverwareTitlesDesc', (l) => l.achSilverwareTitlesDesc);
  add('achSquadCardsOwned', (l) => l.achSquadCardsOwned);
  add('achSquadCardsOwnedDesc', (l) => l.achSquadCardsOwnedDesc);
  add('achSquadEpics', (l) => l.achSquadEpics);
  add('achSquadEpicsDesc', (l) => l.achSquadEpicsDesc);
  add('achSquadHighestUpgrade', (l) => l.achSquadHighestUpgrade);
  add('achSquadHighestUpgradeDesc', (l) => l.achSquadHighestUpgradeDesc);
  add('achSquadLegendaries', (l) => l.achSquadLegendaries);
  add('achSquadLegendariesDesc', (l) => l.achSquadLegendariesDesc);
  add('achSquadUpgrades', (l) => l.achSquadUpgrades);
  add('achSquadUpgradesDesc', (l) => l.achSquadUpgradesDesc);
  add('achTitleCareerWins1', (l) => l.achTitleCareerWins1);
  add('achTitleCareerWins2', (l) => l.achTitleCareerWins2);
  add('achTitleCleanSheets1', (l) => l.achTitleCleanSheets1);
  add('achTitleCleanSheets2', (l) => l.achTitleCleanSheets2);
  add('achTitleCoins1', (l) => l.achTitleCoins1);
  add('achTitleCoins2', (l) => l.achTitleCoins2);
  add('achTitleGoals1', (l) => l.achTitleGoals1);
  add('achTitleGoals2', (l) => l.achTitleGoals2);
  add('achTitleLegendaries1', (l) => l.achTitleLegendaries1);
  add('achTitleLegendaries2', (l) => l.achTitleLegendaries2);
  add('achTitleMastermind1', (l) => l.achTitleMastermind1);
  add('achTitleMastermind2', (l) => l.achTitleMastermind2);
  add('achTitlePacks1', (l) => l.achTitlePacks1);
  add('achTitlePacks2', (l) => l.achTitlePacks2);
  add('achTitleSeasons1', (l) => l.achTitleSeasons1);
  add('achTitleSeasons2', (l) => l.achTitleSeasons2);
  add('achTitleTitles1', (l) => l.achTitleTitles1);
  add('achTitleTitles2', (l) => l.achTitleTitles2);
  add('achTitleUnbeaten1', (l) => l.achTitleUnbeaten1);
  add('achTitleUnbeaten2', (l) => l.achTitleUnbeaten2);
  return table;
}();

/// The Trophy Room's hero: the identity crest on its laurel arc, the
/// progress-first summary line, and the completion as a LARGE
/// five-segment metal bar (each segment = one metal band's share of
/// claimed rungs). Recognition leads with progress, not the badge.
class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.metrics, required this.claimedKeys});

  final CareerMetrics metrics;
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final claimed = _claimedCount();
    final total = _visibleTierCount();

    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LaurelCrest(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.achHubTitle,
                      style: const TextStyle(
                        color: FcmColors.goldSoft,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        letterSpacing: 0.4,
                      ),
                    ),
                    // T-0112: the shared equipped-title chip — live on
                    // equip, domain-resolved (unknown ids never render).
                    const EquippedTitleChip(compact: true),
                    const SizedBox(height: 2),
                    Text(
                      l10n.achHubSubtitle(claimed, total),
                      style: const TextStyle(
                        color: FcmColors.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // The big number: completion percent, gold, confident.
              Text(
                '${(total == 0 ? 0 : (claimed / total) * 100).round()}%',
                style: const TextStyle(
                  color: FcmColors.gold,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetalSegmentBar(
            claimed: claimed,
            total: total,
            claimedKeys: claimedKeys,
          ),
        ],
      ),
    );
  }

  int _claimedCount() {
    var n = 0;
    for (final d in AchievementCatalog.definitions) {
      for (final tier
          in AchievementCatalog.tiersOf(d, AchievementCatalog.economy)) {
        if (claimedKeys.contains('${d.id}:${tier.threshold}')) n++;
      }
    }
    return n;
  }

  int _visibleTierCount() {
    var n = 0;
    for (final d in AchievementCatalog.definitions) {
      n += AchievementCatalog.tiersOf(d, AchievementCatalog.economy).length;
    }
    return n;
  }
}

/// The crest on its laurel arc: a gold disc, the trophy emblem, and
/// two laurel branches hand-painted behind it — the trophy room's
/// identity mark, no stock icon.
class _LaurelCrest extends StatelessWidget {
  const _LaurelCrest();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(painter: _LaurelCrestPainter()),
    );
  }
}

class _LaurelCrestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // The halo disc.
    final disc = Paint()
      ..shader = FcmColors.goldGradient.createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.34),
      );
    canvas.drawCircle(Offset(cx, cy), w * 0.34, disc);
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = FcmColors.goldSoft.withValues(alpha: 0.7),
    );

    // The laurel branches: two mirrored arcs of leaves flanking the
    // disc — each leaf a pointed ellipse along the arc.
    for (final side in [-1.0, 1.0]) {
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.028)
        ..strokeCap = StrokeCap.round
        ..color = FcmColors.bronze.withValues(alpha: 0.9);
      final branch = Path()
        ..moveTo(cx + side * w * 0.14, cy + h * 0.30)
        ..quadraticBezierTo(
          cx + side * w * 0.42,
          cy + h * 0.10,
          cx + side * w * 0.34,
          cy - h * 0.26,
        );
      canvas.drawPath(branch, arc);
      // Leaves along the branch's outer side.
      for (var i = 0; i < 5; i++) {
        final t = 0.18 + i * 0.17;
        // Quadratic interpolation of the branch curve.
        final p0 = Offset(cx + side * w * 0.14, cy + h * 0.30);
        final p1 = Offset(cx + side * w * 0.42, cy + h * 0.10);
        final p2 = Offset(cx + side * w * 0.34, cy - h * 0.26);
        final px = (1 - t) * (1 - t) * p0.dx +
            2 * (1 - t) * t * p1.dx +
            t * t * p2.dx;
        final py = (1 - t) * (1 - t) * p0.dy +
            2 * (1 - t) * t * p1.dy +
            t * t * p2.dy;
        final angle = side * (0.9 - t * 1.1);
        final leaf = Path()
          ..moveTo(px, py)
          ..quadraticBezierTo(
            px + side * w * 0.075 * math.cos(angle),
            py - h * 0.055 + h * 0.02 * math.sin(angle),
            px + side * w * 0.105,
            py - h * 0.052,
          )
          ..quadraticBezierTo(
            px + side * w * 0.05 * math.cos(angle),
            py - h * 0.01,
            px,
            py,
          )
          ..close();
        canvas.drawPath(
          leaf,
          Paint()..color = FcmColors.gold.withValues(alpha: 0.55 + 0.09 * i),
        );
      }
    }

    // The trophy emblem, drawn over the disc in ink.
    final ink = Paint()
      ..color = FcmColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.030)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Cup bowl.
    final bowl = Path()
      ..moveTo(cx - w * 0.13, cy - h * 0.16)
      ..lineTo(cx + w * 0.13, cy - h * 0.16)
      ..quadraticBezierTo(
        cx + w * 0.12,
        cy + h * 0.08,
        cx,
        cy + h * 0.10,
      )
      ..quadraticBezierTo(
        cx - w * 0.12,
        cy + h * 0.08,
        cx - w * 0.13,
        cy - h * 0.16,
      )
      ..close();
    canvas.drawPath(bowl, ink);
    // Handles.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - w * 0.19, cy - h * 0.07),
        width: w * 0.13,
        height: h * 0.13,
      ),
      -math.pi / 2,
      math.pi,
      false,
      ink,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx + w * 0.19, cy - h * 0.07),
        width: w * 0.13,
        height: h * 0.13,
      ),
      math.pi / 2,
      math.pi,
      false,
      ink,
    );
    // Stem + base.
    canvas.drawLine(
      Offset(cx, cy + h * 0.10),
      Offset(cx, cy + h * 0.18),
      ink,
    );
    canvas.drawLine(
      Offset(cx - w * 0.10, cy + h * 0.20),
      Offset(cx + w * 0.10, cy + h * 0.20),
      ink,
    );
  }

  @override
  bool shouldRepaint(_LaurelCrestPainter old) => false;
}

/// The completion bar: five metal-tinted segments (bronze → legend),
/// filled proportionally to that metal band's claimed rungs. Reads
/// "where on the wall my trophies cluster" at a glance.
class _MetalSegmentBar extends StatelessWidget {
  const _MetalSegmentBar({
    required this.claimed,
    required this.total,
    required this.claimedKeys,
  });

  final int claimed;
  final int total;
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context) {
    // The five bands' claimed/total, in metal order.
    final bands = <({BadgeMetal metal, int claimed, int total})>[];
    for (final metal in BadgeMetal.values) {
      var c = 0;
      var t = 0;
      for (final d in AchievementCatalog.definitions) {
        for (final tier
            in AchievementCatalog.tiersOf(d, AchievementCatalog.economy)) {
          if (tier.badgeMetal != metal) continue;
          t++;
          if (claimedKeys.contains('${d.id}:${tier.threshold}')) c++;
        }
      }
      bands.add((metal: metal, claimed: c, total: t));
    }
    return Row(
      children: [
        for (var i = 0; i < bands.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            flex: bands[i].total,
            child: _MetalSegment(
              metal: bands[i].metal,
              claimed: bands[i].claimed,
              total: bands[i].total,
            ),
          ),
        ],
      ],
    );
  }
}

/// One metal band's segment: the fill ratio is the band's own claimed
/// share, tinted with the metal's hue.
class _MetalSegment extends StatelessWidget {
  const _MetalSegment({
    required this.metal,
    required this.claimed,
    required this.total,
  });

  final BadgeMetal metal;
  final int claimed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : (claimed / total).clamp(0.0, 1.0);
    final tint = _metalTint(metal);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Container(color: FcmColors.ember.withValues(alpha: 0.7)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [tint, tint.withValues(alpha: 0.75)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _metalTint(BadgeMetal metal) => switch (metal) {
      BadgeMetal.bronze => const Color(0xFFB08D5C),
      BadgeMetal.silver => FcmColors.silver,
      BadgeMetal.gold => FcmColors.gold,
      BadgeMetal.platinum => const Color(0xFFDCE6EE),
      BadgeMetal.legend => FcmColors.goldSoft,
    };

// ---- the category carousel ------------------------------------------------

/// The horizontally scrolling room picker: one chip per category —
/// icon, localized name, and a live claimable-count badge. The
/// ACTIVE room is highlighted gold; the wall below renders it. This
/// replaces ten stacked sections with a glanceable strip (IA:
/// recognition-before-browsing — the player sees where prizes wait
/// without scrolling the whole catalog).
class _CategoryCarousel extends StatelessWidget {
  const _CategoryCarousel({
    required this.metrics,
    required this.claimedKeys,
    required this.active,
    required this.onPick,
  });

  final CareerMetrics metrics;
  final Set<String> claimedKeys;
  final String active;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AchievementCatalog.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final category = AchievementCatalog.categories[i];
          final isActive = category.id == active;
          final claimable = _claimableCount(category);
          return _CategoryChip(
            icon: _categoryIcon(category.iconName),
            label: _categoryText(l10n, category.l10nPrefix, 'Title'),
            active: isActive,
            claimable: claimable,
            onTap: () => onPick(category.id),
          );
        },
      ),
    );
  }

  int _claimableCount(AchievementCategory category) {
    var n = 0;
    for (final d in AchievementCatalog.definitions
        .where((d) => d.category == category.id)) {
      final progress = metrics.progressFor(d.metricId) ?? 0;
      for (final tier
          in AchievementCatalog.tiersOf(d, AchievementCatalog.economy)) {
        if (claimedKeys.contains('${d.id}:${tier.threshold}')) continue;
        if (progress >= tier.threshold) n++;
        break; // only the rung being climbed counts
      }
    }
    return n;
  }
}

/// One room chip: icon + name, the active one gold-filled, a red-dot
/// count badge when prizes wait.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.claimable,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int claimable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          gradient: active ? FcmColors.goldGradient : null,
          color: active ? null : FcmColors.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active
                ? FcmColors.goldSoft.withValues(alpha: 0.8)
                : FcmColors.bronze.withValues(alpha: 0.30),
          ),
          boxShadow: [
            if (active)
              BoxShadow(
                color: FcmColors.gold.withValues(alpha: 0.30),
                blurRadius: 12,
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? FcmColors.ink : FcmColors.gold,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? FcmColors.ink : FcmColors.silver,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            if (claimable > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? FcmColors.ink
                      : FcmColors.danger.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '$claimable',
                  style: TextStyle(
                    color: active ? FcmColors.goldSoft : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rooms + the wall: the carousel and the active room's list in
/// ONE stateful sliver group — a single source of truth for the
/// active room (the carousel writes it, the wall reads it).
class _CategoryRooms extends StatefulWidget {
  const _CategoryRooms({
    required this.metrics,
    required this.claimedKeys,
  });

  final CareerMetrics metrics;
  final Set<String> claimedKeys;

  @override
  State<_CategoryRooms> createState() => _CategoryRoomsState();
}

class _CategoryRoomsState extends State<_CategoryRooms> {
  String _active = AchievementCatalog.categories.first.id;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
          sliver: SliverToBoxAdapter(
            child: _CategoryCarousel(
              metrics: widget.metrics,
              claimedKeys: widget.claimedKeys,
              active: _active,
              onPick: (id) => setState(() => _active = id),
            ),
          ),
        ),
        _ActiveCategoryWall(
          key: ValueKey('wall-$_active'),
          metrics: widget.metrics,
          claimedKeys: widget.claimedKeys,
          categoryId: _active,
        ),
      ],
    );
  }
}

/// The active room's wall: its heading + its achievement cards with
/// staggered entrances. Rebuilds when the carousel picks a new room.
class _ActiveCategoryWall extends StatelessWidget {
  const _ActiveCategoryWall({
    super.key,
    required this.metrics,
    required this.claimedKeys,
    required this.categoryId,
  });

  final CareerMetrics metrics;
  final Set<String> claimedKeys;
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    final category = AchievementCatalog.categories
        .firstWhere((c) => c.id == categoryId);
    final defs = AchievementCatalog.definitions
        .where((d) => d.category == category.id)
        .toList();

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: FcmColors.steelGradient,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: FcmColors.bronze.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    _categoryIcon(category.iconName),
                    color: FcmColors.gold,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _categoryText(l10n, category.l10nPrefix, 'Title'),
                    style: const TextStyle(
                      color: FcmColors.goldSoft,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  _categoryText(l10n, category.l10nPrefix, 'Subtitle'),
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                // THE hot-path isolation: every tier row repaints in
                // its own layer; the ambient animation touches one
                // row, not the section.
                child: RepaintBoundary(
                  child: FcmEntrance(
                    index: i,
                    maxStaggered: 6,
                    child: _AchievementCard(
                      definition: defs[i],
                      metrics: metrics,
                      claimedKeys: claimedKeys,
                    ),
                  ),
                ),
              ),
              childCount: defs.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ---- the achievement card ------------------------------------------------

/// One achievement, rebuilt premium: the badge on its metal-tinted
/// stage (56px, lit), name + description, the honest geometric
/// progress bar with its rung ladder beneath (each claimed rung a lit
/// pip), and the right column's reward + claim. Claimed cards dim to
/// 55% but keep their light on — the room honours its trophies.
class _AchievementCard extends ConsumerWidget {
  const _AchievementCard({
    required this.definition,
    required this.metrics,
    required this.claimedKeys,
  });

  final AchievementDefinition definition;
  final CareerMetrics metrics;
  final Set<String> claimedKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = l10nOf(context);
    final progress = metrics.progressFor(definition.metricId) ?? 0;
    final tiers = AchievementCatalog.tiersOf(
      definition,
      AchievementCatalog.economy,
    );

    // The rung the player is climbing: the first unclaimed tier
    // (eligible → claimable), else the ladder's last visible rung.
    var tier = tiers.last;
    for (final t in tiers) {
      if (claimedKeys.contains('${definition.id}:${t.threshold}')) {
        continue;
      }
      tier = t;
      break;
    }
    final claimedRungs = tiers
        .where(
          (t) => claimedKeys.contains('${definition.id}:${t.threshold}'),
        )
        .length;
    final allClaimed = claimedRungs == tiers.length;
    final claimed = claimedKeys.contains(
      '${definition.id}:${tier.threshold}',
    );
    final eligible = progress >= tier.threshold && !claimed;

    return Opacity(
      opacity: allClaimed ? 0.55 : 1.0,
      child: FcmPanel(
        accent: eligible
            ? FcmColors.gold
            : (allClaimed ? FcmColors.bronze : null),
        glow: eligible,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BadgeStage(metal: tier.badgeMetal, lit: !allClaimed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _defText(l10n, definition.titleKey),
                          style: const TextStyle(
                            color: FcmColors.goldSoft,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (claimedRungs > 0)
                        _RungsBadge(count: claimedRungs, total: tiers.length),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _defText(l10n, definition.descriptionKey),
                    style: const TextStyle(
                      color: FcmColors.textDim,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  _ProgressLadder(
                    value: progress,
                    threshold: tier.threshold,
                    tiers: tiers,
                    claimedKeys: claimedKeys,
                    definitionId: definition.id,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ClaimColumn(
              tier: tier,
              claimed: claimed,
              eligible: eligible,
              definition: definition,
              progress: progress,
            ),
          ],
        ),
      ),
    );
  }
}

/// The badge's stage: a 56px hexagonal-soft plate tinted with the
/// metal, the badge painted over it, and — when the rung is
/// ELIGIBLE — a slow breathing glow. The metal reads from across
/// the room (rarity signalling, the research's finding).
class _BadgeStage extends StatefulWidget {
  const _BadgeStage({required this.metal, required this.lit});

  final BadgeMetal metal;
  final bool lit;

  @override
  State<_BadgeStage> createState() => _BadgeStageState();
}

class _BadgeStageState extends State<_BadgeStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = _metalTint(widget.metal);
    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, _) {
        final glow = widget.lit ? 0.10 + 0.14 * _breathe.value : 0.0;
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tint.withValues(alpha: 0.16),
                FcmColors.surfaceHigh,
              ],
            ),
            border: Border.all(color: tint.withValues(alpha: 0.45)),
            boxShadow: [
              if (glow > 0)
                BoxShadow(
                  color: tint.withValues(alpha: glow),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
            ],
          ),
          alignment: Alignment.center,
          child: SizedBox(
            width: 46,
            height: 46,
            child: CustomPaint(
              painter: FcmBadgePainter(
                metal: widget.metal,
                phase: 0.5 + 0.5 * _breathe.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The claimed-rungs pill: "3/6" with a tick — the card's banked
/// history at a glance.
class _RungsBadge extends StatelessWidget {
  const _RungsBadge({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: FcmColors.success.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: FcmColors.success,
            size: 10,
          ),
          const SizedBox(width: 3),
          Text(
            l10n.achClaimedRungs(count),
            style: const TextStyle(
              color: FcmColors.success,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// The honest geometric bar + rung ladder: the fill is `value /
/// threshold` capped at 1.0, the "9 / 16" readout beside it, and the
/// rungs beneath — each claimed rung a lit pip in its metal, the
/// climbing rung a hollow ring, future rungs faint ticks.
class _ProgressLadder extends StatelessWidget {
  const _ProgressLadder({
    required this.value,
    required this.threshold,
    required this.tiers,
    required this.claimedKeys,
    required this.definitionId,
  });

  final int value;
  final int threshold;
  final List<AchievementTier> tiers;
  final Set<String> claimedKeys;
  final String definitionId;

  @override
  Widget build(BuildContext context) {
    final ratio = threshold == 0 ? 0.0 : (value / threshold).clamp(0.0, 1.0);
    final complete = value >= threshold;
    // Cap the visible rungs at 7 — the ladder's first four + last
    // three keep the row readable on the widest ladders.
    final shown = tiers.length <= 7
        ? tiers
        : [...tiers.take(4), ...tiers.skip(tiers.length - 3)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 7,
                  child: Stack(
                    children: [
                      Container(
                        color: FcmColors.ember.withValues(alpha: 0.8),
                      ),
                      FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: complete
                                  ? const [
                                      FcmColors.success,
                                      Color(0xFF54845F),
                                    ]
                                  : const [
                                      FcmColors.goldSoft,
                                      FcmColors.gold,
                                    ],
                            ),
                          ),
                        ),
                      ),
                      // The eligible shine: a sweeping highlight over
                      // a complete bar — the "prize waiting" signal.
                      if (complete)
                        const _ShineSweep(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value / $threshold',
              style: TextStyle(
                color: complete ? FcmColors.success : FcmColors.textDim,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0)
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: FcmColors.ember,
                    ),
                  ),
                ),
              _RungPip(
                tier: shown[i],
                claimed: claimedKeys.contains(
                  '$definitionId:${shown[i].threshold}',
                ),
                climbing: shown[i].threshold == threshold,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The endless-loop shine sweep across an eligible bar — a narrow
/// gradient band drifting left→right every 1.8s. Painted, not
/// animated-by-rebuild: one ShaderMask over a static gradient.
class _ShineSweep extends StatefulWidget {
  const _ShineSweep();

  @override
  State<_ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<_ShineSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final band = c.maxWidth * 0.35;
        return AnimatedBuilder(
          animation: _sweep,
          builder: (context, _) {
            final x = -band + (c.maxWidth + band * 2) * _sweep.value;
            return Stack(
              children: [
                Positioned(
                  left: x,
                  top: 0,
                  bottom: 0,
                  width: band,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.30),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// One rung pip: lit in its metal when claimed, a gold hollow ring
/// when it is the rung being climbed, a faint tick otherwise.
class _RungPip extends StatelessWidget {
  const _RungPip({
    required this.tier,
    required this.claimed,
    required this.climbing,
  });

  final AchievementTier tier;
  final bool claimed;
  final bool climbing;

  @override
  Widget build(BuildContext context) {
    final tint = _metalTint(tier.badgeMetal);
    final size = climbing ? 11.0 : 8.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: claimed
            ? LinearGradient(colors: [tint, tint.withValues(alpha: 0.7)])
            : null,
        color: claimed ? null : FcmColors.ember,
        border: Border.all(
          color: climbing
              ? FcmColors.gold
              : (claimed ? tint.withValues(alpha: 0.6) : FcmColors.bronze.withValues(alpha: 0.35)),
          width: climbing ? 1.6 : 1,
        ),
        boxShadow: [
          if (climbing)
            BoxShadow(
              color: FcmColors.gold.withValues(alpha: 0.35),
              blurRadius: 5,
            ),
        ],
      ),
    );
  }
}

/// The right column: reward chip + claim / claimed / locked states.
/// The CLAIM now fires the celebration overlay first (badge burst +
/// coins rain), then the pipeline — the moment is the reward.
class _ClaimColumn extends ConsumerStatefulWidget {
  const _ClaimColumn({
    required this.tier,
    required this.claimed,
    required this.eligible,
    required this.definition,
    required this.progress,
  });

  final AchievementTier tier;
  final bool claimed;
  final bool eligible;
  final AchievementDefinition definition;
  final int progress;

  @override
  ConsumerState<_ClaimColumn> createState() => _ClaimColumnState();
}

class _ClaimColumnState extends ConsumerState<_ClaimColumn> {
  bool _justClaimed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    if (widget.claimed || _justClaimed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: FcmColors.success,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.achClaimedLabel,
            style: const TextStyle(
              color: FcmColors.success,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
    }
    if (!widget.eligible) {
      return FcmCoinChip(coins: widget.tier.coinReward);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FcmCoinChip(coins: widget.tier.coinReward),
        const SizedBox(height: 6),
        FcmButton(
          label: l10n.achClaimAction,
          compact: true,
          onPressed: () async {
            setState(() => _justClaimed = true);
            // The celebration FIRST — the burst marks the moment
            // while the atomic pipeline lands beneath it.
            unawaited(
              showAchievementClaimCelebration(
                context,
                metal: widget.tier.badgeMetal,
                title: _defText(l10nOf(context), widget.definition.titleKey),
                coins: widget.tier.coinReward,
              ),
            );
            await ref.read(
              claimTierProvider(
                ClaimArgs(
                  widget.definition.id,
                  widget.tier.threshold.toString(),
                ),
              ).future,
            );
            refreshAchievements(ref);
          },
        ),
      ],
    );
  }
}

/// Fire-and-forget helper (the celebration outlives this frame).
void unawaited(Future<void> f) {
  f.catchError((_) {});
}

/// Category icon mapping (catalog icon names → IconData).
IconData _categoryIcon(String iconName) => switch (iconName) {
      'whistle' => Icons.sports_rounded,
      'goal' => Icons.sports_soccer_rounded,
      'shield' => Icons.shield_rounded,
      'trophy' => Icons.emoji_events_rounded,
      'cards' => Icons.style_rounded,
      'pack' => Icons.inventory_2_rounded,
      'coins' => Icons.paid_rounded,
      'campus' => Icons.apartment_rounded,
      'heart' => Icons.favorite_rounded,
      'brain' => Icons.psychology_rounded,
      _ => Icons.military_tech_rounded,
    };
