import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import '../main.dart' show appVersion;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _isDarkMode;
  late String _currencySymbol;
  late int _defaultBuyIn;
  late List<int> _rebuyDenominations;
  late int _maxBuyInLimit;

  @override
  void initState() {
    super.initState();
    _isDarkMode = AppSettings.isDarkMode;
    _currencySymbol = AppSettings.currencySymbol;
    _defaultBuyIn = AppSettings.defaultBuyIn;
    _rebuyDenominations = AppSettings.rebuyDenominations;
    _maxBuyInLimit = AppSettings.maxBuyInPerPlayer;
  }

  void _toggleTheme(bool value) {
    setState(() => _isDarkMode = value);
    AppSettings.isDarkMode = value;
  }

  void _showEditBuyInDialog() {
    final controller =
        TextEditingController(text: _defaultBuyIn.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Default Buy-in Amount"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: '$_currencySymbol ',
            hintText: "Enter amount",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final amount = int.tryParse(controller.text);
              if (amount != null && amount > 0) {
                setState(() => _defaultBuyIn = amount);
                AppSettings.defaultBuyIn = amount;
              }
              Navigator.of(context).pop();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showEditDenominationsDialog() {
    final controllers = _rebuyDenominations
        .map((d) => TextEditingController(text: d.toString()))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Re-buy Button Amounts"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...controllers.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: '$_currencySymbol ',
                              labelText: 'Button ${entry.key + 1}',
                            ),
                          ),
                        ),
                        if (controllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red),
                            onPressed: () {
                              setDialogState(() {
                                controllers.removeAt(entry.key);
                              });
                            },
                          ),
                      ],
                    ),
                  );
                }),
                if (controllers.length < 4)
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Add Button"),
                    onPressed: () {
                      setDialogState(() {
                        controllers.add(TextEditingController(text: '500'));
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                final denoms = controllers
                    .map((c) => int.tryParse(c.text) ?? 0)
                    .where((v) => v > 0)
                    .toList();
                if (denoms.isNotEmpty) {
                  setState(() => _rebuyDenominations = denoms);
                  AppSettings.rebuyDenominations = denoms;
                }
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBuyInLimitDialog() {
    final controller = TextEditingController(text: _maxBuyInLimit == 0 ? '' : _maxBuyInLimit.toString());
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Max Buy-in Per Player'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Set a maximum total buy-in limit per player per game. Leave empty or 0 for unlimited.', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        TextField(controller: controller, keyboardType: TextInputType.number, autofocus: true,
          decoration: InputDecoration(prefixText: '$_currencySymbol ', hintText: '0 = unlimited', border: const OutlineInputBorder())),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () {
          final amount = int.tryParse(controller.text) ?? 0;
          setState(() => _maxBuyInLimit = amount);
          AppSettings.maxBuyInPerPlayer = amount;
          Navigator.of(context).pop();
        }, child: const Text('Save')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // --- Appearance ---
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Reduces glare and improves battery life.'),
            value: _isDarkMode,
            onChanged: _toggleTheme,
            secondary: const Icon(Icons.dark_mode_outlined),
          ),

          const Divider(),

          // --- Currency ---
          _buildSectionHeader('Currency'),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Currency Symbol'),
            subtitle: Text('Currently using: $_currencySymbol'),
            trailing: DropdownButton<String>(
              value: _currencySymbol,
              underline: const SizedBox(),
              items: AppSettings.availableCurrencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _currencySymbol = value);
                  AppSettings.currencySymbol = value;
                }
              },
            ),
          ),

          const Divider(),

          // --- Game Defaults ---
          _buildSectionHeader('Game Defaults'),
          ListTile(
            leading: const Icon(Icons.monetization_on_outlined),
            title: const Text('Default Buy-in'),
            subtitle: Text('$_currencySymbol$_defaultBuyIn'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _showEditBuyInDialog,
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Re-buy Buttons'),
            subtitle: Text(
                _rebuyDenominations.map((d) => '+$_currencySymbol$d').join(', ')),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _showEditDenominationsDialog,
          ),

          const Divider(),

          // --- House Rules ---
          _buildSectionHeader('House Rules'),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Max Buy-in Per Player'),
            subtitle: Text(_maxBuyInLimit == 0
                ? 'Unlimited'
                : '$_currencySymbol$_maxBuyInLimit per night'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _showEditBuyInLimitDialog,
          ),

          const SizedBox(height: 32),
          
          // --- App Version ---
          Center(
            child: Text(
              'Poker Tracker v$appVersion',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
