import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/domain/players.dart';
import '../../features/ads/ad_engine.dart' show AdRewardKind;
import '../../features/packs/pack_engine.dart' show PackCategory;
import '../../core/ui/fcm_widgets.dart';
import '../../core/ui/fcm_style.dart';
import 'pack_opening_screen.dart';

/// Packs tab: lists unopened packs (36 starting position packs on a new
/// club, GDD 5.8) and opens them with the cinematic reveal sequence.
class PacksScreen extends ConsumerStatefulWidget {
  const PacksScreen({super.key});

  @override
  ConsumerState<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends ConsumerState<PacksScreen> {
  bool _opening = false;

  @override
  Widget build(BuildContext context) {
    final packs = ref.watch(availablePacksProvider);
    return RefreshIndicator(
      color: FcmColors.gold,
      backgroundColor: FcmColors.surface,
      onRefresh: () async => ref.invalidate(availablePacksProvider),
      child: packs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: FcmPanel(
              accent: FcmColors.danger,
              onTap: () => ref.invalidate(availablePacksProvider),
              child: Column(
                children: [
                  Text('$e', textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Tap to retry',
                      style: TextStyle(color: FcmColors.gold)),
                ],
              ),
            ),
          ),
        ]),
        data: (packs) {
          return ListView.builder(
            // Build a generous window so a screenful of rows is always ready.
            cacheExtent: 900,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
            // header + rewarded-ad free pack offer (GDD 19.3) + packs.
            itemCount: packs.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _PacksHeader(count: packs.length);
              }
              if (index == 1) {
                return const FcmEntrance(
                    index: 1, child: _FreePackAdCard());
              }
              final pack = packs[index - 2];
              final position = pack.scopeValue != null
                  ? Position.fromCode(pack.scopeValue!)
                  : null;
              return FcmEntrance(
                index: index - 1,
                dx: 24,
                dy: 0,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PackRow(
                    label: position?.code ?? 'G',
                    title: position != null
                        ? '${position.code} Position Pack'
                        : 'Global Pack',
                    onTap: () => _open(context, pack.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _open(BuildContext context, int packId) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final store = await ref.read(collectionStoreProvider.future);
      final random = ref.read(randomProvider);
      final result = await store.openPack(packId: packId, random: random);
      ref.invalidate(availablePacksProvider);
      ref.invalidate(collectionProvider);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PackOpeningScreen(players: result.players),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}

class _PacksHeader extends StatelessWidget {
  const _PacksHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return FcmEntrance(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: FitText(
                count == 0 ? 'No packs to open' : '$count ready to open',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const Icon(Icons.auto_awesome, color: FcmColors.gold, size: 22),
          ],
        ),
      ),
    );
  }
}

/// One unopened pack: foil icon, title, odds hint and an OPEN pill.
class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.label,
    required this.title,
    required this.onTap,
  });

  final String label;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FcmPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          _MiniPack(label: label),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FitText(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text(
                  '1 player · low, medium or high value tier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: FcmColors.textDim, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const FcmPill('OPEN'),
        ],
      ),
    );
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
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Opacity(
            opacity: available ? 1 : 0.6,
            child: FcmPanel(
              accent: available ? FcmColors.gold : null,
              glow: available,
              onTap: available && !_busy ? _claim : null,
              child: Row(
                children: [
                  const FcmIconBadge(
                      icon: Icons.play_arrow_rounded, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FitText('Free pack — watch an ad',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          available
                              ? 'One global pack (1 player) for a completed rewarded ad'
                              : 'Already claimed today · ads are always optional',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: FcmColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  if (_busy)
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
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
        borderRadius: BorderRadius.circular(7),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A342C), Color(0xFF141419)],
        ),
        border: Border.all(color: FcmColors.gold, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: FcmColors.bronze.withValues(alpha: 0.55), blurRadius: 10),
        ],
      ),
      child: Container(
        width: 40,
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: FcmColors.gold.withValues(alpha: 0.92),
        child: FitText(label,
            align: Alignment.center,
            style: const TextStyle(
                color: FcmColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
      ),
    );
  }
}
