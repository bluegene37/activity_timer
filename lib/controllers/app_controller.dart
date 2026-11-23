// Gene - Nov, 22, 2026: Import dart:async and session services so sound/vibration setting changes reschedule active background notifications immediately.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../models/alarm_sound.dart';
import '../models/settings.dart';
import '../services/activity_session_service.dart';
import '../services/brew_session_service.dart';
import '../services/interval_session_service.dart';

class AppController {
  final _settings = AppSettings();

  // Reactive variables
  // Gene - Nov 5, 2026: Set default themeMode signal to ThemeMode.light per user requirement
  // final themeMode = signal(ThemeMode.dark);
  final themeMode = signal(ThemeMode.light);
  // Initialize with the standard default, but it will be instantly overridden in onInit
  final themeColor = signal<Color>(const Color(0xFF4A6FFF));
  final soundEnabled = signal(true);
  final vibrationEnabled = signal(true);
  final defaultAlarmSound = signal(AlarmSound.beep);
  final themeStyle = signal(AppThemeStyle.coffee);
  // Gene - Nov, 8, 2026: Added reactive signals for 3-2-1 countdown beeps and 50% halfway warning cue.
  final countdownBeepsEnabled = signal(true);
  final halfwayWarningEnabled = signal(false);

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
    countdownBeepsEnabled.value = _settings.countdownBeepsEnabled;
    halfwayWarningEnabled.value = _settings.halfwayWarningEnabled;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _settings.setThemeMode(mode);
  }

  Future<void> setThemeColor(Color color) async {
    themeColor.value = color;
    await _settings.setThemeColor(color);
  }

  // Gene - Nov, 22, 2026: Reschedule armed OS alarms whenever sound, vibration, or default alarm sound preferences change.
  // Future<void> setSoundEnabled(bool enabled) async {
  //   soundEnabled.value = enabled;
  //   await _settings.setSoundEnabled(enabled);
  // }
  //
  // Future<void> setVibrationEnabled(bool enabled) async {
  //   vibrationEnabled.value = enabled;
  //   await _settings.setVibrationEnabled(enabled);
  // }
  //
  // Future<void> setDefaultAlarmSound(AlarmSound sound) async {
  //   defaultAlarmSound.value = sound;
  //   await _settings.setDefaultAlarmSound(sound);
  // }
  void _rescheduleActiveSessions() {
    unawaited(ActivitySessionService().rescheduleActiveAlarms());
    unawaited(IntervalSessionService().rescheduleActiveAlarms());
    unawaited(BrewSessionService().rescheduleActiveAlarms());
  }

  // Gene - Nov, 23, 2026: Trigger active-session alarm rescheduling immediately upon in-memory setting updates before awaiting Hive disk persistence.
  // Future<void> setSoundEnabled(bool enabled) async {
  //   soundEnabled.value = enabled;
  //   await _settings.setSoundEnabled(enabled);
  //   _rescheduleActiveSessions();
  // }
  //
  // Future<void> setVibrationEnabled(bool enabled) async {
  //   vibrationEnabled.value = enabled;
  //   await _settings.setVibrationEnabled(enabled);
  //   _rescheduleActiveSessions();
  // }
  //
  // Future<void> setDefaultAlarmSound(AlarmSound sound) async {
  //   defaultAlarmSound.value = sound;
  //   await _settings.setDefaultAlarmSound(sound);
  //   _rescheduleActiveSessions();
  // }
  Future<void> setSoundEnabled(bool enabled) async {
    soundEnabled.value = enabled;
    final save = _settings.setSoundEnabled(enabled);
    _rescheduleActiveSessions();
    await save;
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    vibrationEnabled.value = enabled;
    final save = _settings.setVibrationEnabled(enabled);
    _rescheduleActiveSessions();
    await save;
  }

  Future<void> setDefaultAlarmSound(AlarmSound sound) async {
    defaultAlarmSound.value = sound;
    final save = _settings.setDefaultAlarmSound(sound);
    _rescheduleActiveSessions();
    await save;
  }

  Future<void> setThemeStyle(AppThemeStyle style) async {
    themeStyle.value = style;
    await _settings.setThemeStyle(style);
  }

  // Gene - Nov, 8, 2026: Added setters for countdownBeepsEnabled and halfwayWarningEnabled.
  Future<void> setCountdownBeepsEnabled(bool enabled) async {
    countdownBeepsEnabled.value = enabled;
    await _settings.setCountdownBeepsEnabled(enabled);
  }

  Future<void> setHalfwayWarningEnabled(bool enabled) async {
    halfwayWarningEnabled.value = enabled;
    await _settings.setHalfwayWarningEnabled(enabled);
  }
}
