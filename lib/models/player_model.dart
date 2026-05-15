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

  // Phone number for cross-device identity (nullable for backward compat)
  @HiveField(3)
  String? phoneNumber;

  // Firebase UID — set when this player logs in (nullable for offline-only)
  @HiveField(4)
  String? firebaseUid;

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
    this.phoneNumber,
    this.firebaseUid,
  }) : emoji = emoji ?? randomEmoji();

  bool get isLinked => phoneNumber != null && phoneNumber!.isNotEmpty;

  void linkPhone(String phone) {
    phoneNumber = phone;
    save();
  }

  void unlinkPhone() {
    phoneNumber = null;
    save();
  }

  void linkFirebase(String uid) {
    firebaseUid = uid;
    save();
  }

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
