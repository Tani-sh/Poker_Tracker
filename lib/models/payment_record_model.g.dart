// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentRecordAdapter extends TypeAdapter<PaymentRecord> {
  @override
  final int typeId = 5;

  @override
  PaymentRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentRecord(
      fromPlayerName: fields[0] as String,
      toPlayerName: fields[1] as String,
      amount: fields[2] as int,
      timestamp: fields[3] as DateTime,
      note: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PaymentRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.fromPlayerName)
      ..writeByte(1)
      ..write(obj.toPlayerName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
