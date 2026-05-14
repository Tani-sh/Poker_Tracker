import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import '../models/game_player_model.dart';
import '../models/game_session_model.dart';
import '../utils/app_settings.dart';
import '../utils/csv_helper.dart';

class EndGameScreen extends StatefulWidget {
  final List<GamePlayer> gamePlayers;
  final String location;
  final DateTime startTime;

  const EndGameScreen({
    super.key,
    required this.gamePlayers,
    required this.location,
    required this.startTime,
  });

  @override
  State<EndGameScreen> createState() => _EndGameScreenState();
}

class _EndGameScreenState extends State<EndGameScreen> {
  final TextEditingController _notesController = TextEditingController();

  // Calculate historical stats for a player (excluding current game)
  Map<String, dynamic> _getPlayerHistory(String playerName) {
    final historyBox = Hive.box<GameSession>('game_history');
    int games = 0, wins = 0, totalProfit = 0;
    for (var session in historyBox.values) {
      for (var gp in session.players) {
        if (gp.player.name == playerName) {
          games++;
          totalProfit += gp.netProfit;
          if (gp.netProfit > 0) wins++;
        }
      }
    }
    return {
      'games': games,
      'totalProfit': totalProfit,
      'winRate': games > 0 ? (wins / games * 100) : 0.0,
      'avgProfit': games > 0 ? (totalProfit / games) : 0.0,
    };
  }

  Widget _buildBalanceStatus(int difference) {
    final cs = AppSettings.currencySymbol;
    String message;
    Color color;
    IconData icon;

    if (difference == 0) {
      message = "All chips are accounted for. The game is balanced.";
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (difference > 0) {
      message = "There are $cs${difference.abs()} extra chips in play.";
      color = Colors.orange;
      icon = Icons.warning;
    } else {
      message = "There are $cs${difference.abs()} chips missing from play.";
      color = Colors.red;
      icon = Icons.error;
    }

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.all(12.0),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  void _saveGameAndFinish() {
    final session = GameSession(
      location: widget.location,
      startTime: widget.startTime,
      endTime: DateTime.now(),
      players: widget.gamePlayers,
      notes: _notesController.text.trim(),
    );
    Hive.box<GameSession>('game_history').add(session);
    Hive.box<GamePlayer>('live_game').clear();
    AppSettings.clearGameState();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _confirmSaveUnbalanced() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Save Unbalanced Game?"),
        content: const Text(
          "The chips don't balance. This could mean a buy-in was missed or a cash-out was miscounted.\n\nAre you sure you want to save anyway?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
          TextButton(
            onPressed: () { Navigator.of(ctx).pop(); _saveGameAndFinish(); },
            child: const Text("Save Anyway", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _shareResults() {
    Share.share(CsvHelper.generateGameSummary(widget.gamePlayers, widget.location, widget.startTime));
  }

  void _exportCSV() {
    CsvHelper.exportSingleGame(widget.gamePlayers, widget.location, widget.startTime);
  }

  void _showSplitPotDialog() {
    final cs = AppSettings.currencySymbol;
    final uncashedPlayers = widget.gamePlayers.where((gp) => !gp.hasCashedOut).toList();
    if (uncashedPlayers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Need at least 2 uncashed players to split.')));
      return;
    }

    final selected = <GamePlayer>{};
    final potCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('🤝 Split Pot'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Select players splitting the pot:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          ...uncashedPlayers.map((gp) => CheckboxListTile(
            title: Text('${gp.player.emoji} ${gp.player.name}'),
            subtitle: Text('Invested: $cs${gp.totalBuyIn}'),
            value: selected.contains(gp), dense: true,
            onChanged: (v) => setDialogState(() {
              if (v == true) {
                selected.add(gp);
              } else {
                selected.remove(gp);
              }
            }),
          )),
          const SizedBox(height: 8),
          TextField(controller: potCtrl, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total pot to split', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (selected.length < 2) return;
            final pot = int.tryParse(potCtrl.text) ?? 0;
            if (pot <= 0) return;
            final share = pot ~/ selected.length;
            final remainder = pot % selected.length;
            int i = 0;
            for (var gp in selected) {
              gp.cashOut(share + (i == 0 ? remainder : 0));
              i++;
            }
            final names = selected.map((gp) => gp.player.name).join(' & ');
            _notesController.text += '\n🤝 Pot split between $names ($cs$pot total)';
            Navigator.of(ctx).pop();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🤝 $cs$pot split between ${selected.length} players')));
          }, child: const Text('Split')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppSettings.currencySymbol;
    final totalBuyIns = widget.gamePlayers.fold<int>(0, (s, p) => s + p.totalBuyIn);
    final totalCashOuts = widget.gamePlayers.fold<int>(0, (s, p) => s + (p.cashOutAmount ?? 0));
    final difference = totalCashOuts - totalBuyIns;
    final isBalanced = difference == 0;

    final sortedPlayers = List<GamePlayer>.from(widget.gamePlayers)
      ..sort((a, b) => b.netProfit.compareTo(a.netProfit));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Game Results"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _shareResults, tooltip: 'Share'),
          PopupMenuButton(
            itemBuilder: (_) => [const PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Export CSV'), dense: true))],
            onSelected: (v) { if (v == 'csv') _exportCSV(); },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceStatus(difference),
          Expanded(
            child: ListView(
              children: [
                ...sortedPlayers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final player = entry.value;
                  final netProfit = player.netProfit;
                  final isProfit = netProfit >= 0;
                  final medal = index == 0 ? '🥇 ' : (index == 1 ? '🥈 ' : (index == 2 ? '🥉 ' : ''));
                  final history = _getPlayerHistory(player.player.name);

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Main result row
                          Row(children: [
                            Text(player.player.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('$medal${player.player.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("Buy-ins: $cs${player.totalBuyIn} • Out: $cs${player.cashOutAmount ?? 0}",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              if (player.joinTime != null && player.joinTime!.isAfter(widget.startTime.add(const Duration(minutes: 2))))
                                Text('⏰ Joined ${player.joinTime!.difference(widget.startTime).inMinutes}m late',
                                  style: const TextStyle(fontSize: 11, color: Colors.amber)),
                            ])),
                            Text("${isProfit ? '+' : ''}$cs$netProfit",
                              style: TextStyle(color: isProfit ? Colors.green.shade400 : Colors.red.shade400,
                                fontSize: 18, fontWeight: FontWeight.bold)),
                          ]),
                          // Historical stats row
                          if (history['games'] > 0) ...[
                            const Divider(height: 16),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                              _statChip("${history['games']} games", Icons.casino, Colors.grey),
                              _statChip("${(history['winRate'] as double).toStringAsFixed(0)}% wins", Icons.emoji_events,
                                (history['winRate'] as double) >= 50 ? Colors.amber : Colors.grey),
                              _statChip(
                                "${(history['totalProfit'] as int) >= 0 ? '+' : ''}$cs${history['totalProfit']}",
                                Icons.trending_up,
                                (history['totalProfit'] as int) >= 0 ? Colors.greenAccent : Colors.redAccent),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                // Split pot button
                if (widget.gamePlayers.where((gp) => !gp.hasCashedOut).length >= 2)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.handshake_outlined),
                      label: const Text('Split Pot'),
                      onPressed: _showSplitPotDialog,
                    ),
                  ),
                // Notes
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _notesController, maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Game Notes (optional)", hintText: "Any memorable hands or events...",
                      border: OutlineInputBorder(), prefixIcon: Icon(Icons.note_add_outlined)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: Icon(isBalanced ? Icons.flag : Icons.warning_amber),
          label: Text(isBalanced ? "Finish Game & Save" : "Save Anyway (Unbalanced)"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            backgroundColor: isBalanced ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
          ),
          onPressed: isBalanced ? _saveGameAndFinish : _confirmSaveUnbalanced,
        ),
      ),
    );
  }

  Widget _statChip(String label, IconData icon, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }
}
