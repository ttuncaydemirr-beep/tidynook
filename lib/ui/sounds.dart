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

  static const List<String> _names = <String>[
    'deco',
    'hint',
    'lid_close',
    'lid_open',
    'miss',
    'pick',
    'place',
    'room',
    'toggle',
    'win',
  ];

  static Future<void>? _contextDone;

  /// Effects mix with the player's own music instead of taking audio focus.
  static Future<void> _ensureContext() {
    return _contextDone ??= () async {
      try {
        await AudioPlayer.global.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
      } catch (_) {
        // not fatal: effects still play, just with the default focus
      }
    }();
  }

  /// Sets the global audio context and loads every effect up front.
  Future<void> preload() async {
    if (_silent || _disposed) {
      return;
    }
    await _ensureContext();
    for (final n in _names) {
      if (_disposed) {
        return;
      }
      try {
        final p = await _player(n);
        await p.setSource(AssetSource('sounds/$n.wav'));
      } catch (_) {}
    }
  }

  Future<AudioPlayer> _player(String name) async {
    var p = _players[name];
    if (p == null) {
      p = AudioPlayer();
      _players[name] = p;
      try {
        await p.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {}
    }
    return p;
  }

  void play(String name) {
    if (_silent || _disposed || !_enabled()) {
      return;
    }
    unawaited(_play(name));
  }

  Future<void> _play(String name) async {
    try {
      await _ensureContext();
      final p = await _player(name);
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
