import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../models/game_session_model.dart';
import '../models/game_player_model.dart';
import '../models/player_model.dart';
import '../models/payment_record_model.dart';
import 'auth_service.dart';

/// Handles all Firestore read/write operations and Hive ↔ Firestore sync.
///
/// Write flow: Save to Hive (instant) → sync to Firestore in background
/// Read flow:  Load from Hive (fast) → merge with Firestore on login/sync
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._();
  factory FirestoreService() => _instance;
  FirestoreService._();

  final _db = FirebaseFirestore.instance;
  final _auth = AuthService();

  // ──────────────────────────────────────────────────
  // USER PROFILE
  // ──────────────────────────────────────────────────

  /// Create or update the user's Firestore profile.
  /// Uses phone number as the document ID for cross-device identity.
  Future<void> syncUserProfile(Player player) async {
    if (!_auth.isLoggedIn || player.phoneNumber == null) return;
    final docId = _sanitizePhoneForDocId(player.phoneNumber!);
    await _db.collection('users').doc(docId).set({
      'name': player.name,
      'emoji': player.emoji,
      'phoneNumber': player.phoneNumber,
      'lastUid': _auth.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch a user profile by phone number.
  Future<Map<String, dynamic>?> getUserByPhone(String phone) async {
    final normalized = AuthService.normalizePhone(phone);
    final docId = _sanitizePhoneForDocId(normalized);
    final doc = await _db.collection('users').doc(docId).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  /// Sanitize phone number for use as Firestore document ID.
  String _sanitizePhoneForDocId(String phone) {
    return phone.replaceAll('+', '');
  }

  // ──────────────────────────────────────────────────
  // GAME SESSION SYNC
  // ──────────────────────────────────────────────────

  /// Upload a completed game session to Firestore.
  Future<String?> syncGameSession(GameSession session) async {
    if (!_auth.isLoggedIn) return null;

    // Collect all phone numbers for efficient querying.
    // Always include the host's phone so the host can find their own games.
    final playerPhones = <String>{};
    if (_auth.phoneNumber != null) playerPhones.add(_auth.phoneNumber!);
    for (var gp in session.players) {
      if (gp.player.phoneNumber != null && gp.player.phoneNumber!.isNotEmpty) {
        playerPhones.add(gp.player.phoneNumber!);
      }
    }

    // Also collect player names so players without phone numbers
    // can still be found via name-based queries
    final playerNames = session.players.map((gp) => gp.player.name).toList();

    final data = {
      'hostPhone': _auth.phoneNumber,
      'hostUid': _auth.uid,
      'playerPhones': playerPhones.toList(),
      'playerNames': playerNames,
      'location': session.location,
      'startTime': Timestamp.fromDate(session.startTime),
      'endTime': Timestamp.fromDate(session.endTime),
      'notes': session.notes,
      'players': session.players.map((gp) => {
        'name': gp.player.name,
        'emoji': gp.player.emoji,
        'phoneNumber': gp.player.phoneNumber,
        'buyIns': gp.buyIns,
        'cashOutAmount': gp.cashOutAmount,
        'hasCashedOut': gp.hasCashedOut,
        'netProfit': gp.netProfit,
        'totalBuyIn': gp.totalBuyIn,
      }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (session.firestoreId != null) {
        await _db.collection('games').doc(session.firestoreId).update(data);
        return session.firestoreId;
      } else {
        final doc = await _db.collection('games').add(data);
        session.firestoreId = doc.id;
        session.isSynced = true;
        session.save();
        return doc.id;
      }
    } catch (e) {
      _trackFailedSync(session);
      return null;
    }
  }

  /// Sync all un-synced games to Firestore.
  Future<int> syncAllPendingGames() async {
    if (!_auth.isLoggedIn) return 0;

    final historyBox = Hive.box<GameSession>('game_history');
    int synced = 0;

    for (var session in historyBox.values) {
      if (!session.isSynced) {
        final id = await syncGameSession(session);
        if (id != null) synced++;
      }
    }
    return synced;
  }

  /// Fetch all games from Firestore where the user's phone appears
  /// OR where the user's name appears (for players without linked phones).
  Future<List<Map<String, dynamic>>> fetchMyGames(String phoneNumber) async {
    final normalized = AuthService.normalizePhone(phoneNumber);
    try {
      // Primary: efficient server-side filter by phone
      final snap = await _db.collection('games')
          .where('playerPhones', arrayContains: normalized)
          .orderBy('startTime', descending: true)
          .limit(200)
          .get();

      // Also fetch games hosted by this phone (covers case where
      // host's phone wasn't in playerPhones due to older data format)
      final hostSnap = await _db.collection('games')
          .where('hostPhone', isEqualTo: normalized)
          .orderBy('startTime', descending: true)
          .limit(100)
          .get();

      // Merge and deduplicate
      final allDocs = <String, Map<String, dynamic>>{};
      for (var doc in snap.docs) {
        allDocs[doc.id] = {'id': doc.id, ...doc.data()};
      }
      for (var doc in hostSnap.docs) {
        allDocs.putIfAbsent(doc.id, () => {'id': doc.id, ...doc.data()});
      }

      final result = allDocs.values.toList();
      result.sort((a, b) {
        final aTime = (a['startTime'] as Timestamp).toDate();
        final bTime = (b['startTime'] as Timestamp).toDate();
        return bTime.compareTo(aTime);
      });
      return result;
    } catch (e) {
      // Fallback: client-side filter for older data without indexes
      try {
        final snap = await _db.collection('games')
            .orderBy('startTime', descending: true)
            .limit(200)
            .get();

        return snap.docs
            .where((doc) {
              final data = doc.data();
              // Check playerPhones array
              final phones = data['playerPhones'] as List<dynamic>? ?? [];
              if (phones.contains(normalized)) return true;
              // Check hostPhone
              if (data['hostPhone'] == normalized) return true;
              // Check player names as last resort
              final players = data['players'] as List<dynamic>? ?? [];
              if (players.any((p) => p['phoneNumber'] == normalized)) return true;
              return false;
            })
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  /// Merge Firestore games into local Hive (skip duplicates).
  Future<int> mergeCloudGames(String phoneNumber) async {
    final cloudGames = await fetchMyGames(phoneNumber);
    final historyBox = Hive.box<GameSession>('game_history');
    final playersBox = Hive.box<Player>('players');

    // Existing Firestore IDs to avoid duplicates
    final existingIds = historyBox.values
        .where((s) => s.firestoreId != null)
        .map((s) => s.firestoreId!)
        .toSet();

    int imported = 0;

    for (var game in cloudGames) {
      final gameId = game['id'] as String;
      if (existingIds.contains(gameId)) continue;

      final playersList = (game['players'] as List<dynamic>).map((p) {
        final name = p['name'] as String;
        final phone = p['phoneNumber'] as String?;
        Player? localPlayer;

        // Try to find by phone first (more reliable), then by name
        if (phone != null && phone.isNotEmpty) {
          try {
            localPlayer = playersBox.values.firstWhere((pl) => pl.phoneNumber == phone);
          } catch (_) {}
        }
        if (localPlayer == null) {
          try {
            localPlayer = playersBox.values.firstWhere((pl) => pl.name == name);
          } catch (_) {}
        }
        if (localPlayer == null) {
          localPlayer = Player(
            name: name,
            emoji: p['emoji'] as String? ?? Player.randomEmoji(),
            phoneNumber: phone,
          );
          playersBox.add(localPlayer);
        }

        return GamePlayer(
          player: localPlayer,
          buyIns: List<int>.from(p['buyIns'] ?? [0]),
          cashOutAmount: p['cashOutAmount'] as int?,
          hasCashedOut: p['hasCashedOut'] as bool? ?? false,
        );
      }).toList();

      final session = GameSession(
        location: game['location'] as String? ?? 'Unknown',
        startTime: (game['startTime'] as Timestamp).toDate(),
        endTime: (game['endTime'] as Timestamp).toDate(),
        players: playersList,
        notes: game['notes'] as String? ?? '',
        firestoreId: gameId,
        isSynced: true,
      );

      historyBox.add(session);
      imported++;
    }

    return imported;
  }

  // ──────────────────────────────────────────────────
  // PAYMENT SYNC (UPLOAD + DOWNLOAD)
  // ──────────────────────────────────────────────────

  /// Sync a payment record to Firestore.
  /// Includes both player names so any player in the pair can find it.
  Future<void> syncPayment(PaymentRecord payment) async {
    if (!_auth.isLoggedIn) return;
    try {
      await _db.collection('payments').add({
        'fromPlayerName': payment.fromPlayerName,
        'toPlayerName': payment.toPlayerName,
        'amount': payment.amount,
        'timestamp': Timestamp.fromDate(payment.timestamp),
        'note': payment.note,
        'recordedBy': _auth.uid,
        'recordedByPhone': _auth.phoneNumber,
        // Store both names for querying
        'involvedPlayers': [payment.fromPlayerName, payment.toPlayerName],
      });
    } catch (_) {
      // Payment sync failed — non-critical, local record persists
    }
  }

  /// Fetch payments from Firestore that involve any of our local players.
  Future<int> mergeCloudPayments() async {
    if (!_auth.isLoggedIn || _auth.phoneNumber == null) return 0;

    final paymentsBox = Hive.box<PaymentRecord>('payments');
    final playersBox = Hive.box<Player>('players');

    // Get all local player names to search for their payments
    final localPlayerNames = playersBox.values
        .where((p) => !p.isArchived)
        .map((p) => p.name)
        .toSet();

    if (localPlayerNames.isEmpty) return 0;

    int imported = 0;

    try {
      // Fetch payments recorded by our phone (ones we created)
      final byPhoneSnap = await _db.collection('payments')
          .where('recordedByPhone', isEqualTo: _auth.phoneNumber)
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();

      // Also fetch payments that involve any player we know about,
      // queried by the person who recorded them
      // (Firestore doesn't support OR queries, so we fetch by recordedByPhone
      //  and also do a broader fetch)
      final broadSnap = await _db.collection('payments')
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();

      // Merge
      final allDocs = <String, DocumentSnapshot>{};
      for (var doc in byPhoneSnap.docs) {
        allDocs[doc.id] = doc;
      }
      for (var doc in broadSnap.docs) {
        allDocs.putIfAbsent(doc.id, () => doc);
      }

      // Build a set of existing payment fingerprints to avoid duplicates
      final existingFingerprints = paymentsBox.values.map((p) {
        return '${p.fromPlayerName}|${p.toPlayerName}|${p.amount}|${p.timestamp.millisecondsSinceEpoch}';
      }).toSet();

      for (var doc in allDocs.values) {
        final data = doc.data() as Map<String, dynamic>;
        final from = data['fromPlayerName'] as String;
        final to = data['toPlayerName'] as String;

        // Only import if at least one of the players is known to us
        if (!localPlayerNames.contains(from) && !localPlayerNames.contains(to)) {
          continue;
        }

        final amount = data['amount'] as int;
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        final fingerprint = '$from|$to|$amount|${timestamp.millisecondsSinceEpoch}';

        if (existingFingerprints.contains(fingerprint)) continue;

        final payment = PaymentRecord(
          fromPlayerName: from,
          toPlayerName: to,
          amount: amount,
          timestamp: timestamp,
          note: data['note'] as String?,
        );

        paymentsBox.add(payment);
        existingFingerprints.add(fingerprint);
        imported++;
      }
    } catch (_) {
      // Non-critical
    }

    return imported;
  }

  // ──────────────────────────────────────────────────
  // SYNC QUEUE (retry failed syncs)
  // ──────────────────────────────────────────────────

  void _trackFailedSync(GameSession session) {
    final box = Hive.box('settings');
    final pending = box.get('pendingSyncCount', defaultValue: 0) as int;
    box.put('pendingSyncCount', pending + 1);
  }

  int get pendingSyncCount {
    final historyBox = Hive.box<GameSession>('game_history');
    return historyBox.values.where((s) => !s.isSynced).length;
  }

  bool get hasPendingSyncs => pendingSyncCount > 0;

  // ──────────────────────────────────────────────────
  // FULL SYNC (games + payments, bidirectional)
  // ──────────────────────────────────────────────────

  /// Full sync: upload pending local data + pull cloud data (games AND payments).
  Future<Map<String, int>> fullSync() async {
    if (!_auth.isLoggedIn || _auth.phoneNumber == null) {
      return {'uploaded': 0, 'downloaded': 0, 'payments': 0};
    }

    final uploaded = await syncAllPendingGames();
    final downloaded = await mergeCloudGames(_auth.phoneNumber!);
    final payments = await mergeCloudPayments();

    Hive.box('settings').delete('pendingSyncCount');

    return {'uploaded': uploaded, 'downloaded': downloaded, 'payments': payments};
  }
}
