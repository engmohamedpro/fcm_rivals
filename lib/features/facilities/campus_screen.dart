/// FCM Rivals — the Campus tab (GDD 3.5): the club's long-term
/// upgrade project.
///
/// Six buildings, ten levels each, geometrically escalating prices: the
/// manager invests match rewards across seasons for small permanent
/// boosts. One [FacilityCard] per building: icon, title, the ten level
/// pips and the live LV number on top; below, ONE line — the current
/// effect with a small gold "→ next value" delta — and the price button
/// (or a MAX pill at level ten). No invested totals, no "not built yet"
/// filler: the level-1 effect speaks for an unbuilt facility, and the
/// escalating price button already shows the curve.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
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
        for (var i = 0; i < Facility.values.length; i++)
          FcmEntrance(
            index: i,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: i == Facility.values.length - 1 ? 0 : 16,
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

/// One building: icon and title with the ten level pips and the live LV
/// number; below, the single effect line — current effect plus the gold
/// next-level value — with the upgrade button (or MAX pill). A level-0
/// facility shows the effect its first level buys, dimmed.
class FacilityCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final maxed = level >= costs.maxLevel;
    final price = costs.upgradeCost(level);
    final affordable = coins >= price;
    final built = level > 0;

    return FcmPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FcmIconBadge(icon: facility.icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facility.title,
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
                        for (var i = 0; i < costs.maxLevel; i++)
                          Expanded(
                            child: Container(
                              height: 4,
                              margin: const EdgeInsetsDirectional.only(end: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: i < level
                                    ? FcmColors.goldGradient
                                    : null,
                                color: i < level
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
                'LV $level',
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
                        facility.effect.describeAt(built ? level : 1),
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
                        facility.effect.shortValueAt(level + 1),
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
                  busy: busy,
                  onPressed: onUpgrade,
                ),
              ],
            ],
          ),
        ],
      ),
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
