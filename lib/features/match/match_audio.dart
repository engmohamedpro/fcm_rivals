/// FCM Rivals — match-day sound.
///
/// The stadium ambience (assets/audio/live_match.mp3) loops continuously
/// from first-half kick-off until full time, and a goal cheer
/// (assets/audio/goal_cheers.mp3) plays on top of the ambience whenever
/// a goal is scored, by either side.
///
/// Each cheer runs on its OWN one-shot player: two goals close together
/// ring out on top of each other (the second never cuts the first), and
/// a cheer that is already ringing is never cut by anything else either
/// — not by the next goal, not by the full-time whistle, not by half
/// time, not by the screen tearing down. It always plays to its natural
/// end, then retires its player by itself.
///
/// Every platform call is best-effort: a missing plugin (widget tests),
/// a silent device or a failed decode must never take the match screen
/// down, so failures are swallowed. The internal AudioPlayer awaits a
/// creation completer before each call; because every player is always
/// released in the end (stop/dispose for the ambience, self-retirement
/// for cheers), those errors are always consumed rather than escaping
/// as unhandled async exceptions.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// Looped stadium ambience for the live match screen (GDD 13). Volume is
/// held under the cheers so the one-shots stay on top.
const String kAmbienceAsset = 'audio/live_match.mp3';

/// One-shot crowd cheer played over the ambience when a goal goes in.
const String kCheerAsset = 'audio/goal_cheers.mp3';

class MatchAudio {
  /// [ambience] and [cheerPlayer] exist for tests; production leaves them
  /// null and gets a plain [AudioPlayer] bed plus a fresh one-shot player
  /// per goal.
  MatchAudio({AudioPlayer? ambience, AudioPlayer Function()? cheerPlayer})
    : _ambience = ambience ?? AudioPlayer(),
      _cheerPlayer = cheerPlayer ?? AudioPlayer.new;

  static const double _ambienceVolume = 0.5;
  static const double _cheerVolume = 1.0;

  final AudioPlayer _ambience;
  final AudioPlayer Function() _cheerPlayer;

  /// Cheer players still ringing. Each disposes itself the moment its
  /// cheer runs out; nothing else ever stops them.
  final Set<AudioPlayer> _ringing = {};

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

  /// A goal was scored (either side): a FRESH player plays the cheer from
  /// the top over the still-running ambience. A fresh player per goal is
  /// what lets cheers overlap — the previous cheer keeps ringing while
  /// the new one starts, however close the two goals are.
  Future<void> goalCheer() async {
    if (!_started) return;
    final player = _cheerPlayer();
    var sounded = false;
    await _guard(() async {
      // One-shot: the cheer ends by itself, never loops.
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(kCheerAsset), volume: _cheerVolume);
      sounded = true;
    });
    if (!sounded) {
      // It never made a sound (missing plugin, silent host): free the
      // player now — waiting for a completion that cannot come would
      // leak it.
      await _guard(player.dispose);
      return;
    }
    _ringing.add(player);
    // Retire the player when the cheer runs out by itself. Only this
    // path ever disposes a cheer player.
    unawaited(
      player.onPlayerComplete.first
          .then((_) => _retireCheer(player))
          .catchError((Object _) => _retireCheer(player)),
    );
  }

  /// One cheer player finishing: hands its resources back. The dispose
  /// cuts nothing that is still ringing — this runs after the cheer ended.
  void _retireCheer(AudioPlayer player) {
    _ringing.remove(player);
    unawaited(_guard(player.dispose));
  }

  /// Full time: ONLY the ambience obeys the whistle. A cheer that is
  /// still ringing plays out to its natural end over the post-match flow
  /// — the crowd does not stop celebrating because the referee blew
  /// mid-roar, and a goal at the death deserves its full celebration.
  Future<void> stop() async {
    await _guard(_ambience.stop);
  }

  /// Back navigation / screen teardown. Cheers still ringing keep
  /// ringing: each retires itself the moment it completes, so nothing
  /// needs to wait here. Stopping first also consumes the ambience's
  /// internal creation errors on platforms where audio never came up
  /// (see the library comment).
  Future<void> dispose() async {
    await stop();
    await _guard(_ambience.dispose);
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
