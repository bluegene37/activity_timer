import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../models/alarm_sound.dart';
import '../models/settings.dart';

class AppController {
  final _settings = AppSettings();

  // Reactive variables
  final themeMode = signal(ThemeMode.dark);
  // Initialize with the standard default, but it will be instantly overridden in onInit
  final themeColor = signal<Color>(const Color(0xFF4A6FFF));
  final soundEnabled = signal(true);
  final vibrationEnabled = signal(true);
  final defaultAlarmSound = signal(AlarmSound.beep);
  final themeStyle = signal(AppThemeStyle.coffee);

  void onInit() {
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
    themeStyle.value = _settings.themeStyle;
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

  Future<void> setThemeStyle(AppThemeStyle style) async {
    themeStyle.value = style;
    await _settings.setThemeStyle(style);
  }
}
