// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionHistoryAdapter extends TypeAdapter<SessionHistory> {
  @override
  final typeId = 6;

  @override
  SessionHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionHistory(
      id: fields[0] as String?,
      title: fields[1] as String,
      completedAt: fields[2] as DateTime?,
      totalDurationInSeconds: (fields[3] as num).toInt(),
      itemCount: fields[4] == null ? 1 : (fields[4] as num).toInt(),
      loopCount: fields[5] == null ? 0 : (fields[5] as num).toInt(),
      sessionType: fields[6] == null ? 'activity' : fields[6] as String,
    );
  }

  @override
  void write(BinaryWriter writer, SessionHistory obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.completedAt)
      ..writeByte(3)
      ..write(obj.totalDurationInSeconds)
      ..writeByte(4)
      ..write(obj.itemCount)
      ..writeByte(5)
      ..write(obj.loopCount)
      ..writeByte(6)
      ..write(obj.sessionType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
