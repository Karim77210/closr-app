import 'package:flutter/material.dart';
import 'package:closr_app/main.dart' show PendingNavigation;
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/widgets/loading_overlay.dart';
import 'package:closr_app/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSignInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await _authService.signInWithGoogle();
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await _authService.signInWithEmail(email: email, password: password);
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();

    if (email.isEmpty || password.isEmpty || username.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (RegExp(r'[^a-z0-9_]').hasMatch(username)) {
      setState(() => _errorMessage = 'Username can only contain letters, numbers and underscores');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      // Store username FIRST so onboarding gets it immediately after auth
      PendingNavigation.username = username;

      // Check uniqueness (unauthenticated — requires Firestore list rule)
      final taken = await FirestoreService().usernameExists(username);
      if (taken) {
        PendingNavigation.username = null;
        setState(() => _errorMessage = 'This username is already taken');
        return;
      }

      // Create Firebase Auth account → triggers navigation to OnboardingScreen
      await _authService.signUpWithEmail(email: email, password: password);
    } on Exception catch (e) {
      PendingNavigation.username = null;
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ─── Cover header (full-bleed plum gradient) ──────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.of(context).padding.top + 56,
                  24,
                  56,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ClosrColors.plum, ClosrColors.darkBackground],
                  ),
                ),
                child: Column(
                  children: [
                    const ClosrLogoMark(size: 72),
                    const SizedBox(height: 20),
                    Text(
                      'Closr',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: ClosrColors.paper,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect with creators you value',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: ClosrColors.emberSoft,
                          ),
                    ),
                  ],
                ),
              ),

              // ─── Form ─────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 48,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ClosrColors.rose.withAlpha(28),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ClosrColors.rose.withAlpha(90)),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: ClosrColors.rose, fontSize: 14),
                            ),
                          ),
                        if (_errorMessage != null) const SizedBox(height: 16),

                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Username — only on sign up
                        if (_isSignUp) ...[
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              hintText: 'yourname',
                              prefixText: '@',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outlined),
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : (_isSignUp ? _handleSignUp : _handleSignInWithEmail),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            _isSignUp ? 'Create Account' : 'Sign In',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _errorMessage = null;
                                  }),
                          child: Text(
                            _isSignUp ? 'Already have an account? Sign in' : 'Don\'t have an account? Sign up',
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 24),

                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _handleSignInWithGoogle,
                          icon: const Icon(Icons.login),
                          label: const Text('Continue with Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
