import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _avatarUrl;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.getProfile(AuthService.userId!);
    if (profile != null && mounted) {
      setState(() {
        _usernameController.text = profile.username ?? '';
        _displayNameController.text = profile.displayName ?? '';
        _bioController.text = profile.bio ?? '';
        _avatarUrl = profile.avatarUrl;
        _loading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    try {
      final url = await ProfileService.uploadAvatar(bytes, ext == 'png' ? 'png' : 'jpg');
      await ProfileService.updateProfile(avatarUrl: url);
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ProfileService.updateProfile(
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィールを編集'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('完了', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Column(
                  children: [
                    UserAvatar(url: _avatarUrl, size: 86),
                    const SizedBox(height: 8),
                    const Text('写真を変更', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildField('ユーザー名', _usernameController),
            _buildField('名前', _displayNameController),
            _buildField('自己紹介', _bioController, maxLines: 3, maxLength: 160),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            decoration: const InputDecoration(
              border: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
