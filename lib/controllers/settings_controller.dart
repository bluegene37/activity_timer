import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../components/alarm_sound_picker.dart';
import '../models/alarm_sound.dart';
import '../services/cue_player.dart';
import 'app_controller.dart';

class SettingsController extends GetxController {
  final CuePlayer _cuePlayer = AudioCuePlayer();
  late final AppController _appController;

  @override
  void onInit() {
    super.onInit();
    _appController = Get.find<AppController>();
  }

  @override
  void onClose() {
    unawaited(_cuePlayer.dispose());
    super.onClose();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _appController.setThemeMode(mode);
    Get.changeThemeMode(mode);
  }

  Future<void> setThemeColor(Color color) async {
    await _appController.setThemeColor(color);
    // Force rebuild of the app with new theme
    unawaited(Get.forceAppUpdate());
  }

  Future<void> toggleSound(bool enabled) async {
    await _appController.setSoundEnabled(enabled);
  }

  Future<void> toggleVibration(bool enabled) async {
    await _appController.setVibrationEnabled(enabled);
  }

  Future<void> selectDefaultAlarmSound() async {
    final context = Get.context;
    if (context == null) {
      return;
    }
    final choice = await showAlarmSoundPicker(
      context,
      selected: _appController.defaultAlarmSound.value,
      title: 'Default Alarm Sound',
      cuePlayer: _cuePlayer,
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
