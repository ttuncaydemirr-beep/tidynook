// Haptic tick when an item snaps into its slot (Settings > Vibration, default on).
// Uses Flutter's HapticFeedback (the system "click"): no plugin and no VIBRATE permission needed
// for it. Does nothing on the web and never throws.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Haptics {
  /// [enabled] is read on every call; wire it to Progress.vibration: `Haptics(enabled: () => progress.vibration)`.
  Haptics({bool Function()? enabled}) : _enabled = enabled ?? (() => true);

  final bool Function() _enabled;

  /// Tests: every tick is reported here.
  @visibleForTesting
  static void Function(String kind)? debugSink;

  bool get _on {
    try {
      return _enabled();
    } catch (_) {
      return false;
    }
  }

  /// Light tick: an item snapped into its slot.
  void tick() => _fire('tick', HapticFeedback.selectionClick);

  /// Slightly stronger: the box is complete (lid closes).
  void success() => _fire('success', HapticFeedback.mediumImpact);

  void _fire(String kind, Future<void> Function() fn) {
    if (!_on) {
      return;
    }
    debugSink?.call(kind);
    if (kIsWeb) {
      return;
    }
    try {
      unawaited(fn().catchError((Object _) {}));
    } catch (_) {}
  }
}
