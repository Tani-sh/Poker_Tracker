import 'package:hive/hive.dart';
import 'game_player_model.dart';

part 'game_session_model.g.dart';

@HiveType(typeId: 3)
class GameSession extends HiveObject {
  @HiveField(0)
  final String location;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime endTime;

  @HiveField(3)
  final List<GamePlayer> players;

  // Optional notes about the session (memorable hands, events, etc.)
  @HiveField(4, defaultValue: '')
  String notes;

  GameSession({
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.players,
    this.notes = '',
  });

  Duration get duration => endTime.difference(startTime);
}
