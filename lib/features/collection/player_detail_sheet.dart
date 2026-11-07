/// FCM Rivals — player detail sheet (card + full stats + actions).
///
/// Shared by the Collection (with upgrade / merge / sell actions) and the
/// Squad (read-only). The card flips in with a small 3D turn and the stat
/// bars fill as the sheet opens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart';
import '../../core/ui/country_flag.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/player_card.dart';
import '../../l10n/card_class_l10n.dart';
import '../../l10n/l10n_context.dart';
import '../squad/squad_engine.dart';

/// Card rarity for an owned player (same rule as the pack reveal).
CardRarity rarityOf(PlayerCard c) => CardRarity.fromOverall(c.overall);

/// The three attributes printed on a card, including upgrades.
List<({String label, int value})> cardStatsOf(PlayerCard c) {
  int v(PlayerAttribute a) => c.attribute(a);
  if (c.position.isGoalkeeper) {
    return [
      (label: 'GK', value: v(PlayerAttribute.goalkeeping)),
      (label: 'DEF', value: v(PlayerAttribute.defence)),
      (label: 'SUP', value: v(PlayerAttribute.support)),
    ];
  }
  return [
    (label: 'ATT', value: v(PlayerAttribute.attack)),
    (label: 'SUP', value: v(PlayerAttribute.support)),
    (label: 'DEF', value: v(PlayerAttribute.defence)),
  ];
}

/// A full-size [FcmPlayerCard] for an owned player.
Widget ownedCardView(
  PlayerCard c, {
  required double width,
  double glow = 0,
  double? shine,
}) {
  return FcmPlayerCard(
    player: c.base,
    rarity: rarityOf(c),
    width: width,
    overall: c.overall,
    stats: cardStatsOf(c),
    upgradeLevel: c.upgradeLevel,
    glow: glow,
    shine: shine,
  );
}

/// Buttons shown in the sheet. Null labels/callbacks hide the button.
class PlayerDetailActions {
  const PlayerDetailActions({
    this.upgradeLabel,
    this.onUpgrade,
    this.onMerge,
    this.sellLabel,
    this.onSell,
  });

  final String? upgradeLabel;
  final VoidCallback? onUpgrade;
  final VoidCallback? onMerge;
  final String? sellLabel;
  final VoidCallback? onSell;
}

Future<void> showPlayerDetail(
  BuildContext context, {
  required PlayerCard card,
  bool inSquad = false,
  int copies = 1,
  PlayerDetailActions? actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.94,
    ),
    builder: (sheetContext) => _PlayerDetailSheet(
      card: card,
      inSquad: inSquad,
      copies: copies,
      actions: actions,
    ),
  );
}

class _PlayerDetailSheet extends StatelessWidget {
  const _PlayerDetailSheet({
    required this.card,
    required this.inSquad,
    required this.copies,
    required this.actions,
  });

  final PlayerCard card;
  final bool inSquad;
  final int copies;
  final PlayerDetailActions? actions;

  void _run(BuildContext context, VoidCallback? cb) {
    Navigator.of(context).pop();
    cb?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = card.base;
    final rarity = rarityOf(card);
    final width = MediaQuery.sizeOf(context).width;
    final cardWidth = math.min(width * 0.62, 250.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(FcmColors.surface, rarity.accent, 0.22)!,
            FcmColors.night,
          ],
        ),
        border: Border.all(color: rarity.accent.withValues(alpha: 0.45)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Card turns in from the side.
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (context, v, child) {
                final s = 0.85 + 0.15 * v;
                return Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY((1 - v) * 0.9)
                      ..scaleByDouble(s, s, s, 1),
                    child: child,
                  ),
                );
              },
              child: ownedCardView(card, width: cardWidth, glow: 0.8),
            ),
          ),
          const SizedBox(height: 18),
          FcmEntrance(
            index: 1,
            child: Column(
              children: [
                FitText(
                  p.name.toUpperCase(),
                  align: Alignment.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${flagEmojiFor(p.nationality)} ${p.nationality}  ·  ${p.position.code}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: FcmColors.textDim),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FcmPill(
                      l10nOf(context).cardClassLabel(
                        CardClass.fromOverall(card.overall),
                        rarity,
                      ),
                      color: CardClass.fromOverall(card.overall) ==
                              CardClass.premium
                          ? CardClass.premium.accent
                          : rarity.accent,
                      filled: false,
                    ),
                    if (card.upgradeLevel > 0)
                      FcmPill('LEVEL +${card.upgradeLevel}'),
                    if (copies >= 2)
                      FcmPill(
                        '×$copies COPIES',
                        color: FcmColors.bronze,
                        filled: false,
                      ),
                    if (inSquad)
                      const FcmPill(
                        'IN SQUAD',
                        color: FcmColors.success,
                        filled: false,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FcmEntrance(
            index: 2,
            child: FcmPanel(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  FcmStatBar(
                    label: 'ATT',
                    value: card.attribute(PlayerAttribute.attack),
                    bonus: card.upgradedAttack,
                  ),
                  FcmStatBar(
                    label: 'SUP',
                    value: card.attribute(PlayerAttribute.support),
                    bonus: card.upgradedSupport,
                  ),
                  FcmStatBar(
                    label: 'DEF',
                    value: card.attribute(PlayerAttribute.defence),
                    bonus: card.upgradedDefence,
                  ),
                  FcmStatBar(
                    label: 'GK',
                    value: card.attribute(PlayerAttribute.goalkeeping),
                    bonus: card.upgradedGoalkeeping,
                  ),
                  const Divider(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Market value',
                          style: TextStyle(color: FcmColors.textDim),
                        ),
                      ),
                      Text(
                        '€${(p.marketValueEur / 1000000).toStringAsFixed(1)}M',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (actions != null) ...[
            const SizedBox(height: 18),
            FcmEntrance(
              index: 3,
              child: Column(
                children: [
                  if (actions!.onUpgrade != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FcmButton(
                        label: actions!.upgradeLabel ?? 'Upgrade',
                        icon: Icons.trending_up,
                        onPressed: () => _run(context, actions!.onUpgrade),
                      ),
                    ),
                  if (actions!.onMerge != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FcmButton(
                        label: 'Merge duplicate (+1)',
                        icon: Icons.merge_type,
                        style: FcmButtonStyle.steel,
                        onPressed: () => _run(context, actions!.onMerge),
                      ),
                    ),
                  if (actions!.onSell != null)
                    FcmButton(
                      label: actions!.sellLabel ?? 'Sell',
                      icon: Icons.sell_outlined,
                      style: FcmButtonStyle.ghost,
                      onPressed: () => _run(context, actions!.onSell),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
