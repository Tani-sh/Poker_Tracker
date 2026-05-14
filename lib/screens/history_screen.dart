import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/game_session_model.dart';
import '../models/player_stat.dart';
import '../utils/app_settings.dart';
import '../utils/csv_helper.dart';
import 'settle_debts_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  String _formatDuration(Duration d) {
    String td(int n) => n.toString().padLeft(2, "0");
    return "${td(d.inHours)}:${td(d.inMinutes.remainder(60))}:${td(d.inSeconds.remainder(60))}";
  }

  void _shareSession(GameSession session) {
    Share.share(CsvHelper.generateGameSummary(session.players, session.location, session.startTime));
  }

  void _deleteSession(BuildContext context, GameSession session) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Delete This Game?"),
      content: Text("Delete the ${session.location} game from ${DateFormat.yMMMd().format(session.startTime)}?\n\nThis cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
        TextButton(onPressed: () { session.delete(); Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Game deleted.')));
        }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  Future<void> _importCSV(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final csvContent = await file.readAsString();
      final parsed = await CsvHelper.parseImportCSV(csvContent);

      if (parsed.containsKey('error')) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${parsed['error']}')));
        return;
      }
      if (!context.mounted) return;

      final resolvedMapping = parsed['resolvedMapping'] as Map<String, String>?;

      final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Import Preview"),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Sessions to import: ${parsed['sessionCount']}"),
          Text("Unique players: ${parsed['playerCount']}"),
          if (resolvedMapping != null) ...[
            const SizedBox(height: 12),
            const Text("Column mapping:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            ...resolvedMapping.entries.map((e) => Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text('${e.key} ← "${e.value}"', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            )),
          ],
          const SizedBox(height: 12),
          const Text("Players not found in your roster will be created automatically.", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("Import")),
        ],
      ));

      if (confirmed == true && context.mounted) {
        final count = await CsvHelper.commitImport(parsed['sessions'] as Map<String, List<Map<String, dynamic>>>);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported $count session(s)!')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Box<GameSession> historyBox = Hive.box<GameSession>('game_history');
    final cs = AppSettings.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Game History"),
      ),
      body: ValueListenableBuilder(
        valueListenable: historyBox.listenable(),
        builder: (context, Box<GameSession> box, _) {
          final sessions = box.values.toList().cast<GameSession>().reversed.toList();
          if (sessions.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.history_toggle_off, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text("No game history found."),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () => _importCSV(context), icon: const Icon(Icons.file_upload_outlined), label: const Text("Import CSV")),
            ]));
          }
          return Column(
            children: [
              // Prominent CSV action bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _importCSV(context),
                      icon: const Icon(Icons.file_upload_outlined, size: 18),
                      label: const Text('Import CSV'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => CsvHelper.exportGameHistory(),
                      icon: const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Export All'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text('${sessions.length} ${sessions.length == 1 ? 'game' : 'games'} recorded',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
              Expanded(child: ListView.builder(
                itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final date = DateFormat.yMMMd().format(session.startTime);
              final time = DateFormat.jm().format(session.startTime);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text(session.location, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("$date at $time • ${_formatDuration(session.duration)}"),
                  children: [
                    ...session.players.map((player) {
                      final net = player.netProfit;
                      final up = net >= 0;
                      return ListTile(
                        leading: Text(player.player.emoji, style: const TextStyle(fontSize: 20)),
                        title: Text(player.player.name),
                        subtitle: Text("Buy-ins: $cs${player.totalBuyIn} • Out: $cs${player.cashOutAmount ?? 0}"),
                        trailing: Text("${up ? '+' : ''}$cs$net",
                          style: TextStyle(color: up ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                      );
                    }),
                    if (session.notes.isNotEmpty)
                      Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(children: [
                          const Icon(Icons.note, size: 16, color: Colors.grey), const SizedBox(width: 8),
                          Expanded(child: Text(session.notes, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
                        ])),
                    // Action buttons
                    Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton.icon(icon: const Icon(Icons.request_quote_outlined, size: 18), label: const Text("Settle"),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) => SettleDebtsScreen(
                                playerStats: PlayerStat.fromGameSession(session),
                                location: session.location,
                                gameDate: session.startTime,
                              )
                            ));
                          }),
                        TextButton.icon(icon: const Icon(Icons.share_outlined, size: 18), label: const Text("Share"),
                          onPressed: () => _shareSession(session)),
                        TextButton.icon(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          label: const Text("Delete", style: TextStyle(color: Colors.red)),
                          onPressed: () => _deleteSession(context, session)),
                      ]),
                    ),
                  ],
                ),
              );
            },
          )),
            ],
          );
        },
      ),
    );
  }
}
