/// FCM Rivals — one-shot sound effects for the big visual moments (pack
/// opening, card merge).
///
/// Every cue is a short file in assets/audio (rendered by
/// tool/generate_sfx.py — swap any of them for a recorded file of the same
/// name and nothing else changes). Each play runs on its OWN player so
/// cues overlap freely, mixes with whatever else is playing (the user's
/// music is never paused), and retires itself when it finishes.
///
/// Like the match audio, every platform call is best-effort: a missing
/// plugin (widget tests), a silent device or a failed decode must never
/// break the animation it decorates.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;

/// A sound effect: its asset, its natural length, and its mix level.
enum SfxCue {
  tick('audio/sfx_tick.mp3', 0.14, 0.55),
  thud('audio/sfx_thud.mp3', 0.75, 0.85),
  whoosh('audio/sfx_whoosh.mp3', 0.85, 0.7),
  packRiserNormal('audio/sfx_pack_riser_normal.mp3', 1.6, 0.8),
  packRiserLegend('audio/sfx_pack_riser_legend.mp3', 2.2, 0.85),
  packRiserPremium('audio/sfx_pack_riser_premium.mp3', 3.2, 0.9),
  packBurstNormal('audio/sfx_pack_burst_normal.mp3', 3.8, 0.9),
  packBurstLegend('audio/sfx_pack_burst_legend.mp3', 4.6, 0.95),
  packBurstPremium('audio/sfx_pack_burst_premium.mp3', 5.6, 1.0),
  packNameNormal('audio/sfx_pack_name_normal.mp3', 2.0, 0.8),
  packNameLegend('audio/sfx_pack_name_legend.mp3', 3.4, 0.85),
  packNamePremium('audio/sfx_pack_name_premium.mp3', 4.8, 0.9),
  packFinale('audio/sfx_pack_finale.mp3', 4.8, 0.9),
  mergeCharge('audio/sfx_merge_charge.mp3', 1.5, 0.85),
  mergeImpact('audio/sfx_merge_impact.mp3', 4.4, 1.0),
  mergeLevelUp('audio/sfx_merge_levelup.mp3', 3.2, 0.85);

  const SfxCue(this.asset, this.seconds, this.volume);

  /// Asset path relative to `assets/` (what [AssetSource] expects).
  final String asset;

  /// Natural length in seconds — lets callers start a riser early enough
  /// that it ends exactly on the beat it builds to.
  final double seconds;

  /// Base mix level, 0..1; [FcmSfx.play] scales it.
  final double volume;
}

class FcmSfx {
  /// [playerFactory] exists for tests; production gets a plain
  /// [AudioPlayer] per cue.
  FcmSfx({AudioPlayer Function()? playerFactory})
    : _playerFactory = playerFactory ?? AudioPlayer.new;

  /// Master switch for every effect. Defaults on; a settings toggle can
  /// flip it without touching any call site.
  static bool enabled = true;

  final AudioPlayer Function() _playerFactory;

  /// Players still sounding. Each retires itself when its cue ends;
  /// those flagged [_cutOnDispose] are also stopped by [dispose].
  final Set<AudioPlayer> _ringing = {};
  final Set<AudioPlayer> _cutOnDispose = {};
  bool _disposed = false;

  /// Warms the asset cache so the first play of each cue has no decode
  /// delay in the middle of an animation.
  Future<void> preload(Iterable<SfxCue> cues) async {
    if (!enabled) return;
    await _guard(() async {
      await AudioCache.instance.loadAll({for (final c in cues) c.asset}.toList());
    });
  }

  /// Plays [cue] now. [volume] scales the cue's own level, [rate] bends
  /// its pitch/speed (1.0 = as recorded) and [cutOnDispose] marks a cue
  /// that must not outlive the screen (a charge riser, say).
  Future<void> play(
    SfxCue cue, {
    double volume = 1.0,
    double rate = 1.0,
    bool cutOnDispose = false,
  }) async {
    if (!enabled || _disposed) return;
    final player = _playerFactory();
    var sounded = false;
    await _guard(() async {
      await player.setReleaseMode(ReleaseMode.stop);
      // Mix with other audio: never pause the user's music, never cut
      // another cue by taking exclusive focus.
      await player.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      if (rate != 1.0) await player.setPlaybackRate(rate);
      await player.play(
        AssetSource(cue.asset),
        volume: (cue.volume * volume).clamp(0.0, 1.0),
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
    if (_disposed && cutOnDispose) {
      // The screen went away while the cue was starting.
      await _guard(player.dispose);
      return;
    }
    _ringing.add(player);
    if (cutOnDispose) _cutOnDispose.add(player);
    unawaited(
      player.onPlayerComplete.first
          .then((_) => _retire(player))
          .catchError((Object _) => _retire(player)),
    );
  }

  void _retire(AudioPlayer player) {
    _ringing.remove(player);
    _cutOnDispose.remove(player);
    unawaited(_guard(player.dispose));
  }

  /// Screen teardown: cues flagged [cutOnDispose] stop at once; the rest
  /// ring out and retire themselves (a closing chime should finish).
  Future<void> dispose() async {
    _disposed = true;
    for (final p in _cutOnDispose.toList()) {
      _ringing.remove(p);
      _cutOnDispose.remove(p);
      await _guard(p.stop);
      await _guard(p.dispose);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on MissingPluginException {
      // Widget tests and hosts without the audio plugin: expected, quiet.
    } catch (e) {
      assert(() {
        debugPrint('FcmSfx: $e');
        return true;
      }());
    }
  }
}
