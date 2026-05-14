import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/game_player_model.dart';
import 'models/game_session_model.dart';
import 'models/group_preset_model.dart';
import 'models/payment_record_model.dart';
import 'models/player_model.dart';
import 'screens/home_screen.dart';

final appInitialization = Future(() async {
  await Hive.initFlutter('poker_tracker_db');

  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(GamePlayerAdapter());
  Hive.registerAdapter(GameSessionAdapter());
  Hive.registerAdapter(GroupPresetAdapter());
  Hive.registerAdapter(PaymentRecordAdapter());

  await Hive.openBox<Player>('players');
  await Hive.openBox<GamePlayer>('live_game');
  await Hive.openBox<GameSession>('game_history');
  await Hive.openBox<GroupPreset>('group_presets');
  await Hive.openBox<PaymentRecord>('payments');
  await Hive.openBox('settings');
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokerTrackerApp());
}

class PokerTrackerApp extends StatelessWidget {
  const PokerTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: appInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasError) {
          return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Failed to initialize:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          onPressed: () {
                            // Force rebuild by navigating to self
                            runApp(const PokerTrackerApp());
                          },
                        ),
                      ],
                    ),
                  )));
        }

        return ValueListenableBuilder(
          valueListenable:
              Hive.box('settings').listenable(keys: ['isDarkMode']),
          builder: (context, box, child) {
            final isDarkMode = box.get('isDarkMode', defaultValue: true);
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Poker Tracker',
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

              darkTheme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF1A1A1A),
                cardColor: const Color(0xFF2C2C2C),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.tealAccent,
                  brightness: Brightness.dark,
                  primary: Colors.tealAccent,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xFF2C2C2C),
                  elevation: 0,
                  centerTitle: true,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              theme: ThemeData(
                useMaterial3: true,
                brightness: Brightness.light,
                scaffoldBackgroundColor: const Color(0xFFF5F5F0),
                cardColor: Colors.white,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.teal,
                  brightness: Brightness.light,
                  primary: Colors.teal,
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  foregroundColor: Colors.black87,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              home: const HomeScreen(),
            );
          },
        );
      },
    );
  }
}
