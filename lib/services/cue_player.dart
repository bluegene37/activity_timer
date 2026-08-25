import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../models/alarm_sound.dart';
import '../models/settings.dart';

/// Plays the app's audible cues. Injected into the run controllers so tests
/// record cues instead of touching audio.
///
/// One interface for all three timers — activity routines, interval
/// schedules, and brews — so a cue sounds and feels the same everywhere.
abstract interface class CuePlayer {
  /// A boundary was reached: the routine's chosen alarm sound.
  Future<void> playAlarm(AlarmSound sound);

  /// The whole session is done: a longer, unmistakable alarm.
  Future<void> playCompletion();

  /// A short tone marking the start of a session.
  Future<void> playStart();

  Future<void> dispose();
}

class AudioCuePlayer implements CuePlayer {
  AudioCuePlayer() {
    unawaited(_configure());
  }

  /// The whole session is over, so this cue is worth being longer and
  /// louder than a step boundary.
  static const String completionSound = 'timer_complete.wav';

  static bool _contextConfigured = false;

  final AudioPlayer _player = AudioPlayer();
  final AppSettings _settings = AppSettings();

  Future<void> _configure() async {
    try {
      // One-shot cues: stop (rather than release) after playback so the
      // next cue starts without re-preparing the player.
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1);

      if (_contextConfigured) {
        return;
      }
      _contextConfigured = true;
      // The audio session, and the two decisions that matter for a timer:
      //
      //  * respectSilence stays false, so iOS uses the `playback` category
      //    and an alarm still sounds with the ringer switch off — the whole
      //    point of an alarm.
      //  * duckOthers dips music or a podcast for the length of the cue
      //    instead of stopping it outright, which is what every timer app
      //    people run alongside audio does.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.duckOthers,
        ).build(),
      );
    } catch (_) {
      // Audio is best-effort; haptics still fire below.
    }
  }

  Future<void> _play(String fileName) async {
    if (_settings.soundEnabled) {
      try {
        await _player.stop();
        await _player.setVolume(1);
        await _player.setSource(AssetSource('sounds/$fileName'));
        await _player.resume();
      } catch (_) {}
    }
  }

  Future<void> _buzz(int count) async {
    if (!_settings.vibrationEnabled) {
      return;
    }
    for (var i = 0; i < count; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 220));
      }
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  @override
  Future<void> playAlarm(AlarmSound sound) async {
    await _play(sound.fileName);
    unawaited(_buzz(2));
  }

  @override
  Future<void> playCompletion() async {
    await _play(completionSound);
    // Three buzzes: felt through a pocket, and distinct from a boundary.
    unawaited(_buzz(3));
  }

  @override
  Future<void> playStart() async {
    await _play(AlarmSound.beep.fileName);
    unawaited(_buzz(1));
  }

  @override
  Future<void> dispose() => _player.dispose();
}
