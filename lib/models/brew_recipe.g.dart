// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brew_recipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BrewStepAdapter extends TypeAdapter<BrewStep> {
  @override
  final typeId = 9;

  @override
  BrewStep read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrewStep(
      name: fields[0] as String,
      seconds: (fields[1] as num).toInt(),
      kind: fields[4] == null ? BrewStepKind.pour : fields[4] as BrewStepKind,
      pourToFraction: (fields[2] as num?)?.toDouble(),
      pourSeconds: (fields[3] as num?)?.toInt(),
      description: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BrewStep obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.seconds)
      ..writeByte(2)
      ..write(obj.pourToFraction)
      ..writeByte(3)
      ..write(obj.pourSeconds)
      ..writeByte(4)
      ..write(obj.kind)
      ..writeByte(5)
      ..write(obj.description);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrewStepAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BrewRecipeAdapter extends TypeAdapter<BrewRecipe> {
  @override
  final typeId = 8;

  @override
  BrewRecipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrewRecipe(
      id: fields[0] as String?,
      name: fields[1] as String,
      method: fields[2] as BrewMethod,
      doseGrams: (fields[3] as num).toDouble(),
      ratio: (fields[4] as num).toDouble(),
      steps: (fields[5] as List).cast<BrewStep>(),
      notes: fields[6] as String?,
      alarmSoundName: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BrewRecipe obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.method)
      ..writeByte(3)
      ..write(obj.doseGrams)
      ..writeByte(4)
      ..write(obj.ratio)
      ..writeByte(5)
      ..write(obj.steps)
      ..writeByte(6)
      ..write(obj.notes)
      ..writeByte(7)
      ..write(obj.alarmSoundName)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrewRecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BrewStepKindAdapter extends TypeAdapter<BrewStepKind> {
  @override
  final typeId = 10;

  @override
  BrewStepKind read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BrewStepKind.pour;
      case 1:
        return BrewStepKind.wait;
      case 2:
        return BrewStepKind.swirl;
      case 3:
        return BrewStepKind.drawdown;
      default:
        return BrewStepKind.pour;
    }
  }

  @override
  void write(BinaryWriter writer, BrewStepKind obj) {
    switch (obj) {
      case BrewStepKind.pour:
        writer.writeByte(0);
      case BrewStepKind.wait:
        writer.writeByte(1);
      case BrewStepKind.swirl:
        writer.writeByte(2);
      case BrewStepKind.drawdown:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrewStepKindAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BrewMethodAdapter extends TypeAdapter<BrewMethod> {
  @override
  final typeId = 11;

  @override
  BrewMethod read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BrewMethod.v60;
      case 1:
        return BrewMethod.chemex;
      case 2:
        return BrewMethod.kalita;
      case 3:
        return BrewMethod.aeropress;
      case 4:
        return BrewMethod.switchBrewer;
      default:
        return BrewMethod.v60;
    }
  }

  @override
  void write(BinaryWriter writer, BrewMethod obj) {
    switch (obj) {
      case BrewMethod.v60:
        writer.writeByte(0);
      case BrewMethod.chemex:
        writer.writeByte(1);
      case BrewMethod.kalita:
        writer.writeByte(2);
      case BrewMethod.aeropress:
        writer.writeByte(3);
      case BrewMethod.switchBrewer:
        writer.writeByte(4);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrewMethodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
