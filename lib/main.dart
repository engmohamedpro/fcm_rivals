import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';

import 'app/providers.dart';
import 'core/ui/fcm_logo.dart';
import 'core/ui/fcm_style.dart';
import 'core/ui/fcm_language_toggle.dart';
import 'core/ui/fcm_widgets.dart';
import 'features/achievements/achievements_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/facilities/campus_screen.dart';
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

class FcmRivalsApp extends ConsumerWidget {
  const FcmRivalsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The persisted language choice ('en'/'ar'); null follows the
    // system locale (English fallback for anything unsupported).
    final tag = ref.watch(localeProvider);
    final locale = tag == null ? null : Locale(tag);
    return MaterialApp(
      title: 'FCM Rivals',
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'FCM Rivals',
      locale: locale,
      localeResolutionCallback: (device, supported) =>
          device ?? const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildFcmTheme(),
      themeMode: ThemeMode.dark,
      darkTheme: buildFcmTheme(),
      // App-wide responsiveness: system font scaling is honoured but clamped
      // so layouts never break, and very wide screens (tablets, desktop,
      // web) get a centred phone-width column instead of a stretched UI.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scaler = mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.2,
        );
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
class _EntryGate extends ConsumerStatefulWidget {
  const _EntryGate();

  @override
  ConsumerState<_EntryGate> createState() => _EntryGateState();
}

class _EntryGateState extends ConsumerState<_EntryGate> {
  @override
  void initState() {
    super.initState();
    // The persisted language loads once at the gate — before any screen
    // renders — so the whole app starts in the chosen locale.
    unawaited(_loadPersistedLocale());
  }

  Future<void> _loadPersistedLocale() async {
    try {
      final store = await ref.read(userSettingsProvider.future);
      final tag = await store.locale();
      if (tag != null && mounted) {
        ref.read(localeProvider.notifier).state = tag;
      }
    } catch (_) {
      // Storage hiccup: stay on the system locale.
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = ref.watch(clubProvider);
    return club.when(
      loading: () => const Scaffold(body: FcmLogoLoading()),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (club) =>
          club == null ? const ClubCreationScreen() : const GameShell(),
    );
  }
}

/// Bottom-navigation shell over season, team, collection, campus and
/// store. League matches are played live from the Season tab (GDD
/// 13/16); the Team tab holds the squad, formation and tactical setup;
/// the Campus tab is the club's facility upgrade project (GDD 3.5).
///
/// Only the selected tab is built; the others are disposed, so hidden
/// screens hold no memory, timers or listeners. Scroll position is not kept
/// across switches. The Store item carries a badge with the number of
/// unopened packs.
class GameShell extends ConsumerWidget {
  const GameShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(availablePacksProvider).valueOrNull?.length ?? 0;
    final l10n = AppLocalizations.of(context)!;
    final items = [
      FcmNavItem(l10n.navSeason, Icons.emoji_events_rounded),
      FcmNavItem(l10n.navTeam, Icons.shield_rounded),
      FcmNavItem(l10n.navAchievements, Icons.military_tech_rounded),
      FcmNavItem(l10n.navCampus, Icons.apartment_rounded),
      FcmNavItem(l10n.navStore, Icons.storefront_rounded, badge: packs),
      // T-0111: the self destination closes the row — the mid-session
      // tabs (Season/Team) stay adjacent on the hot path.
      FcmNavItem(l10n.navProfile, Icons.badge_rounded),
    ];

    return _GameShellBody(items: items);
  }
}

/// Stateful body: owns the selected tab index; only the selected page is
/// built.
class _GameShellBody extends ConsumerStatefulWidget {
  const _GameShellBody({required this.items});

  final List<FcmNavItem> items;

  @override
  ConsumerState<_GameShellBody> createState() => _GameShellBodyState();
}

class _GameShellBodyState extends ConsumerState<_GameShellBody> {
  int _index = 0;

  // One primary scroll controller per tab, so the outgoing and incoming
  // pages never share one while they cross-fade. Re-tapping the active nav
  // item scrolls that tab back to the top.
  late final List<ScrollController> _scroll = List.generate(
    widget.items.length,
    (_) => ScrollController(),
  );

  @override
  void dispose() {
    for (final c in _scroll) {
      c.dispose();
    }
    super.dispose();
  }

  void _scrollToTop(int i) {
    for (final p in _scroll[i].positions) {
      if (p.pixels > 0) {
        unawaited(
          p.animateTo(
            0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
  }

  Widget _page(int i) => switch (i) {
    0 => const SeasonScreen(),
    1 => const SquadScreen(),
    2 => const AchievementsScreen(),
    3 => const CampusScreen(),
    4 => const PacksScreen(),
    _ => const ProfileScreen(),
  };

  @override
  Widget build(BuildContext context) {
    // Screens can send the player to another tab (e.g. Play Match with
    // no starting XI → Team): switch, then clear the one-shot request.
    ref.listen<int?>(shellTabRequestProvider, (_, request) {
      if (request == null) return;
      ref.read(shellTabRequestProvider.notifier).state = null;
      if (request >= 0 && request < widget.items.length && mounted) {
        setState(() => _index = request);
      }
    });
    // The Team tab (index 1) hides the app bar to give the squad pitch
    // its vertical space (owner decision 2026-11-09); every other tab
    // shows it exactly as before. The hide/show animates the whole
    // chrome (toolbar + gold seam) collapsing to zero height over the
    // same 200ms as the body's cross-fade — no hard jump. With the bar
    // collapsed the Scaffold takes the status-bar inset itself, so the
    // Team content neither sits under the status bar nor gains a gap.
    final appBarShown = _index != 1;
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: _CollapsibleAppBar(
        key: const ValueKey('shell-appbar-slot'),
        shown: appBarShown,
        bar: AppBar(
          centerTitle: false,
          // The toolbar hugs the wordmark art: no dead space above or
          // below it, and the taller mark reads as the game's masthead.
          toolbarHeight: 52,
          // Soft elevation shadow under the chrome — the bar floats above
          // the page while its gold seam marks the lit edge.
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.45),
          flexibleSpace: const _AppBarChrome(),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(5),
            child: FcmGoldSeam(),
          ),
          title: const FcmWordmark(size: 44),
          // Dev-only: the test-coin shortcut is compiled out of profile and
          // release builds (kDebugMode is a const, so tree shaking removes
          // the widget entirely).
          actions: [
            const FcmLanguageToggle(),
            if (kDebugMode) const _TestCoinButton(),
            const _CoinBalance(),
          ],
        ),
      ),
      body: FcmBackdrop(
        // Only the selected tab exists: leaving a tab disposes it (and its
        // timers, listeners and image memory); returning rebuilds it.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, ?current],
          ),
          child: PrimaryScrollController(
            key: ValueKey(_index),
            controller: _scroll[_index],
            child: _page(_index),
          ),
        ),
      ),
      bottomNavigationBar: FcmBottomNav(
        items: widget.items,
        index: _index,
        onReselected: _scrollToTop,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

/// The shell's app bar slot (T-0077): wraps the real [AppBar] so the
/// Team tab can collapse it to zero height with a 200ms animation —
/// the same duration and ease family as the body's AnimatedSwitcher
/// cross-fade, so the chrome and the page change read as one motion.
///
/// The [AppBar] itself is fully preserved (chrome, wordmark, actions,
/// gold seam bottom); only its height animates. While collapsed the
/// reported preferred size is zero, so the Scaffold lays the body out
/// from the status-bar inset down — no overlap, no dead gap. The bar
/// subtree is kept alive (offstage) while hidden so its state and the
/// coin-balance stream survive the round trip; it is simply clipped
/// away.
class _CollapsibleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CollapsibleAppBar({super.key, required this.shown, required this.bar});

  static const Duration _duration = Duration(milliseconds: 200);
  static const Curve _curve = Curves.easeOut;

  /// The wrapped app bar in its fully-shown form.
  final AppBar bar;

  /// Whether the bar is expanded; false collapses it to the status-bar
  /// inset alone (the toolbar + seam fold away, the inset stays — so
  /// the hidden state never parks content under the status bar).
  final bool shown;

  /// [AppBar.preferredSize] already includes the toolbar AND the
  /// bottom seam (52 + 5 = 57 in the shell) but EXCLUDES the top
  /// inset — a real AppBar absorbs the inset internally (its natural
  /// device height is inset + 57), so the expanded slot must budget
  /// both or the OverflowBox clamps the bar below its natural height.
  ///
  /// The reported preferred size is the inset-free bar height; the
  /// Scaffold lays the slot out from its LAID-OUT height (which this
  /// widget drives through the animation below, inset-aware), so this
  /// getter only matters for pre-layout consumers.
  @override
  Size get preferredSize => bar.preferredSize;

  /// The status-bar inset the slot keeps when collapsed: zero in
  /// tests, the device status bar height on hardware — the owner's
  /// 57px gift to the Team tab collapses away, the inset never does.
  static double _insetOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  @override
  Widget build(BuildContext context) {
    final inset = _insetOf(context);
    final expanded = inset + bar.preferredSize.height;
    final collapsed = inset;
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: shown ? collapsed : expanded,
        end: shown ? expanded : collapsed,
      ),
      duration: _duration,
      curve: _curve,
      builder: (context, height, child) {
        return ClipRect(
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: OverflowBox(
              minHeight: 0,
              maxHeight: expanded,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      // The bar is always in the tree — clipped to the inset-high slot
      // when hidden — so its state (coin stream, language toggle)
      // survives the cycle.
      child: bar,
    );
  }
}

/// The AppBar's chrome backdrop: a deep vertical gradient that darkens
/// toward the gold seam, a faint warm sheen behind the wordmark and a
/// 1px top bevel — the bar reads as brushed metal under stage light
/// instead of a flat dark strip.
class _AppBarChrome extends StatelessWidget {
  const _AppBarChrome();

  @override
  Widget build(BuildContext context) {
    // The sheen paints OVER the gradient as the Container's foreground
    // decoration (a DecoratedBox has no foreground layer of its own).
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.55, 1],
          colors: [FcmColors.surfaceHigh, FcmColors.surface, FcmColors.night],
        ),
        border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
      ),
      // A faint warm sheen behind the wordmark, painted over the
      // gradient (full-bleed via foregroundDecoration).
      foregroundDecoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.7, -1.2),
          radius: 1.4,
          colors: [Color(0x14D9B871), Colors.transparent],
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
      padding: const EdgeInsetsDirectional.only(end: 14),
      child: Center(child: FcmCoinChip(coins: club.coins)),
    );
  }
}

/// TEMPORARY DEV BUTTON — remove together with
/// CollectionStore.grantTestCoins once testing is done. Debug builds
/// only (see the kDebugMode guard at the call site); each tap credits
/// 1,000,000 test coins.
class _TestCoinButton extends ConsumerWidget {
  const _TestCoinButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club = ref.watch(clubProvider).valueOrNull;
    if (club == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Add 1M coins (test)',
      visualDensity: VisualDensity.compact,
      icon: const Icon(Icons.add_rounded),
      onPressed: () async {
        final store = await ref.read(collectionStoreProvider.future);
        await store.grantTestCoins();
      },
    );
  }
}
