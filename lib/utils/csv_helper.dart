import 'dart:io';
import 'package:csv/csv.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_player_model.dart';
import '../models/game_session_model.dart';
import '../models/player_model.dart';
import '../services/auth_service.dart';
import 'app_settings.dart';

class CsvHelper {
  /// Export full game history as CSV and share.
  static Future<void> exportGameHistory() async {
    final historyBox = Hive.box<GameSession>('game_history');
    final sessions = historyBox.values.toList();

    final List<List<dynamic>> rows = [
      ['Date', 'Time', 'Location', 'Duration (min)', 'Player', 'Phone', 'Buy-Ins', 'Cash-Out', 'Net Profit'],
    ];

    for (var session in sessions) {
      final date = DateFormat('yyyy-MM-dd').format(session.startTime);
      final time = DateFormat('HH:mm').format(session.startTime);
      final durationMin = session.duration.inMinutes;

      for (var player in session.players) {
        rows.add([
          date,
          time,
          session.location,
          durationMin,
          player.player.name,
          player.player.phoneNumber ?? '',
          player.totalBuyIn,
          player.cashOutAmount ?? 0,
          player.netProfit,
        ]);
      }
    }

    await _shareCSV(rows, 'poker_tracker_history');
  }

  /// Export player ledger as CSV and share.
  static Future<void> exportPlayerLedger(List<Map<String, dynamic>> stats) async {
    final List<List<dynamic>> rows = [
      ['Player', 'Games Played', 'Total Net Profit', 'Win Rate %', 'Avg Profit/Game'],
    ];

    for (var stat in stats) {
      rows.add([
        stat['name'],
        stat['gamesPlayed'],
        stat['totalNetProfit'],
        stat['winRate'],
        stat['avgProfit'],
      ]);
    }

    await _shareCSV(rows, 'poker_tracker_ledger');
  }

  /// Export a single game session as CSV and share.
  static Future<void> exportSingleGame(
      List<GamePlayer> players, String location, DateTime startTime) async {
    final List<List<dynamic>> rows = [
      ['Player', 'Buy-Ins', 'Cash-Out', 'Net Profit'],
    ];

    for (var player in players) {
      rows.add([
        player.player.name,
        player.totalBuyIn,
        player.cashOutAmount ?? 0,
        player.netProfit,
      ]);
    }

    final date = DateFormat('yyyy-MM-dd').format(startTime);
    await _shareCSV(rows, 'poker_game_${location.replaceAll(' ', '_')}_$date');
  }

  // --- Fuzzy header alias maps ---
  static const Map<String, List<String>> _headerAliases = {
    'date': ['date', 'game date', 'session date', 'day'],
    'time': ['time', 'start time', 'game time'],
    'location': ['location', 'venue', 'place', 'spot', 'where'],
    'player': ['player', 'name', 'player name', 'username', 'participant'],
    'buy-ins': ['buy-ins', 'buy-in', 'buyin', 'buy in', 'buyins', 'total buy-in', 'total buy in', 'invested', 'entry'],
    'cash-out': ['cash-out', 'cashout', 'cash out', 'payout', 'final', 'final amount', 'cashed out', 'end amount', 'chips out'],
    'phone': ['phone', 'phone number', 'mobile', 'contact', 'cell', 'number'],
  };

  /// Try to match a CSV header to a known field using fuzzy aliases.
  static String? _matchHeader(String rawHeader) {
    final normalized = rawHeader.toLowerCase().trim();
    for (var entry in _headerAliases.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  /// Parse CSV headers and return the column mapping.
  /// Returns {'mapping': Map<String,int>, 'headers': List<String>, 'missing': List<String>}
  static Map<String, dynamic> resolveHeaders(List<dynamic> headerRow) {
    final Map<String, int> mapping = {};
    final List<String> rawHeaders = headerRow.map((e) => e.toString()).toList();

    for (int i = 0; i < rawHeaders.length; i++) {
      final match = _matchHeader(rawHeaders[i]);
      if (match != null && !mapping.containsKey(match)) {
        mapping[match] = i;
      }
    }

    final missing = ['date', 'player', 'buy-ins', 'cash-out']
        .where((h) => !mapping.containsKey(h))
        .toList();

    return {
      'mapping': mapping,
      'headers': rawHeaders,
      'missing': missing,
    };
  }

  /// Import game history from a CSV file with fuzzy header matching.
  static Future<Map<String, dynamic>> parseImportCSV(String csvContent) async {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) {
      return {'error': 'CSV file is empty'};
    }

    final headerResult = resolveHeaders(rows[0]);
    final missing = headerResult['missing'] as List<String>;
    final mapping = headerResult['mapping'] as Map<String, int>;
    final rawHeaders = headerResult['headers'] as List<String>;

    if (missing.isNotEmpty) {
      return {
        'error': 'Could not match required columns: ${missing.join(", ")}.\n\n'
            'Your columns: ${rawHeaders.join(", ")}\n\n'
            'Expected: date, player, buy-ins (or buy in), cash-out (or cashout/payout)',
        'unmapped': missing,
        'headers': rawHeaders,
      };
    }

    final dateIdx = mapping['date']!;
    final timeIdx = mapping['time'];
    final locationIdx = mapping['location'];
    final playerIdx = mapping['player']!;
    final buyInsIdx = mapping['buy-ins']!;
    final cashOutIdx = mapping['cash-out']!;
    final phoneIdx = mapping['phone'];  // optional column

    // Group rows by date+location to form sessions
    final Map<String, List<Map<String, dynamic>>> sessionGroups = {};
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= [dateIdx, playerIdx, buyInsIdx, cashOutIdx].reduce((a, b) => a > b ? a : b)) continue;

      final dateStr = row[dateIdx].toString();
      final location = locationIdx != null ? row[locationIdx].toString() : 'Imported';
      final key = '$dateStr|$location';

      sessionGroups.putIfAbsent(key, () => []);
      sessionGroups[key]!.add({
        'date': dateStr,
        'time': timeIdx != null ? row[timeIdx].toString() : '00:00',
        'location': location,
        'player': row[playerIdx].toString(),
        'buyIns': int.tryParse(row[buyInsIdx].toString().replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0,
        'cashOut': int.tryParse(row[cashOutIdx].toString().replaceAll(RegExp(r'[^\d.-]'), '')) ?? 0,
        'phone': phoneIdx != null ? row[phoneIdx].toString().trim() : null,
      });
    }

    return {
      'sessions': sessionGroups,
      'sessionCount': sessionGroups.length,
      'playerCount': sessionGroups.values
          .expand((list) => list.map((e) => e['player']))
          .toSet()
          .length,
      'resolvedMapping': mapping.map((k, v) => MapEntry(k, rawHeaders[v])),
    };
  }

  /// Actually commit the parsed CSV data into Hive.
  static Future<int> commitImport(Map<String, List<Map<String, dynamic>>> sessionGroups) async {
    final playersBox = Hive.box<Player>('players');
    final historyBox = Hive.box<GameSession>('game_history');
    int importedCount = 0;

    // Generate hashes for existing sessions to prevent duplicates
    final existingHashes = historyBox.values.map((s) {
      final dateStr = DateFormat('yyyy-MM-dd').format(s.startTime);
      final playerNames = s.players.map((p) => p.player.name).toList()..sort();
      return '$dateStr|${s.location}|${playerNames.join(',')}';
    }).toSet();

    for (var entry in sessionGroups.entries) {
      final rows = entry.value;
      if (rows.isEmpty) continue;

      // Parse date
      DateTime startTime;
      try {
        final dateStr = rows[0]['date'] as String;
        final timeStr = rows[0]['time'] as String;
        startTime = DateFormat('yyyy-MM-dd HH:mm').parse('$dateStr $timeStr');
      } catch (_) {
        startTime = DateTime.now();
      }

      final location = rows[0]['location'] as String;
      
      // Check for duplicate
      final incomingPlayerNames = rows.map((r) => r['player'] as String).toList()..sort();
      final incomingHash = '${DateFormat('yyyy-MM-dd').format(startTime)}|$location|${incomingPlayerNames.join(',')}';
      
      if (existingHashes.contains(incomingHash)) {
        continue; // Skip duplicate
      }

      final List<GamePlayer> gamePlayers = [];

      for (var row in rows) {
        final playerName = row['player'] as String;

        // Find or create player
        Player? player;
        try {
          player = playersBox.values.firstWhere((p) => p.name == playerName);
        } catch (_) {
          final key = await playersBox.add(Player(name: playerName));
          player = playersBox.get(key)!;
        }

        // Link phone number if available from CSV
        final csvPhone = row['phone'] as String?;
        if (csvPhone != null && csvPhone.isNotEmpty && !player.isLinked) {
          player.linkPhone(AuthService.normalizePhone(csvPhone));
        }

        final buyInAmount = row['buyIns'] as int;
        final cashOutAmount = row['cashOut'] as int;

        final gp = GamePlayer(
          player: player,
          buyIns: [buyInAmount],
          cashOutAmount: cashOutAmount,
          hasCashedOut: true,
        );
        gamePlayers.add(gp);
      }

      final session = GameSession(
        location: location,
        startTime: startTime,
        endTime: startTime.add(const Duration(hours: 3)), // estimate
        players: gamePlayers,
      );

      await historyBox.add(session);
      existingHashes.add(incomingHash); // add to set so we don't import duplicates within the same CSV
      importedCount++;
    }

    return importedCount;
  }

  /// Internal: write CSV rows to a temp file and share it.
  static Future<void> _shareCSV(List<List<dynamic>> rows, String filename) async {
    final csvString = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.csv');
    await file.writeAsString(csvString);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Poker Tracker Export',
    );
  }

  /// Generate a shareable text summary for a single game.
  static String generateGameSummary(
      List<GamePlayer> players, String location, DateTime startTime) {
    final cs = AppSettings.currencySymbol;
    final date = DateFormat('MMM d, yyyy').format(startTime);
    final buffer = StringBuffer();

    buffer.writeln('🃏 Poker Session — $location');
    buffer.writeln('📅 $date');
    buffer.writeln('─────────────────────');

    // Sort by profit descending
    final sorted = List<GamePlayer>.from(players)
      ..sort((a, b) => b.netProfit.compareTo(a.netProfit));

    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final prefix = i == 0 ? '🏆' : (p.netProfit >= 0 ? '📈' : '📉');
      final sign = p.netProfit >= 0 ? '+' : '';
      buffer.writeln('$prefix ${p.player.name}: $sign$cs${p.netProfit}');
    }

    buffer.writeln('─────────────────────');
    buffer.writeln('Tracked with Poker Tracker 🎰');

    return buffer.toString();
  }
}
