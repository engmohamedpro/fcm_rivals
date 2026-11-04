import 'package:flutter/material.dart';

import 'app_localizations.dart';

/// Resolves the ambient [AppLocalizations] or falls back to the English
/// bundle. The shipped app always installs the delegates on its
/// MaterialApp, but a screen pumped under a plain MaterialApp (widget
/// tests, previews, embedded hosts) has no localization scope — the
/// English fallback keeps such screens self-contained instead of
/// crashing on a null lookup.
AppLocalizations l10nOf(BuildContext context) =>
    AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
