/// FCM Rivals — the Campus tab (GDD 3.5): the club's long-term
/// upgrade project.
///
/// Six buildings, ten levels each, geometrically escalating prices: the
/// manager invests match rewards across seasons for small permanent
/// boosts — training facilities add a few percent to a playing
/// attribute for every player, the recovery centre speeds post-match
/// healing, the medical centre cuts injury risk. The screen leads with
/// a header card summarising today's combined effect, then one
/// [FacilityCard] per building showing the live effect at the current
/// level, the effect the NEXT level buys, the escalating price and the
/// total invested so far — so the curve is always legible (GDD 15:
/// effects must be visible).
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
    final fractions = campus.attributeFractions;

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
                'Permanent, always-on upgrades paid for with coins. '
                    'Levels get pricier as the campus grows — a project '
                    'you build across seasons, not a shopping spree.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: FcmColors.textDim,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FcmEntrance(
          index: 1,
          child: _CampusSummaryCard(
            coins: club?.coins ?? 0,
            fractions: fractions,
            recoveryBonus: campus.recoveryBonusPercent,
            injuryReduction: campus.injuryRiskReductionPercent,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < Facility.values.length; i++)
          FcmEntrance(
            index: 2 + i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FacilityCard(
                facility: Facility.values[i],
                level: campus.levelOf(Facility.values[i]),
                coins: club?.coins ?? 0,
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

/// Header card: the club's coin balance and the combined effect of
/// today's campus — the numbers every building contributes to.
class _CampusSummaryCard extends StatelessWidget {
  const _CampusSummaryCard({
    required this.coins,
    required this.fractions,
    required this.recoveryBonus,
    required this.injuryReduction,
  });

  final int coins;
  final ({double attack, double support, double defence, double goalkeeping})
      fractions;
  final double recoveryBonus;
  final double injuryReduction;

  static String _pct(double v) {
    final pts = v * 100;
    return '+${pts.toStringAsFixed(pts.truncateToDouble() == pts ? 0 : 1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return FcmPanel(
      accent: FcmColors.bronze,
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  color: FcmColors.gold, size: 22),
              const SizedBox(width: 8),
              const Text(
                'CAMPUS EFFECT TODAY',
                style: TextStyle(
                  color: FcmColors.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              FcmCoinChip(coins: coins),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _EffectPill(icon: Icons.sports_soccer_rounded,
                  label: 'ATT ${_pct(fractions.attack)}'),
              _EffectPill(icon: Icons.hub_rounded,
                  label: 'SUP ${_pct(fractions.support)}'),
              _EffectPill(icon: Icons.shield_rounded,
                  label: 'DEF ${_pct(fractions.defence)}'),
              _EffectPill(icon: Icons.sports_handball_rounded,
                  label: 'GK ${_pct(fractions.goalkeeping)}'),
              _EffectPill(
                  icon: Icons.spa_rounded,
                  label:
                      'RECOVERY +${recoveryBonus.toStringAsFixed(1)}%'),
              _EffectPill(
                  icon: Icons.medical_services_rounded,
                  label:
                      'INJURY RISK −${injuryReduction.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EffectPill extends StatelessWidget {
  const _EffectPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: FcmColors.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// One building: icon and title, the live level pips (ten segments),
/// the CURRENT effect line, the NEXT-level effect line with its price
/// and the upgrade button (or MAX). The total invested sits in the
/// corner so the escalating curve stays visible.
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
                    const SizedBox(height: 3),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'LV $level',
                    style: const TextStyle(
                      color: FcmColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${costs.investedAt(level)} in',
                    style: const TextStyle(
                      color: FcmColors.textDim,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (level > 0) ...[
            _EffectLine(
              icon: Icons.check_circle_rounded,
              color: FcmColors.success,
              text: facility.effect.describeAt(level),
            ),
            const SizedBox(height: 4),
          ] else
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Not built yet.',
                style: const TextStyle(
                    color: FcmColors.textDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: maxed
                    ? const Text(
                        'Maximum level reached.',
                        style: TextStyle(
                          color: FcmColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : _EffectLine(
                        icon: Icons.arrow_upward_rounded,
                        color: FcmColors.gold,
                        text:
                            'Next: ${facility.effect.describeAt(level + 1)}',
                      ),
              ),
              const SizedBox(width: 8),
              if (!maxed)
                FcmButton(
                  compact: true,
                  icon: Icons.monetization_on_rounded,
                  label: '$price',
                  loading: busy,
                  style: affordable
                      ? FcmButtonStyle.gold
                      : FcmButtonStyle.steel,
                  onPressed: busy ? null : onUpgrade,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One effect statement with its leading icon — the "visible effects"
/// rule (GDD 15) made literal.
class _EffectLine extends StatelessWidget {
  const _EffectLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
