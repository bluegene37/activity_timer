import 'dart:async';

import 'package:flutter/material.dart';

import '../components/alarm_sound_picker.dart';
import '../models/alarm_sound.dart';
import '../services/cue_player.dart';
import '../services/locator.dart';
import '../services/ui_messenger.dart';
import 'app_controller.dart';

class SettingsController {
  final CuePlayer _cuePlayer = AudioCuePlayer();
  late final AppController _appController;

  void onInit() {
    _appController = locator<AppController>();
  }

  void onClose() {
    unawaited(_cuePlayer.dispose());
  }

  // MaterialApp is wrapped in a SignalBuilder that reads these values, so
  // writing the signal is all it takes to restyle the app — no explicit
  // "rebuild everything" call.
  Future<void> setThemeMode(ThemeMode mode) =>
      _appController.setThemeMode(mode);

  Future<void> setThemeColor(Color color) =>
      _appController.setThemeColor(color);

  Future<void> toggleSound(bool enabled) async {
    await _appController.setSoundEnabled(enabled);
  }

  Future<void> toggleVibration(bool enabled) async {
    await _appController.setVibrationEnabled(enabled);
  }

  Future<void> selectDefaultAlarmSound() async {
    final choice = await UiMessenger().showDialogBuilder<AlarmSoundChoice>(
      (dialogContext) => AlarmSoundPickerDialog(
        selected: _appController.defaultAlarmSound.value,
        title: 'Default Alarm Sound',
        cuePlayer: _cuePlayer,
      ),
    );
    final sound = choice?.sound;
    if (sound != null) {
      await _appController.setDefaultAlarmSound(sound);
    }
  }

  /// Previews through the same player the timers use, so what you hear
  /// while picking is what you get while running.
  Future<void> previewAlarmSound(AlarmSound sound) =>
      _cuePlayer.playAlarm(sound);
}
