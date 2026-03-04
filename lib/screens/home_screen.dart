import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../app.dart';
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import 'feed_screen.dart';
import 'explore_screen.dart';
import 'inbox_screen.dart';
import 'camera_screen.dart';
import 'profile_screen.dart';

@JS('eval')
external JSAny _jsEval(JSString code);

void _jsPlayBeep() {
  _jsEval('try{var c=new AudioContext(),o=c.createOscillator(),g=c.createGain();o.connect(g);g.connect(c.destination);g.gain.value=0.3;o.frequency.value=880;o.start(c.currentTime);o.stop(c.currentTime+0.15);}catch(e){}'.toJS);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _checkedOnboarding = false;
  Key _cameraKey = UniqueKey();
  RealtimeChannel? _dmChannel;
  Timer? _pollTimer;
  int _lastUnread = -1; // -1 = initial (don't notify on first load)
  bool _didPromptPush = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _initUnreadAndStartPolling();
    _subscribeToDMs();
    PushNotificationService.initialize();
    _maybePromptPushPermission();
  }

  void _maybePromptPushPermission() {
    if (_didPromptPush) return;
    if (!PushNotificationService.shouldPromptPermission()) return;
    _didPromptPush = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('通知を有効にする'),
          content: const Text('DMの新着メッセージをプッシュ通知で受け取れます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('後で'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                PushNotificationService.requestPermissionAndSubscribe();
              },
              child: const Text('許可する',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _dmChannel?.unsubscribe();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initUnreadAndStartPolling() async {
    // Get initial unread count without notifying
    try {
      final unread = await DMService.getTotalUnreadCount();
      if (!mounted) return;
      _lastUnread = unread;
      context.read<AppState>().setUnreadMessages(unread);
    } catch (_) {
      _lastUnread = 0;
    }
    // Start polling after initial load
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _pollUnread());
  }

  void _subscribeToDMs() {
    _dmChannel = DMService.subscribeToAllMessages((Message message) {
      if (!mounted) return;
      if (message.senderId == AuthService.userId) return;
      // Realtime message arrived - show notification immediately
      _showInAppNotification(message.content);
      context.read<AppState>().refreshBadges();
    });
  }

  Future<void> _pollUnread() async {
    if (!mounted) return;
    try {
      final unread = await DMService.getTotalUnreadCount();
      if (!mounted) return;
      if (unread > _lastUnread && _lastUnread >= 0) {
        _showInAppNotification('新しいメッセージがあります');
      }
      _lastUnread = unread;
      context.read<AppState>().setUnreadMessages(unread);
    } catch (_) {}
  }

  void _showInAppNotification(String text) {
    if (!mounted) return;

    // Play notification sound
    _playNotificationSound();

    // Show banner at top of screen
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: AppColors.accent,
        leading: const Icon(Icons.mail, color: Colors.white),
        content: Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).clearMaterialBanners();
              setState(() => _currentIndex = 2); // Switch to inbox tab
            },
            child: const Text('開く', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: const Text('閉じる', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        ScaffoldMessenger.of(context).clearMaterialBanners();
      }
    });

    // Also try browser notification (works on desktop, not iOS)
    _tryBrowserNotification(text);
  }

  void _playNotificationSound() {
    try {
      _jsPlayBeep();
    } catch (_) {}
  }

  void _tryBrowserNotification(String body) {
    try {
      if (html.Notification.permission == 'granted') {
        html.Notification('Real-Insta', body: body, icon: 'favicon.png');
      }
    } catch (_) {}
  }

  Future<void> _checkOnboarding() async {
    if (_checkedOnboarding) return;
    _checkedOnboarding = true;
    final profile = await ProfileService.getProfile(AuthService.userId!);
    if (profile?.username == null || profile!.username!.isEmpty) {
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auth guard: if user logged out, redirect to login
    final uid = AuthService.userId;
    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final appState = context.watch<AppState>();
    if (appState.requestedTab != null) {
      _currentIndex = appState.requestedTab!;
      appState.requestedTab = null;
    }

    final screens = [
      const FeedScreen(),
      const ExploreScreen(),
      const InboxScreen(),
      _currentIndex == 3
          ? CameraScreen(key: _cameraKey, isActive: true)
          : const SizedBox.shrink(),
      ProfileScreen(userId: uid),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            if (i == 3 && _currentIndex == 3) {
              setState(() => _cameraKey = UniqueKey());
            } else {
              setState(() => _currentIndex = i);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.card,
          selectedItemColor: AppColors.text,
          unselectedItemColor: AppColors.textSecondary,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          iconSize: 28,
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'ホーム'),
            const BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: '検索'),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: appState.unreadMessages > 0,
                label: Text('${appState.unreadMessages}', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.send_outlined, size: 26),
              ),
              activeIcon: Badge(
                isLabelVisible: appState.unreadMessages > 0,
                label: Text('${appState.unreadMessages}', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.send, size: 26),
              ),
              label: 'DM',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), activeIcon: Icon(Icons.add_box), label: '投稿'),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'プロフ'),
          ],
        ),
      ),
    );
  }
}
