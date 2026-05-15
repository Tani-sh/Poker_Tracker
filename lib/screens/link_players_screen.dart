import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/player_model.dart';
import '../widgets/contact_picker_sheet.dart';

/// Bulk screen to link existing name-only players to phone contacts.
/// Shown after first login or accessible from Settings.
class LinkPlayersScreen extends StatefulWidget {
  const LinkPlayersScreen({super.key});

  @override
  State<LinkPlayersScreen> createState() => _LinkPlayersScreenState();
}

class _LinkPlayersScreenState extends State<LinkPlayersScreen> {
  late final Box<Player> _playersBox;
  List<Player> _unlinkedPlayers = [];

  @override
  void initState() {
    super.initState();
    _playersBox = Hive.box<Player>('players');
    _refreshList();
  }

  void _refreshList() {
    setState(() {
      _unlinkedPlayers = _playersBox.values
          .where((p) => !p.isArchived && !p.isLinked)
          .toList();
    });
  }

  int get _totalActive => _playersBox.values.where((p) => !p.isArchived).length;
  int get _linkedCount => _totalActive - _unlinkedPlayers.length;

  void _pickContactFor(Player player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactPickerSheet(
        onContactSelected: (name, phone) {
          // Check if another player already has this phone
          final existing = _playersBox.values
              .where((p) => p.phoneNumber == phone && p.key != player.key)
              .toList();

          if (existing.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('⚠️ ${existing.first.name} already has this number')),
            );
            return;
          }

          player.linkPhone(phone);
          _refreshList();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ ${player.name} linked to $phone')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalActive > 0 ? _linkedCount / _totalActive : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Players to Contacts'),
      ),
      body: Column(
        children: [
          // Progress header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: Column(
              children: [
                Text(
                  '$_linkedCount of $_totalActive linked',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0 ? Colors.greenAccent : Colors.tealAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Link players to phone contacts so they can log in\nand see their game history on their own device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),

          // Player list
          Expanded(
            child: _unlinkedPlayers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        const Text('All players linked!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _unlinkedPlayers.length,
                    itemBuilder: (context, index) {
                      final player = _unlinkedPlayers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(player.emoji, style: const TextStyle(fontSize: 20)),
                          ),
                          title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('No phone linked', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonal(
                                onPressed: () => _pickContactFor(player),
                                child: const Text('Link Contact'),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  // Just skip — leave unlinked
                                  setState(() => _unlinkedPlayers.removeAt(index));
                                },
                                child: Text('Skip', style: TextStyle(color: Colors.grey.shade500)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom action
          if (_unlinkedPlayers.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done — Link the rest later'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
