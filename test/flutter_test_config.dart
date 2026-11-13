// FCM Rivals — global widget-test configuration (T-0103).
//
// Every `flutter test` run loads this file once PER TEST FILE, before
// any test or setUp in that file runs. Installing the audioplayers
// channel mocks here makes the pack reveal soundtrack (and any other
// sfx call site) resolve silently in EVERY test — no per-file import,
// no innocent-bystander MissingPluginException flakes when an async
// sound call lands inside a later, unrelated test.
//
// The per-file helpers in `audioplayers_mocks.dart` cannot be reused
// verbatim here: `setMockStreamHandler` registers an addTearDown, and
// `testExecutable` runs OUTSIDE any test. So this config installs the
// same channels through raw binary-messenger message handlers —
// semantically identical (an empty stream answers `listen`/`cancel`
// with silence; player commands return null; path_provider returns a
// temp dir), but with nothing to tear down: the binding resets its
// mock handlers between test files on its own.
//
// Runtime audio behavior is untouched: these handlers only exist in
// the test binding, never in a debug/profile/release build.
import 'dart:async' show FutureOr;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

/// Streams registered per player (its command `create` call carries the
/// id): each gets an empty-stream message handler so the plugin's
/// `listen` never surfaces as a MissingPluginException.
final _playerEventChannels = <String>[];

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // The mocks talk to the test binding's binary messenger; ensure it
  // exists before the first test file loads (testExecutable runs
  // pre-suite, before any test creates a binding itself).
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestWidgetsFlutterBinding.instance.defaultBinaryMessenger;

  Future<Object?> ok(MethodCall call) async => null;

  // An empty event stream: `listen` and `cancel` both return silence.
  Future<ByteData?> emptyStream(ByteData? message) async {
    final codec = StandardMethodCodec();
    return codec.encodeSuccessEnvelope(null);
  }

  // Global events.
  messenger.setMockMessageHandler(
    'xyz.luan/audioplayers.global/events',
    emptyStream,
  );

  // Player commands: null for everything; a `create` also wires that
  // player's event channel before the plugin listens to it.
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      if (call.method == 'create' && call.arguments is Map) {
        final playerId = (call.arguments as Map)['playerId'] as String;
        final name = 'xyz.luan/audioplayers/events/$playerId';
        _playerEventChannels.add(name);
        messenger.setMockMessageHandler(name, emptyStream);
      }
      return null;
    },
  );

  // path_provider (AudioCache's temp dir).
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => '/tmp/fcm_test_audio',
  );

  // Global control channel (sourceId etc.) — plain success.
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    ok,
  );

  await testMain();
}
