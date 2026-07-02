import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/widgets/loading_overlay.dart';
import 'package:closr_app/theme.dart';

class CreatorSettingsScreen extends StatefulWidget {
  final AppUser user;

  const CreatorSettingsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<CreatorSettingsScreen> createState() => _CreatorSettingsScreenState();
}

class _CreatorSettingsScreenState extends State<CreatorSettingsScreen> {
  final _authService = AuthService();
  final _imagePicker = ImagePicker();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  final _priceController = TextEditingController();
  final _limitController = TextEditingController();
  final _ibanController = TextEditingController();
  final _messageCharsController = TextEditingController();
  final _messageCooldownController = TextEditingController();
  final _messageDailyController = TextEditingController();

  XFile? _profileImage;
  Uint8List? _profileImageData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController.text = widget.user.displayName;
    _usernameController.text = widget.user.username;
    _bioController.text = widget.user.bio;
    _priceController.text = (widget.user.subscriptionPriceCents / 100).toStringAsFixed(0);
    _limitController.text = widget.user.subscriberLimit > 0 ? widget.user.subscriberLimit.toString() : '50';
    _ibanController.text = widget.user.iban;
    _messageCharsController.text = widget.user.messageCharacterLimit.toString();
    _messageCooldownController.text = widget.user.messageCooldownSeconds.toString();
    _messageDailyController.text = widget.user.maxMessagesPerDay.toString();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
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

  Future<void> _saveSettings() async {
    final displayName = _displayNameController.text.trim();
    final username = _usernameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final limit = int.tryParse(_limitController.text.trim()) ?? 0;
    final iban = _ibanController.text.trim();
    final messageChars = int.tryParse(_messageCharsController.text.trim()) ?? 300;
    final cooldown = int.tryParse(_messageCooldownController.text.trim()) ?? 20;
    final daily = int.tryParse(_messageDailyController.text.trim()) ?? 10;

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Username cannot be empty.');
      return;
    }
    if (bio.length > 100) {
      setState(() => _errorMessage = 'Bio must be 100 characters or fewer.');
      return;
    }
    if (price < 20) {
      setState(() => _errorMessage = 'Subscription price must be at least 20 EUR.');
      return;
    }
    if (limit <= 0) {
      setState(() => _errorMessage = 'Subscriber limit must be higher than 0.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.updateUserProfile(
        uid: widget.user.uid,
        displayName: displayName.isNotEmpty ? displayName : null,
        username: username,
        bio: bio,
        subscriptionPriceCents: price * 100,
        subscriberLimit: limit,
        iban: iban,
        messageCharacterLimit: messageChars,
        messageCooldownSeconds: cooldown,
        maxMessagesPerDay: daily,
        photoFile: _profileImage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Creator settings saved.')),
      );
      Navigator.pop(context);
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
    final photoProvider = _profileImageData != null
        ? MemoryImage(_profileImageData!) as ImageProvider
        : (widget.user.photoUrl?.isNotEmpty == true ? NetworkImage(widget.user.photoUrl!) : null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Settings'),
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 40,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUploadPhotoCard(context, photoProvider),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _displayNameController,
                    label: 'Full name',
                    hint: 'Your first and last name',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'Your public creator username',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _bioController,
                    label: 'Bio',
                    hint: 'Short introduction (100 chars max)',
                    maxLines: 3,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _priceController,
                    label: 'Subscription price (EUR)',
                    hint: 'Minimum 20 EUR',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _limitController,
                    label: 'Subscriber limit',
                    hint: 'Suggested 50',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _ibanController,
                    label: 'IBAN for payouts',
                    hint: 'Enter your IBAN',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _messageCharsController,
                    label: 'Character limit per message',
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
                  if (_errorMessage != null)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: ClosrColors.rose.withAlpha(28),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ClosrColors.rose.withAlpha(90)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: ClosrColors.rose),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Creator Settings'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPhotoCard(BuildContext context, ImageProvider? imageProvider) {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: ClosrColors.emberSoft,
              backgroundImage: imageProvider,
              child: imageProvider == null ? const Icon(Icons.camera_alt_outlined, color: ClosrColors.ink) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Update profile picture', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('This appears on your public creator page.'),
                ],
              ),
            ),
            const Icon(Icons.edit, color: ClosrColors.ember),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
