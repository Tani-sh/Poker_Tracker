import 'package:hive/hive.dart';

part 'group_preset_model.g.dart';

@HiveType(typeId: 4)
class GroupPreset extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<int> playerKeys;

  @HiveField(2)
  int defaultBuyIn;

  @HiveField(3)
  String location;

  GroupPreset({
    required this.name,
    required this.playerKeys,
    required this.defaultBuyIn,
    this.location = '',
  });
}
