import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../services.dart';
import 'feed_screen.dart';
import 'explore_screen.dart';
import 'camera_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    context.read<AppState>().refreshBadges();
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
    final appState = context.watch<AppState>();
    final uid = AuthService.userId!;

    final screens = [
      const FeedScreen(),
      const ExploreScreen(),
      const CameraScreen(),
      const NotificationsScreen(),
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
          onTap: (i) => setState(() => _currentIndex = i),
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
            const BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), activeIcon: Icon(Icons.add_box), label: '投稿'),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: appState.unreadNotifications > 0,
                label: Text('${appState.unreadNotifications}', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.favorite_border),
              ),
              activeIcon: Badge(
                isLabelVisible: appState.unreadNotifications > 0,
                label: Text('${appState.unreadNotifications}', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.favorite),
              ),
              label: '通知',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'プロフ'),
          ],
        ),
      ),
    );
  }
}
