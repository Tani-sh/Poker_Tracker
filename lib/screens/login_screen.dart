import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/account_linking_service.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _auth = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _signIn() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _errorMessage = 'Enter a valid 10-digit phone number');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    final user = await _auth.signInWithPhone(phone);
    if (user != null) {
      // Trigger first-login data linking and cloud sync
      try {
        await AccountLinkingService().onFirstLogin();
        await FirestoreService().fullSync();
      } catch (_) {
        // Non-critical — local data works fine without sync
      }
      _navigateHome();
    } else {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to sign in. Check your internet connection.';
        _isLoading = false;
      });
    }
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _continueOffline() {
    _navigateHome();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // Logo area
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.tealAccent.withValues(alpha: 0.3), Colors.teal.withValues(alpha: 0.1)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.5), width: 2),
                  ),
                  child: const Center(child: Text('🃏', style: TextStyle(fontSize: 48))),
                ),
                const SizedBox(height: 24),
                const Text('Poker Tracker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Track games · Settle debts · See your stats',
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  textAlign: TextAlign.center),
                const SizedBox(height: 48),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Enter your phone number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade600),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('+91', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(fontSize: 18, letterSpacing: 1.5),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'XXXXXXXXXX',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.tealAccent, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Sign In'),
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                    ]),
                  ),
                ],

                const SizedBox(height: 32),

                // Divider
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade700)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade700)),
                ]),

                const SizedBox(height: 16),

                // Continue offline
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _continueOffline,
                    icon: const Icon(Icons.wifi_off_outlined, size: 18),
                    label: const Text('Continue Offline'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('All features work offline. Sign in later to sync across devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
