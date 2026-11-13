import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../app/providers.dart';
import '../../core/ui/scene_loading.dart';
import '../ads/ad_engine.dart' show AdEngine, AdRewardKind;
import '../collection/card_merge_animation.dart' show showCardMergeAnimation;
import '../collection/collection_results.dart' show SquadCapacity;
import '../economy/economy_engine.dart'
    show EconomyEngine, formatCoins;
import '../match/tactics.dart';
import 'formations.dart';
import 'player_card_reveal.dart';
import 'squad_drag.dart' show SquadSwapping;
import 'squad_engine.dart' show PlayerCard;
import 'squad_slots_button.dart';
import 'squad_swap.dart';
import 'squad_view.dart';

/// Team tab (nav label 'Team'): the club's permanent tactical setup (GDD 10) — formation,
/// playing style and mentality as dropdowns with their visible percentage
/// effects, the pitch with the starting XI and colour-coded stamina bars
/// (GDD 11), bench and reserves, and Auto Pick (GDD 6.2/6.3/6.4).
/// Players can be held and dropped on each other to swap places between the
/// pitch, the bench and the reserves — a starting slot only accepts a
/// player of its own position.
/// Every change here is saved immediately as the club's default setup;
/// the pre-match screen reuses the same view for match-only overrides.
class SquadScreen extends ConsumerWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squad = ref.watch(squadProvider);
    final club = ref.watch(clubProvider).valueOrNull;
    // Upgradable marks (T-0089): the owned rows grouped by base player —
    // two or more copies means a duplicate is available to merge a level
    // up (the Collection sheet's own Merge rule). getCollection already
    // filters status 'owned' (merged duplicates are excluded), so a
    // plain count is the truth; watching the provider means a merge or
    // sale on the Collection tab re-derives the marks on the next build.
    final collection = ref.watch(collectionProvider).valueOrNull;
    // Squad capacity: the pool title shows N/capacity and the button
    // beside it buys the next block of slots.
    final capacity = ref.watch(squadCapacityProvider).valueOrNull;
    final ownedCounts = <int, int>{};
    for (final c in collection ?? const <PlayerCard>[]) {
      ownedCounts.update(
        c.base.playerId,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    final upgradableIds = <int>{
      for (final e in ownedCounts.entries)
        if (e.value >= 2) e.key,
    };

    return squad.when(
      loading: () => const SceneLoadingMarker(),
      error: (e, _) => Center(child: Text('$e')),
      data: (squad) {
        final xi = {
          for (final e in squad.entries)
            if (e.key < Formation.startingXiSize) e.key: e.value,
        };
        // The bench in slot order, re-sorted best-first by overall: the
        // strip always reads highest → lowest whatever order the map or
        // the database hands back.
        final bench = [
          for (var slot = Formation.startingXiSize;
              slot < Formation.startingXiSize + Formation.benchSize;
              slot++)
            if (squad.containsKey(slot)) squad[slot]!,
        ]..sort((a, b) {
          final byOverall = b.overall.compareTo(a.overall);
          if (byOverall != 0) return byOverall;
          return a.ownedId.compareTo(b.ownedId);
        });
        // The pool: EVERY owned card, best-first. Cards already in the XI
        // or on the bench stay in it, drawn faded with a check.
        final inSquad = {
          for (final e in squad.entries)
            if (e.key < Formation.startingXiSize + Formation.benchSize)
              e.value.ownedId,
        };
        // One card per PLAYER: extra copies of the same base player are
        // upgrade fodder (the gold upgrade mark says so), not extra
        // players — they neither show as separate cards nor count in the
        // pool total. The card that stands for him is the copy already in
        // the XI / bench when there is one, otherwise the strongest copy.
        bool standsFor(PlayerCard a, PlayerCard b) {
          final aIn = inSquad.contains(a.ownedId);
          final bIn = inSquad.contains(b.ownedId);
          if (aIn != bIn) return aIn;
          if (a.overall != b.overall) return a.overall > b.overall;
          return a.ownedId < b.ownedId;
        }

        final onePerPlayer = <int, PlayerCard>{};
        for (final c in collection ?? const <PlayerCard>[]) {
          final current = onePerPlayer[c.base.playerId];
          if (current == null || standsFor(c, current)) {
            onePerPlayer[c.base.playerId] = c;
          }
        }
        final reserves = [...onePerPlayer.values]..sort((a, b) {
          final byOverall = b.overall.compareTo(a.overall);
          if (byOverall != 0) return byOverall;
          return a.ownedId.compareTo(b.ownedId);
        });
        final tactics = tacticsFromDbPayload(club?.tactics);
        // The mentality stays an ENGINE value (owner request
        // 2026-11-13): the saved column loads for matches and the AI,
        // but the Team tab no longer edits it.

        // Top padding matches the sides and the gap below the control
        // card, so the card sits in even whitespace on all four sides.
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            TacticsSetupView(
              formation: formationOfCode(club?.formationCode ?? '4-3-3'),
              tactics: tactics,
              xi: xi,
              bench: bench,
              reserves: reserves,
              onFormation: (code) => _changeFormation(context, ref, code),
              onTactics: (t) => _changeTactics(context, ref, tactics: t),
              onAutoPick: () => _autoPick(context, ref),
              onClear: () => _clearSquad(ref),
              poolTitle: 'All players',
              poolSelectedIds: inSquad,
              poolCapacity: capacity?.capacity,
              poolTrailing: capacity == null
                  ? null
                  : SquadSlotsButton(
                      slots: capacity.nextBlockSlots,
                      price: capacity.nextBlockPrice,
                      canAfford:
                          club == null || club.coins >= capacity.nextBlockPrice,
                      onTap: () => _buySlots(context, ref, capacity),
                    ),
              // The saved setup is about identity — match-day fitness
              // (stamina) and the per-card stat rows belong to the
              // pre-match phase only.
              showStamina: false,
              showStats: false,
              // T-0117: the pure management surface — no match-day
              // condition chrome of any kind (stamina bars, injury
              // badges, injured-card inertness). The saved XI is the
              // club's identity eleven on merit; fitness belongs to
              // the pre-match duplicate and the kick-off guard.
              showCondition: false,
              // T-0092: no setup summary row on the Team tab — the
              // pitch tells the rating story; pre-match/live keep it.
              showSetupSummary: false,
              // Tapping a player shows the full card big with an
              // animated zoom (rays, sparkle, pulsing glow) — a
              // showcase of a known player, not a pack-style reveal:
              // no counting, no masked name. The detail sheet with
              // its stat bars and actions stays on the Collection
              // tab, where the actions live.
              onPlayerTap: (card) => _openCardView(
                context,
                ref,
                card,
                // The T-0089 owned-count plumbing feeds the reveal's
                // UPGRADE: the other copies of THIS player (the same
                // grouping, filtered to the tapped card's base).
                [
                  for (final c in collection ?? const <PlayerCard>[])
                    if (c.base.playerId == card.base.playerId &&
                        c.ownedId != card.ownedId)
                      c,
                ],
              ),
              // A card with an owned duplicate carries the upgradable
              // mark (T-0089).
              upgradable: (playerId) => upgradableIds.contains(playerId),
              // Hold a player and drop him on another to swap them
              // (pitch ↔ bench ↔ reserves) — no hint line anymore
              // (T-0093); the interaction teaches itself. The same
              // plan validates the
              // green / red hover feedback and the final drop.
              swapping: SquadSwapping(
                rejection: (dragged, target) => planSquadDrop(
                  formation: formationOfCode(club?.formationCode ?? '4-3-3'),
                  squad: squad,
                  dragged: dragged,
                  target: target,
                ).rejection,
                onSwap: (dragged, target) => _swap(
                  context,
                  ref,
                  formationCode: club?.formationCode ?? '4-3-3',
                  squad: squad,
                  dragged: dragged,
                  target: target,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Buys the next block of squad slots: confirmed first (price and
  /// affordability up front), then charged atomically by the store. The
  /// capacity provider is refreshed so the title and the next price move.
  Future<void> _buySlots(
    BuildContext context,
    WidgetRef ref,
    SquadCapacity capacity,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) => messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

    final coins = ref.read(clubProvider).valueOrNull?.coins;
    final confirmed = await showBuySquadSlotsDialog(
      context,
      slots: capacity.nextBlockSlots,
      price: capacity.nextBlockPrice,
      coins: coins,
    );
    if (confirmed != true) return;
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final next = await store.buySquadSlots();
      ref.invalidate(squadCapacityProvider);
      say('Your squad now holds ${next.capacity} players.');
    } catch (e) {
      say('$e'.replaceFirst('CollectionException: ', ''));
    }
  }

  /// Applies a drag-and-drop swap: validated once more against the squad
  /// as it is now, then saved as the club's squad. A refused drop explains
  /// itself in a snackbar and changes nothing.
  ///
  /// A drop that redefined an empty slot (custom formation building)
  /// carries the new formation: the store persists BOTH, atomically, so
  /// the pitch and the squad can never disagree.
  Future<void> _swap(
    BuildContext context,
    WidgetRef ref, {
    required String formationCode,
    required Map<int, PlayerCard> squad,
    required PlayerCard dragged,
    required SquadDropTarget target,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) => messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));

    final outcome = planSquadDrop(
      formation: formationOfCode(formationCode),
      squad: squad,
      dragged: dragged,
      target: target,
    );
    if (!outcome.isAccepted) {
      say(outcome.rejection!);
      return;
    }
    try {
      final store = await ref.read(collectionStoreProvider.future);
      await store.saveSquadAndFormation(
        outcome.assignment!,
        formationCode: outcome.formation?.code,
      );
      ref.invalidate(squadProvider);
    } catch (e) {
      say('$e'.replaceFirst('CollectionException: ', ''));
    }
  }

  /// Persists the club's tactical setup (GDD 10.2) — used by the
  /// custom-tactics sheet on this tab. The mentality no longer passes
  /// through here (owner request 2026-11-13): it is an engine value.
  Future<void> _changeTactics(
    BuildContext context,
    WidgetRef ref, {
    TeamTactics? tactics,
  }) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeTactics(tactics: tactics);
    ref.invalidate(squadProvider);
  }

  Future<void> _autoPick(BuildContext context, WidgetRef ref) async {
    final store = await ref.read(collectionStoreProvider.future);
    // T-0117: the Team tab's pick is MERIT-ONLY — injured players
    // still compete for the saved XI (fitness belongs to the pre-match
    // duplicate and the kick-off guard, never the identity eleven).
    // Natural positions only: a slot nobody can play naturally stays
    // empty rather than taking an out-of-position filler. No snackbar.
    await store.autoPickSquad(excludeInjured: false, naturalOnly: true);
    ref.invalidate(squadProvider);
  }

  /// Empties the saved squad — XI, bench and reserves. No snackbar: the
  /// pitch and strips visibly empty.
  Future<void> _clearSquad(WidgetRef ref) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.saveSquad(const {});
    ref.invalidate(squadProvider);
  }

  /// Persists a new formation (GDD 6.4) and re-picks the best XI for it.
  /// The code may be a preset ('4-3-3') or a custom code ('C|GK,…').
  Future<void> _changeFormation(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeFormation(code);
    ref.invalidate(squadProvider);
  }

  /// Opens the full-card view with the T-0090 actions wired: SELL is
  /// the squad-aware sale (XI slot re-picked inside the transaction),
  /// UPGRADE merges the first duplicate and refreshes the card in
  /// place. The view pops itself on a successful SELL (the sold row
  /// no longer exists); an upgrade keeps it open, stronger.
  Future<void> _openCardView(
    BuildContext context,
    WidgetRef ref,
    PlayerCard card,
    List<PlayerCard> duplicates,
  ) async {
    // The bridge the upgrade flow uses to re-render the revealed card
    // in place after a merge (Requirement 4): the reveal registers its
    // refresh here when its state exists.
    final refreshBridge = ValueNotifier<void Function(PlayerCard,
        List<PlayerCard>)?>((_, _) {});
    await showPlayerCardReveal(
      context,
      card: card,
      duplicates: duplicates,
      onSell: () => _sellFromView(context, ref, card),
      onUpgrade: (duplicate) => _upgradeFromView(
        context,
        ref,
        card,
        duplicate,
        refreshBridge,
      ),
      onRefreshRegistered:
          (refresh) => refreshBridge.value = refresh,
    );
  }

  /// SELL from the full view: the ad selling-bonus offer first (same
  /// as the Collection tab — both tabs must sell identically), then
  /// the confirm dialog, then the squad-aware sale. Success pops the
  /// reveal (the row is gone) and refreshes the team screen's data.
  Future<void> _sellFromView(
    BuildContext context,
    WidgetRef ref,
    PlayerCard card,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final adStore = await ref.read(adStoreProvider.future);
    final club = await ref.read(clubProvider.future);
    final canBoost =
        club != null &&
        await adStore.remainingToday(club.id, AdRewardKind.sellingBonus) > 0;
    var bonusWatched = false;
    if (canBoost) {
      if (!context.mounted) return;
      bonusWatched =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Boost this sale?'),
              content: const Text(
                'Watch a rewarded ad to add +20% to the selling price of '
                'this sale. Ads are always optional.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No thanks'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Watch ad'),
                ),
              ],
            ),
          ) ??
          false;
      if (bonusWatched) {
        try {
          await adStore.grantBoost(
            clubId: club.id,
            kind: AdRewardKind.sellingBonus,
            playbackCompleted: true,
          );
        } catch (_) {
          bonusWatched = false;
        }
      }
    }
    if (!context.mounted) return;

    final economy = EconomyEngine();
    final price = economy.sellPriceOfUpgraded(card.base, card.upgradeLevel);
    final boosted = bonusWatched ? AdEngine().sellingBonus(price) : price;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sell player?'),
        content: Text(
          '${card.base.name} will be sold for ${formatCoins(boosted)} coins. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sell'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final store = await ref.read(collectionStoreProvider.future);
    try {
      final result = await store.sellPlayerFromSquad(card.ownedId);
      ref.invalidate(collectionProvider);
      ref.invalidate(squadProvider);
      navigator.pop();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Sold for ${formatCoins(result.credit)} coins'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  /// UPGRADE from the full view: merge the tapped card with its first
  /// duplicate (free, levels unlimited), play the merge animation,
  /// then refresh the revealed card in place — the view stays open
  /// showing the stronger man.
  Future<void> _upgradeFromView(
    BuildContext context,
    WidgetRef ref,
    PlayerCard target,
    PlayerCard duplicate,
    ValueNotifier<void Function(PlayerCard, List<PlayerCard>)?> refreshBridge,
  ) async {
    final revealContext = context;
    final store = await ref.read(collectionStoreProvider.future);
    try {
      final result = await store.mergeDuplicates(
        targetOwnedId: target.ownedId,
        duplicateOwnedId: duplicate.ownedId,
      );
      ref.invalidate(collectionProvider);
      ref.invalidate(squadProvider);
      // Re-render the revealed card in place: the merge consumed one
      // duplicate and levelled the target — re-read the fresh row (the
      // squad/collection providers were just invalidated) and hand it
      // plus the remaining copies to the reveal.
      final fresh = await ref.read(squadProvider.future);
      final targetRow = fresh.values
          .where((c) => c.ownedId == target.ownedId)
          .firstOrNull;
      if (targetRow != null) {
        final collectionNow = await ref.read(collectionProvider.future);
        final remaining = <PlayerCard>[
          for (final c in collectionNow)
            if (c.base.playerId == target.base.playerId &&
                c.ownedId != target.ownedId)
              c,
        ];
        refreshBridge.value?.call(targetRow, remaining);
      }
      if (!revealContext.mounted) return;
      if (MediaQuery.disableAnimationsOf(revealContext)) {
        ScaffoldMessenger.of(revealContext).showSnackBar(
          SnackBar(
            content: Text(
              '${target.base.name} upgraded to +${result.newUpgradeLevel} '
              '(+${result.newUpgradeLevel}% stats)',
            ),
          ),
        );
      } else {
        await showCardMergeAnimation(
          revealContext,
          target: target,
          duplicate: duplicate,
          newLevel: result.newUpgradeLevel,
        );
      }
    } catch (e) {
      if (revealContext.mounted) {
        ScaffoldMessenger.of(revealContext)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}
