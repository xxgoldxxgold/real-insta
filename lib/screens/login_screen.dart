import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../constants.dart';
import '../services.dart';
import '../widgets/logo_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _loading = false;
  String? _error;
  final bool _inApp = isInAppBrowser;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    setState(() { _loading = true; _error = null; });
    try {
      if (_isLogin) {
        await AuthService.signInWithEmail(email, password);
      } else {
        await AuthService.signUpWithEmail(email, password);
      }
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showOpenBrowserDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ブラウザで開く', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: const Text(
          'Googleログインはアプリ内ブラウザでは利用できません。\n\nSafari・Chromeで real-insta.com を開いてログインしてください。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: 'https://real-insta.com'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URLをコピーしました'), duration: Duration(seconds: 2)),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('URLをコピー'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      const LogoText(fontSize: 40),
                      const SizedBox(height: 32),
                      // Email field - Instagram style
                      _buildInputField(
                        controller: _emailController,
                        hint: 'メールアドレス',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      _buildInputField(
                        controller: _passwordController,
                        hint: 'パスワード',
                        obscure: true,
                        onSubmitted: (_) => _handleEmailAuth(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      const SizedBox(height: 16),
                      // Login button - Instagram blue
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleEmailAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(_isLogin ? 'ログイン' : '新規登録', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // OR divider - Instagram style
                      Row(
                        children: [
                          Expanded(child: Container(height: 1, color: AppColors.border)),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('または', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(child: Container(height: 1, color: AppColors.border)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Google login
                      _buildSocialButton(
                        icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.accent)),
                        label: 'Googleでログイン',
                        onTap: () async {
                          if (_inApp) { _showOpenBrowserDialog(); return; }
                          setState(() { _loading = true; _error = null; });
                          try {
                            await AuthService.signInWithGoogle();
                            if (mounted) context.go('/');
                          } catch (e) {
                            if (mounted) setState(() => _error = e.toString());
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      // Apple login
                      _buildSocialButton(
                        icon: const Icon(Icons.apple, size: 22, color: AppColors.text),
                        label: 'Appleでログイン',
                        onTap: () async {
                          setState(() { _loading = true; _error = null; });
                          try {
                            await AuthService.signInWithApple();
                          } catch (e) {
                            if (mounted) setState(() => _error = e.toString());
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom signup link - Instagram style with border
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'アカウントをお持ちでないですか？ ' : 'すでにアカウントをお持ちですか？ ',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? '登録する' : 'ログイン',
                      style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    bool obscure = false,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required Widget icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: TextButton(
        onPressed: _loading ? null : onTap,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
