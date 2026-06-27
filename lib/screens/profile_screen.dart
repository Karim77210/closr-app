import 'package:flutter/material.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/screens/creator_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser user;

  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();

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
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue[100],
                        ),
                        child: Center(
                          child: Text(
                            widget.user.displayName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Role: ${widget.user.role.name.toUpperCase()}',
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
                        _buildInfoRow('Email', widget.user.email),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Member Since',
                          _formatDate(widget.user.createdAt),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          'Status',
                          widget.user.isActive ? 'Active' : 'Inactive',
                        ),
                      ],
                    ),
                  ),
                ),
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
                    if (widget.user.role == UserRole.creator) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreatorSettingsScreen(user: widget.user),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming soon!')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),

                if (widget.user.role == UserRole.creator)
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
                      _buildSettingsTile(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Payout Settings',
                        subtitle: 'Manage your payments',
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
}
