// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsDataAdapter extends TypeAdapter<AppSettingsData> {
  @override
  final typeId = 0;

  @override
  AppSettingsData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettingsData(
      themeMode: fields[0] == null ? 'dark' : fields[0] as String,
      soundEnabled: fields[1] == null ? true : fields[1] as bool,
      vibrationEnabled: fields[2] == null ? true : fields[2] as bool,
      themeColor:
          fields[3] == null
              ? AppSettings.defaultThemeColorValue
              : (fields[3] as num).toInt(),
      defaultAlarmSound: fields[4] == null ? 'beep' : fields[4] as String,
      themeStyle: fields[5] == null ? 'coffee' : fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettingsData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.themeMode)
      ..writeByte(1)
      ..write(obj.soundEnabled)
      ..writeByte(2)
      ..write(obj.vibrationEnabled)
      ..writeByte(3)
      ..write(obj.themeColor)
      ..writeByte(4)
      ..write(obj.defaultAlarmSound)
      ..writeByte(5)
      ..write(obj.themeStyle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
