import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/services/stripe_service.dart';
import 'package:closr_app/screens/creator_settings_screen.dart';
import 'package:closr_app/screens/edit_profile_screen.dart';
import 'package:closr_app/screens/wallet_screen.dart';
import 'package:closr_app/widgets/closr_avatar.dart';
import 'package:closr_app/widgets/error_banner.dart';
import 'package:closr_app/widgets/grouped_list.dart';
import 'package:closr_app/widgets/labeled_field.dart';
import 'package:closr_app/widgets/page_heading.dart';
import 'package:closr_app/theme.dart';

/// Settings hub (Figma "Settings"): balance + avatar header, grouped
/// Payments / Security / Creator / General sections.
class ProfileScreen extends StatefulWidget {
  final AppUser user;

  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _stripeService = StripeService();

  late AppUser _user;
  StreamSubscription<AppUser?>? _userSub;

  int? _balanceCents;
  bool _balanceLoading = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _userSub = _firestoreService.streamUser(_user.uid).listen((u) {
      if (u == null || !mounted) return;
      setState(() => _user = u);
    });
    if (_user.role == UserRole.creator) _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final data = await _stripeService.getCreatorEarnings();
      final subs = (data['subscribers'] as List).cast<Map<String, dynamic>>();
      int grossCents = 0;
      for (final sub in subs) {
        for (final inv in (sub['invoices'] as List).cast<Map<String, dynamic>>()) {
          grossCents += inv['amountPaid'] as int;
        }
      }
      if (mounted) setState(() { _balanceCents = (grossCents * 0.85).round(); _balanceLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  void _handleSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _authService.signOut();
                // Navigation is handled automatically by StreamBuilder in main.dart
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sign out failed: $e')),
                  );
                }
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: ClosrColors.rose)),
          ),
        ],
      ),
    );
  }

  bool get _hasPasswordProvider {
    final providers = FirebaseAuth.instance.currentUser?.providerData ?? [];
    return providers.any((p) => p.providerId == 'password');
  }

  void _handleChangePassword() {
    if (!_hasPasswordProvider) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Password managed by Google'),
          content: const Text(
            'You signed in with Google — your password is managed by your Google account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Text('We will send a password reset link to ${_user.email}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: _user.email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password reset link sent to ${_user.email}')),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Could not send reset email')),
                );
              }
            },
            child: const Text('Send link'),
          ),
        ],
      ),
    );
  }

  void _handleChangeEmail() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangeEmailSheet(),
    );
  }

  Future<void> _handlePaymentMethods() async {
    if (_user.role == UserRole.creator && _user.stripeConnectOnboarded) {
      try {
        await _stripeService.openStripeDashboard();
      } on Exception catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  void _showConnectedApps() {
    final providers = FirebaseAuth.instance.currentUser?.providerData ?? [];
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Connected apps', style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),
              GroupedSection(
                children: [
                  for (final p in providers)
                    GroupedRow(
                      icon: p.providerId == 'google.com'
                          ? Icons.g_mobiledata
                          : Icons.email_outlined,
                      label: p.providerId == 'google.com'
                          ? 'Google — ${p.email ?? _user.email}'
                          : 'Email — ${p.email ?? _user.email}',
                      trailing: const SizedBox.shrink(),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBecomeCreatorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BecomeCreatorSheet(user: widget.user),
    );
  }

  void _openEditProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditProfileScreen(user: _user)),
    );
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon!')),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  String get _balanceText {
    if (_balanceLoading) return '€ …';
    if (_balanceCents == null) return '€ ?';
    return '€${(_balanceCents! / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCreator = _user.role == UserRole.creator;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Header: balance / name + avatar ─────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isCreator) ...[
                            Text(
                              'Balance',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _balanceText,
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => WalletScreen(creator: _user),
                                ),
                              ),
                              child: const Text('View wallet'),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            PageHeading(_user.displayName),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClosrAvatar(
                          photoUrl: _user.photoUrl?.isNotEmpty == true ? _user.photoUrl : null,
                          initialSource: _user.displayName,
                          size: 92,
                          editBadge: true,
                          onTap: _openEditProfile,
                          onEditTap: _openEditProfile,
                        ),
                        const SizedBox(height: 10),
                        Text('@${_user.username}', style: theme.textTheme.titleMedium),
                        if (_user.bio.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 180,
                            child: Text(
                              _user.bio,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ─── Payments ─────────────────────────────────────────────
                const SectionTitle('Payments'),
                GroupedSection(
                  children: [
                    GroupedRow(
                      icon: Icons.lock_outline,
                      label: 'Payment methods',
                      onTap: _handlePaymentMethods,
                    ),
                  ],
                ),

                // ─── Security ─────────────────────────────────────────────
                const SectionTitle('Security'),
                GroupedSection(
                  children: [
                    GroupedRow(
                      icon: Icons.lock_outline,
                      label: 'Change password',
                      onTap: _handleChangePassword,
                    ),
                    GroupedRow(
                      icon: Icons.email_outlined,
                      label: 'Change email address',
                      onTap: _handleChangeEmail,
                    ),
                    GroupedRow(
                      icon: Icons.grid_view_outlined,
                      label: 'Manage connected apps',
                      onTap: _showConnectedApps,
                    ),
                  ],
                ),

                // ─── Creator ──────────────────────────────────────────────
                const SectionTitle('Creator'),
                GroupedSection(
                  children: [
                    if (isCreator) ...[
                      GroupedRow(
                        icon: Icons.settings_outlined,
                        label: 'Creator Settings',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CreatorSettingsScreen(user: _user),
                          ),
                        ),
                      ),
                      GroupedRow(
                        icon: Icons.trending_up_outlined,
                        label: 'Analytics',
                        onTap: _comingSoon,
                      ),
                    ] else
                      GroupedRow(
                        icon: Icons.star_outline,
                        label: 'Become a Creator',
                        onTap: () => _showBecomeCreatorSheet(context),
                      ),
                  ],
                ),

                // ─── General ──────────────────────────────────────────────
                const SectionTitle('General'),
                GroupedSection(
                  children: [
                    GroupedRow(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      onTap: _comingSoon,
                    ),
                    GroupedRow(
                      icon: Icons.logout,
                      label: 'Sign Out',
                      destructive: true,
                      onTap: _handleSignOut,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Change email sheet ───────────────────────────────────────────────────────

class _ChangeEmailSheet extends StatefulWidget {
  const _ChangeEmailSheet();

  @override
  State<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<_ChangeEmailSheet> {
  final _emailController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    setState(() { _isSaving = true; _error = null; });
    try {
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(newEmail);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification link sent — your email updates after you confirm it.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'requires-recent-login'
          ? 'For security, please sign out and sign back in, then retry.'
          : (e.message ?? 'Could not update email'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Change email address', style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 16),
          ],
          LabeledField(
            label: 'New email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            hint: 'olivia.r@closr.com',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send verification link'),
          ),
        ],
      ),
    );
  }
}

// ─── Become creator sheet ─────────────────────────────────────────────────────

class _BecomeCreatorSheet extends StatefulWidget {
  final AppUser user;
  const _BecomeCreatorSheet({required this.user});

  @override
  State<_BecomeCreatorSheet> createState() => _BecomeCreatorSheetState();
}

class _BecomeCreatorSheetState extends State<_BecomeCreatorSheet> {
  final _firestoreService = FirestoreService();
  final _priceController = TextEditingController(text: '20');
  final _limitController = TextEditingController(text: '50');
  final _bioController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _priceController.dispose();
    _limitController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final limit = int.tryParse(_limitController.text.trim()) ?? 0;

    if (price <= 0) {
      setState(() => _error = 'Price must be greater than €0');
      return;
    }
    if (limit <= 0) {
      setState(() => _error = 'Subscriber limit must be greater than 0');
      return;
    }

    setState(() { _isLoading = true; _error = null; });
    try {
      await _firestoreService.updateUser(widget.user.uid, {
        'role': 'creator',
        'subscriptionPriceCents': price * 100,
        'subscriberLimit': limit,
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Become a Creator', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'This action is irreversible — you cannot go back to subscriber mode.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 16),
            ],
            LabeledField(
              label: 'Monthly subscription price (€)',
              controller: _priceController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Subscriber limit',
              controller: _limitController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Bio (optional)',
              controller: _bioController,
              hint: 'Coach and content creator...',
              maxLines: 3,
              maxLength: 100,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Become a Creator'),
            ),
          ],
        ),
      ),
    );
  }
}
