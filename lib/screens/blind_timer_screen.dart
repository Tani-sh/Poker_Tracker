import 'dart:async';
import 'package:flutter/material.dart';

// The vibration package import has been removed.

// A simple data class for a blind level
class BlindLevel {
  final int smallBlind;
  final int bigBlind;
  BlindLevel(this.smallBlind, this.bigBlind);

  @override
  String toString() => '$smallBlind / $bigBlind';
}

class BlindTimerScreen extends StatefulWidget {
  const BlindTimerScreen({super.key});

  @override
  State<BlindTimerScreen> createState() => _BlindTimerScreenState();
}

class _BlindTimerScreenState extends State<BlindTimerScreen> {
  // --- Timer State ---
  Timer? _timer;
  Duration _currentDuration = const Duration(minutes: 15);
  bool _isPaused = true;
  int _currentLevelIndex = 0;

  // --- Configuration ---
  Duration _selectedLevelDuration = const Duration(minutes: 15);
  final List<BlindLevel> _blindLevels = [
    BlindLevel(25, 50),
    BlindLevel(50, 100),
    BlindLevel(75, 150),
    BlindLevel(100, 200),
    BlindLevel(150, 300),
    BlindLevel(200, 400),
    BlindLevel(300, 600),
    BlindLevel(400, 800),
    BlindLevel(500, 1000),
    BlindLevel(800, 1600),
    BlindLevel(1000, 2000),
  ];

  @override
  void dispose() {
    _timer?.cancel(); // Important to prevent memory leaks
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel(); // Prevent duplicate timers
    setState(() {
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentDuration.inSeconds <= 0) {
        _levelUp();
      } else {
        setState(() {
          _currentDuration = _currentDuration - const Duration(seconds: 1);
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isPaused = true;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _currentLevelIndex = 0;
      _currentDuration = _selectedLevelDuration;
      _isPaused = true;
    });
  }

  void _levelUp() {
    // The vibration code has been removed.
    // Instead, show a SnackBar as a visual notification.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Blinds are up!"),
        duration: Duration(seconds: 3),
      ),
    );

    _timer?.cancel();
    setState(() {
      if (_currentLevelIndex < _blindLevels.length - 1) {
        _currentLevelIndex++;
        _currentDuration = _selectedLevelDuration;
        _startTimer(); // Automatically start the next level
      } else {
        _isPaused = true; // Tournament finished
      }
    });
  }

  void _skipLevel() {
    if (_currentLevelIndex < _blindLevels.length - 1) {
      _levelUp();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = _blindLevels[_currentLevelIndex];
    final nextLevel = _currentLevelIndex < _blindLevels.length - 1
        ? _blindLevels[_currentLevelIndex + 1]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tournament Blind Timer"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // --- Configuration Row ---
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Level Duration:",
                        style: TextStyle(fontSize: 16)),
                    DropdownButton<Duration>(
                      value: _selectedLevelDuration,
                      items: const [
                        DropdownMenuItem(
                            value: Duration(minutes: 10),
                            child: Text("10 mins")),
                        DropdownMenuItem(
                            value: Duration(minutes: 15),
                            child: Text("15 mins")),
                        DropdownMenuItem(
                            value: Duration(minutes: 20),
                            child: Text("20 mins")),
                        DropdownMenuItem(
                            value: Duration(minutes: 30),
                            child: Text("30 mins")),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLevelDuration = value;
                            if (_isPaused) {
                              // Only reset duration if paused
                              _currentDuration = value;
                            }
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // --- Timer Display ---
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDuration(_currentDuration),
                    style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: _currentDuration.inMinutes < 1
                            ? Colors.red.shade300
                            : null),
                  ),
                  const SizedBox(height: 24),
                  Text("Current Blinds",
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(currentLevel.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text("Next Blinds",
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(nextLevel?.toString() ?? "Final Level",
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            ),

            // --- Control Buttons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  iconSize: 40,
                  onPressed: _resetTimer,
                  tooltip: "Reset Timer",
                ),
                IconButton(
                  icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                  iconSize: 80,
                  onPressed: _isPaused ? _startTimer : _pauseTimer,
                  tooltip: _isPaused ? "Start Timer" : "Pause Timer",
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 40,
                  onPressed: _skipLevel,
                  tooltip: "Next Level",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
