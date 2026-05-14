// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_preset_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GroupPresetAdapter extends TypeAdapter<GroupPreset> {
  @override
  final int typeId = 4;

  @override
  GroupPreset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroupPreset(
      name: fields[0] as String,
      playerKeys: (fields[1] as List).cast<int>(),
      defaultBuyIn: fields[2] as int,
      location: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GroupPreset obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.playerKeys)
      ..writeByte(2)
      ..write(obj.defaultBuyIn)
      ..writeByte(3)
      ..write(obj.location);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupPresetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
