import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/game_player_model.dart';
import '../models/game_session_model.dart';
import '../models/player_model.dart';
import '../models/player_stat.dart';
import '../utils/app_settings.dart';
import 'game_setup_screen.dart';
import 'history_screen.dart';
import 'settle_debts_screen.dart';
import 'settings_screen.dart';
import 'blind_timer_screen.dart';
import 'stats_dashboard_screen.dart';
import 'hand_rankings_screen.dart';
import 'player_ledger_screen.dart';
import 'live_game_screen.dart';
import 'manage_players_screen.dart';
import 'player_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Box<GamePlayer> _liveGameBox;

  @override
  void initState() {
    super.initState();
    _liveGameBox = Hive.box<GamePlayer>('live_game');
  }

  /// Build the overall leaderboard from game history.
  List<Map<String, dynamic>> _buildLeaderboard() {
    final historyBox = Hive.box<GameSession>('game_history');
    final Map<String, Map<String, dynamic>> stats = {};

    for (var session in historyBox.values) {
      for (var gp in session.players) {
        final name = gp.player.name;
        final emoji = gp.player.emoji;
        stats.putIfAbsent(name, () => {'name': name, 'emoji': emoji, 'totalProfit': 0, 'games': 0, 'wins': 0});
        stats[name]!['totalProfit'] = (stats[name]!['totalProfit'] as int) + gp.netProfit;
        stats[name]!['games'] = (stats[name]!['games'] as int) + 1;
        if (gp.netProfit > 0) stats[name]!['wins'] = (stats[name]!['wins'] as int) + 1;
      }
    }

    final list = stats.values.toList();
    list.sort((a, b) => (b['totalProfit'] as int).compareTo(a['totalProfit'] as int));
    return list;
  }

  List<int> _getRecentProfits(String playerName) {
    final historyBox = Hive.box<GameSession>('game_history');
    final sessions = historyBox.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final cumulative = <int>[];
    int running = 0;
    for (var session in sessions) {
      for (var gp in session.players) {
        if (gp.player.name == playerName) {
          running += gp.netProfit;
          cumulative.add(running);
        }
      }
    }
    // Return last 6 cumulative points
    if (cumulative.length > 6) return cumulative.sublist(cumulative.length - 6);
    return cumulative;
  }

  Widget _buildLeaderboardSection() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<GameSession>('game_history').listenable(),
      builder: (context, box, _) {
        final leaderboard = _buildLeaderboard();
        if (leaderboard.isEmpty) return const SizedBox.shrink();

        final cs = AppSettings.currencySymbol;
        final topPlayers = leaderboard.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('🏆 Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerLedgerScreen())),
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 146,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: topPlayers.length,
                itemBuilder: (context, index) {
                  final p = topPlayers[index];
                  final profit = p['totalProfit'] as int;
                  final isPositive = profit >= 0;
                  final medal = index == 0 ? '🥇' : (index == 1 ? '🥈' : (index == 2 ? '🥉' : '#${index + 1}'));
                  final games = p['games'] as int;
                  final wins = p['wins'] as int;
                  final winRate = games > 0 ? (wins / games * 100).toStringAsFixed(0) : '0';

                  final playerName = p['name'] as String;
                  final playerEmoji = p['emoji'] as String;

                  // Find the Player object to pass to detail screen
                  final playersBox = Hive.box<Player>('players');
                  Player? playerObj;
                  try {
                    playerObj = playersBox.values.firstWhere((pl) => pl.name == playerName);
                  } catch (_) {
                    playerObj = null;
                  }

                  return GestureDetector(
                    onTap: playerObj != null ? () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PlayerDetailScreen(player: playerObj!),
                      ));
                    } : null,
                    child: Container(
                      width: 130,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Card(
                        elevation: index < 3 ? 4 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: index == 0 ? BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 1.5) : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(medal, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 4),
                                  Text(playerEmoji, style: const TextStyle(fontSize: 20)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(playerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis, maxLines: 1),
                              const SizedBox(height: 2),
                              Text('${isPositive ? '+' : ''}$cs$profit',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                  color: isPositive ? Colors.greenAccent : Colors.redAccent)),
                              // Sparkline
                              Builder(builder: (_) {
                                final profits = _getRecentProfits(playerName);
                                if (profits.length < 2) {
                                  return Text('$winRate% wins · $games g', style: TextStyle(fontSize: 9, color: Colors.grey.shade500));
                                }
                                final spots = profits.asMap().entries
                                    .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();
                                final trendUp = profits.last >= profits.first;
                                return SizedBox(
                                  width: 80, height: 20,
                                  child: LineChart(LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: const FlTitlesData(show: false),
                                    borderData: FlBorderData(show: false),
                                    lineTouchData: const LineTouchData(enabled: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots,
                                        isCurved: true, curveSmoothness: 0.3,
                                        dotData: const FlDotData(show: false),
                                        barWidth: 1.5,
                                        color: trendUp ? Colors.greenAccent : Colors.redAccent,
                                        belowBarData: BarAreaData(show: false),
                                      ),
                                    ],
                                  )),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }

  Widget _buildDashboardButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
    bool isFeatured = false,
  }) {
    return Card(
      elevation: 4,
      color: isFeatured
          ? (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: 0.8)
          : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40,
                color: isFeatured ? Colors.black : color ?? Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isFeatured ? Colors.black : null),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poker Tracker'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            tooltip: 'Settings'),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _liveGameBox.listenable(),
        builder: (context, Box<GamePlayer> box, _) {
          final isGameActive = box.isNotEmpty;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leaderboard
                _buildLeaderboardSection(),

                // Dashboard grid
                GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    if (isGameActive)
                      _buildDashboardButton(
                        icon: Icons.play_arrow, label: 'Resume Game',
                        isFeatured: true, color: Colors.greenAccent,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveGameScreen())),
                      ),
                    _buildDashboardButton(
                      icon: Icons.play_circle_fill_outlined,
                      label: isGameActive ? 'Start New Game' : 'Start Cash Game',
                      onPressed: () {
                        if (isGameActive) {
                          showDialog(context: context, builder: (ctx) => AlertDialog(
                            title: const Text("Overwrite existing game?"),
                            content: const Text("Starting a new game will delete the current game in progress."),
                            actions: [
                              TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(ctx).pop()),
                              TextButton(child: const Text("Confirm"), onPressed: () {
                                _liveGameBox.clear();
                                Navigator.of(ctx).pop();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const GameSetupScreen()));
                              }),
                            ],
                          ));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const GameSetupScreen()));
                        }
                      },
                    ),
                    _buildDashboardButton(icon: Icons.timer_outlined, label: 'Tournament Timer',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlindTimerScreen()))),
                    _buildDashboardButton(icon: Icons.people_alt_outlined, label: 'Manage Players',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagePlayersScreen()))),
                    _buildDashboardButton(
                      icon: Icons.history, label: 'Game History',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    ),
                    _buildDashboardButton(
                      icon: Icons.bar_chart_rounded, label: 'Stats Dashboard',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsDashboardScreen())),
                    ),
                    _buildDashboardButton(
                      icon: Icons.request_quote_outlined, label: 'Outstanding Debts',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SettleDebtsScreen(playerStats: PlayerStat.calculateAllTimeStats())
                      )),
                    ),
                    _buildDashboardButton(
                      icon: Icons.leaderboard, label: 'Player Ledger',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerLedgerScreen())),
                    ),
                    _buildDashboardButton(icon: Icons.style_outlined, label: 'Hand Rankings',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HandRankingsScreen()))),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
