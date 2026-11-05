/// FCM Rivals — match-day sound.
///
/// The stadium ambience (assets/audio/live_match.mp3) follows the match
/// clock: it starts looping with the first-half kick-off, ends with the
/// half-time whistle, comes back with the second-half kick-off and ends
/// for good at full time. The user's pause button holds it mid-loop —
/// pause holds, resume releases — so the bed never sounds over a match
/// that is not being played.
///
/// A goal cheer (assets/audio/goal_cheers.mp3) plays on top whenever a
/// goal goes in, by either side. Each cheer runs on its OWN one-shot
/// player: two goals close together ring out on top of each other (the
/// second never cuts the first), and a cheer that is already ringing is
/// never cut by anything else either — not by the next goal, not by the
/// half-time or full-time whistle, not by the screen tearing down. It
/// always plays to its natural end, then retires its player by itself.
/// Home goals ring out at full volume; away goals get a much quieter
/// cheer — the crowd is the home crowd.
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

/// Where the ambience bed stands in the match.
enum _AmbiencePhase {
  /// Before the first-half kick-off: nothing sounds yet.
  idle,

  /// A half is being played: the bed loops.
  playing,

  /// The user holds the match: the bed is held mid-loop.
  paused,

  /// Between the halves: the bed is silent until the second-half
  /// kick-off brings it back.
  breaking,

  /// After the final whistle: the bed is done for good.
  finished,
}

class MatchAudio {
  /// [ambience] and [cheerPlayer] exist for tests; production leaves them
  /// null and gets a plain [AudioPlayer] bed plus a fresh one-shot player
  /// per goal.
  MatchAudio({AudioPlayer? ambience, AudioPlayer Function()? cheerPlayer})
    : _ambience = ambience ?? AudioPlayer(),
      _cheerPlayer = cheerPlayer ?? AudioPlayer.new;

  static const double _ambienceVolume = 0.5;

  /// Home goals ring out at full volume — the crowd is the home crowd.
  static const double _homeCheerVolume = 1.0;

  /// Away goals get a much quieter cheer: the same cheer, held down to
  /// the away end's pocket of fans.
  static const double _awayCheerVolume = 0.3;

  final AudioPlayer _ambience;
  final AudioPlayer Function() _cheerPlayer;

  /// Cheer players still ringing. Each disposes itself the moment its
  /// cheer runs out; nothing else ever stops them.
  final Set<AudioPlayer> _ringing = {};

  _AmbiencePhase _phase = _AmbiencePhase.idle;

  /// First-half kick-off: starts the ambience looping. Idempotent, so a
  /// rebuild or a repeated call cannot stack a second loop on the same
  /// player. The second half is brought back by [secondHalfKickOff],
  /// never by calling start again.
  Future<void> start() async {
    if (_phase != _AmbiencePhase.idle) return;
    _phase = _AmbiencePhase.playing;
    await _guard(() async {
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.play(
        AssetSource(kAmbienceAsset),
        volume: _ambienceVolume,
      );
    });
  }

  /// Half time: the whistle ends the first half, and the bed with it —
  /// nothing sounds over the break. Idempotent against a duplicated
  /// event; a bed that never started or already ended just ignores it.
  Future<void> halfTimeBreak() async {
    if (_phase != _AmbiencePhase.playing && _phase != _AmbiencePhase.paused) {
      return;
    }
    _phase = _AmbiencePhase.breaking;
    await _guard(_ambience.stop);
  }

  /// Second-half kick-off: the bed returns from the top of its loop.
  /// Only a break leads back in — a duplicated event, or a call while
  /// already playing, is ignored.
  Future<void> secondHalfKickOff() async {
    if (_phase != _AmbiencePhase.breaking) return;
    _phase = _AmbiencePhase.playing;
    await _guard(() async {
      await _ambience.setReleaseMode(ReleaseMode.loop);
      await _ambience.play(
        AssetSource(kAmbienceAsset),
        volume: _ambienceVolume,
      );
    });
  }

  /// The user held the match: the bed is held mid-loop with it. A hold
  /// during the half-time break or after full time is ignored — there
  /// is nothing sounding to hold.
  Future<void> pause() async {
    if (_phase != _AmbiencePhase.playing) return;
    _phase = _AmbiencePhase.paused;
    await _guard(_ambience.pause);
  }

  /// The user released the match: a held bed picks up where it was
  /// held. Releasing during the half-time break is ignored — the bed
  /// returns with the second-half kick-off, not with the button.
  Future<void> resume() async {
    if (_phase != _AmbiencePhase.paused) return;
    _phase = _AmbiencePhase.playing;
    await _guard(_ambience.resume);
  }

  /// A goal went in ([isHome] says which end it went in at). A FRESH
  /// player plays the cheer from the top over the ambience — home goals
  /// at the home crowd's volume, away goals much quieter. A fresh player
  /// per goal is what lets cheers overlap: the previous cheer keeps
  /// ringing while the new one starts, however close the two goals are.
  Future<void> goalCheer({required bool isHome}) async {
    if (_phase == _AmbiencePhase.idle) return;
    final player = _cheerPlayer();
    var sounded = false;
    await _guard(() async {
      // One-shot: the cheer ends by itself, never loops.
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(
        AssetSource(kCheerAsset),
        volume: isHome ? _homeCheerVolume : _awayCheerVolume,
      );
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
  /// A stop before kick-off still runs (it consumes the player's
  /// creation errors on hosts where audio never came up) but leaves the
  /// phase alone, so a later start remains possible.
  Future<void> stop() async {
    if (_phase == _AmbiencePhase.finished) return;
    final wasIdle = _phase == _AmbiencePhase.idle;
    if (!wasIdle) _phase = _AmbiencePhase.finished;
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
