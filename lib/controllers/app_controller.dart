import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/alarm_sound.dart';
import '../models/settings.dart';

class AppController extends GetxController {
  final _settings = AppSettings();
  
  // Reactive variables
  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;
  // Initialize with the standard default, but it will be instantly overridden in onInit
  final Rx<Color> themeColor = const Color(0xFF4A6FFF).obs; 
  final RxBool soundEnabled = true.obs;
  final RxBool vibrationEnabled = true.obs;
  final Rx<AlarmSound> defaultAlarmSound = AlarmSound.beep.obs;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    await _settings.loadSettings();
    
    // Update reactive variables with precisely what is stored in Hive DB
    themeMode.value = _settings.themeMode;
    themeColor.value = _settings.themeColor;
    soundEnabled.value = _settings.soundEnabled;
    vibrationEnabled.value = _settings.vibrationEnabled;
    defaultAlarmSound.value = _settings.defaultAlarmSound;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _settings.setThemeMode(mode);
  }

  Future<void> setThemeColor(Color color) async {
    themeColor.value = color;
    await _settings.setThemeColor(color);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled.value = enabled;
    await _settings.setSoundEnabled(enabled);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    vibrationEnabled.value = enabled;
    await _settings.setVibrationEnabled(enabled);
  }

  Future<void> setDefaultAlarmSound(AlarmSound sound) async {
    defaultAlarmSound.value = sound;
    await _settings.setDefaultAlarmSound(sound);
  }
}
