import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';

import 'alarm_sound.dart';

part 'settings.g.dart';

@HiveType(typeId: 0)
class AppSettingsData extends HiveObject {
  AppSettingsData({
    this.themeMode = 'dark',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.themeColor = AppSettings.defaultThemeColorValue,
    this.defaultAlarmSound = 'beep',
  });

  @HiveField(0)
  String themeMode;

  @HiveField(1)
  bool soundEnabled;

  @HiveField(2)
  bool vibrationEnabled;

  @HiveField(3)
  int themeColor;

  @HiveField(4)
  String defaultAlarmSound;
}

/// Process-wide cache of the persisted [AppSettingsData], backed by Hive.
class AppSettings {
  factory AppSettings() => _instance;

  AppSettings._internal();

  static final AppSettings _instance = AppSettings._internal();

  static const defaultThemeColorValue = 0xFF4A6FFF; // Default blue
  static const defaultThemeColor = Color(defaultThemeColorValue);

  static const _boxName = 'settings';
  static const _settingsKey = 'app_settings';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  Color _themeColor = defaultThemeColor;
  AlarmSound _defaultAlarmSound = AlarmSound.beep;

  ThemeMode get themeMode => _themeMode;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  Color get themeColor => _themeColor;
  AlarmSound get defaultAlarmSound => _defaultAlarmSound;

  /// [ThemeMode] values round-trip through their [Enum.name], so persisted
  /// strings ('light' / 'dark' / 'system') need no manual mapping table.
  static ThemeMode _themeModeFromName(String name) => ThemeMode.values
      .firstWhere((mode) => mode.name == name, orElse: () => ThemeMode.dark);

  Future<void> loadSettings() async {
    final box = await Hive.openBox<AppSettingsData>(_boxName);

    var settings = box.get(_settingsKey);
    if (settings == null) {
      settings = AppSettingsData();
      await box.put(_settingsKey, settings);
    }

    _themeMode = _themeModeFromName(settings.themeMode);
    _soundEnabled = settings.soundEnabled;
    _vibrationEnabled = settings.vibrationEnabled;
    _themeColor = Color(settings.themeColor);
    _defaultAlarmSound = AlarmSound.fromString(settings.defaultAlarmSound);
  }

  /// Read-modify-write the single persisted settings record.
  Future<void> _update(void Function(AppSettingsData settings) change) async {
    final box = await Hive.openBox<AppSettingsData>(_boxName);
    final settings = box.get(_settingsKey) ?? AppSettingsData();
    change(settings);
    await box.put(_settingsKey, settings);
  }

  Future<void> setThemeColor(Color color) async {
    _themeColor = color;
    await _update((settings) => settings.themeColor = color.toARGB32());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _update((settings) => settings.themeMode = mode.name);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _update((settings) => settings.soundEnabled = enabled);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _update((settings) => settings.vibrationEnabled = enabled);
  }

  Future<void> setDefaultAlarmSound(AlarmSound sound) async {
    _defaultAlarmSound = sound;
    await _update((settings) => settings.defaultAlarmSound = sound.name);
  }
}
