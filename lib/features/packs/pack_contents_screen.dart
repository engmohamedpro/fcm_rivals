/// FCM Rivals — pack contents screen.
///
/// Tapping a store cell (or its ⓘ badge) shows every player that pack
/// can draw: name, position and overall rating only — no stat rows —
/// sorted from the highest rated down, so the odds ladder reads at a
/// glance: what the best possible pull looks like, and how deep the pool
/// runs. The screen is a read-only showcase; buying stays on the store.
library;

import 'package:flutter/material.dart';

import '../../core/domain/players.dart' show BasePlayer;
import '../../core/ui/fcm_style.dart';
import '../../core/ui/fcm_widgets.dart';
import 'pack_engine.dart' show PackCategory, PackTier, PackTierColor;

/// The contents list of one store pack.
class PackContentsScreen extends StatelessWidget {
  const PackContentsScreen({
    super.key,
    required this.title,
    required this.category,
    required this.scopeValue,
    required this.tier,
    required this.loadPlayers,
  });

  /// Full offer title, e.g. 'Gold Global Pack'.
  final String title;

  final PackCategory category;
  final String? scopeValue;
  final PackTier tier;

  /// Loads the eligible pool, best-first (store-side ordering).
  final Future<List<BasePlayer>> Function() loadPlayers;

  @override
  Widget build(BuildContext context) {
    final tierColor = tier.accent;
    return Scaffold(
      backgroundColor: FcmColors.night,
      appBar: AppBar(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900)),
        backgroundColor: FcmColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<BasePlayer>>(
        future: loadPlayers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: FcmPanel(
                accent: FcmColors.danger,
                child: Text('${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final players = snapshot.data ?? const <BasePlayer>[];
          if (players.isEmpty) {
            return const Center(
              child: Text('No eligible players for this pack',
                  style: TextStyle(color: FcmColors.textDim)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: players.length,
            itemBuilder: (context, i) {
              final p = players[i];
              final rarity = CardRarity.fromOverall(p.baseStats.overall);
              return FcmEntrance(
                index: i,
                dx: 0,
                dy: 12,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FcmPanel(
                    accent: rarity.accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        // Rating block: the overall, colour-coded by rarity.
                        SizedBox(
                          width: 56,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FcmCountUp(
                                value: p.baseStats.overall,
                                style: TextStyle(
                                  color: rarity.accent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rarity.label,
                                style: TextStyle(
                                  color: rarity.accent.withValues(alpha: 0.8),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${p.position.code} · ${p.nationality}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FcmColors.textDim,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Rank: #1 is the best possible pull.
                        Text(
                          '#${i + 1}',
                          style: TextStyle(
                            color: tierColor.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
