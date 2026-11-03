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
      ref.invalidate(clubProvider);
      ref.invalidate(campusProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('CollectionException: ', ''))),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        FcmEntrance(
          child: Column(
            children: [
              const SizedBox(height: 4),
              const Text(
                'Club campus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Permanent boosts — every level costs more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < Facility.values.length; i++)
          FcmEntrance(
            index: 1 + i,
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: i == Facility.values.length - 1 ? 0 : 12),
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
                              margin: const EdgeInsets.only(right: 3),
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
                FcmButton(
                  compact: true,
                  coinValue: price,
                  label: '',
                  loading: busy,
                  style: affordable
                      ? FcmButtonStyle.gold
                      : FcmButtonStyle.steel,
                  onPressed: busy ? null : onUpgrade,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
