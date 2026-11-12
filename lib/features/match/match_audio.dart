/// FCM Rivals — match-day sound.
///
/// The stadium ambience (assets/audio/live_match.mp3) plays continuously
/// from the start of the first half until the end of the second half, looped,
/// and is never affected, paused, or stopped by half-time breaks, user pause actions,
/// or playing/disposing any other sound (whistles, cheers).
///
/// Every platform call is best-effort: a missing plugin (widget tests),
/// a silent device or a failed decode must never take the match screen
/// down, so failures are swallowed.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// Looped stadium ambience for the live match screen (GDD 13).
const String kAmbienceAsset = 'audio/live_match.mp3';

/// One-shot crowd cheer played over the ambience when a goal goes in.
const String kCheerAsset = 'audio/goal_cheers.mp3';

/// Referee start whistle played at kick-off of first and second halves.
const String kStartWhistleAsset = 'audio/start_whistle.mp3';

/// Referee end whistle played at half-time and full-time.
const String kEndWhistleAsset = 'audio/end_whistle.mp3';

class MatchAudio {
  MatchAudio({AudioPlayer? ambience, AudioPlayer Function()? cheerPlayer})
    : _ambience = ambience ?? AudioPlayer(),
      _cheerPlayer = cheerPlayer ?? AudioPlayer.new;

  static const double _ambienceVolume = 0.5;
  static const double _homeCheerVolume = 1.0;
  static const double _awayCheerVolume = 0.3;

  final AudioPlayer _ambience;
  final AudioPlayer Function() _cheerPlayer;

  final Set<AudioPlayer> _ringing = {};
  bool _started = false;
  bool _finished = false;

  /// First-half kick-off: starts the continuous looping ambience and the start whistle.
  Future<void> start() async {
    if (_started || _finished) return;
    _started = true;
    unawaited(_playOneShot(kStartWhistleAsset));
    await _guard(() async {
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.play(
        AssetSource(kAmbienceAsset),
        volume: _ambienceVolume,
      );
    });
  }

  /// Half-time: plays the end whistle. The ambience bed continues looping uninterrupted.
  Future<void> halfTimeBreak() async {
    if (!_started || _finished) return;
    unawaited(_playOneShot(kEndWhistleAsset));
  }

  /// Second-half kick-off: plays the start whistle. The ambience bed continues looping uninterrupted.
  Future<void> secondHalfKickOff() async {
    if (!_started || _finished) return;
    unawaited(_playOneShot(kStartWhistleAsset));
  }

  /// User pause action: ambience continues playing unaffected.
  Future<void> pause() async {
    // Ambience is not affected or paused by any action.
  }

  /// User resume action: ambience continues playing unaffected.
  Future<void> resume() async {
    // Ambience is not affected or paused by any action.
  }

  /// Goal cheer plays over the ambience.
  Future<void> goalCheer({required bool isHome}) async {
    if (!_started || _finished) return;
    unawaited(
      _playOneShot(
        kCheerAsset,
        volume: isHome ? _homeCheerVolume : _awayCheerVolume,
      ),
    );
  }

  Future<void> _playOneShot(String asset, {double volume = 1.0}) async {
    final player = _cheerPlayer();
    var sounded = false;
    await _guard(() async {
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(asset), volume: volume);
      sounded = true;
    });
    if (!sounded) {
      await _guard(player.dispose);
      return;
    }
    _ringing.add(player);
    unawaited(
      player.onPlayerComplete.first
          .then((_) => _retireCheer(player))
          .catchError((Object _) => _retireCheer(player)),
    );
  }

  void _retireCheer(AudioPlayer player) {
    _ringing.remove(player);
    unawaited(_guard(player.dispose));
  }

  /// Full time: plays the end whistle and stops the ambience bed.
  Future<void> stop() async {
    if (_finished) return;
    _finished = true;
    if (_started) {
      unawaited(_playOneShot(kEndWhistleAsset));
    }
    await _guard(_ambience.stop);
  }

  Future<void> dispose() async {
    await stop();
    await _guard(_ambience.dispose);
  }

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
