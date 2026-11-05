// Match-day sound: the ambience must follow the match clock — looping
// from the first-half kick-off until the half-time whistle, back with
// the second-half kick-off, ended for good at full time, and held
// mid-loop by the user's pause. Every goal must play its cheer IN FULL
// on its own one-shot player — cheers overlap instead of cutting each
// other, and neither the full-time whistle nor half time nor screen
// teardown cuts a cheer that is still ringing; home goals ring at full
// volume, away goals much quieter. Everything must stay quiet (never
// throw, never leak unhandled async errors) where the audio plugin is
// absent — the case in every widget test and on any host without the
// platform channel.
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

/// One recorded player command: the method, the player it ran on, and
/// the full argument string (urls, volumes) for needle lookups.
final List<({String method, String playerId, String full})> playerCalls = [];

/// Set by installMocks; fires the plugin's completion event for one
/// player through its event channel, so a test can retire a cheer on cue.
late void Function(String playerId) sendCompleteEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Calls seen on the audioplayers platform channel, with full arguments
  // (volumes, sources) for content assertions.
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
    // resume/stop/release/dispose all land here. setSourceUrl is
    // answered with a "prepared" event, and a helper lets tests fire
    // "complete" for a specific player so a cheer can be retired on
    // cue. Both are delivered without awaiting here, or the outbound
    // call would re-enter the messenger and deadlock.
    void sendEvent(String playerId, Map<String, dynamic> payload) {
      unawaited(
        messenger.handlePlatformMessage(
          'xyz.luan/audioplayers/events/$playerId',
          const StandardMethodCodec().encodeSuccessEnvelope(payload),
          null,
        ),
      );
    }

    playerCalls.clear();
    messenger.setMockMethodCallHandler(playerChannel, (call) async {
      final playerId = call.arguments is Map
          ? (call.arguments as Map)['playerId']
          : null;
      final full = '${call.method}:${call.arguments}';
      if (playerId is String) {
        playerCalls.add((method: call.method, playerId: playerId, full: full));
      }
      calls.add(full);
      if (call.method == 'setSourceUrl' && call.arguments is Map) {
        final playerId = (call.arguments as Map)['playerId'] as String;
        sendEvent(playerId, const <String, dynamic>{
          'event': 'audio.onPrepared',
          'value': true,
        });
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

    // Exposed for the tests below: retire a ringing cheer on cue.
    sendCompleteEvent = (String playerId) =>
        sendEvent(playerId, const {'event': 'audio.onComplete'});
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

    test(
      'a home goal plays the cheer at full volume over the ambience',
      () async {
        final audio = MatchAudio();
        await audio.start();
        calls.clear();
        playerCalls.clear();

        await audio.goalCheer(isHome: true);

        expect(
          calls,
          containsAllInOrder([
            matches(RegExp(r'setReleaseMode:.*stop')),
            matches(RegExp(r'setVolume:.*1\.0')),
            matches(RegExp(r'setSourceUrl:.*goal_cheers\.mp3')),
            matches(RegExp(r'resume:')),
          ]),
          reason:
              'a home goal plays the cheer at the home crowd\'s volume over '
              'the still-looping ambience',
        );
        // The cheer never stops the ambience underneath it.
        expect(
          playerCalls.where((c) => c.method == 'stop'),
          isEmpty,
          reason: 'nothing was stopped',
        );
        await audio.dispose();
      },
    );

    test('an away goal plays the same cheer much quieter', () async {
      final audio = MatchAudio();
      await audio.start();
      calls.clear();
      playerCalls.clear();

      await audio.goalCheer(isHome: false);

      expect(
        calls,
        containsAllInOrder([
          matches(RegExp(r'setReleaseMode:.*stop')),
          matches(RegExp(r'setVolume:.*0\.3')),
          matches(RegExp(r'setSourceUrl:.*goal_cheers\.mp3')),
          matches(RegExp(r'resume:')),
        ]),
        reason:
            'an away goal still gets its full cheer, held down to the '
            'away end\'s pocket of fans',
      );
      await audio.dispose();
    });

    test('home and away goals stack without touching each other', () async {
      final audio = MatchAudio();
      await audio.start();
      calls.clear();
      playerCalls.clear();

      // An away goal lands, then a home goal a second later — one at
      // each volume, neither cutting the other.
      await audio.goalCheer(isHome: false);
      await audio.goalCheer(isHome: true);

      final cheerVolumes = playerCalls
          .where(
            (c) =>
                c.method == 'setVolume' && c.full.contains('0.3') ||
                (c.method == 'setVolume' && c.full.contains('1.0')),
          )
          .length;
      expect(cheerVolumes, 2, reason: 'two cheers, one per volume');
      expect(
        playerCalls.where((c) => c.method == 'stop'),
        isEmpty,
        reason: 'no cheer cuts the other',
      );
      await audio.dispose();
    });

    test('two cheers close together stack on top of each other', () async {
      final audio = MatchAudio();
      await audio.start();
      calls.clear();
      playerCalls.clear();

      // The second goal lands while the first cheer is still ringing —
      // two home goals, the loudest case.
      await audio.goalCheer(isHome: true);
      await audio.goalCheer(isHome: true);

      // Two distinct one-shot players, each with its own full source
      // setup: the second play never restarts or cuts the first.
      final cheerPlayers = playerCalls
          .where(
            (c) => c.method == 'setSourceUrl' && c.full.contains('goal_cheers'),
          )
          .map((c) => c.playerId)
          .toSet();
      expect(
        cheerPlayers.length,
        2,
        reason: 'two goals in quick succession get two distinct players',
      );
      expect(
        playerCalls.where((c) => c.method == 'stop'),
        isEmpty,
        reason: 'the second cheer must not stop the first',
      );
      await audio.dispose();
    });

    test(
      'a ringing cheer is not cut by stop (full time / half time)',
      () async {
        final audio = MatchAudio();
        await audio.start();
        final ambienceId = _idOfFirst('setSourceUrl', 'live_match');
        await audio.goalCheer(isHome: true);
        final cheerId = _idOfFirst('setSourceUrl', 'goal_cheers');
        expect(cheerId, isNotNull);
        calls.clear();
        playerCalls.clear();

        await audio.stop();

        // Only the ambience player was stopped; the cheer's player is
        // untouched and keeps ringing to its natural end.
        final stoppedIds = playerCalls
            .where((c) => c.method == 'stop')
            .map((c) => c.playerId)
            .toSet();
        expect(stoppedIds, {
          ambienceId,
        }, reason: 'the whistle stops only the bed');
        expect(
          stoppedIds.contains(cheerId),
          isFalse,
          reason: 'the ringing cheer survives the final whistle',
        );
        await audio.dispose();
      },
    );

    test(
      'half time ends the ambience for the break, then it returns',
      () async {
        final audio = MatchAudio();
        await audio.start();
        final ambienceId = _idOfFirst('setSourceUrl', 'live_match');
        expect(ambienceId, isNotNull);
        calls.clear();
        playerCalls.clear();

        // The half-time whistle: the bed goes silent for the break.
        await audio.halfTimeBreak();

        final stoppedIds = playerCalls
            .where((c) => c.method == 'stop')
            .map((c) => c.playerId)
            .toSet();
        expect(stoppedIds, {
          ambienceId,
        }, reason: 'half time stops the bed, and nothing else');

        // The break ends: the second-half kick-off brings the bed back on
        // the SAME player, from the top of its loop.
        calls.clear();
        playerCalls.clear();
        await audio.secondHalfKickOff();

        expect(
          calls,
          containsAllInOrder([
            matches(RegExp(r'setReleaseMode:.*loop')),
            matches(RegExp(r'setVolume:.*0\.5')),
            matches(RegExp(r'setSourceUrl:.*live_match\.mp3')),
            matches(RegExp(r'resume:')),
          ]),
          reason: 'the second half loops the ambience again in full setup',
        );
        await audio.dispose();
      },
    );

    test(
      'a duplicated second-half event does not stack a second loop',
      () async {
        final audio = MatchAudio();
        await audio.start();
        await audio.halfTimeBreak();
        await audio.secondHalfKickOff();
        calls.clear();

        // A repeated kickoff event while already playing: ignored, the
        // bed must not re-issue loop mode or resume.
        await audio.secondHalfKickOff();

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
          reason: 'a repeated kick-off must not restart the loop',
        );
        await audio.dispose();
      },
    );

    test(
      'the pause button holds the bed mid-loop, resume releases it',
      () async {
        final audio = MatchAudio();
        await audio.start();
        final ambienceId = _idOfFirst('setSourceUrl', 'live_match');
        calls.clear();
        playerCalls.clear();

        // The user holds the match: the bed holds with it — pause, not
        // stop, so it picks up where it was held.
        await audio.pause();
        expect(
          playerCalls.where((c) => c.method == 'pause').map((c) => c.playerId),
          contains(ambienceId),
          reason: 'a held match holds the ambience mid-loop',
        );
        // Nothing was stopped or re-sourced while held.
        expect(
          playerCalls.where((c) => c.method == 'stop').isEmpty,
          isTrue,
          reason: 'a hold is not a stop',
        );

        // The user releases the match: the bed continues.
        calls.clear();
        playerCalls.clear();
        await audio.resume();
        expect(
          playerCalls.where((c) => c.method == 'resume').map((c) => c.playerId),
          contains(ambienceId),
          reason: 'the released match releases the ambience',
        );
        // And it keeps looping over the release — no re-source, no new
        // loop setup, no stop.
        expect(
          playerCalls
              .where(
                (c) =>
                    c.method == 'setSourceUrl' ||
                    c.method == 'setReleaseMode' ||
                    c.method == 'stop',
              )
              .isEmpty,
          isTrue,
          reason: 'a resume continues the held loop where it stood',
        );
        await audio.dispose();
      },
    );

    test('pause during the break or after full time is ignored', () async {
      final audio = MatchAudio();
      await audio.start();
      await audio.halfTimeBreak();
      calls.clear();
      playerCalls.clear();

      // The user taps hold while the bed is already silent for the
      // break: nothing sounds, nothing to hold — ignored.
      await audio.pause();
      await audio.resume();
      expect(
        playerCalls.where((c) => c.method == 'pause' || c.method == 'resume'),
        isEmpty,
        reason: 'the bed only follows the button while a half plays',
      );
      await audio.dispose();
    });

    test('stop before kick-off still consumes player errors', () async {
      final audio = MatchAudio();
      // A stop before start: the phase stays idle, so a later start is
      // still possible — the back-navigation-before-kick-off corner.
      await audio.stop();
      calls.clear();

      await audio.start();
      expect(
        calls,
        containsAllInOrder([
          matches(RegExp(r'setReleaseMode:.*loop')),
          matches(RegExp(r'setSourceUrl:.*live_match\.mp3')),
          matches(RegExp(r'resume:')),
        ]),
        reason: 'a stop before kick-off does not block a later start',
      );
      await audio.dispose();
    });

    test('a ringing cheer is not cut by dispose (back navigation)', () async {
      final audio = MatchAudio();
      await audio.start();
      final ambienceId = _idOfFirst('setSourceUrl', 'live_match');
      await audio.goalCheer(isHome: true);
      final cheerId = _idOfFirst('setSourceUrl', 'goal_cheers');
      calls.clear();
      playerCalls.clear();

      await audio.dispose();

      // Teardown touches only the ambience: no cheer player is stopped,
      // released or disposed here — it retires itself when its cheer
      // completes.
      final touchedIds = playerCalls
          .where(
            (c) =>
                c.method == 'stop' ||
                c.method == 'release' ||
                c.method == 'dispose',
          )
          .map((c) => c.playerId)
          .toSet();
      expect(touchedIds, {
        ambienceId,
      }, reason: 'only the ambience is torn down');
      expect(
        touchedIds.contains(cheerId),
        isFalse,
        reason: 'the ringing cheer outlives the screen',
      );
    });

    test('a finished cheer retires its own player', () async {
      final audio = MatchAudio();
      await audio.start();
      calls.clear();
      playerCalls.clear();

      await audio.goalCheer(isHome: true);
      final cheerId = _idOfFirst('setSourceUrl', 'goal_cheers');
      expect(cheerId, isNotNull);

      // The cheer runs out on its own: the platform fires complete.
      sendCompleteEvent(cheerId!);
      // The retirement goes through microtask turns; let them land.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        playerCalls.where((c) => c.method == 'dispose').map((c) => c.playerId),
        contains(cheerId),
        reason: 'the finished cheer frees its own player',
      );
      await audio.dispose();
    });

    test('start is idempotent — no second loop stacks on the player', () async {
      final audio = MatchAudio();
      await audio.start();
      // The plugin pings getCurrentPosition around actions; ignore those
      // and count only the calls that would duplicate playback setup.
      int setupCalls() => calls
          .where(
            (c) =>
                c.startsWith('setReleaseMode:') ||
                c.startsWith('setSourceUrl:') ||
                c.startsWith('resume:'),
          )
          .length;

      final afterFirst = setupCalls();
      await audio.start();

      expect(
        setupCalls(),
        afterFirst,
        reason:
            'a repeated start must not re-issue loop mode, source or '
            'resume on the player',
      );
      await audio.dispose();
    });

    test('stop halts the ambience only (full time)', () async {
      final audio = MatchAudio();
      await audio.start();
      final ambienceId = _idOfFirst('setSourceUrl', 'live_match');
      await audio.goalCheer(isHome: true);
      calls.clear();
      playerCalls.clear();

      await audio.stop();

      final stoppedIds = playerCalls
          .where((c) => c.method == 'stop')
          .map((c) => c.playerId)
          .toSet();
      expect(stoppedIds, {
        ambienceId,
      }, reason: 'full time stops the ambience and nothing else');
      await audio.dispose();
    });

    test('goalCheer is ignored before kick-off', () async {
      final audio = MatchAudio();
      await audio.goalCheer(isHome: true);
      // The ambience player may still register itself (create + position
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
      await audio.goalCheer(isHome: true);
      await audio.goalCheer(isHome: false);
      await audio.pause();
      await audio.resume();
      await audio.halfTimeBreak();
      await audio.secondHalfKickOff();
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

/// The player id of the first [method] call whose arguments mention
/// [needle] (asset url, volume, …); null when nothing matched.
String? _idOfFirst(String method, String needle) {
  for (final record in playerCalls) {
    if (record.method == method && record.full.contains(needle)) {
      return record.playerId;
    }
  }
  return null;
}
