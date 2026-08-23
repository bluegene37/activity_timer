// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interval_phase.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IntervalPhaseAdapter extends TypeAdapter<IntervalPhase> {
  @override
  final typeId = 7;

  @override
  IntervalPhase read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return IntervalPhase.work;
      case 1:
        return IntervalPhase.rest;
      case 2:
        return IntervalPhase.prepare;
      case 3:
        return IntervalPhase.cooldown;
      default:
        return IntervalPhase.work;
    }
  }

  @override
  void write(BinaryWriter writer, IntervalPhase obj) {
    switch (obj) {
      case IntervalPhase.work:
        writer.writeByte(0);
      case IntervalPhase.rest:
        writer.writeByte(1);
      case IntervalPhase.prepare:
        writer.writeByte(2);
      case IntervalPhase.cooldown:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntervalPhaseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
