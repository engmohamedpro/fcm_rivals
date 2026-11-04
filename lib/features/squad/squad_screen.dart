import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../features/match/tactics.dart';
import 'formations.dart';
import 'player_card_reveal.dart';
import 'squad_drag.dart' show SquadSwapping;
import 'squad_engine.dart' show PlayerCard;
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

    return squad.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (squad) {
        final xi = {
          for (final e in squad.entries)
            if (e.key < Formation.startingXiSize) e.key: e.value,
        };
        // Bench then reserves in slot order, each strip re-sorted
        // best-first by overall: the strips always read highest → lowest
        // whatever order the map or the database hands back.
        List<PlayerCard> strip(int from, int to) =>
            [
              for (var slot = from; slot < to; slot++)
                if (squad.containsKey(slot)) squad[slot]!,
            ]..sort((a, b) {
              final byOverall = b.overall.compareTo(a.overall);
              if (byOverall != 0) return byOverall;
              return a.ownedId.compareTo(b.ownedId);
            });
        final bench = strip(
          Formation.startingXiSize,
          Formation.startingXiSize + Formation.benchSize,
        );
        final reserves = strip(
          Formation.startingXiSize + Formation.benchSize,
          Formation.squadSize,
        );
        final style = PlayingStyle.values.firstWhere(
          (s) => s.name == club?.playingStyle,
          orElse: () => PlayingStyle.balanced,
        );
        final mentality = Mentality.values.firstWhere(
          (m) => m.name == club?.mentality,
          orElse: () => Mentality.balanced,
        );

        // Top padding matches the sides and the gap below the control
        // card, so the card sits in even whitespace on all four sides.
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            // The tactical setup is always available — with an empty
            // collection the pitch simply renders its empty slots —
            // so the tab never hides itself behind a placeholder; the
            // hint above the view just explains how to fill it.
            if (squad.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: FcmPanel(
                  child: Text(
                    'Open packs to collect players, then tap Auto Pick.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: FcmColors.textDim),
                  ),
                ),
              ),
            TacticsSetupView(
              formationCode: club?.formationCode ?? '4-3-3',
              style: style,
              mentality: mentality,
              xi: xi,
              bench: bench,
              reserves: reserves,
              onFormation: (code) => _changeFormation(context, ref, code),
              onStyle: (s) =>
                  _changeTactics(context, ref, playingStyle: s.name),
              onMentality: (m) =>
                  _changeTactics(context, ref, mentality: m.name),
              onAutoPick: () => _autoPick(context, ref),
              // The saved setup is about identity — match-day fitness
              // (stamina) and the per-card stat rows belong to the
              // pre-match phase only.
              showStamina: false,
              showStats: false,
              // Tapping a player shows the full card big with an
              // animated zoom (rays, sparkle, pulsing glow) — a
              // showcase of a known player, not a pack-style reveal:
              // no counting, no masked name. The detail sheet with
              // its stat bars and actions stays on the Collection
              // tab, where the actions live.
              onPlayerTap: (card) => showPlayerCardReveal(context, card: card),
              // Hold a player and drop him on another to swap them
              // (pitch ↔ bench ↔ reserves). The same plan validates the
              // green / red hover feedback and the final drop.
              swapping: SquadSwapping(
                rejection: (dragged, target) => planSquadDrop(
                  formation: formationByCode(club?.formationCode ?? '4-3-3'),
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

  /// Applies a drag-and-drop swap: validated once more against the squad
  /// as it is now, then saved as the club's squad. A refused drop explains
  /// itself in a snackbar and changes nothing.
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
      formation: formationByCode(formationCode),
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
      await store.saveSquad(outcome.assignment!);
      ref.invalidate(squadProvider);
    } catch (e) {
      say('$e'.replaceFirst('CollectionException: ', ''));
    }
  }

  /// Persists the club's tactical setup (GDD 10.2/10.3) — used by the
  /// playing-style and mentality dropdowns on this tab.
  Future<void> _changeTactics(
    BuildContext context,
    WidgetRef ref, {
    String? playingStyle,
    String? mentality,
  }) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeTactics(playingStyle: playingStyle, mentality: mentality);
    ref.invalidate(squadProvider);
  }

  Future<void> _autoPick(BuildContext context, WidgetRef ref) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.autoPickSquad();
    ref.invalidate(squadProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Best squad selected')));
    }
  }

  /// Persists a new formation (GDD 6.4) and re-picks the best XI for it.
  Future<void> _changeFormation(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeFormation(code);
    ref.invalidate(squadProvider);
  }
}
