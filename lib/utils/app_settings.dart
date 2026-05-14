import 'package:hive/hive.dart';

/// Central helper to read app-wide settings from the Hive 'settings' box.
class AppSettings {
  static Box get _box => Hive.box('settings');

  // --- Theme ---
  static bool get isDarkMode => _box.get('isDarkMode', defaultValue: true);
  static set isDarkMode(bool v) => _box.put('isDarkMode', v);

  // --- Currency ---
  static String get currencySymbol =>
      _box.get('currencySymbol', defaultValue: '₹');
  static set currencySymbol(String v) => _box.put('currencySymbol', v);

  static const List<String> availableCurrencies = [
    '₹', '\$', '€', '£', '¥', '฿', 'chips',
  ];

  // --- Buy-in ---
  static int get defaultBuyIn => _box.get('defaultBuyIn', defaultValue: 100);
  static set defaultBuyIn(int v) => _box.put('defaultBuyIn', v);

  // --- Re-buy denominations ---
  static List<int> get rebuyDenominations {
    final stored = _box.get('rebuyDenominations');
    if (stored != null && stored is List) {
      return List<int>.from(stored);
    }
    return [100, 200];
  }

  static set rebuyDenominations(List<int> v) =>
      _box.put('rebuyDenominations', v);

  // --- Admin / Banker mode ---
  static bool get isAdminMode =>
      _box.get('isAdminMode', defaultValue: true);
  static set isAdminMode(bool v) => _box.put('isAdminMode', v);

  // --- Live game view mode ---
  static bool get useTableView =>
      _box.get('useTableView', defaultValue: true);
  static set useTableView(bool v) => _box.put('useTableView', v);

  // --- Game persistence (for resume) ---
  static DateTime? get gameStartTime {
    final stored = _box.get('gameStartTime');
    return stored is DateTime ? stored : null;
  }

  static set gameStartTime(DateTime? v) => _box.put('gameStartTime', v);

  static String get gameLocation =>
      _box.get('gameLocation', defaultValue: 'Unknown Location');
  static set gameLocation(String v) => _box.put('gameLocation', v);

  /// Format an amount with the configured currency symbol.
  static String formatAmount(dynamic amount) {
    return '$currencySymbol$amount';
  }

  // --- Buy-in Limit ---
  static int get maxBuyInPerPlayer => _box.get('maxBuyInPerPlayer', defaultValue: 0); // 0 = unlimited
  static set maxBuyInPerPlayer(int v) => _box.put('maxBuyInPerPlayer', v);

  // --- Activity Log (ephemeral, cleared on game end) ---
  static List<String> get activityLog {
    final stored = _box.get('activityLog');
    if (stored != null && stored is List) return List<String>.from(stored);
    return [];
  }
  static void addLogEntry(String entry) {
    final log = activityLog;
    final ts = DateTime.now();
    final time = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    log.add('$time  $entry');
    _box.put('activityLog', log);
  }
  static void clearActivityLog() => _box.delete('activityLog');

  // --- Pot Expenses (ephemeral, cleared on game end) ---
  static List<Map<String, dynamic>> get potExpenses {
    final stored = _box.get('potExpenses');
    if (stored != null && stored is List) {
      return List<Map<String, dynamic>>.from(stored.map((e) => Map<String, dynamic>.from(e)));
    }
    return [];
  }
  static void addPotExpense(String label, int amount) {
    final expenses = potExpenses;
    expenses.add({'label': label, 'amount': amount});
    _box.put('potExpenses', expenses);
  }
  static void clearPotExpenses() => _box.delete('potExpenses');
  static int get totalPotExpenses => potExpenses.fold(0, (s, e) => s + (e['amount'] as int));

  static void clearGameState() {
    _box.delete('gameStartTime');
    _box.delete('gameLocation');
    clearActivityLog();
    clearPotExpenses();
  }
}
