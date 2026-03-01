import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../constants.dart';
import '../services.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  Uint8List? _imageBytes;
  String? _imageExt;
  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  bool _posting = false;
  bool _pickerOpened = false;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _autoOpenPicker() {
    if (_pickerOpened || _imageBytes != null) return;
    _pickerOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pickImage(ImageSource.gallery);
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1080, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    setState(() {
      _imageBytes = bytes;
      _imageExt = ext == 'png' ? 'png' : 'jpg';
    });
  }

  Future<void> _post() async {
    if (_imageBytes == null) return;
    setState(() => _posting = true);
    try {
      await PostService.createPost(
        imageBytes: _imageBytes!,
        ext: _imageExt!,
        caption: _captionController.text.isNotEmpty ? _captionController.text : null,
        locationName: _locationController.text.isNotEmpty ? _locationController.text : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿しました！')));
        setState(() {
          _imageBytes = null;
          _pickerOpened = false;
          _captionController.clear();
          _locationController.clear();
        });
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto open gallery when this tab is shown
    _autoOpenPicker();

    return Scaffold(
      appBar: AppBar(
        title: const Text('新規投稿'),
        actions: [
          if (_imageBytes != null)
            TextButton(
              onPressed: _posting ? null : _post,
              child: _posting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('シェア', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 16)),
            ),
        ],
      ),
      body: _imageBytes == null ? _buildPicker() : _buildEditor(),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.text, width: 2),
            ),
            child: const Icon(Icons.camera_alt_outlined, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('写真を選んでシェアしよう', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _pickImage(ImageSource.gallery),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('ライブラリから選択', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _pickImage(ImageSource.camera),
            child: const Text('写真を撮る', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.memory(_imageBytes!, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _captionController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'キャプションを書く...',
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: '場所を追加',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () => setState(() {
                _imageBytes = null;
                _pickerOpened = false;
              }),
              child: const Text('写真を変更', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}
