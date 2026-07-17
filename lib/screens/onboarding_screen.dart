import 'dart:math';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:closr_app/main.dart' show PendingNavigation;
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/widgets/loading_overlay.dart';
import 'package:closr_app/widgets/closr_card.dart';
import 'package:closr_app/widgets/error_banner.dart';
import 'package:closr_app/widgets/grouped_list.dart';
import 'package:closr_app/widgets/labeled_field.dart';
import 'package:closr_app/widgets/page_heading.dart';
import 'package:closr_app/widgets/upload_card.dart';
import 'package:closr_app/theme.dart';

const _funNames = [
  'Brave Panda', 'Swift Falcon', 'Curious Otter', 'Quiet Tiger',
  'Happy Koala', 'Bold Eagle', 'Gentle Whale', 'Clever Fox',
  'Wise Owl', 'Playful Lynx', 'Fierce Jaguar', 'Shy Rabbit',
];

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
  late final String _funNameHint = _funNames[Random().nextInt(_funNames.length)];
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  final _bioController = TextEditingController();
  final _priceController = TextEditingController(text: '20');
  final _limitController = TextEditingController(text: '50');
  final _messageCharsController = TextEditingController(text: '300');
  final _messageCooldownController = TextEditingController(text: '20');
  final _messageDailyController = TextEditingController(text: '10');

  UserRole? _selectedRole;
  XFile? _profileImage;
  Uint8List? _profileImageData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Capture & clear username from signup
    final signupUsername = PendingNavigation.username ?? '';
    PendingNavigation.username = null;

    _usernameController = TextEditingController(text: signupUsername);
    _displayNameController = TextEditingController(
      text: widget.displayName.isNotEmpty ? widget.displayName : _funNameHint,
    );

    // Coming from Stripe checkout → go directly to subscriber form, skip role selection
    if (PendingNavigation.checkoutCreatorUid != null) {
      _selectedRole = UserRole.subscriber; // synchronous, no flash
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _priceController.dispose();
    _limitController.dispose();

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
  }

  Future<void> _submitSubscriberProfile() async {
    final username = _usernameController.text.trim().toLowerCase();
    final displayName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : _funNameHint;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _authService.createUserProfile(
        uid: widget.uid,
        email: widget.email,
        displayName: displayName,
        role: UserRole.subscriber,
        username: username,
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

  Future<void> _submitCreatorProfile() async {
    final displayName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : _funNameHint;
    final username = _usernameController.text.trim().toLowerCase();
    final bio = _bioController.text.trim();
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final limit = int.tryParse(_limitController.text.trim()) ?? 0;
    final messageChars = int.tryParse(_messageCharsController.text.trim()) ?? 300;
    final cooldown = int.tryParse(_messageCooldownController.text.trim()) ?? 20;
    final daily = int.tryParse(_messageDailyController.text.trim()) ?? 10;

    if (bio.length > 100) {
      setState(() => _errorMessage = 'Bio must be 100 characters or fewer.');
      return;
    }
    if (price <= 0) {
      setState(() => _errorMessage = 'Subscription price must be greater than 0.' );
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
        displayName: displayName,
        role: UserRole.creator,
        username: username,
        bio: bio,
        subscriptionPriceCents: price * 100,
        subscriberLimit: limit,
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

  String get _greetingName {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) return '@$username';
    return _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : widget.displayName;
  }

  ImageProvider? get _avatarPreview {
    if (_profileImageData != null) return MemoryImage(_profileImageData!);
    if (widget.photoUrl != null) return NetworkImage(widget.photoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedRole != null
          ? AppBar(
              leading: IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 24),
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _selectedRole = null;
                          _errorMessage = null;
                        });
                      },
              ),
            )
          : null,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selectedRole == null)
                      ..._buildRoleStep(context)
                    else
                      ..._buildFormStep(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Step 1: account type (onboarding1) ──────────────────────────────────
  List<Widget> _buildRoleStep(BuildContext context) {
    return [
      const SizedBox(height: 48),
      PageHeading(
        'Nice to meet you,\n$_greetingName!',
        color: ClosrColors.ember,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      if (_errorMessage != null) ...[
        ErrorBanner(_errorMessage!),
        const SizedBox(height: 8),
      ],
      const SectionTitle('Choose your account type'),
      _buildRoleCard(
        context,
        role: UserRole.creator,
        title: 'Creator',
        description: 'Monetize your audience\nwith paid subscribers.',
        icon: LucideIcons.star,
      ),
      const SizedBox(height: 16),
      _buildRoleCard(
        context,
        role: UserRole.subscriber,
        title: 'Subscriber',
        description: 'Connect and support\nthe creators you love!',
        icon: LucideIcons.user,
      ),
    ];
  }

  // ─── Step 2: profile form (onboarding2) ──────────────────────────────────
  List<Widget> _buildFormStep(BuildContext context) {
    final theme = Theme.of(context);
    final isCreator = _selectedRole == UserRole.creator;

    return [
      const SizedBox(height: 8),
      PageHeading(
        'Tell us more...',
        color: ClosrColors.ember,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'We need a few more details\nto set up your account :',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      if (_errorMessage != null) ...[
        ErrorBanner(_errorMessage!),
        const SizedBox(height: 8),
      ],
      const SectionTitle('Profil'),
      UploadCard(
        onTap: _isLoading ? null : _pickProfileImage,
        preview: _avatarPreview,
      ),
      const SizedBox(height: 24),
      LabeledField(
        label: 'Display name',
        controller: _displayNameController,
        hint: _funNameHint,
      ),
      if (isCreator) ...[
        const SizedBox(height: 16),
        LabeledField(
          label: 'Bio',
          controller: _bioController,
          hint: 'Coach and content creator...',
          maxLines: 3,
          maxLength: 100,
        ),
        SectionTitle('Default tchat settings', padding: const EdgeInsets.only(top: 8, bottom: 4)),
        Text(
          'You will be able to change settings for each conversations later.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Subscription price',
          controller: _priceController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Number of paid 1:1 conversations',
          controller: _limitController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Message character limit',
          controller: _messageCharsController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Cooldown between messages (sec)',
          controller: _messageCooldownController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'Max messages per day',
          controller: _messageDailyController,
          keyboardType: TextInputType.number,
        ),
      ],
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: _isLoading
            ? null
            : (isCreator ? _submitCreatorProfile : _submitSubscriberProfile),
        child: const Text('Start chatting'),
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required UserRole role,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return ClosrCard(
      onTap: _isLoading ? null : () => _handleSelectRole(role),
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ClosrColors.ember, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ClosrColors.ember,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
