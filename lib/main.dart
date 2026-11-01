import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'features/collection/collection_collection_screen.dart';
import 'features/match/match_screen.dart';
import 'features/packs/packs_screen.dart';
import 'features/season/season_screen.dart';
import 'features/squad/squad_screen.dart';
import 'features/onboarding/club_creation_screen.dart';

void main() {
  runApp(const ProviderScope(child: FcmRivalsApp()));
}

class FcmRivalsApp extends StatelessWidget {
  const FcmRivalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Rivals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7A3B)),
        useMaterial3: true,
      ),
      home: const _EntryGate(),
    );
  }
}

/// Routes between onboarding (no club yet) and the main game shell.
class _EntryGate extends ConsumerWidget {
  const _EntryGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider);
    return club.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (club) =>
          club == null ? const ClubCreationScreen() : const GameShell(),
    );
  }
}

/// Bottom-navigation shell over season, match, packs, squad and collection.
class GameShell extends StatelessWidget {
  const GameShell({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('FCM Rivals'),
          actions: const [_CoinBalance()],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Season'),
              Tab(text: 'Match'),
              Tab(text: 'Packs'),
              Tab(text: 'Squad'),
              Tab(text: 'Collection'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SeasonScreen(),
            MatchScreen(),
            PacksScreen(),
            SquadScreen(),
            CollectionScreen(),
          ],
        ),
      ),
    );
  }
}

class _CoinBalance extends ConsumerWidget {
  const _CoinBalance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider).valueOrNull;
    if (club == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Text(
          '${_formatCoins(club.coins)} coins',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

String _formatCoins(int coins) {
  if (coins >= 1000000) {
    final v = coins / 1000000;
    return '${v >= 10 ? v.round() : v.toStringAsFixed(1)}M';
  }
  if (coins >= 10000) return '${(coins / 1000).round()}k';
  return '$coins';
}
