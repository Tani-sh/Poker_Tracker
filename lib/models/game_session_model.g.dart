// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameSessionAdapter extends TypeAdapter<GameSession> {
  @override
  final int typeId = 3;

  @override
  GameSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameSession(
      location: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime,
      players: (fields[3] as List).cast<GamePlayer>(),
      notes: fields[4] == null ? '' : fields[4] as String,
      firestoreId: fields[5] as String?,
      isSynced: fields[6] == null ? false : fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, GameSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.location)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.players)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.firestoreId)
      ..writeByte(6)
      ..write(obj.isSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
