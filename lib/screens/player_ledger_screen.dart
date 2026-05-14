import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_session_model.dart';
import '../models/player_model.dart';
import '../utils/app_settings.dart';
import '../utils/csv_helper.dart';
import 'player_detail_screen.dart';
import 'settle_debts_screen.dart';

import '../models/player_stat.dart';

class PlayerLedgerScreen extends StatelessWidget {
  const PlayerLedgerScreen({super.key});

  void _exportLedgerCSV(List<PlayerStat> stats) {
    final data = stats
        .map((s) => {
              'name': s.player.name,
              'gamesPlayed': s.gamesPlayed,
              'totalNetProfit': s.totalNetProfit,
              'winRate': s.winRate.toStringAsFixed(1),
              'avgProfit': s.avgProfit.toStringAsFixed(2),
            })
        .toList();
    CsvHelper.exportPlayerLedger(data);
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppSettings.currencySymbol;

    // Reactive: listens to both boxes
    return ValueListenableBuilder(
      valueListenable: Hive.box<GameSession>('game_history').listenable(),
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<Player>('players').listenable(),
          builder: (context, _, __) {
            final playerStats = PlayerStat.calculateAllTimeStats();

            return Scaffold(
              appBar: AppBar(
                title: const Text("Player Ledger"),
                actions: [
                  if (playerStats.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined),
                      onPressed: () => _exportLedgerCSV(playerStats),
                      tooltip: 'Export Ledger CSV',
                    ),
                ],
              ),
              body: playerStats.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.leaderboard_outlined,
                              size: 80,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          const Text("No player stats yet."),
                          const Text("Play some games to see the leaderboard!",
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: playerStats.length,
                      itemBuilder: (context, index) {
                        final stat = playerStats[index];
                        final isProfit = stat.totalNetProfit >= 0;

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PlayerDetailScreen(player: stat.player),
                                ),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Text(stat.player.emoji,
                                  style: const TextStyle(fontSize: 20)),
                            ),
                            title: Text(
                              stat.player.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                                "Games: ${stat.gamesPlayed} • Win Rate: ${stat.winRate.toStringAsFixed(0)}%"),
                            trailing: Text(
                              "${isProfit ? '+' : ''}$cs${stat.totalNetProfit}",
                              style: TextStyle(
                                color: isProfit
                                    ? Colors.green.shade600
                                    : Colors.red.shade600,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              floatingActionButton: playerStats.isNotEmpty
                  ? FloatingActionButton.extended(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SettleDebtsScreen(playerStats: playerStats),
                          ),
                        );
                      },
                      label: const Text("Settle Debts"),
                      icon: const Icon(Icons.request_quote_outlined),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
