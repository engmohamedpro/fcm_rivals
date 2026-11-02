/// FCM Rivals — match-day sound.
///
/// Two layered players: the stadium ambience (assets/audio/live_match.mp3)
/// loops continuously from first-half kick-off until full time, and a goal
/// cheer (assets/audio/goal_cheers.mp3) plays once on top of the ambience
/// whenever a goal is scored, by either side.
///
/// Every platform call is best-effort: a missing plugin (widget tests),
/// a silent device or a failed decode must never take the match screen
/// down, so failures are swallowed. The internal AudioPlayer awaits a
/// creation completer before each call; because [stop] always runs in
/// [dispose], those errors are always consumed rather than escaping as
/// unhandled async exceptions.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// Looped stadium ambience for the live match screen (GDD 13). Volume is
/// held under the cheers so the one-shot stays on top.
const String kAmbienceAsset = 'audio/live_match.mp3';

/// One-shot crowd cheer played over the ambience when a goal goes in.
const String kCheerAsset = 'audio/goal_cheers.mp3';

class MatchAudio {
  /// [ambience] and [cheers] exist for tests; production leaves them null
  /// and gets plain [AudioPlayer]s.
  MatchAudio({AudioPlayer? ambience, AudioPlayer? cheers})
    : _ambience = ambience ?? AudioPlayer(),
      _cheers = cheers ?? AudioPlayer();

  static const double _ambienceVolume = 0.5;
  static const double _cheerVolume = 1.0;

  final AudioPlayer _ambience;
  final AudioPlayer _cheers;

  bool _started = false;

  /// Kick-off: starts the ambience looping. Idempotent, so a rebuild or a
  /// repeated call cannot stack a second loop on the same player.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _guard(() async {
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.play(
        AssetSource(kAmbienceAsset),
        volume: _ambienceVolume,
      );
    });
  }

  /// A goal was scored (either side): the cheer plays from the top over
  /// the still-running ambience. If the previous cheer is still going,
  /// restarting it is the right call for a quick double.
  Future<void> goalCheer() async {
    if (!_started) return;
    await _guard(
      () => _cheers.play(AssetSource(kCheerAsset), volume: _cheerVolume),
    );
  }

  /// Full time: the ambience runs "from first-half kick-off until the
  /// second half ends", so it stops the moment the match does — not after
  /// the post-match recovery choice.
  Future<void> stop() async {
    await _guard(_ambience.stop);
    await _guard(_cheers.stop);
  }

  /// Back navigation / screen teardown. Stopping first also consumes the
  /// players' internal creation errors on platforms where audio never
  /// came up (see the library comment).
  Future<void> dispose() async {
    await stop();
    await _guard(_ambience.dispose);
    await _guard(_cheers.dispose);
  }

  /// Sound is decorative: never let an audio failure escape into the
  /// match flow. Plugin-less environments (widget tests) are the expected
  /// quiet case; anything else is surfaced in debug builds only.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      // Widget tests and hosts without the audio plugin: expected, quiet.
    } catch (e) {
      assert(() {
        debugPrint('MatchAudio: $e');
        return true;
      }());
    }
  }
}
