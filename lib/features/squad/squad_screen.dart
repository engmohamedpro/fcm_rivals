import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import '../../features/match/tactics.dart';
import '../collection/player_detail_sheet.dart';
import 'formations.dart';
import 'squad_view.dart';

/// Tactics tab: the club's permanent tactical setup (GDD 10) — formation,
/// playing style and mentality as dropdowns with their visible percentage
/// effects, the pitch with the starting XI and colour-coded stamina bars
/// (GDD 11), bench and reserves, and Auto Pick (GDD 6.2/6.3/6.4).
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
        final bench = [
          for (final e in squad.entries)
            if (e.key >= Formation.startingXiSize &&
                e.key < Formation.startingXiSize + Formation.benchSize)
              e.value,
        ];
        final reserves = [
          for (final e in squad.entries)
            if (e.key >= Formation.startingXiSize + Formation.benchSize)
              e.value,
        ];
        final style = PlayingStyle.values.firstWhere(
            (s) => s.name == club?.playingStyle,
            orElse: () => PlayingStyle.balanced);
        final mentality = Mentality.values.firstWhere(
            (m) => m.name == club?.mentality,
            orElse: () => Mentality.balanced);

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
          children: [
            if (squad.isEmpty)
              const FcmPanel(
                child: Text(
                  'Open packs to collect players, then tap Auto Pick.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: FcmColors.textDim),
                ),
              )
            else
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
                onPlayerTap: (card) =>
                    showPlayerDetail(context, card: card, inSquad: true),
              ),
          ],
        );
      },
    );
  }

  /// Persists the club's tactical setup (GDD 10.2/10.3) — used by the
  /// playing-style and mentality dropdowns on this tab.
  Future<void> _changeTactics(BuildContext context, WidgetRef ref,
      {String? playingStyle, String? mentality}) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeTactics(
        playingStyle: playingStyle, mentality: mentality);
    ref.invalidate(clubProvider);
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
      BuildContext context, WidgetRef ref, String code) async {
    final store = await ref.read(collectionStoreProvider.future);
    await store.changeFormation(code);
    ref.invalidate(clubProvider);
    ref.invalidate(squadProvider);
  }
}
