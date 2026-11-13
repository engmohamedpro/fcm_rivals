/// FCM Rivals — the shared EN/AR language toggle (T-0096).
///
/// One tap flips the whole app's locale and persists the choice (GDD
/// localization). The glyph stays in the TARGET language so the switch
/// always shows where it leads. Extracted from the main shell's app
/// bar so first-run surfaces (club creation) can carry it too —
/// behavior identical in both places.
library;

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart'
    show localeProvider, setLocale, userSettingsProvider;
import '../../l10n/app_localizations.dart';

import 'fcm_style.dart' show FcmColors;

/// The app bar-style language button: gold glyph of the target
/// language ('ع' / 'EN'), a localized tooltip, one tap flips and
/// persists through [setLocale] so `MaterialApp` rebuilds live.
class FcmLanguageToggle extends ConsumerWidget {
  const FcmLanguageToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tag = ref.watch(localeProvider);
    final next = tag == 'ar' ? 'en' : 'ar';
    return IconButton(
      tooltip: AppLocalizations.of(context)?.languageLabel ?? 'Language',
      visualDensity: VisualDensity.compact,
      onPressed: () => unawaited(
        setLocale(
          controller: ref.read(localeProvider.notifier),
          settings: () => ref.read(userSettingsProvider.future),
          tag: next,
        ),
      ),
      icon: Text(
        next == 'ar' ? 'ع' : 'EN',
        style: const TextStyle(
          color: FcmColors.goldSoft,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}
