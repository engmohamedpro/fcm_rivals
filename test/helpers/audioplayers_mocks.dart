// Quiets the audioplayers platform channels for widget tests that pump
// the live match screen.
//
// MatchAudio swallows every audio failure (sound is decorative), so the
// match flow works without the plugin. But the plugin's EventChannels
// report a missing `listen` handler into FlutterError — which fails
// widget tests — when the platform side is absent. The per-player event
// stream is keyed by a UUID, so the handler is registered dynamically:
// every `create` call on the command channel registers a do-nothing
// stream handler for that player's event channel before the plugin
// listens to it.
//
// Usage: call [installAudioplayersMocks] in setUp and
// [clearAudioplayersMocks] in tearDown.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The global (all players) control channel.
const _globalChannel = MethodChannel('xyz.luan/audioplayers.global');

/// The global event stream channel (EventChannel `listen`/`cancel`).
const _globalEventsChannel = EventChannel(
  'xyz.luan/audioplayers.global/events',
);

/// The player command channel used by audioplayers 6.x.
const _playerChannel = MethodChannel('xyz.luan/audioplayers');

/// path_provider, used by AudioCache to pick a temp dir for assets.
const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

/// Event channels registered per player during this test, so they can
/// all be cleared afterwards.
final List<EventChannel> _playerEventChannels = <EventChannel>[];

void installAudioplayersMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // An empty stream handler: answers `listen`/`cancel` with silence.
  final emptyStream = MockStreamHandler.inline(
    onListen: (_, _) {},
    onCancel: (_) {},
  );

  Future<Object?> ok(MethodCall call) async => null;

  messenger.setMockMethodCallHandler(_globalChannel, ok);
  // Global events: an empty stream handler answers `listen` quietly.
  messenger.setMockStreamHandler(_globalEventsChannel, emptyStream);

  // Player commands: plain success for everything, and each `create`
  // also registers the player's event channel before the plugin wires
  // its stream — that is the `listen` that otherwise surfaces as a
  // MissingPluginException in FlutterError.
  messenger.setMockMethodCallHandler(_playerChannel, (call) async {
    if (call.method == 'create' && call.arguments is Map) {
      final playerId = (call.arguments as Map)['playerId'] as String;
      final events = EventChannel('xyz.luan/audioplayers/events/$playerId');
      messenger.setMockStreamHandler(events, emptyStream);
      _playerEventChannels.add(events);
    }
    return null;
  });

  messenger.setMockMethodCallHandler(
    _pathProviderChannel,
    (call) async => '/tmp/fcm_test_audio',
  );

  // Without a platform side, setSourceUrl never receives its "prepared"
  // event; a short timeout turns that into a quickly-swallowed error
  // inside MatchAudio instead of a 30s stall in every test.
  AudioPlayer.preparationTimeout = const Duration(milliseconds: 50);
}

void clearAudioplayersMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_globalChannel, null);
  messenger.setMockMessageHandler(_globalEventsChannel.name, null);
  messenger.setMockMethodCallHandler(_playerChannel, null);
  for (final channel in _playerEventChannels) {
    messenger.setMockMessageHandler(channel.name, null);
  }
  _playerEventChannels.clear();
  messenger.setMockMethodCallHandler(_pathProviderChannel, null);
  AudioPlayer.preparationTimeout = const Duration(seconds: 30);
}
