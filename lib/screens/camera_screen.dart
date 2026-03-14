import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../services.dart';

class CameraScreen extends StatefulWidget {
  final bool isActive;
  const CameraScreen({super.key, this.isActive = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  Uint8List? _imageBytes;

  final _captionController = TextEditingController();
  final _locationController = TextEditingController();
  final _transformController = TransformationController();
  bool _posting = false;
  bool _fromCamera = false;

  // Aspect ratio state
  double _aspectRatio = 1.0;
  bool _isOriginalRatio = false;
  int _naturalW = 0;
  int _naturalH = 0;
  double _vpW = 0;
  double _vpH = 0;

  // Camera state
  bool _cameraActive = false;
  html.VideoElement? _video;
  html.MediaStream? _mediaStream;
  bool _facingUser = false;
  String _viewId = '';
  static int _viewCounter = 0;

  @override
  void dispose() {
    _captionController.dispose();
    _locationController.dispose();
    _transformController.dispose();
    _stopCamera();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1080, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;

      _fromCamera = source == ImageSource.camera;
      _aspectRatio = 1.0;
      _isOriginalRatio = false;
      _transformController.value = Matrix4.identity();
    });
    _loadImageDimensions(bytes);
  }

  Future<void> _loadImageDimensions(Uint8List bytes) async {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement();
    final c = Completer<void>();
    img.onLoad.listen((_) => c.complete());
    img.onError.listen((_) => c.complete());
    img.src = url;
    await c.future;
    html.Url.revokeObjectUrl(url);
    if (mounted) {
      setState(() {
        _naturalW = img.naturalWidth;
        _naturalH = img.naturalHeight;
      });
    }
  }

  void _toggleAspectRatio() {
    setState(() {
      if (_isOriginalRatio) {
        _aspectRatio = 1.0;
        _isOriginalRatio = false;
      } else {
        if (_naturalW > 0 && _naturalH > 0) {
          double ratio = _naturalW / _naturalH;
          ratio = ratio.clamp(4.0 / 5.0, 1.91);
          _aspectRatio = ratio;
        }
        _isOriginalRatio = true;
      }
      _transformController.value = Matrix4.identity();
    });
  }

  Future<void> _startCamera() async {
    try {
      final facing = _facingUser ? 'user' : 'environment';
      final mirror = _facingUser ? 'scaleX(-1)' : 'none';

      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) throw Exception('mediaDevices not supported');

      final stream = await mediaDevices.getUserMedia({
        'video': {'facingMode': facing, 'width': {'ideal': 1080}, 'height': {'ideal': 1080}},
        'audio': false,
      });

      final video = html.VideoElement()
        ..setAttribute('playsinline', 'true')
        ..setAttribute('autoplay', 'true')
        ..muted = true
        ..style.cssText = 'width:100%;height:100%;object-fit:cover;transform:$mirror;background:black;';

      video.srcObject = stream;
      _video = video;
      _mediaStream = stream;

      _viewCounter++;
      _viewId = 'ri-camera-view-$_viewCounter';
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) => video);

      if (mounted) setState(() => _cameraActive = true);

      await Future.delayed(const Duration(milliseconds: 100));
      await video.play();
    } catch (e) {
      _video = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('カメラエラー: $e'), duration: const Duration(seconds: 5)),
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

        _fromCamera = true;
        _cameraActive = false;
        _aspectRatio = 1.0;
        _isOriginalRatio = false;
        _transformController.value = Matrix4.identity();
      });
      _loadImageDimensions(Uint8List.fromList(bytes));
    }
  }

  void _stopCamera() {
    try {
      final stream = _mediaStream;
      if (stream != null) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        _mediaStream = null;
      }
    } catch (_) {}
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

  Future<Uint8List> _getCroppedImage() async {
    final blob = html.Blob([_imageBytes!]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement();
    final completer = Completer<void>();
    img.onLoad.listen((_) => completer.complete());
    img.onError.listen((_) => completer.complete());
    img.src = url;
    await completer.future;
    html.Url.revokeObjectUrl(url);

    final imgW = img.naturalWidth.toDouble();
    final imgH = img.naturalHeight.toDouble();
    if (imgW == 0 || imgH == 0) return _imageBytes!;

    final vpW = _vpW;
    final vpH = _vpH;
    if (vpW <= 0 || vpH <= 0) return _imageBytes!;

    final cs = (vpW / imgW > vpH / imgH) ? vpW / imgW : vpH / imgH;
    final dispW = imgW * cs;
    final dispH = imgH * cs;
    final offX = (vpW - dispW) / 2;
    final offY = (vpH - dispH) / 2;

    final m = _transformController.value;
    final zoom = m.getMaxScaleOnAxis();
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);

    var srcX = (-tx / zoom - offX) / cs;
    var srcY = (-ty / zoom - offY) / cs;
    var srcW = vpW / zoom / cs;
    var srcH = vpH / zoom / cs;

    if (srcX < 0) { srcW += srcX; srcX = 0; }
    if (srcY < 0) { srcH += srcY; srcY = 0; }
    if (srcX + srcW > imgW) srcW = imgW - srcX;
    if (srcY + srcH > imgH) srcH = imgH - srcY;
    if (srcW < 1 || srcH < 1) return _imageBytes!;

    const outW = 1080;
    final outH = (outW / _aspectRatio).round().clamp(1, 1350);

    final canvas = html.CanvasElement(width: outW, height: outH);
    canvas.context2D.drawImageScaledFromSource(
      img, srcX, srcY, srcW, srcH,
      0, 0, outW.toDouble(), outH.toDouble(),
    );

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final b64 = dataUrl.split(',').last;
    return Uint8List.fromList(base64Decode(b64));
  }

  Future<void> _post() async {
    if (_imageBytes == null) return;
    setState(() => _posting = true);
    try {
      final croppedBytes = await _getCroppedImage();
      await PostService.createPost(
        imageBytes: croppedBytes,
        ext: 'jpg',
        caption: _captionController.text.isNotEmpty ? _captionController.text : null,
        locationName: _locationController.text.isNotEmpty ? _locationController.text : null,
        fromCamera: _fromCamera,
      );
      if (mounted) {
        context.read<AppState>().requestFeedRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿しました！')));
        setState(() {
          _imageBytes = null;
          _captionController.clear();
          _locationController.clear();
        });
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        final isAiBlock = e.toString().contains('AI加工');
        final msg = isAiBlock
            ? 'AI加工・AI生成された画像は投稿できません'
            : 'エラー: $e';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: isAiBlock ? Colors.red.shade700 : null,
          duration: const Duration(seconds: 4),
        ));
        if (isAiBlock) {
          setState(() { _imageBytes = null; });
        }
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraActive) return _buildCameraUI();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E7EB)),
        ),
        title: const Text('新規投稿', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        actions: [
          if (_imageBytes != null)
            TextButton(
              onPressed: _posting ? null : _post,
              child: _posting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('シェア', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600, fontSize: 16)),
            ),
        ],
      ),
      body: _imageBytes == null ? _buildPicker() : _buildEditor(),
    );
  }

  Widget _buildCameraUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // カメラ映像エリア
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: HtmlElementView(viewType: _viewId),
                ),

                // 上部コントロール
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _controlButton(
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                            onTap: () { _stopCamera(); if (mounted) setState(() => _cameraActive = false); },
                          ),
                          _controlButton(
                            child: CustomPaint(
                              size: const Size(20, 20),
                              painter: _FlipIconPainter(),
                            ),
                            onTap: _flipCamera,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 下部コントロールバー
          SafeArea(
            top: false,
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.only(top: 20, bottom: 24, left: 24, right: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ギャラリーボタン
                  GestureDetector(
                    onTap: () {
                      _stopCamera();
                      if (mounted) {
                        setState(() { _cameraActive = false; });
                        _pickImage(ImageSource.gallery);
                      }
                    },
                    child: Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: CustomPaint(
                        size: const Size(22, 22),
                        painter: _GalleryIconPainter(),
                      ),
                    ),
                  ),

                  // シャッターボタン
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 58, height: 58,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // スペーサー
                  const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildPicker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // カメラアイコン（Next.js版と同じSVG風デザイン）
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB), width: 2),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(40, 40),
                painter: _CameraIconPainter(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '写真を撮ってシェアしよう',
            style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 208,
            height: 44,
            child: ElevatedButton(
              onPressed: _startCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0095F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('カメラを起動', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _pickImage(ImageSource.gallery),
            child: const Text('ライブラリから選択', style: TextStyle(color: Color(0xFF0095F6), fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // プレビュー画像（Next.js版と同じ正方形・黒背景）
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = w / _aspectRatio;
              _vpW = w;
              _vpH = h;
              return Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: w,
                      height: h,
                      child: ClipRect(
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 1.0,
                          maxScale: 5.0,
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12, bottom: 12,
                      child: GestureDetector(
                        onTap: _toggleAspectRatio,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            _isOriginalRatio ? Icons.crop_square : Icons.fullscreen,
                            color: Colors.white, size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // キャプション入力（Next.js版と同じスタイル）
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _captionController,
                maxLines: 3,
                maxLength: 300,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'キャプションを入力...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                  counterText: '',
                ),
              ),
            ),
          ),
          // 場所を追加
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _locationController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '場所を追加',
                hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          // 別の写真を選ぶ
          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () => setState(() {
                _imageBytes = null;
              }),
              child: const Text(
                '別の写真を選ぶ',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Next.js版のSVGカメラアイコンを再現
class _CameraIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.width / 24;

    // カメラボディ
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(1 * s, 6 * s, 22 * s, 15 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(body, paint);

    // レンズ部分の台形（上部）
    final path = Path()
      ..moveTo(8 * s, 6 * s)
      ..lineTo(10 * s, 3 * s)
      ..lineTo(14 * s, 3 * s)
      ..lineTo(16 * s, 6 * s);
    canvas.drawPath(path, paint);

    // レンズ（円）
    canvas.drawCircle(Offset(12 * s, 13 * s), 4 * s, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Next.js版のフリップアイコンを再現
class _FlipIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.width / 24;

    final path = Path()
      ..moveTo(16 * s, 3 * s)
      ..lineTo(21 * s, 3 * s)
      ..lineTo(21 * s, 8 * s);
    canvas.drawPath(path, paint);

    final path2 = Path()
      ..moveTo(4 * s, 20 * s)
      ..lineTo(21 * s, 3 * s);
    canvas.drawPath(path2, paint);

    final path3 = Path()
      ..moveTo(8 * s, 21 * s)
      ..lineTo(3 * s, 21 * s)
      ..lineTo(3 * s, 16 * s);
    canvas.drawPath(path3, paint);

    final path4 = Path()
      ..moveTo(20 * s, 4 * s)
      ..lineTo(3 * s, 21 * s);
    canvas.drawPath(path4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Next.js版のギャラリーアイコンを再現
class _GalleryIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final s = size.width / 24;
    // オフセットで中央に
    final ox = (size.width - 22 * s) / 2;
    final oy = (size.height - 22 * s) / 2;

    // 外枠
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(ox + 3 * s, oy + 3 * s, 18 * s, 18 * s),
      Radius.circular(2 * s),
    );
    canvas.drawRRect(rect, paint);

    // 太陽（丸）
    canvas.drawCircle(Offset(ox + 8.5 * s, oy + 8.5 * s), 1.5 * s, paint);

    // 山（ポリライン）
    final path = Path()
      ..moveTo(ox + 21 * s, oy + 15 * s)
      ..lineTo(ox + 16 * s, oy + 10 * s)
      ..lineTo(ox + 5 * s, oy + 21 * s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
