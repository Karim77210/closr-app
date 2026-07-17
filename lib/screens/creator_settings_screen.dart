import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/widgets/loading_overlay.dart';
import 'package:closr_app/widgets/error_banner.dart';
import 'package:closr_app/widgets/grouped_list.dart';
import 'package:closr_app/widgets/labeled_field.dart';
import 'package:closr_app/widgets/page_heading.dart';
import 'package:closr_app/theme.dart';

/// Creator pricing & default chat settings. Profile fields (photo, name,
/// username, bio) live in [EditProfileScreen] — no duplicates.
class CreatorSettingsScreen extends StatefulWidget {
  final AppUser user;

  const CreatorSettingsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<CreatorSettingsScreen> createState() => _CreatorSettingsScreenState();
}

class _CreatorSettingsScreenState extends State<CreatorSettingsScreen> {
  final _authService = AuthService();
  final _priceController = TextEditingController();
  final _limitController = TextEditingController();
  final _messageCharsController = TextEditingController();
  final _messageCooldownController = TextEditingController();
  final _messageDailyController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _priceController.text = (widget.user.subscriptionPriceCents / 100).toStringAsFixed(0);
    _limitController.text = widget.user.subscriberLimit > 0 ? widget.user.subscriberLimit.toString() : '50';
    _messageCharsController.text = widget.user.messageCharacterLimit.toString();
    _messageCooldownController.text = widget.user.messageCooldownSeconds.toString();
    _messageDailyController.text = widget.user.maxMessagesPerDay.toString();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _limitController.dispose();
    _messageCharsController.dispose();
    _messageCooldownController.dispose();
    _messageDailyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final price = int.tryParse(_priceController.text.trim()) ?? 0;
    final limit = int.tryParse(_limitController.text.trim()) ?? 0;
    final messageChars = int.tryParse(_messageCharsController.text.trim()) ?? 300;
    final cooldown = int.tryParse(_messageCooldownController.text.trim()) ?? 20;
    final daily = int.tryParse(_messageDailyController.text.trim()) ?? 10;

    if (price <= 0) {
      setState(() => _errorMessage = 'Subscription price must be greater than 0.');
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
        subscriptionPriceCents: price * 100,
        subscriberLimit: limit,
        messageCharacterLimit: messageChars,
        messageCooldownSeconds: cooldown,
        maxMessagesPerDay: daily,
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PageHeading(
                    'Creator settings',
                    color: ClosrColors.ember,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your pricing and default conversation limits.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(_errorMessage!),
                  ],
                  const SectionTitle('Pricing'),
                  LabeledField(
                    label: 'Subscription price',
                    controller: _priceController,
                    hint: 'e.g. 20',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Number of paid 1:1 conversations',
                    controller: _limitController,
                    hint: 'Suggested 50',
                    keyboardType: TextInputType.number,
                  ),
                  const SectionTitle('Default tchat settings'),
                  LabeledField(
                    label: 'Message character limit',
                    controller: _messageCharsController,
                    hint: 'Default 300',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Cooldown between messages (sec)',
                    controller: _messageCooldownController,
                    hint: 'Default 20',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Max messages per day',
                    controller: _messageDailyController,
                    hint: 'Default 10',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    child: const Text('Save settings'),
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
}
