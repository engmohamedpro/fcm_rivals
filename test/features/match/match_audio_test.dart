// Match-day sound: the ambience must loop from kick-off to full time,
// goal cheers must play on top of it, and everything must stay quiet
// (never throw, never leak unhandled async errors) where the audio
// plugin is absent — the case in every widget test and on any host
// without the platform channel.
//
// The platform layer is mocked at the method-channel level with the
// exact channel and method names audioplayers 6.8.1 sends, so the
// assertions exercise the real call path: xyz.luan/audioplayers for
// player commands, xyz.luan/audioplayers.global for init, and the
// path_provider + rootBundle lookups behind asset loading.
import 'dart:async' show unawaited;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/match_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Calls seen on the audioplayers platform channel. Player commands are
  // tagged with the method; the two players share the channel, so tests
  // that need to tell them apart count calls instead.
  final calls = <String>[];
  // Temp roots handed to path_provider; each getTemporaryDirectory call
  // makes a fresh one so players never share cache files.
  var tempDirCounter = 0;

  const playerChannel = MethodChannel('xyz.luan/audioplayers');
  const globalChannel = MethodChannel('xyz.luan/audioplayers.global');

  void installMocks() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Player commands: create/setReleaseMode/setVolume/setSourceUrl/
    // resume/stop/release/dispose all land here. Every setSourceUrl is
    // answered with a "prepared" event on the player's event channel,
    // which the plugin awaits before playback can proceed.
    messenger.setMockMethodCallHandler(playerChannel, (call) async {
      calls.add('${call.method}:${call.arguments}');
      if (call.method == 'setSourceUrl' && call.arguments is Map) {
        final playerId = (call.arguments as Map)['playerId'] as String;
        // Answer with a "prepared" event on the player's event channel —
        // the plugin awaits it before playback proceeds. It must be a
        // success envelope (EventChannel decodes envelopes, not raw
        // messages) and delivered without awaiting here, or the outbound
        // call would re-enter the messenger and deadlock.
        unawaited(
          messenger.handlePlatformMessage(
            'xyz.luan/audioplayers/events/$playerId',
            const StandardMethodCodec().encodeSuccessEnvelope(<String, dynamic>{
              'event': 'audio.onPrepared',
              'value': true,
            }),
            null,
          ),
        );
      }
      return null;
    });

    // Global init, awaited by every AudioPlayer creation.
    messenger.setMockMethodCallHandler(globalChannel, (call) async {
      calls.add('global.${call.method}:${call.arguments}');
      return null;
    });

    // path_provider: a fresh temp directory per player.
    tempDirCounter = 0;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async {
        tempDirCounter++;
        return '/tmp/fcm_test_audio_$tempDirCounter';
      },
    );

    // Asset loading: the real bytes for both shipped files, so
    // AudioCache.loadPath succeeds and setSourceUrl receives a real
    // local path. The request is the raw UTF-8 asset key (no codec
    // envelope); unknown keys fail loudly instead of passing silently.
    Future<ByteData?> loadAsset(ByteData? message) async {
      final key = message == null
          ? null
          : String.fromCharCodes(message.buffer.asUint8List()).trim();
      final asset = <String, List<int>>{
        'assets/audio/live_match.mp3': List.filled(64, 0x01),
        'assets/audio/goal_cheers.mp3': List.filled(64, 0x02),
      }[key];
      if (asset == null) throw StateError('missing asset $key');
      return const StandardMessageCodec().encodeMessage(
        Uint8List.fromList(asset),
      );
    }

    messenger.setMockMessageHandler('flutter/assets', loadAsset);
  }

  setUp(() {
    calls.clear();
    installMocks();
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(playerChannel, null);
    messenger.setMockMethodCallHandler(globalChannel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMessageHandler('flutter/assets', null);
  });

  group('MatchAudio with the platform mocked', () {
    test('start loops the ambience asset at its bed volume', () async {
      final audio = MatchAudio();
      await audio.start();

      expect(
        calls,
        containsAllInOrder([
          matches(RegExp(r'setReleaseMode:.*loop')),
          matches(RegExp(r'setVolume:.*0\.5')),
          matches(RegExp(r'setSourceUrl:.*live_match\.mp3')),
          matches(RegExp(r'resume:')),
        ]),
        reason:
            'the ambience must be set to loop, ducked to its bed '
            'volume, sourced from the asset and played',
      );
      await audio.dispose();
    });

    test('goalCheer plays the cheer once on top of the ambience', () async {
      final audio = MatchAudio();
      await audio.start();
      calls.clear();

      await audio.goalCheer();

      expect(
        calls,
        containsAllInOrder([
          matches(RegExp(r'setVolume:.*1\.0')),
          matches(RegExp(r'setSourceUrl:.*goal_cheers\.mp3')),
          matches(RegExp(r'resume:')),
        ]),
        reason:
            'a goal plays the cheer at full volume over the '
            'still-looping ambience',
      );
      // The cheer never stops the ambience underneath it.
      expect(calls.any((c) => c.startsWith('stop:')), isFalse);
      await audio.dispose();
    });

    test('start is idempotent — no second loop stacks on the player', () async {
      final audio = MatchAudio();
      await audio.start();
      // The plugin pings getCurrentPosition around actions; ignore those
      // and count only the calls that would duplicate playback setup.
      final setupAfterFirst = calls
          .where(
            (c) =>
                c.startsWith('setReleaseMode:') ||
                c.startsWith('setSourceUrl:') ||
                c.startsWith('resume:'),
          )
          .length;
      await audio.start();
      final setupAfterSecond = calls
          .where(
            (c) =>
                c.startsWith('setReleaseMode:') ||
                c.startsWith('setSourceUrl:') ||
                c.startsWith('resume:'),
          )
          .length;

      expect(
        setupAfterSecond,
        setupAfterFirst,
        reason:
            'a repeated start must not re-issue loop mode, source or '
            'resume on the player',
      );
      await audio.dispose();
    });

    test('stop halts both players (full time)', () async {
      final audio = MatchAudio();
      await audio.start();
      await audio.goalCheer();
      calls.clear();

      await audio.stop();

      expect(
        calls.where((c) => c.startsWith('stop:')).length,
        2,
        reason:
            'both the ambience and any running cheer stop at the '
            'final whistle',
      );
      await audio.dispose();
    });

    test('dispose stops and releases both players', () async {
      final audio = MatchAudio();
      await audio.start();
      calls.clear();

      await audio.dispose();

      // dispose() internally calls release() per player, whose stop also
      // lands on the channel: two stops and two releases per player is
      // the plugin's own dispose path, so expect the doubled count.
      expect(calls.where((c) => c.startsWith('stop:')).length, 4);
      expect(calls.where((c) => c.startsWith('release:')).length, 2);
    });

    test('goalCheer is ignored before kick-off', () async {
      final audio = MatchAudio();
      await audio.goalCheer();
      // The two players still register themselves (create + position
      // pings), but nothing that would make sound may be issued.
      expect(
        calls
            .where(
              (c) =>
                  c.startsWith('setReleaseMode:') ||
                  c.startsWith('setSourceUrl:') ||
                  c.startsWith('resume:'),
            )
            .isEmpty,
        isTrue,
        reason: 'no cheer can sound before the ambience has kicked off',
      );
      await audio.dispose();
    });
  });

  group('MatchAudio without the plugin (tests, quiet hosts)', () {
    test('all lifecycle calls complete silently', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        playerChannel,
        (call) async => throw MissingPluginException(),
      );
      messenger.setMockMethodCallHandler(
        globalChannel,
        (call) async => throw MissingPluginException(),
      );

      final audio = MatchAudio();
      await audio.start();
      await audio.goalCheer();
      await audio.stop();
      await audio.dispose();
      // Reaching here without throwing (and with no unhandled async
      // error failing the test) is exactly the contract.
    });
  });

  test('asset constants point at the shipped files', () {
    expect(kAmbienceAsset, 'audio/live_match.mp3');
    expect(kCheerAsset, 'audio/goal_cheers.mp3');
  });
}
