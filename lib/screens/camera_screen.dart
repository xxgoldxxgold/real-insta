import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
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

  // Camera state
  bool _cameraActive = false;
  html.VideoElement? _video;
  html.MediaStream? _stream;
  String? _currentViewId;
  bool _facingUser = false;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _stopCamera();
    super.dispose();
  }

  void _autoOpenPicker() {
    if (_pickerOpened || _imageBytes != null || _cameraActive) return;
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

  Future<void> _startCamera() async {
    try {
      final constraints = {
        'video': {
          'facingMode': _facingUser ? 'user' : 'environment',
          'width': {'ideal': 1080},
          'height': {'ideal': 1080},
        },
        'audio': false,
      };
      final stream = await html.window.navigator.mediaDevices!.getUserMedia(constraints);
      _stream = stream;

      final video = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover';
      _video = video;

      // Mirror front camera
      if (_facingUser) {
        video.style.transform = 'scaleX(-1)';
      }

      final viewId = 'camera-${DateTime.now().millisecondsSinceEpoch}';
      ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) => video);
      _currentViewId = viewId;

      if (mounted) setState(() => _cameraActive = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラにアクセスできません: $e')),
        );
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_video == null) return;
    final w = _video!.videoWidth;
    final h = _video!.videoHeight;
    if (w == 0 || h == 0) return;

    final canvas = html.CanvasElement(width: w, height: h);
    final ctx = canvas.context2D;

    // Mirror front camera capture
    if (_facingUser) {
      ctx.translate(w.toDouble(), 0);
      ctx.scale(-1, 1);
    }
    ctx.drawImage(_video!, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64Str = dataUrl.split(',').last;
    final bytes = base64Decode(base64Str);

    _stopCamera();
    if (mounted) {
      setState(() {
        _imageBytes = Uint8List.fromList(bytes);
        _imageExt = 'jpg';
        _cameraActive = false;
      });
    }
  }

  void _stopCamera() {
    _stream?.getTracks().forEach((track) => track.stop());
    _stream = null;
    _video = null;
  }

  Future<void> _flipCamera() async {
    _stopCamera();
    setState(() {
      _facingUser = !_facingUser;
      _cameraActive = false;
    });
    await _startCamera();
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

    if (_cameraActive) return _buildCameraView();

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

  Widget _buildCameraView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_currentViewId != null)
            Positioned.fill(
              child: HtmlElementView(viewType: _currentViewId!),
            ),
          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () {
                        _stopCamera();
                        setState(() => _cameraActive = false);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                      onPressed: _flipCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery button
                    GestureDetector(
                      onTap: () {
                        _stopCamera();
                        setState(() {
                          _cameraActive = false;
                          _pickerOpened = false;
                        });
                        _pickImage(ImageSource.gallery);
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.photo_library, color: Colors.white, size: 20),
                      ),
                    ),
                    // Capture button
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    // Spacer to balance layout
                    const SizedBox(width: 40, height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
            onPressed: _startCamera,
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
