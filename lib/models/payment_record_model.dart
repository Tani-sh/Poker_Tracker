import 'package:hive/hive.dart';

part 'payment_record_model.g.dart';

@HiveType(typeId: 5)
class PaymentRecord extends HiveObject {
  @HiveField(0)
  String fromPlayerName;

  @HiveField(1)
  String toPlayerName;

  @HiveField(2)
  int amount;

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  String? note;

  PaymentRecord({
    required this.fromPlayerName,
    required this.toPlayerName,
    required this.amount,
    required this.timestamp,
    this.note,
  });
}
