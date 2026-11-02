import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'core/ui/fcm_logo.dart';
import 'core/ui/fcm_style.dart';
import 'core/ui/fcm_widgets.dart';
import 'features/collection/collection_collection_screen.dart';
import 'features/onboarding/club_creation_screen.dart';
import 'features/packs/packs_screen.dart';
import 'features/season/season_screen.dart';
import 'features/squad/squad_screen.dart';

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
      theme: buildFcmTheme(),
      themeMode: ThemeMode.dark,
      darkTheme: buildFcmTheme(),
      // App-wide responsiveness: system font scaling is honoured but clamped
      // so layouts never break, and very wide screens (tablets, desktop,
      // web) get a centred phone-width column instead of a stretched UI.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scaler =
            mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.2);
        return MediaQuery(
          data: mq.copyWith(textScaler: scaler),
          child: ColoredBox(
            color: FcmColors.night,
            child: Center(
              child: SizedBox(
                width: math.min(mq.size.width, 820),
                height: mq.size.height,
                child: child,
              ),
            ),
          ),
        );
      },
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
      loading: () => const Scaffold(body: FcmLogoLoading()),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (club) =>
          club == null ? const ClubCreationScreen() : const GameShell(),
    );
  }
}

/// Bottom-navigation shell over season, packs, squad and collection.
/// League matches are played live from the Season tab (GDD 13/16).
///
/// Tabs are built lazily on first visit and then kept alive, so scroll
/// positions and loaded data survive switching. The Packs item carries a
/// badge with the number of unopened free packs.
class GameShell extends ConsumerWidget {
  const GameShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(availablePacksProvider).valueOrNull?.length ?? 0;
    final items = [
      const FcmNavItem('Season', Icons.sports_soccer),
      FcmNavItem('Packs', Icons.style, badge: packs),
      const FcmNavItem('Squad', Icons.groups),
      const FcmNavItem('Collection', Icons.collections_bookmark),
    ];

    return _GameShellBody(items: items);
  }
}

/// Stateful body: owns the selected tab index and the lazily built pages.
class _GameShellBody extends StatefulWidget {
  const _GameShellBody({required this.items});

  final List<FcmNavItem> items;

  @override
  State<_GameShellBody> createState() => _GameShellBodyState();
}

class _GameShellBodyState extends State<_GameShellBody> {
  int _index = 0;
  final Set<int> _visited = {0};

  Widget _page(int i) => switch (i) {
        0 => const SeasonScreen(),
        1 => const PacksScreen(),
        2 => const SquadScreen(),
        _ => const CollectionScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        centerTitle: false,
        title: const FcmWordmark(),
        actions: const [_CoinBalance()],
      ),
      body: FcmBackdrop(
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              _visited.contains(i)
                  ? _TabPage(active: i == _index, child: _page(i))
                  : const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: FcmBottomNav(
        items: widget.items,
        index: _index,
        onChanged: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
      ),
    );
  }
}

/// One kept-alive tab: cross-fades and ignores touches while hidden.
class _TabPage extends StatelessWidget {
  const _TabPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Offstage(offstage: !active, child: child),
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
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Center(child: FcmCoinChip(coins: club.coins)),
    );
  }
}
