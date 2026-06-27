import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/widgets/loading_overlay.dart';

class OnboardingScreen extends StatefulWidget {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;

  const OnboardingScreen({
    Key? key,
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
  }) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _priceController = TextEditingController(text: '20');
  final _limitController = TextEditingController(text: '50');
  final _ibanController = TextEditingController();
  final _messageCharsController = TextEditingController(text: '300');
  final _messageCooldownController = TextEditingController(text: '20');
  final _messageDailyController = TextEditingController(text: '10');

  UserRole? _selectedRole;
  XFile? _profileImage;
  Uint8List? _profileImageData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    _priceController.dispose();
    _limitController.dispose();
    _ibanController.dispose();
    _messageCharsController.dispose();
    _messageCooldownController.dispose();
    _messageDailyController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _profileImage = picked;
        _profileImageData = bytes;
      });
    }
  }

  Future<void> _handleSelectRole(UserRole role) async {
    setState(() {
      _selectedRole = role;
      _errorMessage = null;
    });
    if (role == UserRole.subscriber) {
      await _submitSubscriberProfile();
    }
  }

  Future<void> _submitSubscriberProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService.createUserProfile(
        uid: widget.uid,
        email: widget.email,
        displayName: widget.displayName,
        role: UserRole.subscriber,
        photoUrl: widget.photoUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitCreatorProfile() async {
    final username = _usernameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final limit = int.tryParse(_limitController.text.trim()) ?? 0;
    final iban = _ibanController.text.trim();
    final messageChars = int.tryParse(_messageCharsController.text.trim()) ?? 300;
    final cooldown = int.tryParse(_messageCooldownController.text.trim()) ?? 20;
    final daily = int.tryParse(_messageDailyController.text.trim()) ?? 10;

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please choose a username.');
      return;
    }
    if (bio.length > 100) {
      setState(() => _errorMessage = 'Bio must be 100 characters or fewer.');
      return;
    }
    if (price < 20) {
      setState(() => _errorMessage = 'Subscription price must be at least 20 EUR.' );
      return;
    }
    if (limit <= 0) {
      setState(() => _errorMessage = 'Please set a maximum subscriber limit.' );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.createUserProfile(
        uid: widget.uid,
        email: widget.email,
        displayName: widget.displayName,
        role: UserRole.creator,
        username: username,
        bio: bio,
        subscriptionPriceCents: price * 100,
        subscriberLimit: limit,
        iban: iban,
        messageCharacterLimit: messageChars,
        messageCooldownSeconds: cooldown,
        maxMessagesPerDay: daily,
        photoFile: _profileImage,
        photoUrl: widget.photoUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Onboarding'),
        elevation: 0,
        leading: _selectedRole != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _selectedRole = null;
                          _errorMessage = null;
                        });
                      },
              )
            : null,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 48,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome, ${widget.displayName}!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedRole == null
                        ? 'Choose your account type'
                        : _selectedRole == UserRole.creator
                            ? 'Set up your creator page'
                            : 'Finish setting up your subscriber account',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[700],
                        ),
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 20),

                  if (_selectedRole == null) ...[
                    _buildRoleCard(
                      context,
                      role: UserRole.creator,
                      title: 'I\'m a Creator',
                      description: 'Monetize your audience with paid subscribers.',
                      icon: Icons.star_outlined,
                      iconColor: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    _buildRoleCard(
                      context,
                      role: UserRole.subscriber,
                      title: 'I\'m a Subscriber',
                      description: 'Connect with creators you admire.',
                      icon: Icons.favorite_outlined,
                      iconColor: Colors.red,
                    ),
                  ] else if (_selectedRole == UserRole.creator) ...[
                    _buildUploadPhotoCard(context),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _usernameController,
                      label: 'Username',
                      hint: 'choose your unique username',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _bioController,
                      label: 'Short bio',
                      hint: 'Tell subscribers what you offer (100 chars max)',
                      maxLength: 100,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _priceController,
                      label: 'Subscription price (EUR)',
                      hint: '20 - 150 suggested',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _limitController,
                      label: 'Subscriber limit',
                      hint: 'Default 50',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _ibanController,
                      label: 'IBAN for payouts',
                      hint: 'Optional payout IBAN',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _messageCharsController,
                      label: 'Message character limit',
                      hint: 'Default 300',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _messageCooldownController,
                      label: 'Cooldown between messages (sec)',
                      hint: 'Default 20',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _messageDailyController,
                      label: 'Max messages per day',
                      hint: 'Default 10',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitCreatorProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Complete Creator Setup'),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Text(
                      'You are about to finish your subscriber account setup.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitSubscriberProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Complete Subscriber Setup'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPhotoCard(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _pickProfileImage,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.blue[100],
              backgroundImage: _profileImageData != null
                  ? MemoryImage(_profileImageData!) as ImageProvider<Object>
                  : (widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null) as ImageProvider<Object>?,
              child: _profileImage == null && widget.photoUrl == null
                  ? const Icon(Icons.camera_alt_outlined, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Upload a profile picture', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Choose a photo for your public creator page.'),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    {
      required TextEditingController controller,
      required String label,
      String? hint,
      TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      int? maxLength,
    }
  ) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required UserRole role,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: _isLoading ? null : () => _handleSelectRole(role),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withAlpha((0.1 * 255).round()),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
