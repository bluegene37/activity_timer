import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'alarm_sound.dart';

part 'settings.g.dart';

@HiveType(typeId: 0)
class AppSettingsData extends HiveObject {
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

  AppSettingsData({
    this.themeMode = 'dark',
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.themeColor = 0xFF4A6FFF, // Default blue color
    this.defaultAlarmSound = 'beep',
  });
}

class AppSettings {
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark theme
  bool _soundEnabled = true; // Default to sound on
  bool _vibrationEnabled = true; // Default to vibration on
  Color _themeColor = const Color(0xFF4A6FFF); // Default blue color
  AlarmSound _defaultAlarmSound = AlarmSound.beep; // Default alarm sound

  ThemeMode get themeMode => _themeMode;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  Color get themeColor => _themeColor;
  AlarmSound get defaultAlarmSound => _defaultAlarmSound;

  // Singleton pattern
  static final AppSettings _instance = AppSettings._internal();

  factory AppSettings() {
    return _instance;
  }

  AppSettings._internal();

  // Load settings from Hive
  Future<void> loadSettings() async {
    final box = await Hive.openBox<AppSettingsData>('settings');

    // Get settings or create default if none exist
    final settings =
        box.get('app_settings') ??
        AppSettingsData(
          themeMode: 'dark',
          soundEnabled: true,
          vibrationEnabled: true,
          themeColor: 0xFF4A6FFF,
          defaultAlarmSound: 'beep',
        );

    // Save default settings if none exist
    if (box.get('app_settings') == null) {
      await box.put('app_settings', settings);
    }

    // Convert string to ThemeMode
    switch (settings.themeMode) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
      default:
        _themeMode = ThemeMode.dark;
    }

    _soundEnabled = settings.soundEnabled;
    _vibrationEnabled = settings.vibrationEnabled;
    _themeColor = Color(settings.themeColor);
    _defaultAlarmSound = AlarmSound.fromString(settings.defaultAlarmSound);
  }

  // Save theme color to Hive
  Future<void> setThemeColor(Color color) async {
    _themeColor = color;

    final box = await Hive.openBox<AppSettingsData>('settings');
    final settings = box.get('app_settings')!;
    settings.themeColor = color.toARGB32();
    await settings.save();
  }

  // Save theme mode to Hive
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    // Convert ThemeMode to string
    String themeModeString;
    switch (mode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
        themeModeString = 'system';
        break;
    }

    final box = await Hive.openBox<AppSettingsData>('settings');
    final settings = box.get('app_settings')!;
    settings.themeMode = themeModeString;
    await settings.save();
  }

  // Save sound enabled setting
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;

    final box = await Hive.openBox<AppSettingsData>('settings');
    final settings = box.get('app_settings')!;
    settings.soundEnabled = enabled;
    await settings.save();
  }

  // Save vibration enabled setting
  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;

    final box = await Hive.openBox<AppSettingsData>('settings');
    final settings = box.get('app_settings')!;
    settings.vibrationEnabled = enabled;
    await settings.save();
  }

  // Save default alarm sound
  Future<void> setDefaultAlarmSound(AlarmSound sound) async {
    _defaultAlarmSound = sound;

    final box = await Hive.openBox<AppSettingsData>('settings');
    final settings = box.get('app_settings')!;
    settings.defaultAlarmSound = sound.name;
    await settings.save();
  }
}
