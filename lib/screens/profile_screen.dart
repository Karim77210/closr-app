import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/services/stripe_service.dart';
import 'package:closr_app/screens/creator_settings_screen.dart';
import 'package:closr_app/screens/wallet_screen.dart';

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
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile info
                Center(
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue[100],
                        backgroundImage: _user.photoUrl != null && _user.photoUrl!.isNotEmpty
                            ? NetworkImage(_user.photoUrl!) as ImageProvider
                            : null,
                        child: _user.photoUrl == null || _user.photoUrl!.isEmpty
                            ? Text(
                                _user.displayName.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${_user.username}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Account info
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Email', _user.email),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Member Since',
                          _formatDate(_user.createdAt),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Status',
                          _user.isActive ? 'Active' : 'Inactive',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Wallet card — creators only
                if (_user.role == UserRole.creator) ...[
                  _buildWalletCard(context),
                  const SizedBox(height: 32),
                ] else
                  const SizedBox(height: 32),

                // Settings section
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                _buildSettingsTile(
                  icon: Icons.edit_outlined,
                  title: 'Edit Profile',
                  subtitle: 'Update your name and photo',
                  onTap: () {
                    if (_user.role == UserRole.creator) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatorSettingsScreen(user: widget.user),
                        ),
                      );
                    } else {
                      _showEditSubscriberSheet(context);
                    }
                  },
                ),
                const SizedBox(height: 12),

                if (_user.role == UserRole.subscriber) ...[
                  _buildSettingsTile(
                    icon: Icons.star_outline,
                    title: 'Become a Creator',
                    subtitle: 'Monetize your audience with paid subscribers',
                    onTap: () => _showBecomeCreatorSheet(context),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_user.role == UserRole.creator)
                  Column(
                    children: [
                      _buildSettingsTile(
                        icon: Icons.settings_outlined,
                        title: 'Creator Settings',
                        subtitle: 'Edit creator page, pricing, payouts, and limits',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatorSettingsScreen(user: widget.user),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTile(
                        icon: Icons.trending_up_outlined,
                        title: 'Analytics',
                        subtitle: 'View your subscriber stats',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon!')),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Read our privacy policy',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Sign out button
                ElevatedButton(
                  onPressed: _handleSignOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[700], size: 24),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_outlined,
          size: 16,
          color: Colors.grey[400],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showEditSubscriberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditSubscriberSheet(user: widget.user),
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    String balanceText;
    if (_balanceLoading) {
      balanceText = '€ …';
    } else if (_balanceCents == null) {
      balanceText = '€ ?';
    } else {
      balanceText = '€ ${(_balanceCents! / 100).toStringAsFixed(2)}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance',
                  style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  balanceText,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => WalletScreen(creator: _user)),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('View wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showBecomeCreatorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _BecomeCreatorSheet(user: widget.user),
    );
  }
}

class _EditSubscriberSheet extends StatefulWidget {
  final AppUser user;
  const _EditSubscriberSheet({required this.user});

  @override
  State<_EditSubscriberSheet> createState() => _EditSubscriberSheetState();
}

class _EditSubscriberSheetState extends State<_EditSubscriberSheet> {
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  late final _nameController = TextEditingController(text: widget.user.displayName);
  late final _usernameController = TextEditingController(text: widget.user.username);
  XFile? _newPhoto;
  Uint8List? _newPhotoBytes;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() { _newPhoto = file; _newPhotoBytes = bytes; });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    if (name.isEmpty || username.isEmpty) {
      setState(() => _error = 'Name and username are required');
      return;
    }
    setState(() { _isLoading = true; _error = null; });
    try {
      await _authService.updateUserProfile(
        uid: widget.user.uid,
        displayName: name,
        username: username,
        photoFile: _newPhoto,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } on Exception catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: _newPhotoBytes != null
                        ? MemoryImage(_newPhotoBytes!) as ImageProvider
                        : (widget.user.photoUrl != null ? NetworkImage(widget.user.photoUrl!) : null),
                    child: (_newPhotoBytes == null && widget.user.photoUrl == null)
                        ? Text(widget.user.displayName[0].toUpperCase(),
                            style: const TextStyle(fontSize: 28, color: Colors.white))
                        : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.blue[600], shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50], borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Username',
              prefixText: '@',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _BecomeCreatorSheet extends StatefulWidget {
  final AppUser user;
  const _BecomeCreatorSheet({required this.user});

  @override
  State<_BecomeCreatorSheet> createState() => _BecomeCreatorSheetState();
}

class _BecomeCreatorSheetState extends State<_BecomeCreatorSheet> {
  final _authService = AuthService();
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

    if (price < 20) {
      setState(() => _error = 'Minimum price is €20');
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
        'updatedAt': DateTime.now(),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Become a Creator',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'This action is irreversible — you cannot go back to subscriber mode.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Monthly subscription price (€)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _limitController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Subscriber limit',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Bio (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.blue[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Become a Creator', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
