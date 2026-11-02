import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/domain/leagues.dart';
import '../../core/domain/players.dart';
import '../../features/ads/ad_engine.dart' show AdRewardKind;
import '../../features/packs/pack_engine.dart' show PackCategory;

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
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(position?.code ?? 'G',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(position != null
                      ? '${position.code} Position Pack'
                      : 'Global Pack'),
                  subtitle: Text(
                      '1 player · drawn from a low, medium or high value tier',
                      style: Theme.of(context).textTheme.bodySmall),
                  trailing: const Icon(Icons.card_giftcard_outlined),
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
      builder: (_) => PackRevealScreen(players: result.players),
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

/// Reveal sequence (GDD 5.6): one card at a time, low → mid → high tier,
/// with bigger effects for the top tier.
class PackRevealScreen extends StatefulWidget {
  const PackRevealScreen({super.key, required this.players});

  final List<BasePlayer> players;

  @override
  State<PackRevealScreen> createState() => _PackRevealScreenState();
}

class _PackRevealScreenState extends State<PackRevealScreen> {
  int _revealed = 0;

  void _revealNext() {
    if (_revealed < widget.players.length) {
      setState(() => _revealed++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    final revealedAll = _revealed >= players.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Pack opening')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (var i = 0; i < players.length; i++)
                  _RevealCard(
                    player: players[i],
                    tier: i,
                    visible: i < _revealed,
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: revealedAll
                      ? () => Navigator.of(context).pop()
                      : _revealNext,
                  child: Text(revealedAll
                      ? 'Add to collection'
                      : 'Reveal player ${_revealed + 1}/${players.length}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({
    required this.player,
    required this.tier,
    required this.visible,
  });

  final BasePlayer player;
  final int tier;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!visible) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const SizedBox(
          height: 110,
          child: Center(child: Icon(Icons.lock_outline, size: 32)),
        ),
      );
    }
    final tierLabel = ['Low', 'Medium', 'High'][tier.clamp(0, 2)];
    final tierColor = switch (tier) {
      0 => Colors.blueGrey,
      1 => Colors.blue,
      _ => Colors.amber.shade800,
    };
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: tierColor, width: 6)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: tierColor,
                  child: Text('${player.baseStats.overall}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name,
                          style: theme.textTheme.titleMedium),
                      Text(
                        '${player.position.code} · ${player.age}y · ${player.nationality}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(tierLabel, style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${player.club}${player.leagueCode.isEmpty ? '' : ' · ${leagueDisplayName(player.leagueCode)}'} · '
              '€${(player.marketValueEur / 1000000).toStringAsFixed(1)}M',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
