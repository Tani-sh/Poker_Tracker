// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_player_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GamePlayerAdapter extends TypeAdapter<GamePlayer> {
  @override
  final int typeId = 2;

  @override
  GamePlayer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GamePlayer(
      player: fields[0] as Player,
      buyIns: (fields[1] as List).cast<int>(),
      cashOutAmount: fields[2] as int?,
      hasCashedOut: fields[3] as bool,
      joinTime: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, GamePlayer obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.player)
      ..writeByte(1)
      ..write(obj.buyIns)
      ..writeByte(2)
      ..write(obj.cashOutAmount)
      ..writeByte(3)
      ..write(obj.hasCashedOut)
      ..writeByte(4)
      ..write(obj.joinTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GamePlayerAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
