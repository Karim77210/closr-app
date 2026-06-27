import 'package:flutter/material.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/widgets/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  String? get _returnTo {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return args['returnTo'] as String?;
    return null;
  }

  void _onAuthSuccess() {
    final returnTo = _returnTo;
    if (returnTo != null) {
      Navigator.of(context).pushReplacementNamed(returnTo);
    }
    // Otherwise AuthWrapper handles navigation via authStateChanges
  }

  Future<void> _handleSignInWithGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await _authService.signInWithGoogle();
      if (mounted) _onAuthSuccess();
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
      if (mounted) _onAuthSuccess();
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (mounted) _onAuthSuccess();
    } on Exception catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
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
                  // Logo / Title
                  const SizedBox(height: 40),
                  Text(
                    'closr',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect with creators you value',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 40),

                  // Error message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),

                  // Email field
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display name (only for sign up)
                  if (_isSignUp)
                    Column(
                      children: [
                        TextField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: 'Display Name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: const Icon(Icons.person_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Password field
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.lock_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign in / Sign up button
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isSignUp ? _handleSignUp : _handleSignInWithEmail),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue[600],
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isSignUp ? 'Create Account' : 'Sign In',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle sign up / sign in
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _errorMessage = null;
                            });
                          },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign in'
                          : 'Don\'t have an account? Sign up',
                      style: TextStyle(color: Colors.blue[600]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[300])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google Sign-In button
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleSignInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
