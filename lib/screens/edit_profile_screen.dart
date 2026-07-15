import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/auth_service.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/widgets/closr_avatar.dart';
import 'package:closr_app/widgets/error_banner.dart';
import 'package:closr_app/widgets/grouped_list.dart';
import 'package:closr_app/widgets/labeled_field.dart';

/// Figma "Profil settings": centered avatar, "Edit profile picture" action,
/// grouped rows to change username / bio / display name.
class EditProfileScreen extends StatefulWidget {
  final AppUser user;

  const EditProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _imagePicker = ImagePicker();

  late AppUser _user;
  StreamSubscription<AppUser?>? _userSub;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _userSub = _firestoreService.streamUser(_user.uid).listen((u) {
      if (u == null || !mounted) return;
      setState(() => _user = u);
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await _authService.updateUserProfile(uid: _user.uid, photoFile: picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _editField({
    required String title,
    required String label,
    required String initialValue,
    String? hint,
    String? prefixText,
    int maxLines = 1,
    int? maxLength,
    required Future<void> Function(String value) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditFieldSheet(
        title: title,
        label: label,
        initialValue: initialValue,
        hint: hint,
        prefixText: prefixText,
        maxLines: maxLines,
        maxLength: maxLength,
        onSave: onSave,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: ClosrAvatar(
                    photoUrl: _user.photoUrl?.isNotEmpty == true ? _user.photoUrl : null,
                    initialSource: _user.displayName,
                    size: 92,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: _isUploadingPhoto
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: _pickAndUploadPhoto,
                          child: const Text('Edit profile picture'),
                        ),
                ),
                const SizedBox(height: 24),
                GroupedSection(
                  children: [
                    GroupedRow(
                      icon: Icons.person_outline,
                      label: 'Change display name',
                      onTap: () => _editField(
                        title: 'Change display name',
                        label: 'Display name',
                        initialValue: _user.displayName,
                        onSave: (value) => _authService.updateUserProfile(
                          uid: _user.uid,
                          displayName: value,
                        ),
                      ),
                    ),
                    GroupedRow(
                      icon: Icons.alternate_email,
                      label: 'Change username',
                      onTap: () => _editField(
                        title: 'Change username',
                        label: 'Username',
                        initialValue: _user.username,
                        prefixText: '@',
                        onSave: (value) => _authService.updateUserProfile(
                          uid: _user.uid,
                          username: value.toLowerCase(),
                        ),
                      ),
                    ),
                    GroupedRow(
                      icon: Icons.edit_note_outlined,
                      label: 'Change bio',
                      onTap: () => _editField(
                        title: 'Change bio',
                        label: 'Bio',
                        initialValue: _user.bio,
                        hint: 'Coach and content creator...',
                        maxLines: 3,
                        maxLength: 100,
                        onSave: (value) => _authService.updateUserProfile(
                          uid: _user.uid,
                          bio: value,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small bottom sheet with a single [LabeledField] and a Save button.
class _EditFieldSheet extends StatefulWidget {
  final String title;
  final String label;
  final String initialValue;
  final String? hint;
  final String? prefixText;
  final int maxLines;
  final int? maxLength;
  final Future<void> Function(String value) onSave;

  const _EditFieldSheet({
    required this.title,
    required this.label,
    required this.initialValue,
    this.hint,
    this.prefixText,
    this.maxLines = 1,
    this.maxLength,
    required this.onSave,
  });

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
  late final _controller = TextEditingController(text: widget.initialValue);
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty && widget.maxLines == 1) {
      setState(() => _error = '${widget.label} cannot be empty');
      return;
    }
    setState(() { _isSaving = true; _error = null; });
    try {
      await widget.onSave(value);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.label} updated!')),
      );
    } on Exception catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
          Text(widget.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 16),
          ],
          LabeledField(
            label: widget.label,
            controller: _controller,
            hint: widget.hint,
            prefixText: widget.prefixText,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
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
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
