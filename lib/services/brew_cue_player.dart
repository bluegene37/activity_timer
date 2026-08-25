import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../models/alarm_sound.dart';
import '../models/settings.dart';

/// Plays the sound that marks the end of a brew step. Injected into
/// `BrewRunController` so tests can record cues instead of touching audio.
abstract interface class BrewCuePlayer {
  Future<void> playStepEnd(AlarmSound sound);

  Future<void> dispose();
}

class AudioBrewCuePlayer implements BrewCuePlayer {
  final AudioPlayer _player = AudioPlayer();
  final AppSettings _settings = AppSettings();

  @override
  Future<void> playStepEnd(AlarmSound sound) async {
    if (_settings.soundEnabled) {
      try {
        await _player.stop();
        await _player.setSource(AssetSource('sounds/${sound.fileName}'));
        await _player.resume();
      } catch (_) {}
    }
    if (_settings.vibrationEnabled) {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  @override
  Future<void> dispose() => _player.dispose();
}
