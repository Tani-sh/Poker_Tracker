import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/game_player_model.dart';
import '../models/game_session_model.dart';
import '../models/player_model.dart';
import '../utils/app_settings.dart';

class PlayerDetailScreen extends StatefulWidget {
  final Player player;

  const PlayerDetailScreen({super.key, required this.player});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  List<FlSpot> _profitHistorySpots = [];
  int _totalProfit = 0;
  int _gamesPlayed = 0;
  double _winRate = 0.0;
  double _avgProfitPerGame = 0.0;
  int _biggestWin = 0;
  int _biggestLoss = 0;

  @override
  void initState() {
    super.initState();
    _calculatePlayerStatsAndHistory();
  }

  void _calculatePlayerStatsAndHistory() {
    final historyBox = Hive.box<GameSession>('game_history');
    final List<FlSpot> spots = [];
    int cumulativeProfit = 0;
    int gameCount = 0;
    int gamesWon = 0;
    int maxWin = 0;
    int maxLoss = 0;

    spots.add(const FlSpot(0, 0));

    final sessions = historyBox.values.toList();
    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    for (var session in sessions) {
      GamePlayer? gamePlayer;
      try {
        gamePlayer = session.players.firstWhere(
          (p) => p.player.name == widget.player.name,
        );
      } catch (e) {
        gamePlayer = null;
      }

      if (gamePlayer != null) {
        gameCount++;
        final netProfit = gamePlayer.netProfit;
        cumulativeProfit += netProfit;

        if (netProfit > 0) gamesWon++;
        if (netProfit > maxWin) maxWin = netProfit;
        if (netProfit < maxLoss) maxLoss = netProfit;

        spots.add(FlSpot(gameCount.toDouble(), cumulativeProfit.toDouble()));
      }
    }

    setState(() {
      _profitHistorySpots = spots;
      _totalProfit = cumulativeProfit;
      _gamesPlayed = gameCount;
      _winRate = gameCount > 0 ? (gamesWon / gameCount) * 100 : 0.0;
      _avgProfitPerGame = gameCount > 0 ? cumulativeProfit / gameCount : 0.0;
      _biggestWin = maxWin;
      _biggestLoss = maxLoss;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppSettings.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.player.emoji} ${widget.player.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Profit Over Time",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: _profitHistorySpots.length < 2
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart,
                              size: 60,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          const Text("Not enough game data to show a graph."),
                        ],
                      ),
                    )
                  : LineChart(_buildChartData()),
            ),
            const SizedBox(height: 32),
            Text(
              "Career Statistics",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _buildStatCard("Total Profit/Loss", "$cs$_totalProfit",
                    _totalProfit >= 0 ? Colors.green : Colors.red),
                _buildStatCard("Games Played", _gamesPlayed.toString(),
                    Theme.of(context).colorScheme.secondary),
                _buildStatCard("Win Rate", "${_winRate.toStringAsFixed(1)}%",
                    Colors.blueAccent),
                _buildStatCard(
                    "Avg Profit/Game",
                    "$cs${_avgProfitPerGame.toStringAsFixed(0)}",
                    _avgProfitPerGame >= 0 ? Colors.green : Colors.red),
                _buildStatCard("Biggest Win", "$cs$_biggestWin", Colors.green),
                _buildStatCard("Biggest Loss", "$cs$_biggestLoss", Colors.red),
              ],
            ),

            // --- Achievements ---
            const SizedBox(height: 32),
            Text("Achievements", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _buildAchievements(),

            // --- Head-to-Head ---
            const SizedBox(height: 32),
            Text("Head-to-Head", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _buildHeadToHead(),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievements() {
    final badges = <Map<String, String>>[];
    final historyBox = Hive.box<GameSession>('game_history');
    final sessions = historyBox.values.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    // Calculate streak data
    int currentStreak = 0;
    int maxStreak = 0;
    int biggestRecovery = 0;

    for (var session in sessions) {
      GamePlayer? gp;
      try { gp = session.players.firstWhere((p) => p.player.name == widget.player.name); } catch (_) { continue; }

      if (gp.netProfit > 0) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 0;
      }

      // Recovery: bought in a lot but ended up positive
      if (gp.buyIns.length > 1 && gp.netProfit > 0) {
        final recovery = gp.netProfit;
        if (recovery > biggestRecovery) biggestRecovery = recovery;
      }
    }

    // Award badges
    if (maxStreak >= 3) badges.add({'icon': '🔥', 'title': 'Hot Streak', 'desc': '$maxStreak wins in a row'});
    if (_winRate >= 60 && _gamesPlayed >= 10) badges.add({'icon': '🦈', 'title': 'Shark', 'desc': '${_winRate.toStringAsFixed(0)}% win rate over $_gamesPlayed games'});
    if (_gamesPlayed >= 5 && _winRate >= 80) badges.add({'icon': '👑', 'title': 'Dominator', 'desc': 'Won ${_winRate.toStringAsFixed(0)}% of games'});
    if (_biggestWin >= AppSettings.defaultBuyIn * 5) badges.add({'icon': '💰', 'title': 'Big Score', 'desc': 'Won ${AppSettings.currencySymbol}$_biggestWin in one game'});
    if (biggestRecovery > 0) badges.add({'icon': '🐢', 'title': 'Comeback King', 'desc': 'Recovered ${AppSettings.currencySymbol}$biggestRecovery after rebuying'});
    if (_gamesPlayed >= 20) badges.add({'icon': '🎖️', 'title': 'Veteran', 'desc': '$_gamesPlayed games played'});
    if (_gamesPlayed >= 5 && _winRate < 30) badges.add({'icon': '🎰', 'title': 'Gambler', 'desc': 'Keeps coming back despite ${_winRate.toStringAsFixed(0)}% win rate'});

    if (badges.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16),
          child: Text('No achievements yet. Play more games to unlock badges!', style: TextStyle(fontStyle: FontStyle.italic))),
      );
    }

    return Wrap(
      spacing: 8, runSpacing: 8,
      children: badges.map((b) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(b['icon']!, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(b['desc']!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ]),
        ),
      )).toList(),
    );
  }

  Widget _buildHeadToHead() {
    final historyBox = Hive.box<GameSession>('game_history');
    final Map<String, Map<String, dynamic>> h2h = {};

    for (var session in historyBox.values) {
      GamePlayer? myGp;
      try { myGp = session.players.firstWhere((p) => p.player.name == widget.player.name); } catch (_) { continue; }

      for (var otherGp in session.players) {
        if (otherGp.player.name == widget.player.name) continue;
        final otherName = otherGp.player.name;
        h2h.putIfAbsent(otherName, () => {'emoji': otherGp.player.emoji, 'games': 0, 'myProfit': 0, 'theirProfit': 0});
        h2h[otherName]!['games'] = (h2h[otherName]!['games'] as int) + 1;
        h2h[otherName]!['myProfit'] = (h2h[otherName]!['myProfit'] as int) + myGp.netProfit;
        h2h[otherName]!['theirProfit'] = (h2h[otherName]!['theirProfit'] as int) + otherGp.netProfit;
      }
    }

    if (h2h.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16),
          child: Text('No shared games with other players yet.', style: TextStyle(fontStyle: FontStyle.italic))),
      );
    }

    final cs = AppSettings.currencySymbol;
    final sorted = h2h.entries.toList()..sort((a, b) => (b.value['games'] as int).compareTo(a.value['games'] as int));

    return Column(
      children: sorted.map((e) {
        final name = e.key;
        final data = e.value;
        final games = data['games'] as int;
        final myProfit = data['myProfit'] as int;
        final theirProfit = data['theirProfit'] as int;
        final emoji = data['emoji'] as String;
        final isAhead = myProfit > theirProfit;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Text(emoji, style: const TextStyle(fontSize: 24)),
            title: Text('vs $name', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$games shared games · You: ${myProfit >= 0 ? '+' : ''}$cs$myProfit · Them: ${theirProfit >= 0 ? '+' : ''}$cs$theirProfit'),
            trailing: Icon(
              isAhead ? Icons.arrow_upward : Icons.arrow_downward,
              color: isAhead ? Colors.green : Colors.red,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData() {
    final cs = AppSettings.currencySymbol;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300;
    final gradientColors = [
      Colors.blue.shade300,
      Colors.deepPurple.shade300,
    ];

    return LineChartData(
      gridData: FlGridData(
        show: true,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: gridColor, strokeWidth: 1),
        getDrawingVerticalLine: (value) =>
            FlLine(color: gridColor, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
          show: true,
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval:
                _gamesPlayed > 10 ? (_gamesPlayed / 5).floorToDouble() : 1,
            getTitlesWidget: (value, meta) {
              if (value == 0 || value > _gamesPlayed) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("G${value.toInt()}",
                    style: const TextStyle(fontSize: 12)),
              );
            },
          )),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) => Text("$cs${value.toInt()}",
                style: const TextStyle(fontSize: 11)),
          ))),
      borderData:
          FlBorderData(show: true, border: Border.all(color: gridColor)),
      minX: 0,
      maxX: _gamesPlayed.toDouble(),
      lineBarsData: [
        LineChartBarData(
          spots: _profitHistorySpots,
          isCurved: true,
          gradient: LinearGradient(colors: gradientColors),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors
                  .map((color) => color.withValues(alpha: 0.3))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
