import 'app_localizations.dart';
import '../core/ui/fcm_style.dart';

/// Localized card-class label (T-0049): the premium red tier's tag in
/// the user-facing pill surfaces. The canvas/brand marks
/// ([CardRarity.label], [CardClass.label]) stay EN by the existing
/// convention; this resolves the ACTIVE locale where a context exists.
extension CardClassL10n on AppLocalizations {
  String cardClassLabel(CardClass cardClass, CardRarity rarity) =>
      cardClass == CardClass.premium ? cardClassPremium : rarity.label;
}
