import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Short sound effects from assets/sounds/<name>.wav. Never throws.
class Sounds {
  Sounds({required bool Function() enabled})
      : _enabled = enabled,
        _silent = false;

  /// A sounds object that never plays anything (tests).
  Sounds.silent()
      : _enabled = (() => false),
        _silent = true;

  final bool Function() _enabled;
  final bool _silent;
  final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};
  bool _disposed = false;

  void play(String name) {
    if (_silent || _disposed || !_enabled()) {
      return;
    }
    unawaited(_play(name));
  }

  Future<void> _play(String name) async {
    try {
      var p = _players[name];
      if (p == null) {
        p = AudioPlayer();
        _players[name] = p;
        try {
          await p.setPlayerMode(PlayerMode.lowLatency);
        } catch (_) {}
      }
      if (_disposed) {
        return;
      }
      try {
        await p.stop();
      } catch (_) {}
      await p.play(AssetSource('sounds/$name.wav'));
    } catch (_) {
      // Audio problems must never reach the UI.
    }
  }

  void dispose() {
    _disposed = true;
    for (final p in _players.values) {
      try {
        unawaited(p.dispose().catchError((Object _) {}));
      } catch (_) {}
    }
    _players.clear();
  }
}
