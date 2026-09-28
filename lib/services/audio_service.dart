import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';

enum Sfx { move, merge, win, gameOver, coin }

/// Short sound effects and light haptics, both respecting user settings.
class AudioService {
  final StorageService storage;
  final _pool = <Sfx, AudioPlayer>{};

  AudioService(this.storage);

  static const _files = {
    Sfx.move: 'move.wav',
    Sfx.merge: 'merge.wav',
    Sfx.win: 'win.wav',
    Sfx.gameOver: 'gameover.wav',
    Sfx.coin: 'coin.wav',
  };

  Future<void> play(Sfx sfx) async {
    if (storage.muted) return;
    try {
      final player = _pool.putIfAbsent(
        sfx,
        () => AudioPlayer()..setPlayerMode(PlayerMode.lowLatency),
      );
      await player.stop();
      await player.play(AssetSource('sounds/${_files[sfx]}'), volume: 0.7);
    } catch (_) {
      // Audio is non-critical.
    }
  }

  void light() {
    if (storage.vibration) HapticFeedback.lightImpact();
  }

  void medium() {
    if (storage.vibration) HapticFeedback.mediumImpact();
  }
}
