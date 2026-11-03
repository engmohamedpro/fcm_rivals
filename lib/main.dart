import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'core/ui/fcm_logo.dart';
import 'core/ui/fcm_style.dart';
import 'core/ui/fcm_widgets.dart';
import 'features/collection/collection_collection_screen.dart';
import 'features/onboarding/club_creation_screen.dart';
import 'features/packs/pack_effects.dart' show precachePackLogo;
import 'features/packs/packs_screen.dart';
import 'features/season/season_screen.dart';
import 'features/squad/squad_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Decode the brand art for canvas painting (the store's foil packs)
  // while the first frame renders; painters fall back to the text
  // wordmark until it lands.
  unawaited(precachePackLogo());
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

/// Bottom-navigation shell over season, team, collection and store. League
/// matches are played live from the Season tab (GDD 13/16); the Team tab
/// holds the squad, formation and tactical setup.
///
/// Tabs are built lazily on first visit and then kept alive, so scroll
/// positions and loaded data survive switching. The Store item carries a
/// badge with the number of unopened packs.
class GameShell extends ConsumerWidget {
  const GameShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(availablePacksProvider).valueOrNull?.length ?? 0;
    final items = [
      const FcmNavItem('Season', Icons.emoji_events_rounded),
      const FcmNavItem('Team', Icons.shield_rounded),
      const FcmNavItem('Collection', Icons.collections_bookmark),
      FcmNavItem('Store', Icons.storefront_rounded, badge: packs),
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
        1 => const SquadScreen(),
        2 => const CollectionScreen(),
        _ => const PacksScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        centerTitle: false,
        // The toolbar hugs the wordmark art: no dead space above or
        // below it, and the taller mark reads as the game's masthead.
        toolbarHeight: 44,
        title: const FcmWordmark(size: 44),
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
