import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/game_session_model.dart';
import '../utils/app_settings.dart';

class StatsDashboardScreen extends StatelessWidget {
  const StatsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stats Dashboard"),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<GameSession>('game_history').listenable(),
        builder: (context, Box<GameSession> box, _) {
          final sessions = box.values.toList();

          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 80,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text("No stats yet."),
                  const Text("Play some games to see aggregate stats!",
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            );
          }

          final cs = AppSettings.currencySymbol;

          // Calculate aggregate stats
          final totalGames = sessions.length;

          final totalDuration = sessions.fold<Duration>(
            Duration.zero,
            (sum, s) => sum + s.duration,
          );
          final avgDurationMin =
              totalGames > 0 ? totalDuration.inMinutes / totalGames : 0;

          // All player results across all games
          final allResults =
              sessions.expand((s) => s.players).toList();
          final totalPlayers =
              allResults.map((p) => p.player.name).toSet().length;

          final totalMoneyInPlay =
              allResults.fold<int>(0, (sum, p) => sum + p.totalBuyIn);

          // Biggest single-game win and loss
          int biggestWin = 0;
          String biggestWinPlayer = '';
          String biggestWinGame = '';
          int biggestLoss = 0;
          String biggestLossPlayer = '';
          String biggestLossGame = '';

          for (var session in sessions) {
            for (var p in session.players) {
              if (p.netProfit > biggestWin) {
                biggestWin = p.netProfit;
                biggestWinPlayer = '${p.player.emoji} ${p.player.name}';
                biggestWinGame =
                    '${session.location} (${DateFormat.yMMMd().format(session.startTime)})';
              }
              if (p.netProfit < biggestLoss) {
                biggestLoss = p.netProfit;
                biggestLossPlayer = '${p.player.emoji} ${p.player.name}';
                biggestLossGame =
                    '${session.location} (${DateFormat.yMMMd().format(session.startTime)})';
              }
            }
          }

          // Most frequent player
          final playerFrequency = <String, int>{};
          final playerEmojis = <String, String>{};
          for (var r in allResults) {
            playerFrequency[r.player.name] =
                (playerFrequency[r.player.name] ?? 0) + 1;
            playerEmojis[r.player.name] = r.player.emoji;
          }
          final mostFrequentPlayer = playerFrequency.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // Most common location
          final locationFrequency = <String, int>{};
          for (var s in sessions) {
            locationFrequency[s.location] =
                (locationFrequency[s.location] ?? 0) + 1;
          }
          final mostCommonLocation = locationFrequency.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview cards
                Text("Overview",
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _buildStatTile(context, "Total Games", "$totalGames",
                        Icons.casino, Colors.tealAccent),
                    _buildStatTile(
                        context,
                        "Avg Duration",
                        "${avgDurationMin.toStringAsFixed(0)} min",
                        Icons.timer_outlined,
                        Colors.blueAccent),
                    _buildStatTile(
                        context,
                        "Unique Players",
                        "$totalPlayers",
                        Icons.people_outline,
                        Colors.purpleAccent),
                    _buildStatTile(
                        context,
                        "Total Money Played",
                        "$cs$totalMoneyInPlay",
                        Icons.monetization_on_outlined,
                        Colors.amberAccent),
                  ],
                ),

                const SizedBox(height: 24),

                // Records
                Text("Records",
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),

                if (biggestWin > 0)
                  _buildRecordCard(
                    context,
                    icon: Icons.emoji_events,
                    iconColor: Colors.amber,
                    title: "Biggest Single-Game Win",
                    value: "+$cs$biggestWin",
                    valueColor: Colors.green,
                    subtitle: "$biggestWinPlayer\n$biggestWinGame",
                  ),

                if (biggestLoss < 0)
                  _buildRecordCard(
                    context,
                    icon: Icons.trending_down,
                    iconColor: Colors.red,
                    title: "Biggest Single-Game Loss",
                    value: "$cs$biggestLoss",
                    valueColor: Colors.red,
                    subtitle: "$biggestLossPlayer\n$biggestLossGame",
                  ),

                const SizedBox(height: 24),

                // Frequency
                Text("Regulars",
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),

                if (mostFrequentPlayer.isNotEmpty)
                  ...mostFrequentPlayer.take(5).map((entry) {
                    final emoji = playerEmojis[entry.key] ?? '🎯';
                    return ListTile(
                      leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(entry.key),
                      trailing: Text("${entry.value} games",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }),

                const SizedBox(height: 24),

                // Locations
                Text("Favourite Spots",
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),

                if (mostCommonLocation.isNotEmpty)
                  ...mostCommonLocation.take(3).map((entry) {
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(entry.key),
                      trailing: Text("${entry.value} games",
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value,
      IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color valueColor,
    required String subtitle,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13)),
                  Text(value,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: valueColor)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
