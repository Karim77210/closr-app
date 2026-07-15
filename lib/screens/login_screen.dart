import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'package:closr_app/main.dart' show PendingNavigation;
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/widgets/loading_overlay.dart';
import 'package:closr_app/widgets/labeled_field.dart';
import 'package:closr_app/widgets/error_banner.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),

                      // ─── Logo lockup ─────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const ClosrLogoMark(size: 56),
                          const SizedBox(width: 16),
                          Text(
                            'Closr',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Paid messaging app.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: ClosrColors.ember,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        _isSignUp
                            ? 'Sign up by entering your details.'
                            : 'Welcome back! Please enter your details.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        ErrorBanner(_errorMessage!),
                        const SizedBox(height: 16),
                      ],

                      // ─── Form ────────────────────────────────────────────
                      LabeledField(
                        label: 'Email',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        hint: 'olivia.r@closr.com',
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),

                      if (_isSignUp) ...[
                        LabeledField(
                          label: 'Username',
                          controller: _usernameController,
                          hint: '@username',
                        ),
                        const SizedBox(height: 16),
                      ],

                      LabeledField(
                        label: 'Password',
                        controller: _passwordController,
                        obscureText: true,
                        hint: '••••••••',
                        onSubmitted: (_) => _isSignUp ? _handleSignUp() : _handleSignInWithEmail(),
                      ),
                      const SizedBox(height: 32),

                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : (_isSignUp ? _handleSignUp : _handleSignInWithEmail),
                        child: Text(_isSignUp ? 'Sign up' : 'Sign in'),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: SignInButton(
                          Buttons.google,
                          text: _isSignUp ? 'Sign up with Google' : 'Sign in with Google',
                          onPressed: _handleSignInWithGoogle,
                          elevation: 0,
                          shape: StadiumBorder(
                            side: BorderSide(color: theme.colorScheme.outline),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ─── Toggle footer ───────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _errorMessage = null;
                                  }),
                          child: Text.rich(
                            TextSpan(
                              text: _isSignUp
                                  ? 'Already have an account? '
                                  : 'Don\'t have an account? ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              children: [
                                TextSpan(
                                  text: _isSignUp ? 'Sign in' : 'Sign up',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: ClosrColors.ember,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
