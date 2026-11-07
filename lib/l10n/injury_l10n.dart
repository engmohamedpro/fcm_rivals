import 'app_localizations.dart';
import '../features/match/commentary.dart';
import '../features/match/injury.dart';

/// Localized injury commentary (T-0054, GDD 11.7): the engine chain's
/// only l10n strings. `generateCommentary` resolves its English default
/// inline; UI call sites pass a closure over this extension so Arabic
/// renders natively (RTL-safe — no positional interpolation, names are
/// inserted as-is).
extension InjuryL10n on AppLocalizations {
  String injuryCommentaryLine(
    InjuryKind kind,
    String playerName,
    bool playsShort,
  ) =>
      switch (kind) {
        InjuryKind.knock =>
          injuryCommentaryKnock(playerName) +
              (playsShort ? injuryCommentaryPlaysShort : ''),
        InjuryKind.muscle =>
          injuryCommentaryMuscle(playerName) +
              (playsShort ? injuryCommentaryPlaysShort : ''),
        InjuryKind.serious =>
          injuryCommentarySerious(playerName) +
              (playsShort ? injuryCommentaryPlaysShort : ''),
      };
}

/// Bridges the commentary localizer typedef to the localized extension —
/// the closure UI call sites hand to `generateCommentary`.
InjuryCommentaryLocalizer injuryCommentaryLocalizer(AppLocalizations l10n) =>
    (kind, playerName, playsShort) =>
        l10n.injuryCommentaryLine(kind, playerName, playsShort);
