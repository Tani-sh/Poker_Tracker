import 'package:hive/hive.dart';
import 'game_session_model.dart';
import 'player_model.dart';

class PlayerStat {
  final Player player;
  final int totalNetProfit;
  final int gamesPlayed;
  final double winRate;
  final double avgProfit;

  PlayerStat({
    required this.player,
    required this.totalNetProfit,
    required this.gamesPlayed,
    required this.winRate,
    required this.avgProfit,
  });

  static List<PlayerStat> calculateAllTimeStats() {
    final historyBox = Hive.box<GameSession>('game_history');
    final playersBox = Hive.box<Player>('players');

    final Map<String, Map<String, dynamic>> statsMap = {};

    for (var player in playersBox.values) {
      if (player.isArchived) continue;
      statsMap[player.name] = {
        'player': player,
        'totalNetProfit': 0,
        'gamesPlayed': 0,
        'gamesWon': 0,
      };
    }

    for (var session in historyBox.values) {
      for (var gamePlayer in session.players) {
        final playerName = gamePlayer.player.name;
        if (statsMap.containsKey(playerName)) {
          statsMap[playerName]!['totalNetProfit'] += gamePlayer.netProfit;
          statsMap[playerName]!['gamesPlayed'] += 1;
          if (gamePlayer.netProfit > 0) {
            statsMap[playerName]!['gamesWon'] += 1;
          }
        }
      }
    }

    final sortedStats = statsMap.values.map((s) {
      final gp = s['gamesPlayed'] as int;
      return PlayerStat(
        player: s['player'] as Player,
        totalNetProfit: s['totalNetProfit'] as int,
        gamesPlayed: gp,
        winRate: gp > 0 ? (s['gamesWon'] as int) / gp * 100 : 0.0,
        avgProfit: gp > 0 ? (s['totalNetProfit'] as int) / gp : 0.0,
      );
    }).toList();

    sortedStats.sort((a, b) => b.totalNetProfit.compareTo(a.totalNetProfit));
    return sortedStats;
  }
  
  static List<PlayerStat> fromGameSession(GameSession session) {
    return session.players.map((gp) {
      return PlayerStat(
        player: gp.player,
        totalNetProfit: gp.netProfit,
        gamesPlayed: 1,
        winRate: gp.netProfit > 0 ? 100.0 : 0.0,
        avgProfit: gp.netProfit.toDouble(),
      );
    }).toList()
      ..sort((a, b) => b.totalNetProfit.compareTo(a.totalNetProfit));
  }
}
