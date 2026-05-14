import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game_player_model.dart';
import '../models/player_model.dart';
import '../utils/app_settings.dart';
import '../widgets/poker_table_view.dart';
import '../widgets/player_action_sheet.dart';
import 'end_game_screen.dart';
import 'hand_rankings_screen.dart';

class LiveGameScreen extends StatefulWidget {
  final List<Player>? initialPlayers;
  final String? location;

  const LiveGameScreen({super.key, this.initialPlayers, this.location});

  @override
  State<LiveGameScreen> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends State<LiveGameScreen> {
  final Box<GamePlayer> _liveGameBox = Hive.box<GamePlayer>('live_game');
  final Box<Player> _playersBox = Hive.box<Player>('players');
  int? _expandedCardKey;
  late DateTime _startTime;
  late String _location;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  late bool _isTableView;
  late bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _isTableView = AppSettings.useTableView;
    _isAdmin = AppSettings.isAdminMode;
    final defaultBuyIn = AppSettings.defaultBuyIn;

    if (_liveGameBox.isEmpty && widget.initialPlayers != null) {
      _startTime = DateTime.now();
      _location = widget.location ?? 'Unknown Location';
      AppSettings.gameStartTime = _startTime;
      AppSettings.gameLocation = _location;
      AppSettings.clearActivityLog();
      AppSettings.clearPotExpenses();
      for (var player in widget.initialPlayers!) {
        _liveGameBox.put(player.key, GamePlayer(player: player, buyIns: [defaultBuyIn], joinTime: _startTime));
        AppSettings.addLogEntry('${player.emoji} ${player.name} bought in — ${AppSettings.currencySymbol}$defaultBuyIn');
      }
    } else {
      _startTime = AppSettings.gameStartTime ?? DateTime.now();
      _location = AppSettings.gameLocation;
    }

    _elapsed = DateTime.now().difference(_startTime);
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(_startTime));
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours; final m = d.inMinutes.remainder(60); final s = d.inSeconds.remainder(60);
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }

  // ---- Actions ----

  void _addBuyIn(GamePlayer gp, int amount) {
    final maxLimit = AppSettings.maxBuyInPerPlayer;
    if (maxLimit > 0 && (gp.totalBuyIn + amount) > maxLimit) {
      final cs = AppSettings.currencySymbol;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⛔ ${gp.player.name} would exceed the $cs$maxLimit buy-in limit!'), backgroundColor: Colors.red.shade700),
      );
      return;
    }
    setState(() => gp.addBuyIn(amount));
    final cs = AppSettings.currencySymbol;
    AppSettings.addLogEntry('${gp.player.emoji} ${gp.player.name} re-bought — $cs$amount (total: $cs${gp.totalBuyIn})');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $cs$amount buy-in for ${gp.player.name}'), duration: const Duration(seconds: 2)),
    );
  }

  void _showCustomBuyInDialog(GamePlayer gp) {
    final ctrl = TextEditingController();
    final cs = AppSettings.currencySymbol;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Custom Buy-in for ${gp.player.name}"),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
        decoration: InputDecoration(prefixText: '$cs ', hintText: "Enter amount"), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
        TextButton(child: const Text("Add Buy-in"), onPressed: () {
          final amt = int.tryParse(ctrl.text);
          if (amt != null && amt > 0) _addBuyIn(gp, amt);
          Navigator.of(ctx).pop();
        }),
      ],
    ));
  }

  void _undoBuyIn(GamePlayer gp) {
    if (gp.buyIns.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Can't undo the initial buy-in.")));
      return;
    }
    setState(() => gp.undoLastBuyIn());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Undid last buy-in for ${gp.player.name}')));
  }

  void _undoCashOut(GamePlayer gp) {
    setState(() => gp.undoCashOut());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Undid cash-out for ${gp.player.name}')));
  }

  void _showCashOutDialog(GamePlayer gp) {
    final ctrl = TextEditingController();
    final cs = AppSettings.currencySymbol;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("Cash Out ${gp.player.name}"),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
        decoration: InputDecoration(prefixText: '$cs ', hintText: "Final chip amount"), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
        TextButton(child: const Text("Confirm Cash Out"), onPressed: () {
          final amt = int.tryParse(ctrl.text);
          if (amt != null && amt >= 0) {
            gp.cashOut(amt);
            AppSettings.addLogEntry('${gp.player.emoji} ${gp.player.name} cashed out — $cs$amt (P/L: ${gp.netProfit >= 0 ? '+' : ''}$cs${gp.netProfit})');
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${gp.player.name} cashed out for $cs$amt')));
          }
        }),
      ],
    ));
  }

  void _openPlayerSheet(GamePlayer gp) {
    if (gp.hasCashedOut && !_isAdmin) return;
    PlayerActionSheet.show(context,
      gamePlayer: gp,
      addBuyIn: _addBuyIn,
      showCashOutDialog: _showCashOutDialog,
      undoBuyIn: _undoBuyIn,
      undoCashOut: _undoCashOut,
      showCustomBuyIn: _showCustomBuyInDialog,
    );
  }

  void _showAddPlayerDialog() {
    final allPlayers = _playersBox.values.where((p) => !p.isArchived).toList();
    final inGame = _liveGameBox.keys.toList();
    final available = allPlayers.where((p) => !inGame.contains(p.key)).toList();
    final defaultBuyIn = AppSettings.defaultBuyIn;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Add Player to Game"),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [
        if (available.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text("All players are in the game.", style: TextStyle(fontStyle: FontStyle.italic))),
        ...available.map((p) => ListTile(
          leading: Text(p.emoji, style: const TextStyle(fontSize: 24)),
          title: Text(p.name),
          onTap: () {
            _liveGameBox.put(p.key, GamePlayer(player: p, buyIns: [defaultBuyIn], joinTime: DateTime.now()));
            AppSettings.addLogEntry('${p.emoji} ${p.name} joined late — ${AppSettings.currencySymbol}$defaultBuyIn buy-in');
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${p.name} joined!')));
          },
        )),
        ListTile(leading: const Icon(Icons.add), title: const Text("Create New Player..."), onTap: () {
          Navigator.of(ctx).pop(); _showCreatePlayerDialog();
        }),
      ])),
      actions: [TextButton(child: const Text("Cancel"), onPressed: () => Navigator.of(ctx).pop())],
    ));
  }

  void _showCreatePlayerDialog() {
    final ctrl = TextEditingController();
    final defaultBuyIn = AppSettings.defaultBuyIn;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Create and Add Player"),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: "Player Name"), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Cancel")),
        TextButton(onPressed: () async {
          final name = ctrl.text.trim();
          if (name.isNotEmpty) {
            // Duplicate check
            if (_playersBox.values.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Player with this name already exists.')));
              Navigator.of(ctx).pop(); return;
            }
            final key = await _playersBox.add(Player(name: name));
            final player = _playersBox.get(key)!;
            _liveGameBox.put(player.key, GamePlayer(player: player, buyIns: [defaultBuyIn], joinTime: DateTime.now()));
          }
          if (ctx.mounted) Navigator.of(ctx).pop();
        }, child: const Text("Create & Add")),
      ],
    ));
  }

  void _showEndGameDialog() {
    final allPlayers = _liveGameBox.toMap().entries.toList();
    final remaining = allPlayers.where((e) => !e.value.hasCashedOut).toList();
    final alreadyCashed = allPlayers.where((e) => e.value.hasCashedOut).toList();

    if (remaining.isEmpty) { _navigateToResults(); return; }

    final cs = AppSettings.currencySymbol;
    final controllers = {for (var e in remaining) e.key as int: TextEditingController()};
    final totalBuyIns = allPlayers.fold<int>(0, (s, e) => s + e.value.totalBuyIn);

    Navigator.push(context, MaterialPageRoute(builder: (_) => _FinalChipCountScreen(
      remaining: remaining.map((e) => MapEntry(e.key as int, e.value)).toList(),
      alreadyCashed: alreadyCashed.map((e) => MapEntry(e.key as int, e.value)).toList(),
      controllers: controllers,
      totalBuyIns: totalBuyIns,
      cs: cs,
      onConfirm: () {
        for (var e in remaining) {
          final amt = int.tryParse(controllers[e.key as int]!.text);
          if (amt != null && amt >= 0) e.value.cashOut(amt);
        }
        Navigator.of(context).pop(); // pop chip count screen
        _navigateToResults();
      },
    )));
  }

  void _navigateToResults() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EndGameScreen(
      gamePlayers: _liveGameBox.values.toList(), location: _location, startTime: _startTime)));
  }

  void _showHandRankings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Column(children: [
          Padding(padding: const EdgeInsets.all(12),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)))),
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Hand Rankings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Expanded(child: HandRankingsScreen.buildRankingsList(scrollController: scrollCtrl)),
        ]),
      ),
    );
  }

  void _showActivityLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        final log = AppSettings.activityLog;
        return DraggableScrollableSheet(
          initialChildSize: 0.7, minChildSize: 0.4, maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) => Column(children: [
            Padding(padding: const EdgeInsets.all(12),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)))),
            const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('📋 Activity Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Expanded(
              child: log.isEmpty
                  ? const Center(child: Text('No activity yet.', style: TextStyle(fontStyle: FontStyle.italic)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: log.length,
                      itemBuilder: (_, i) {
                        final entry = log[log.length - 1 - i]; // newest first
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(entry.substring(0, 5), style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'monospace')),
                            const SizedBox(width: 10),
                            Expanded(child: Text(entry.substring(6), style: const TextStyle(fontSize: 13))),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        );
      },
    );
  }

  void _showPotExpenseDialog() {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final cs = AppSettings.currencySymbol;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('🍕 Add Pot Expense'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'What for?', hintText: 'e.g., Pizza, Drinks, Dealer', border: OutlineInputBorder()), autofocus: true),
        const SizedBox(height: 12),
        TextField(controller: amountCtrl, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Amount', prefixText: '$cs ', border: const OutlineInputBorder())),
        if (AppSettings.potExpenses.isNotEmpty) ...[  
          const SizedBox(height: 12),
          const Divider(),
          ...AppSettings.potExpenses.map((e) => ListTile(
            dense: true,
            title: Text('${e['label']}'), trailing: Text('$cs${e['amount']}'),
          )),
          Text('Total: $cs${AppSettings.totalPotExpenses}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        FilledButton(onPressed: () {
          final label = labelCtrl.text.trim();
          final amount = int.tryParse(amountCtrl.text) ?? 0;
          if (label.isNotEmpty && amount > 0) {
            AppSettings.addPotExpense(label, amount);
            AppSettings.addLogEntry('🍕 Pot expense: $label — $cs$amount');
            Navigator.of(ctx).pop();
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🍕 Added $cs$amount for $label')));
          }
        }, child: const Text('Add')),
      ],
    ));
  }

  // ---- List View Builder ----

  Widget _buildListView(List<MapEntry<dynamic, GamePlayer>> entries) {
    final cs = AppSettings.currencySymbol;
    final rebuyDenoms = AppSettings.rebuyDenominations;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final key = entries[index].key;
        final gp = entries[index].value;
        final isExpanded = _expandedCardKey == key;
        final defaultBuyIn = AppSettings.defaultBuyIn;
        final isOverextended = gp.totalBuyIn >= defaultBuyIn * 3 && !gp.hasCashedOut;

        return Card(
          elevation: isExpanded ? 6 : 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: isOverextended ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.red, width: 1.5),
          ) : null,
          child: InkWell(
            onTap: (!_isAdmin || gp.hasCashedOut) ? null : () => setState(() => _expandedCardKey = isExpanded ? null : key as int),
            child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Row(children: [
                    Text(gp.player.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(gp.player.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                  ])),
                  const SizedBox(width: 16),
                  if (gp.hasCashedOut)
                    Flexible(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Flexible(child: Text("Out: $cs${gp.cashOutAmount}", overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontStyle: FontStyle.italic))),
                      if (_isAdmin) IconButton(icon: Icon(Icons.undo, color: Colors.grey.shade600),
                        onPressed: () => _undoCashOut(gp), tooltip: 'Undo Cash Out'),
                    ]))
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isOverextended) const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text('⚠️', style: TextStyle(fontSize: 14)),
                      ),
                      Text("$cs${gp.totalBuyIn}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                        color: isOverextended ? Colors.red : null)),
                    ]),
                ]),
                if (isExpanded && !gp.hasCashedOut && _isAdmin) ...[
                  const Divider(height: 24),
                  Text("Transactions", style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (int i = 0; i < gp.buyIns.length; i++)
                    ListTile(title: Text(i == 0 ? "Initial Buy-in" : "Re-buy"), trailing: Text("$cs${gp.buyIns[i]}"), dense: true),
                  const Divider(),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ElevatedButton.icon(icon: const Icon(Icons.exit_to_app), label: const Text("Cash Out"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
                      onPressed: () => _showCashOutDialog(gp)),
                    IconButton(icon: const Icon(Icons.undo), tooltip: "Undo Last Buy-in", onPressed: () => _undoBuyIn(gp)),
                    ...rebuyDenoms.map((d) => ElevatedButton(
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: () => _addBuyIn(gp, d), child: Text("+$cs$d"))),
                    OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                      onPressed: () => _showCustomBuyInDialog(gp), child: const Text("+Custom")),
                  ]),
                ],
              ],
            )),
          ),
        );
      },
    );
  }

  void _showWhosWinning() {
    final cs = AppSettings.currencySymbol;
    final activePlayers = _liveGameBox.values.where((gp) => !gp.hasCashedOut).toList();

    // Players who already cashed out — we know their actual profit
    final cashedPlayers = _liveGameBox.values.where((gp) => gp.hasCashedOut).toList();
    cashedPlayers.sort((a, b) => b.netProfit.compareTo(a.netProfit));

    // Active players sorted by totalBuyIn ASCENDING = least invested = safest
    final safest = List<GamePlayer>.from(activePlayers)
      ..sort((a, b) => a.totalBuyIn.compareTo(b.totalBuyIn));

    // Active players sorted by totalBuyIn DESCENDING = most invested = deepest in
    final deepest = List<GamePlayer>.from(activePlayers)
      ..sort((a, b) => b.totalBuyIn.compareTo(a.totalBuyIn));

    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          body: Center(
            child: SingleChildScrollView(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(height: 40),

                // --- Deepest In (most at risk) ---
                const Text('💸', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                const Text('DEEPEST IN', style: TextStyle(fontSize: 14, letterSpacing: 3, color: Colors.redAccent)),
                const Text('Most money invested — highest risk', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 16),
                ...deepest.take(3).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final gp = e.value;
                  final indicator = i == 0 ? '🔴' : (i == 1 ? '🟠' : '🟡');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '$indicator ${gp.player.emoji} ${gp.player.name}  —  $cs${gp.totalBuyIn}',
                      style: TextStyle(fontSize: i == 0 ? 24 : 18, fontWeight: FontWeight.bold,
                        color: i == 0 ? Colors.redAccent : Colors.white70),
                    ),
                  );
                }),

                const SizedBox(height: 32),
                Divider(color: Colors.grey.shade800, indent: 60, endIndent: 60),
                const SizedBox(height: 32),

                // --- Safest (least invested) ---
                const Text('🛡️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                const Text('SAFEST POSITION', style: TextStyle(fontSize: 14, letterSpacing: 3, color: Colors.greenAccent)),
                const Text('Least invested — lowest risk', style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 16),
                ...safest.take(3).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final gp = e.value;
                  final indicator = i == 0 ? '🟢' : (i == 1 ? '🔵' : '⚪');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '$indicator ${gp.player.emoji} ${gp.player.name}  —  $cs${gp.totalBuyIn}',
                      style: TextStyle(fontSize: i == 0 ? 24 : 18, fontWeight: FontWeight.bold,
                        color: i == 0 ? Colors.greenAccent : Colors.white70),
                    ),
                  );
                }),

                // --- Confirmed Results (already cashed out) ---
                if (cashedPlayers.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Divider(color: Colors.grey.shade800, indent: 60, endIndent: 60),
                  const SizedBox(height: 24),
                  const Text('✅ CONFIRMED', style: TextStyle(fontSize: 14, letterSpacing: 3, color: Colors.blueAccent)),
                  const Text('Already cashed out', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 12),
                  ...cashedPlayers.map((gp) {
                    final profit = gp.netProfit;
                    final isUp = profit >= 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${gp.player.emoji} ${gp.player.name}  —  ${isUp ? '+' : ''}$cs$profit',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: isUp ? Colors.green : Colors.red),
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 40),
                Text('Tap anywhere to close', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game is saved. Resume anytime from Home.'), duration: Duration(seconds: 2)));
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(children: [
            const Text("Live Game"),
            Text('⏱ ${_fmtElapsed(_elapsed)}  •  📍 $_location',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ]),
          toolbarHeight: 64,
          actions: [
            // Admin lock toggle
            IconButton(
              icon: Icon(_isAdmin ? Icons.lock_open : Icons.lock_outline,
                color: _isAdmin ? Colors.tealAccent : Colors.grey),
              tooltip: _isAdmin ? 'Admin: ON' : 'Admin: OFF (view only)',
              onPressed: () => setState(() {
                _isAdmin = !_isAdmin;
                AppSettings.isAdminMode = _isAdmin;
              }),
            ),
            // View toggle
            IconButton(
              icon: Icon(_isTableView ? Icons.view_list : Icons.circle_outlined),
              tooltip: _isTableView ? 'Switch to List View' : 'Switch to Table View',
              onPressed: () => setState(() {
                _isTableView = !_isTableView;
                AppSettings.useTableView = _isTableView;
              }),
            ),
            // Activity log
            IconButton(icon: const Icon(Icons.receipt_long_outlined), tooltip: 'Activity Log', onPressed: _showActivityLog),
            // Pot expenses
            if (_isAdmin) IconButton(icon: const Icon(Icons.fastfood_outlined), tooltip: 'Pot Expenses', onPressed: _showPotExpenseDialog),
            // Hand rankings
            IconButton(icon: const Icon(Icons.style_outlined), tooltip: 'Hand Rankings', onPressed: _showHandRankings),
            // Who's winning
            IconButton(icon: const Icon(Icons.emoji_events_outlined), tooltip: 'Game Status', onPressed: _showWhosWinning),
            // Add player
            if (_isAdmin) IconButton(icon: const Icon(Icons.person_add_alt_1), tooltip: 'Add Player', onPressed: _showAddPlayerDialog),
            // End game
            if (_isAdmin) IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'End Game', onPressed: _showEndGameDialog),
          ],
        ),
        body: ValueListenableBuilder<Box<GamePlayer>>(
          valueListenable: _liveGameBox.listenable(),
          builder: (context, box, _) {
            final entries = box.toMap().entries.toList();
            if (_isTableView) {
              return PokerTableView(
                players: entries.map((e) => MapEntry(e.key, e.value)).toList(),
                elapsed: _elapsed, location: _location, isAdmin: _isAdmin,
                defaultBuyIn: AppSettings.defaultBuyIn,
                onPlayerTap: _openPlayerSheet,
              );
            } else {
              return _buildListView(entries.map((e) => MapEntry(e.key, e.value)).toList());
            }
          },
        ),
      ),
    );
  }
}

// ---- Full-screen Final Chip Count Editor ----

class _FinalChipCountScreen extends StatefulWidget {
  final List<MapEntry<int, GamePlayer>> remaining;
  final List<MapEntry<int, GamePlayer>> alreadyCashed;
  final Map<int, TextEditingController> controllers;
  final int totalBuyIns;
  final String cs;
  final VoidCallback onConfirm;

  const _FinalChipCountScreen({
    required this.remaining,
    required this.alreadyCashed,
    required this.controllers,
    required this.totalBuyIns,
    required this.cs,
    required this.onConfirm,
  });

  @override
  State<_FinalChipCountScreen> createState() => _FinalChipCountScreenState();
}

class _FinalChipCountScreenState extends State<_FinalChipCountScreen> {
  int _totalCashOuts = 0;

  @override
  void initState() {
    super.initState();
    _totalCashOuts = widget.alreadyCashed.fold<int>(0, (s, e) => s + (e.value.cashOutAmount ?? 0));
    for (var ctrl in widget.controllers.values) {
      ctrl.addListener(_recalculate);
    }
  }

  void _recalculate() {
    int cashOuts = widget.alreadyCashed.fold<int>(0, (s, e) => s + (e.value.cashOutAmount ?? 0));
    for (var ctrl in widget.controllers.values) {
      cashOuts += int.tryParse(ctrl.text) ?? 0;
    }
    setState(() => _totalCashOuts = cashOuts);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final potExpenses = AppSettings.totalPotExpenses;
    final diff = _totalCashOuts + potExpenses - widget.totalBuyIns;
    final isBalanced = diff == 0;
    final hasInput = widget.controllers.values.any((c) => c.text.isNotEmpty);

    Color statusColor;
    String statusText;
    IconData statusIcon;
    if (!hasInput) {
      statusColor = Colors.grey;
      statusText = 'Fill in the "Final" column for each player';
      statusIcon = Icons.edit_note;
    } else if (isBalanced) {
      statusColor = Colors.green;
      statusText = 'Balanced — all chips accounted for';
      statusIcon = Icons.check_circle;
    } else if (diff > 0) {
      statusColor = Colors.orange;
      statusText = '$cs${diff.abs()} extra (out > in)';
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.red;
      statusText = '$cs${diff.abs()} missing (out < in)';
      statusIcon = Icons.error;
    }

    // Build all rows (remaining + already cashed)
    final allEntries = <_SheetRow>[];
    for (var e in widget.remaining) {
      final gp = e.value;
      final initialBuyIn = gp.buyIns.first;
      final reBuys = gp.totalBuyIn - initialBuyIn;
      allEntries.add(_SheetRow(
        emoji: gp.player.emoji,
        name: gp.player.name,
        initial: initialBuyIn,
        reBuys: reBuys,
        totalIn: gp.totalBuyIn,
        controller: widget.controllers[e.key],
        cashOutAmount: null,
        isCashed: false,
      ));
    }
    for (var e in widget.alreadyCashed) {
      final gp = e.value;
      final initialBuyIn = gp.buyIns.first;
      final reBuys = gp.totalBuyIn - initialBuyIn;
      allEntries.add(_SheetRow(
        emoji: gp.player.emoji,
        name: gp.player.name,
        initial: initialBuyIn,
        reBuys: reBuys,
        totalIn: gp.totalBuyIn,
        controller: null,
        cashOutAmount: gp.cashOutAmount,
        isCashed: true,
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final Chip Count'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: statusColor.withValues(alpha: 0.15),
            child: Row(children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(statusText,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12))),
              Text('Out: $cs$_totalCashOuts / In: $cs${widget.totalBuyIns}',
                  style: TextStyle(color: statusColor, fontSize: 11)),
            ]),
          ),
          // Sheet header
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(children: [
              SizedBox(width: 100, child: Text('Player', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('Initial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(child: Text('Re-buys', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              Expanded(child: Text('Total In', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
              SizedBox(width: 90, child: Text('Final', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
            ]),
          ),
          const Divider(height: 1),
          // Sheet rows
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: allEntries.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade800),
              itemBuilder: (context, index) {
                final row = allEntries[index];
                return Container(
                  color: row.isCashed
                      ? Theme.of(context).cardColor.withValues(alpha: 0.3)
                      : null,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    // Player
                    SizedBox(
                      width: 100,
                      child: Row(children: [
                        Text(row.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(row.name,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                color: row.isCashed ? Colors.grey : null,
                                decoration: row.isCashed ? TextDecoration.lineThrough : null),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                    // Initial
                    Expanded(child: Text('$cs${row.initial}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: row.isCashed ? Colors.grey : null))),
                    // Re-buys
                    Expanded(child: Text(row.reBuys > 0 ? '+$cs${row.reBuys}' : '—',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13,
                            color: row.reBuys > 0
                                ? (row.isCashed ? Colors.grey : Colors.orangeAccent)
                                : Colors.grey.shade700))),
                    // Total In
                    Expanded(child: Text('$cs${row.totalIn}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: row.isCashed ? Colors.grey : null))),
                    // Final chips (editable or fixed)
                    SizedBox(
                      width: 90,
                      child: row.isCashed
                          ? Text('$cs${row.cashOutAmount}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: Colors.grey))
                          : TextField(
                              controller: row.controller,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                hintText: '0',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                    ),
                  ]),
                );
              },
            ),
          ),
          // Totals row
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(children: [
              Row(children: [
                const SizedBox(width: 100, child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const Expanded(child: SizedBox()),
                const Expanded(child: SizedBox()),
                Expanded(child: Text('$cs${widget.totalBuyIns}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                SizedBox(width: 90, child: Text('$cs$_totalCashOuts',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: isBalanced ? Colors.green : (diff > 0 ? Colors.orange : Colors.red)))),
              ]),
              if (potExpenses > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('🍕 Pot expenses: $cs$potExpenses deducted',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          icon: Icon(isBalanced ? Icons.check_circle : Icons.warning_amber),
          label: Text(isBalanced ? 'End Game ✅' : 'End Game (Unbalanced)'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            backgroundColor: isBalanced ? Colors.green : Colors.orange,
            foregroundColor: Colors.white,
          ),
          onPressed: hasInput ? widget.onConfirm : null,
        ),
      ),
    );
  }
}

class _SheetRow {
  final String emoji;
  final String name;
  final int initial;
  final int reBuys;
  final int totalIn;
  final TextEditingController? controller;
  final int? cashOutAmount;
  final bool isCashed;

  _SheetRow({
    required this.emoji,
    required this.name,
    required this.initial,
    required this.reBuys,
    required this.totalIn,
    required this.controller,
    required this.cashOutAmount,
    required this.isCashed,
  });
}

