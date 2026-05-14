import 'dart:math';
import 'package:hive/hive.dart';

part 'player_model.g.dart';

@HiveType(typeId: 1)
class Player extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1, defaultValue: false)
  bool isArchived;

  // Emoji avatar for visual identification
  @HiveField(2, defaultValue: '🎯')
  String emoji;

  static const List<String> availableEmojis = [
    '🎯', '🃏', '♠️', '♥️', '♦️', '♣️', '🎲', '🎰',
    '🐺', '🦊', '🦁', '🐯', '🐻', '🐼', '🦅', '🐉',
    '👑', '🔥', '⚡', '💎', '🌟', '🎪', '🎭', '🏆',
    '🦈', '🐊', '🦂', '🐍', '🦉', '🐧', '🐲', '🎃',
  ];

  static String randomEmoji() {
    return availableEmojis[Random().nextInt(availableEmojis.length)];
  }

  Player({
    required this.name,
    this.isArchived = false,
    String? emoji,
  }) : emoji = emoji ?? randomEmoji();

  void archive() {
    isArchived = true;
    save();
  }

  void unarchive() {
    isArchived = false;
    save();
  }

  void updateEmoji(String newEmoji) {
    emoji = newEmoji;
    save();
  }
}
