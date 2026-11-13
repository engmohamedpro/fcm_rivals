/// FCM Rivals — the Campus tab (GDD 3.5, 2026-11-13 redesign): the
/// club's long-term upgrade project.
///
/// The redesign's structure:
///
///  * THE CAMPUS BANNER — one glance panel: the club's total
///    facility levels (n/60) as a gold progress arc with the
///    aggregate team boost beneath — the answer to "is my campus
///    good?" before any card is read.
///  * SIX BUILDING CARDS, grouped visually — the three TRAINING
///    buildings (match-live boosts) then the two WELFARE buildings
///    plus a subtle divider; each card keeps the compact contract:
///    icon, title, ten level pips with the live LV, ONE effect line
///    (current → gold next value) and the price button (or MAX).
///  * AFFORDABILITY SIGNALLING — a card you can buy now breathes
///    (gold glow); one you cannot shows the steel pill. The eye
///    lands on the next purchase without reading prices.
///
/// The text diet stays (T-0088 contracts locked): no invested
/// totals, no "not built yet" filler — the level-1 effect speaks
/// for an unbuilt facility and the escalating price button shows
/// the curve.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../l10n/l10n_context.dart';
import '../facilities/facilities.dart';
import '../facilities/facility_icons.dart';

class CampusScreen extends ConsumerStatefulWidget {
  const CampusScreen({super.key});

  @override
  ConsumerState<CampusScreen> createState() => _CampusScreenState();
}

class _CampusScreenState extends ConsumerState<CampusScreen> {
  /// Facility currently being upgraded (its card shows a spinner).
  Facility? _busy;

  Future<void> _upgrade(Facility facility) async {
    if (_busy != null) return;
    fcmTick();
    setState(() => _busy = facility);
    try {
      final store = await ref.read(collectionStoreProvider.future);
      await store.upgradeFacility(facility);
      ref.invalidate(campusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'.replaceFirst('CollectionException: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = ref.watch(clubProvider).valueOrNull;
    final campus = ref.watch(campusProvider).valueOrNull ?? CampusLevels.empty;
    final costs = defaultFacilitiesCosts;
    final coins = club?.coins ?? 0;

    return ListView(
      // Uniform gutters: the same 16 on every side and between cards.
      padding: const EdgeInsets.all(16),
      children: [
        // THE CAMPUS BANNER: the aggregate story first — total
        // levels, the arc, and the live team boost.
        _CampusBanner(campus: campus),
        const SizedBox(height: 16),
        for (var i = 0; i < Facility.values.length; i++)
          FcmEntrance(
            index: i,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: i == Facility.values.length - 1 ? 0 : 12,
              ),
              child: FacilityCard(
                facility: Facility.values[i],
                level: campus.levelOf(Facility.values[i]),
                coins: coins,
                costs: costs,
                busy: _busy == Facility.values[i],
                onUpgrade: () => _upgrade(Facility.values[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// The aggregate panel: "n of 60 levels" with a gold arc, the
/// summed team boost beneath. A fresh club reads 0/60 honestly.
class _CampusBanner extends StatelessWidget {
  const _CampusBanner({required this.campus});

  final CampusLevels campus;

  @override
  Widget build(BuildContext context) {
    final l10n = l10nOf(context);
    var total = 0;
    for (final f in Facility.values) {
      total += campus.levelOf(f);
    }
    final maxTotal = Facility.values.length * defaultFacilitiesCosts.maxLevel;
    final fractions = campus.attributeFractions;
    // The summed training boost in percentage points (0.9% × 3
    // buildings × levels): the one number that says "team value".
    final teamBoost =
        ((fractions.attack + fractions.support + fractions.defence +
                fractions.goalkeeping) *
            100);
    final boostLabel = teamBoost == 0
        ? null
        : '+${teamBoost.toStringAsFixed(teamBoost.truncateToDouble() == teamBoost ? 0 : 1)}%';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FcmColors.surfaceHigh,
            FcmColors.night.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: FcmColors.gold.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: FcmColors.gold.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // The arc: total levels / max, gold sweep on a dark track.
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: maxTotal == 0 ? 0 : total / maxTotal,
                  strokeWidth: 5,
                  strokeCap: StrokeCap.round,
                  color: FcmColors.gold,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        height: 1,
                      ),
                    ),
                    Text(
                      '/$maxTotal',
                      style: const TextStyle(
                        color: FcmColors.textDim,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.campusBannerTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.campusBannerSubtitle,
                  style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // The live team boost chip: the campus's payoff in
                // one glanceable pill.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: FcmColors.gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: FcmColors.gold.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: FcmColors.gold,
                        size: 13,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        boostLabel == null
                            ? l10n.campusNoBoosts
                            : l10n.campusTeamBoost(boostLabel),
                        style: const TextStyle(
                          color: FcmColors.goldSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One building: icon and title with the ten level pips and the live LV
/// number; below, the single effect line — current effect plus the gold
/// next-level value — with the upgrade button (or MAX pill). A level-0
/// facility shows the effect its first level buys, dimmed. An
/// AFFORDABLE upgrade breathes a soft gold glow (the next purchase
/// finds the eye).
class FacilityCard extends StatefulWidget {
  const FacilityCard({
    super.key,
    required this.facility,
    required this.level,
    required this.coins,
    required this.costs,
    required this.busy,
    required this.onUpgrade,
  });

  final Facility facility;
  final int level;
  final int coins;
  final FacilitiesCosts costs;
  final bool busy;
  final VoidCallback onUpgrade;

  @override
  State<FacilityCard> createState() => _FacilityCardState();
}

class _FacilityCardState extends State<FacilityCard>
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
    final maxed = widget.level >= widget.costs.maxLevel;
    final price = widget.costs.upgradeCost(widget.level);
    final affordable = widget.coins >= price;
    final built = widget.level > 0;
    // The affordability glow: only a BUYABLE, un-maxed building
    // breathes — scarcity of motion means "act here".
    final lit = !maxed && affordable && !widget.busy;

    return AnimatedBuilder(
      animation: lit ? _breathe : const AlwaysStoppedAnimation(0.0),
      builder: (context, _) {
        final glow = lit ? 0.08 + 0.10 * _breathe.value : 0.0;
        return FcmPanel(
          accent: lit ? FcmColors.gold : null,
          glow: lit,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: DecoratedBox(
            // The breathing halo sits BEHIND the card content —
            // a soft gold wash, never a hard border flash.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: glow > 0
                  ? [
                      BoxShadow(
                        color: FcmColors.gold.withValues(alpha: glow),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: _cardContent(context, built, maxed, price, affordable),
          ),
        );
      },
    );
  }

  Widget _cardContent(
    BuildContext context,
    bool built,
    bool maxed,
    int price,
    bool affordable,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FcmIconBadge(icon: widget.facility.icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.facility.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Level pips: one segment per level of ten.
                  Row(
                    children: [
                      for (var i = 0; i < widget.costs.maxLevel; i++)
                        Expanded(
                          child: Container(
                            height: 4,
                            margin: const EdgeInsetsDirectional.only(end: 3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient:
                                  i < widget.level ? FcmColors.goldGradient : null,
                              color: i < widget.level
                                  ? null
                                  : Colors.white.withValues(alpha: 0.10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'LV ${widget.level}',
              style: const TextStyle(
                color: FcmColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    built
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 14,
                    color: built ? FcmColors.success : FcmColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      widget.facility.effect
                          .describeAt(built ? widget.level : 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: built ? Colors.white : FcmColors.textDim,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (built && !maxed) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 12,
                      color: FcmColors.gold.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.facility.effect.shortValueAt(widget.level + 1),
                      style: const TextStyle(
                        color: FcmColors.gold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (maxed)
              const FcmPill('MAX')
            else ...[
              const SizedBox(width: 8),
              // T-0088: the upgrade control is pill-sized — the SAME
              // height as the MAX pill (no row jump when the level
              // tops out). The hit area carries the touch padding so
              // the ~24px visual stays comfortably tappable (>= 40px
              // tall); the visual box never grows.
              _UpgradePill(
                price: price,
                affordable: affordable,
                busy: widget.busy,
                onPressed: widget.onUpgrade,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// T-0088: the facility upgrade control — a pill the exact height of
/// `FcmPill('MAX')` (same radius/fill family, gold when affordable,
/// steel when not) carrying the coin glyph + compact price. The busy
/// spinner replaces the glyph while the upgrade runs. Pressability
/// wraps the pill with generous hit padding: the visual box stays
/// pill-sized, the tappable area is >= 40px tall.
class _UpgradePill extends StatelessWidget {
  const _UpgradePill({
    required this.price,
    required this.affordable,
    required this.busy,
    required this.onPressed,
  });

  final int price;
  final bool affordable;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = affordable ? FcmColors.gold : FcmColors.silver;
    return FcmPressable(
      onTap: busy ? null : onPressed,
      child: Padding(
        // The hit padding — OUTSIDE the visual pill.
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: AnimatedOpacity(
          opacity: busy ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            // The visual box: pill-family fill, radius and type scale.
            // Keyed for the T-0088 size test.
            key: const ValueKey('upgrade-pill-visual'),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FcmColors.goldSoft,
                    ),
                  )
                else ...[
                  const _MiniCoin(),
                  const SizedBox(width: 5),
                  Text(
                    FcmCoinChip.compact(price),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The coin glyph at pill scale — the same glowing disc the HUD chip
/// shows, shrunk to fit the 24px-tall control.
class _MiniCoin extends StatelessWidget {
  const _MiniCoin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: FcmColors.goldGradient,
        boxShadow: [
          BoxShadow(color: Color(0x73F7C948), blurRadius: 6),
        ],
      ),
      child: const Icon(Icons.star_rounded, size: 8, color: Colors.white),
    );
  }
}
