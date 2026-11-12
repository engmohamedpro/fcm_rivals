/// FCM Rivals — scene loading: WHEN the transition overlay shows.
///
/// `SceneLoadingTransition` (scene_loading_transition.dart) is the
/// picture; this file decides when it is on screen. The pieces:
///
///  * [SceneLoadingController] counts active loads. The overlay is shown
///    once a load has lasted [showDelay] (so near-instant loads never
///    flash it), stays up for at least [minVisible] once shown (so it
///    never flickers), and hides when the last load ends. A person who
///    dismisses it stays dismissed until the next load begins.
///  * [SceneLoadingHost] sits once above the Navigator (in
///    `MaterialApp.builder`), so the overlay covers EVERYTHING — every
///    tab, pushed route and dialog — and provides the controller.
///  * [SceneLoadingMarker] is the drop-in for a loading branch: put it
///    where a `CircularProgressIndicator` was and the overlay shows for
///    exactly as long as that branch is on screen.
///  * [SceneLoadingScope.track] wraps any Future (a route's data load, a
///    save) for code that has no loading branch of its own.
///
/// Without a host in the tree (unit tests, isolated screens) every call
/// here is a harmless no-op and the marker falls back to a plain spinner.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'scene_loading_transition.dart';

/// Counts active loads and owns the show/hide timing. See the library doc.
class SceneLoadingController extends ChangeNotifier {
  SceneLoadingController({
    this.showDelay = const Duration(milliseconds: 150),
    this.minVisible = const Duration(milliseconds: 700),
    this.hideGrace = const Duration(milliseconds: 120),
  });

  /// How long a load must last before the overlay appears.
  final Duration showDelay;

  /// Shortest time the overlay stays once it has appeared.
  final Duration minVisible;

  /// Lets back-to-back loads (one screen ends as the next begins) share
  /// one continuous overlay instead of hiding and re-showing.
  final Duration hideGrace;

  int _pending = 0;
  bool _visible = false;
  bool _dismissed = false;
  bool _disposed = false;
  DateTime? _shownAt;
  Timer? _showTimer;
  Timer? _hideTimer;

  /// Whether the overlay is on screen (it may still be fading out).
  bool get visible => _visible && !_dismissed;

  /// True while at least one load is active and not dismissed — the
  /// overlay absorbs touches only then; while it lingers after the load
  /// finished, touches reach the new screen underneath.
  bool get blocking => visible && _pending > 0;

  /// Number of loads currently registered.
  int get pending => _pending;

  /// A load started. Pair with [end]; prefer [track] or the marker.
  void begin() {
    if (_disposed) return;
    _pending++;
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_pending == 1) {
      // A fresh load: a previous dismissal no longer applies.
      _dismissed = false;
      if (_visible) {
        // Reusing a still-lingering overlay: `blocking` flips back on.
        // Deferred, because begin() may run during a build.
        scheduleMicrotask(_notify);
      }
    }
    if (!_visible && _showTimer == null) {
      _showTimer = Timer(showDelay, _show);
    }
  }

  /// A load finished. Never notifies synchronously, so it is safe to call
  /// from `dispose`.
  void end() {
    // After dispose (a marker unmounting after its host) there is nothing
    // left to time; never create a timer that would outlive the app.
    if (_disposed || _pending == 0) return;
    _pending--;
    if (_pending > 0) return;
    _showTimer?.cancel();
    _showTimer = null;
    if (_visible) {
      final shown = _shownAt;
      final elapsed = shown == null
          ? minVisible
          : DateTime.now().difference(shown);
      final remaining = minVisible - elapsed;
      final wait = remaining > hideGrace ? remaining : hideGrace;
      _hideTimer?.cancel();
      _hideTimer = Timer(wait, _hide);
      // `blocking` just flipped to false; tell listeners on the next
      // microtask so touches pass through immediately.
      scheduleMicrotask(_notify);
    }
  }

  /// Runs [future] as a load: the overlay shows while it is pending.
  Future<T> track<T>(Future<T> future) {
    begin();
    return future.whenComplete(end);
  }

  /// The person dismissed the overlay; it stays hidden until the next
  /// load begins.
  void dismiss() {
    if (!_visible || _dismissed) return;
    _dismissed = true;
    _notify();
  }

  void _show() {
    _showTimer = null;
    if (_pending == 0 || _dismissed) return;
    _visible = true;
    _shownAt = DateTime.now();
    _notify();
  }

  void _hide() {
    _hideTimer = null;
    if (_pending > 0) return;
    _visible = false;
    _shownAt = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }
}

/// Exposes the nearest [SceneLoadingController] to the tree below the
/// [SceneLoadingHost].
class SceneLoadingScope extends InheritedWidget {
  const SceneLoadingScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final SceneLoadingController controller;

  /// The controller, or null when no host is in the tree.
  static SceneLoadingController? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<SceneLoadingScope>()
      ?.controller;

  /// Shows the transition for as long as [future] is pending. Without a
  /// host it simply returns [future].
  static Future<T> track<T>(BuildContext context, Future<T> future) {
    final controller = maybeOf(context);
    return controller == null ? future : controller.track(future);
  }

  // The controller instance never changes for a host's lifetime.
  @override
  bool updateShouldNotify(SceneLoadingScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Hosts the overlay above [child] (the app's Navigator) and provides the
/// controller to everything below. Mount it once, in `MaterialApp.builder`.
class SceneLoadingHost extends StatefulWidget {
  const SceneLoadingHost({super.key, required this.child, this.controller});

  final Widget child;

  /// Optional externally-owned controller (tests); otherwise the host
  /// creates and disposes its own.
  final SceneLoadingController? controller;

  @override
  State<SceneLoadingHost> createState() => _SceneLoadingHostState();
}

class _SceneLoadingHostState extends State<SceneLoadingHost> {
  late final SceneLoadingController _controller =
      widget.controller ?? SceneLoadingController();

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SceneLoadingScope(
      controller: _controller,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned.fill(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                final visible = _controller.visible;
                return IgnorePointer(
                  ignoring: !_controller.blocking,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: visible
                        ? SceneLoadingTransition(
                            key: const ValueKey('scene-loading'),
                            onDismiss: _controller.dismiss,
                          )
                        : const SizedBox.shrink(key: ValueKey('scene-idle')),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Drop-in for a loading branch: while this widget is mounted, the scene
/// transition is requested. Renders nothing under a host (the overlay is
/// the visual); renders [fallback] — a gold spinner by default — when
/// there is no host, so isolated screens and tests still show progress.
class SceneLoadingMarker extends StatefulWidget {
  const SceneLoadingMarker({super.key, this.fallback});

  /// What to show when no [SceneLoadingHost] is above. Null means the
  /// default centred spinner.
  final Widget? fallback;

  @override
  State<SceneLoadingMarker> createState() => _SceneLoadingMarkerState();
}

class _SceneLoadingMarkerState extends State<SceneLoadingMarker> {
  SceneLoadingController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = SceneLoadingScope.maybeOf(context);
    if (!identical(next, _controller)) {
      _controller?.end();
      _controller = next;
      _controller?.begin();
    }
  }

  @override
  void dispose() {
    _controller?.end();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) return const SizedBox.shrink();
    return widget.fallback ??
        const Center(child: CircularProgressIndicator());
  }
}
