// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alarm_sound.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlarmSoundAdapter extends TypeAdapter<AlarmSound> {
  @override
  final int typeId = 5;

  @override
  AlarmSound read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AlarmSound.beep;
      case 1:
        return AlarmSound.bell;
      case 2:
        return AlarmSound.chime;
      case 3:
        return AlarmSound.digital;
      case 4:
        return AlarmSound.gentle;
      default:
        return AlarmSound.beep;
    }
  }

  @override
  void write(BinaryWriter writer, AlarmSound obj) {
    switch (obj) {
      case AlarmSound.beep:
        writer.writeByte(0);
        break;
      case AlarmSound.bell:
        writer.writeByte(1);
        break;
      case AlarmSound.chime:
        writer.writeByte(2);
        break;
      case AlarmSound.digital:
        writer.writeByte(3);
        break;
      case AlarmSound.gentle:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmSoundAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}