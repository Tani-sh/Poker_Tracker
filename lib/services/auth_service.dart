import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';

/// Centralized authentication service wrapping Firebase Phone Auth.
/// Designed for offline-first: caches auth state in Hive for fast startup.
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  String? get uid => _auth.currentUser?.uid;
  String? get phoneNumber => cachedPhone;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  void _cacheAuthState(String? phoneOverride) {
    final box = Hive.box('settings');
    if (isLoggedIn) {
      if (phoneOverride != null) box.put('cachedPhone', phoneOverride);
      box.put('cachedUid', uid);
    }
  }

  String? get cachedPhone => Hive.box('settings').get('cachedPhone');
  String? get cachedUid => Hive.box('settings').get('cachedUid');

  /// Sign in using just the phone number and Anonymous Auth to secure the database connection.
  Future<User?> signInWithPhone(String phone) async {
    try {
      final normalized = _normalizePhone(phone);
      final result = await _auth.signInAnonymously();
      _cacheAuthState(normalized);
      return result.user;
    } catch (e) {
      return null;
    }
  }

  /// Sign out and clear cache.
  Future<void> signOut() async {
    await _auth.signOut();
    final box = Hive.box('settings');
    box.delete('cachedPhone');
    box.delete('cachedUid');
  }

  /// Normalize phone number to +91XXXXXXXXXX format.
  static String _normalizePhone(String input) {
    // Remove spaces, dashes, parentheses
    String cleaned = input.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // If already has country code
    if (cleaned.startsWith('+')) return cleaned;

    // Remove leading 0
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);

    // Add +91 for India
    if (cleaned.length == 10) return '+91$cleaned';

    // Fallback
    return '+91$cleaned';
  }

  /// Public normalizer for use elsewhere.
  static String normalizePhone(String input) => _normalizePhone(input);
}
