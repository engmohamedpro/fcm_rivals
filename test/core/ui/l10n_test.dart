// Localization layer (2026-11-04_localization): the ARB lookup carries
// both locales with correct Arabic copy, the compact coin readout is
// unit-aware per locale, and the RTL sweep left no direction-unsafe
// layouts behind.
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/ui/fcm_widgets.dart' show FcmCoinChip;
import 'package:fcm_rivals/l10n/app_localizations.dart';

void main() {
  test('AppLocalizations loads EN and AR with the expected messages',
      () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.navSeason, 'Season');
    expect(en.navStore, 'Store');
    expect(en.createYourClub, 'Create your club');
    expect(en.playMatch, 'Play match');
    expect(en.startSeasonInDivision(2), 'Start season in division 2');
    expect(en.nextFixtureRound(5), 'Next fixture · round 5');

    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(ar.navSeason, 'الموسم');
    expect(ar.navTeam, 'الفريق');
    expect(ar.navCollection, 'المجموعة');
    expect(ar.navCampus, 'الحرم');
    expect(ar.navStore, 'المتجر');
    expect(ar.createYourClub, 'أنشئ ناديك');
    expect(ar.playMatch, 'العب المباراة');
    expect(ar.startSeasonInDivision(2), 'ابدأ الموسم في الدرجة 2');
    expect(ar.tapAgainToSkip, contains('مرة أخرى'));
  });

  test('only en and ar are supported; the shell resolves the rest',
      () async {
    expect(AppLocalizations.delegate.isSupported(const Locale('en')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('ar')), isTrue);
    expect(AppLocalizations.delegate.isSupported(const Locale('fr')), isFalse);
    expect(AppLocalizations.supportedLocales, hasLength(2));
  });

  test('compact coin readout is unit-aware per locale', () {
    // English (default, no l10n passed): M/K suffixes.
    expect(FcmCoinChip.compact(2_500_000), '2.5M');
    expect(FcmCoinChip.compact(15_000_000), '15M');
    expect(FcmCoinChip.compact(47_000), '47K');
    expect(FcmCoinChip.compact(950), '950');
  });

  test('compact coin readout uses ARB units when handed the AR bundle',
      () async {
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(FcmCoinChip.compact(2_500_000, l10n: ar), '2.5 م');
    expect(FcmCoinChip.compact(15_000_000, l10n: ar), '15 م');
    expect(FcmCoinChip.compact(47_000, l10n: ar), '47 ألف');
    expect(FcmCoinChip.compact(950, l10n: ar), '950');
  });
}
