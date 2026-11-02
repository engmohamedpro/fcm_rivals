import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/domain/players.dart';
import '../../features/ads/ad_engine.dart' show AdRewardKind;
import '../../features/packs/pack_engine.dart' show PackCategory;
import '../../core/ui/fcm_style.dart';
import 'pack_opening_screen.dart';

/// Packs tab: lists unopened packs (36 starting position packs on a new
/// club, GDD 5.8) and handles opening with a reveal sequence.
class PacksScreen extends ConsumerWidget {
  const PacksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(availablePacksProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(availablePacksProvider),
      child: packs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          ListTile(title: Text('$e'), subtitle: const Text('Tap to retry'),
              onTap: () => ref.invalidate(availablePacksProvider)),
        ]),
        data: (packs) {
          return ListView.builder(
            // +1 slot for the rewarded-ad free pack offer (GDD 19.3).
            itemCount: packs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return const _FreePackAdCard();
              }
              final pack = packs[index - 1];
              final position = pack.scopeValue != null
                  ? Position.fromCode(pack.scopeValue!)
                  : null;
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: _MiniPack(label: position?.code ?? 'G'),
                  title: Text(
                    position != null
                        ? '${position.code} Position Pack'
                        : 'Global Pack',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                      '1 player · drawn from a low, medium or high value tier',
                      style: Theme.of(context).textTheme.bodySmall),
                  trailing: const Icon(Icons.auto_awesome, color: FcmColors.gold),
                  onTap: () => _open(context, ref, pack.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, int packId) async {
    final store = await ref.read(collectionStoreProvider.future);
    final random = ref.read(randomProvider);
    final result = await store.openPack(packId: packId, random: random);
    ref.invalidate(availablePacksProvider);
    ref.invalidate(collectionProvider);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PackOpeningScreen(
        players: result.players,
        tiers: result.tiers,
      ),
    ));
  }
}

/// Rewarded-ad free pack offer (GDD 19.3 'Free user-selected pack'):
/// one global pack per day for one completed ad. Always optional.
class _FreePackAdCard extends ConsumerStatefulWidget {
  const _FreePackAdCard();

  @override
  ConsumerState<_FreePackAdCard> createState() => _FreePackAdCardState();
}

class _FreePackAdCardState extends ConsumerState<_FreePackAdCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<AdRewardKind?>(
      future: _adAvailable(),
      builder: (context, snapshot) {
        final available = snapshot.data != null;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: available
              ? theme.colorScheme.secondaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Free pack — watch an ad'),
            subtitle: Text(available
                ? 'One global pack (1 player) for a completed rewarded ad'
                : 'Already claimed today · ads are always optional'),
            trailing: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: available && !_busy ? _claim : null,
          ),
        );
      },
    );
  }

  /// Non-null when the free-pack ad is still available today.
  Future<AdRewardKind?> _adAvailable() async {
    final ads = await ref.read(adStoreProvider.future);
    final club = await ref.read(clubProvider.future);
    if (club == null) return null;
    return await ads.remainingToday(club.id, AdRewardKind.freePack) > 0
        ? AdRewardKind.freePack
        : null;
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final ads = await ref.read(adStoreProvider.future);
      final club = await ref.read(clubProvider.future);
      if (club == null) return;
      // Playback is simulated in v1; the store validates completion.
      await ads.grantFreePack(
        clubId: club.id,
        category: PackCategory.global,
        playbackCompleted: true,
      );
      ref.invalidate(availablePacksProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Free pack added to your packs')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ad reward unavailable')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Tiny foil-pack icon for the pack list.
class _MiniPack extends StatelessWidget {
  const _MiniPack({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3F7DFF), Color(0xFF0B1E78)],
        ),
        border: Border.all(color: FcmColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: FcmColors.royal.withValues(alpha: 0.5), blurRadius: 8),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}
