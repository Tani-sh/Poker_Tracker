import 'package:hive/hive.dart';
import '../models/player_model.dart';
import '../models/game_session_model.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

/// Handles first-login account claiming:
/// Links the logged-in user's phone number to an existing local Player,
/// then syncs/merges cloud history.
class AccountLinkingService {
  static final AccountLinkingService _instance = AccountLinkingService._();
  factory AccountLinkingService() => _instance;
  AccountLinkingService._();

  final _auth = AuthService();
  final _firestore = FirestoreService();

  /// Called after successful phone number sign-in.
  /// Returns a summary of what was found/linked.
  Future<Map<String, dynamic>> onFirstLogin() async {
    if (!_auth.isLoggedIn || _auth.phoneNumber == null) {
      return {'linked': false, 'gamesFound': 0};
    }

    final phone = _auth.phoneNumber!;
    final uid = _auth.uid!;
    final playersBox = Hive.box<Player>('players');

    // Step 1: Find or create the local Player for this phone number
    Player? myPlayer;
    try {
      myPlayer = playersBox.values.firstWhere((p) => p.phoneNumber == phone);
    } catch (_) {
      // No local player with this phone — check if there's one without a phone
      // that might be "me" (we'll let the user link manually via the bulk screen)
    }

    // Step 2: Link Firebase UID to the player if found
    if (myPlayer != null && myPlayer.firebaseUid == null) {
      myPlayer.linkFirebase(uid);
    }

    // Step 3: Sync user profile to Firestore
    if (myPlayer != null) {
      await _firestore.syncUserProfile(myPlayer);
    }

    // Step 4: Full sync — upload local games, pull cloud games
    final syncResult = await _firestore.fullSync();

    // Step 5: Calculate total stats for this user
    int totalGames = 0;
    int totalProfit = 0;
    if (myPlayer != null) {
      final historyBox = Hive.box<GameSession>('game_history');
      for (var session in historyBox.values) {
        for (var gp in session.players) {
          if (gp.player.name == myPlayer.name ||
              gp.player.phoneNumber == phone) {
            totalGames++;
            totalProfit += gp.netProfit;
          }
        }
      }
    }

    return {
      'linked': myPlayer != null,
      'playerName': myPlayer?.name,
      'gamesFound': totalGames,
      'totalProfit': totalProfit,
      'uploaded': syncResult['uploaded'] ?? 0,
      'downloaded': syncResult['downloaded'] ?? 0,
    };
  }

  /// Get the count of unlinked players (for showing the migration prompt).
  int getUnlinkedPlayerCount() {
    final playersBox = Hive.box<Player>('players');
    return playersBox.values
        .where((p) => !p.isArchived && !p.isLinked)
        .length;
  }

  /// Check if this is the user's first login (never synced before).
  bool get isFirstSync {
    final box = Hive.box('settings');
    return !box.get('hasCompletedFirstSync', defaultValue: false);
  }

  /// Mark first sync as complete.
  void markFirstSyncComplete() {
    Hive.box('settings').put('hasCompletedFirstSync', true);
  }
}
