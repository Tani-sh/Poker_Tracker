import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/player_model.dart';
import '../models/game_session_model.dart';
import '../models/group_preset_model.dart';
import '../utils/app_settings.dart';
import 'live_game_screen.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  final Box<Player> _playersBox = Hive.box<Player>('players');
  final List<Player> _selectedPlayers = [];
  final TextEditingController _locationController = TextEditingController();
  bool _fetchingLocation = false;

  Future<void> _autoDetectLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied.')));
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permanently denied. Enable in Settings.')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)));
      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.name, p.subLocality, p.locality].where((s) => s != null && s.isNotEmpty);
        final location = parts.take(2).join(', ');
        _locationController.text = location;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📍 $location')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  // Get previously used locations for auto-suggest
  List<String> _getPreviousLocations() {
    final historyBox = Hive.box<GameSession>('game_history');
    final locations = historyBox.values
        .map((s) => s.location)
        .where((l) => l.isNotEmpty && l != 'Unknown Location')
        .toSet()
        .toList();
    locations.sort();
    return locations;
  }

  void _togglePlayerSelection(Player player) {
    setState(() {
      final isSelected = _selectedPlayers.any((p) => p.key == player.key);
      if (isSelected) {
        _selectedPlayers.removeWhere((p) => p.key == player.key);
      } else {
        _selectedPlayers.add(player);
      }
    });
  }

  void _showAddPlayerDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Create New Player"),
              content: TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: "Player Name"),
                  autofocus: true),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("Cancel")),
                TextButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        _playersBox.add(Player(name: name));
                      }
                      Navigator.of(context).pop();
                    },
                    child: const Text("Add")),
              ],
            ));
  }

  void _loadPreset(GroupPreset preset) {
    final players = <Player>[];
    for (var key in preset.playerKeys) {
      final p = _playersBox.get(key);
      if (p != null && !p.isArchived) players.add(p);
    }
    if (players.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active players found in this group.')));
      return;
    }
    setState(() {
      _selectedPlayers.clear();
      _selectedPlayers.addAll(players);
      if (preset.location.isNotEmpty) _locationController.text = preset.location;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚡ Loaded "${preset.name}" (${players.length} players)')));
  }

  void _saveGroupPreset() {
    final nameCtrl = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Save Group Preset'),
      content: TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'e.g., Friday Boys', border: OutlineInputBorder()), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () {
          final name = nameCtrl.text.trim();
          if (name.isNotEmpty) {
            final presetsBox = Hive.box<GroupPreset>('group_presets');
            presetsBox.add(GroupPreset(
              name: name,
              playerKeys: _selectedPlayers.map((p) => p.key as int).toList(),
              defaultBuyIn: AppSettings.defaultBuyIn,
              location: _locationController.text.trim(),
            ));
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Saved "$name" as group preset')));
          }
          Navigator.of(ctx).pop();
        }, child: const Text('Save')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final previousLocations = _getPreviousLocations();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Setup New Game"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt),
            onPressed: _showAddPlayerDialog,
            tooltip: 'Create New Player',
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: _playersBox.listenable(),
        builder: (context, Box<Player> box, _) {
          final players = box.values
              .where((player) => !player.isArchived)
              .toList();

          if (players.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 80,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  const Text("No active players found."),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddPlayerDialog,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Player"),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              // Quick Start presets
              ValueListenableBuilder(
                valueListenable: Hive.box<GroupPreset>('group_presets').listenable(),
                builder: (context, Box<GroupPreset> presetsBox, _) {
                  if (presetsBox.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Text('⚡ Quick Start', style: Theme.of(context).textTheme.titleSmall),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: presetsBox.toMap().entries.map((entry) {
                            final preset = entry.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onLongPress: () {
                                  showDialog(context: context, builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Preset?'),
                                    content: Text('Remove "${preset.name}"?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                      TextButton(onPressed: () { preset.delete(); Navigator.of(ctx).pop(); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ));
                                },
                                child: ActionChip(
                                  label: Text(preset.name),
                                  avatar: const Icon(Icons.group, size: 16),
                                  onPressed: () => _loadPreset(preset),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return previousLocations;
                          }
                          return previousLocations.where((l) => l
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                        },
                        fieldViewBuilder:
                            (context, controller, focusNode, onSubmitted) {
                          _locationController.text = controller.text;
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: "Location",
                              hintText: "e.g., Home, Office",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            onChanged: (v) => _locationController.text = v,
                          );
                        },
                        onSelected: (String selection) {
                          _locationController.text = selection;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _fetchingLocation ? null : _autoDetectLocation,
                      icon: _fetchingLocation
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      tooltip: 'Auto-detect location',
                    ),
                  ],
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text(
                      "Select Players (${_selectedPlayers.length} selected)",
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedPlayers.length == players.length) {
                            _selectedPlayers.clear();
                          } else {
                            _selectedPlayers.clear();
                            _selectedPlayers.addAll(players);
                          }
                        });
                      },
                      child: Text(_selectedPlayers.length == players.length
                          ? "Deselect All"
                          : "Select All"),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    final isSelected =
                        _selectedPlayers.any((p) => p.key == player.key);
                    return CheckboxListTile(
                      title: Text('${player.emoji}  ${player.name}'),
                      value: isSelected,
                      onChanged: (bool? value) {
                        _togglePlayerSelection(player);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            if (_selectedPlayers.length >= 2)
              IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Save as Group Preset',
                onPressed: _saveGroupPreset,
              ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _selectedPlayers.length < 2
                    ? null
                    : () {
                        Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (context) => LiveGameScreen(
                            initialPlayers: _selectedPlayers,
                            location: _locationController.text.trim(),
                          )));
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text("Start Game (${_selectedPlayers.length} players)"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
