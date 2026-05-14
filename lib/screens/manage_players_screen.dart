import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/player_model.dart';
import 'player_ledger_screen.dart';

class ManagePlayersScreen extends StatefulWidget {
  const ManagePlayersScreen({super.key});

  @override
  State<ManagePlayersScreen> createState() => _ManagePlayersScreenState();
}

class _ManagePlayersScreenState extends State<ManagePlayersScreen> {
  final Box<Player> _playersBox = Hive.box<Player>('players');
  final TextEditingController _nameController = TextEditingController();
  bool _showArchived = false;

  void _showAddPlayerDialog() {
    _nameController.clear();
    String selectedEmoji = Player.randomEmoji();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add New Player"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: "Player Name"),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text("Choose Avatar:"),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.count(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: Player.availableEmojis.map((emoji) {
                    final isSelected = emoji == selectedEmoji;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => selectedEmoji = emoji),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  width: 2)
                              : null,
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1)
                              : null,
                        ),
                        child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 20))),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final name = _nameController.text.trim();
                if (name.isEmpty) { Navigator.of(context).pop(); return; }
                // Duplicate check
                if (_playersBox.values.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('A player with this name already exists.')));
                  return;
                }
                _playersBox.add(Player(name: name, isArchived: false, emoji: selectedEmoji));
                Navigator.of(context).pop();
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Player player) {
    final ctrl = TextEditingController(text: player.name);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Rename Player"),
      content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: "New name")),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
        TextButton(onPressed: () {
          final newName = ctrl.text.trim();
          if (newName.isEmpty || newName == player.name) { Navigator.of(ctx).pop(); return; }
          if (_playersBox.values.any((p) => p.name.toLowerCase() == newName.toLowerCase() && p.key != player.key)) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name already taken.')));
            return;
          }
          player.name = newName;
          player.save();
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Renamed to $newName')));
        }, child: const Text("Rename")),
      ],
    ));
  }

  void _showEditEmojiDialog(Player player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Change Avatar for ${player.name}"),
        content: SizedBox(
          width: 280,
          height: 120,
          child: GridView.count(
            crossAxisCount: 8,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: Player.availableEmojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  player.updateEmoji(emoji);
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: emoji == player.emoji
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2)
                        : null,
                  ),
                  child:
                      Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _confirmPermanentDelete(Player player) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Permanently Delete ${player.name}?"),
        content: const Text(
            "This action cannot be undone and will permanently remove the player from all history."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              player.delete();
              Navigator.of(context).pop();
            },
            child: const Text("Delete Forever",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? "Archived Players" : "Manage Players"),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlayerLedgerScreen()),
            ),
            tooltip: 'View Player Ledger',
          ),
          IconButton(
            icon: Icon(_showArchived
                ? Icons.inventory_2_outlined
                : Icons.archive_outlined),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
              });
            },
            tooltip:
                _showArchived ? 'Show Active Players' : 'Show Archived Players',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _playersBox.listenable(),
        builder: (context, Box<Player> box, _) {
          final players = box.values
              .where((player) => player.isArchived == _showArchived)
              .toList();

          if (players.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showArchived
                        ? Icons.archive_outlined
                        : Icons.people_outline,
                    size: 80,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(_showArchived
                      ? "No archived players."
                      : "No active players found."),
                  if (!_showArchived) ...[
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddPlayerDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("Add Player"),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              return ListTile(
                leading: GestureDetector(
                  onTap: () => _showEditEmojiDialog(player),
                  child: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(player.emoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                title: Text(player.name),
                onLongPress: _showArchived ? null : () => _showRenameDialog(player),
                trailing: _showArchived
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.unarchive,
                                color: Colors.green),
                            onPressed: () => player.unarchive(),
                            tooltip: 'Unarchive Player',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever,
                                color: Colors.red),
                            onPressed: () => _confirmPermanentDelete(player),
                            tooltip: 'Delete Permanently',
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.archive, color: Colors.orange),
                        onPressed: () => player.archive(),
                        tooltip: 'Archive Player',
                      ),
              );
            },
          );
        },
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              onPressed: _showAddPlayerDialog,
              tooltip: 'Add Player',
              child: const Icon(Icons.add),
            ),
    );
  }
}
