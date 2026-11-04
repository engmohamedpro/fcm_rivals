import 'app_localizations.dart';
import '../features/match/stamina.dart';

/// Localized names for [PepTalk] choices. The enum lives with the
/// engine's recovery model and keeps an English `displayName` for
/// non-UI surfaces (logs, debug output); UI copy resolves through the
/// ARB keys so Arabic renders natively.
extension PepTalkL10n on AppLocalizations {
  String pepTalkName(PepTalk talk) => switch (talk) {
        PepTalk.restEveryone => pepTalkRestEveryone,
        PepTalk.focusExhausted => pepTalkFocusExhausted,
        PepTalk.rewardSubstitutes => pepTalkRewardSubstitutes,
        PepTalk.everyoneGaveBest => pepTalkEveryoneGaveBest,
      };
}
