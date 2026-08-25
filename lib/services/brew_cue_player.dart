import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../models/alarm_sound.dart';
import '../models/settings.dart';

/// Plays the sound that marks the end of a brew step. Injected into
/// `BrewRunController` so tests can record cues instead of touching audio.
abstract interface class BrewCuePlayer {
  Future<void> playStepEnd(AlarmSound sound);

  /// The whole brew is done: a longer, unmistakable alarm.
  Future<void> playCompleted();

  Future<void> dispose();
}

class AudioBrewCuePlayer implements BrewCuePlayer {
  AudioBrewCuePlayer() {
    // One-shot cues: stop (rather than release) after playback so the next
    // cue starts instantly, matching the interval timer's proven setup.
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
  }

  final AudioPlayer _player = AudioPlayer();
  final AppSettings _settings = AppSettings();

  Future<void> _play(String fileName) async {
    if (_settings.soundEnabled) {
      try {
        await _player.stop();
        await _player.setSource(AssetSource('sounds/$fileName'));
        await _player.resume();
      } catch (_) {}
    }
    if (_settings.vibrationEnabled) {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  @override
  Future<void> playStepEnd(AlarmSound sound) => _play(sound.fileName);

  @override
  Future<void> playCompleted() async {
    await _play('timer_complete.mp3');
    if (_settings.vibrationEnabled) {
      // Double buzz so a finished brew is felt even with the phone pocketed.
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 250),
          HapticFeedback.heavyImpact,
        ),
      );
    }
  }

  @override
  Future<void> dispose() => _player.dispose();
}
