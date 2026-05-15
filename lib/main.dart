import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/game_player_model.dart';
import 'models/game_session_model.dart';
import 'models/group_preset_model.dart';
import 'models/payment_record_model.dart';
import 'models/player_model.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'utils/app_theme.dart';

/// App version — displayed in Settings and used for update checks.
const String appVersion = '3.0.0';

/// Initialize Firebase, Hive adapters, and open all boxes.
/// Returns a NEW Future each time (so retry works).
Future<void> initializeApp() async {
  await Firebase.initializeApp();

  await Hive.initFlutter('poker_tracker_db');

  // Register adapters only if not already registered
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PlayerAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GamePlayerAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(GameSessionAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GroupPresetAdapter());
  if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(PaymentRecordAdapter());

  await Hive.openBox<Player>('players');
  await Hive.openBox<GamePlayer>('live_game');
  await Hive.openBox<GameSession>('game_history');
  await Hive.openBox<GroupPreset>('group_presets');
  await Hive.openBox<PaymentRecord>('payments');
  await Hive.openBox('settings');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PokerTrackerApp());
}

class PokerTrackerApp extends StatefulWidget {
  const PokerTrackerApp({super.key});

  @override
  State<PokerTrackerApp> createState() => _PokerTrackerAppState();
}

class _PokerTrackerAppState extends State<PokerTrackerApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = initializeApp();
  }

  void _retry() {
    setState(() {
      _initFuture = initializeApp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
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
                          onPressed: _retry,
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
              darkTheme: AppTheme.dark,
              theme: AppTheme.light,
              home: AuthService().isLoggedIn ? const HomeScreen() : const LoginScreen(),
            );
          },
        );
      },
    );
  }
}
