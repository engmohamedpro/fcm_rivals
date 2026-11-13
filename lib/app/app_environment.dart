/// FCM Rivals — the app's build environment, one source of truth.
///
/// WHY THIS EXISTS (environment switch request 2026-11-12): every
/// debug-only surface used to gate itself on `kDebugMode` directly,
/// scattered across four files. That works, but it answers the wrong
/// question — "how was this compiled?" — when the question we care
/// about is "which app is this?". A `flutter build apk --release`
/// handed to a tester outside the team is still a release-shaped
/// binary with debug tools inside; `flutter run --profile` is a
/// performance build, not a development one.
///
/// So the environment is now EXPLICIT, chosen at build time:
///
/// ```sh
/// flutter run --dart-define=APP_ENV=dev      # default anyway
/// flutter run --dart-define=APP_ENV=qa       # tester build
/// flutter build apk --release --dart-define=APP_ENV=qa
/// flutter build apk --release                # production (no define)
/// ```
///
/// The switch is COMPILE-TIME: [FcmApp.env] is a `const` built from
/// `String.fromEnvironment`, so every gate reading it tree-shakes
/// away in production builds exactly like `kDebugMode` did — no
/// runtime flag, nothing to flip on a shipped binary.
///
/// Semantics of the three values:
/// * [AppEnvironment.dev]  — the developer's own device/simulator.
///   The default for plain `flutter run` (debug builds), so the dev
///   loop needs no extra flags. (The dev-only debug surfaces — the
///   test-coin button and the pack draw picker — were REMOVED at the
///   owner's request 2026-11-13; the gate stays for future tooling.)
/// * [AppEnvironment.qa]   — a build handed to testers/owner. REAL
///   odds and real economy only (no free coins, no planted draws) —
///   QA must experience the game the player will. Kept as an explicit
///   value so a tester build can never be mistaken for production:
///   it can carry QA-only surfaces later (extra logging, a fixture
///   reset, …) without touching production code paths.
/// * [AppEnvironment.production] — the store build. Nothing debug
///   exists here, and the compiler proves it.
///
/// Rule of thumb for new gates: development conveniences read
/// [FcmApp.isDev]; QA tooling reads [FcmApp.isQa]; anything that must
/// NEVER ship reads [FcmApp.isDev] only. Prefer these over raw
/// `kDebugMode` — new code should not answer "which app?" with a
/// fact about the compiler.
library;

import 'package:flutter/foundation.dart' show kReleaseMode;

/// The three build environments the app ships as.
enum AppEnvironment {
  /// The developer's build: `flutter run` (debug, the default when
  /// APP_ENV is unset on a debug compile). Debug tools allowed.
  dev,

  /// A tester build: real gameplay, real odds, real economy — plus
  /// (later) QA-only surfaces. Built explicitly with
  /// `--dart-define=APP_ENV=qa`.
  qa,

  /// The store build: `flutter build` in release mode without an
  /// APP_ENV define. No debug surfaces can exist here.
  production;
}

/// The compile-time environment of THIS build.
///
/// Resolution order:
/// 1. An explicit `--dart-define=APP_ENV=dev|qa|production` always
///    wins, whatever the compile mode — a QA build is QA even when
///    built in debug mode for live inspection.
/// 2. No define: the compile mode decides — debug/profile compiles
///    are [AppEnvironment.dev] (the developer's loop), release
///    compiles are [AppEnvironment.production].
///
/// An unknown APP_ENV value (typo) FALLS BACK to the compile-mode
/// default rather than throwing: a misflagged build should still
/// boot, and the fallback is always the safe side for that compile
/// mode — dev gets dev tools, release stays clean.
abstract final class FcmApp {
  /// The environment this binary was built for. See [FcmApp]. Written
  /// as nested const TERNARIES (const switch expressions are not
  /// constant expressions until Dart supports them) so the whole
  /// chain is a valid const and tree-shakes in production builds.
  static const AppEnvironment env =
      String.fromEnvironment('APP_ENV') == 'dev'
          ? AppEnvironment.dev
          : String.fromEnvironment('APP_ENV') == 'qa'
          ? AppEnvironment.qa
          : String.fromEnvironment('APP_ENV') == 'production'
          ? AppEnvironment.production
          // Unset or a typo: the compile-mode default — dev tools on
          // debug compiles, clean release builds.
          : kReleaseMode
          ? AppEnvironment.production
          : AppEnvironment.dev;

  /// True on developer builds — the only place debug tools may live.
  static const bool isDev = env == AppEnvironment.dev;

  /// True on tester builds (explicit `--dart-define=APP_ENV=qa`).
  static const bool isQa = env == AppEnvironment.qa;

  /// True on the store build.
  static const bool isProduction = env == AppEnvironment.production;

  /// Short tag for logs and about screens, e.g. `env:qa` (a const
  /// ternary — `.name` is an extension getter and not const-evaluable).
  static const String tag =
      isDev ? 'env:dev' : isQa ? 'env:qa' : 'env:production';
}
