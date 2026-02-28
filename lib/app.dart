import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'services.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/post_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/hashtag_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/thread_screen.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier() {
    _sub = AuthService.authStateChanges.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = AuthNotifier();

class AppState extends ChangeNotifier {
  int unreadNotifications = 0;
  int unreadMessages = 0;

  void setUnreadNotifications(int count) {
    unreadNotifications = count;
    notifyListeners();
  }

  void setUnreadMessages(int count) {
    unreadMessages = count;
    notifyListeners();
  }

  Future<void> refreshBadges() async {
    if (AuthService.userId == null) return;
    try {
      final results = await Future.wait([
        NotificationService.getUnreadCount(),
        DMService.getTotalUnreadCount(),
      ]);
      unreadNotifications = results[0];
      unreadMessages = results[1];
      notifyListeners();
    } catch (_) {}
  }
}

class RealInstaApp extends StatelessWidget {
  const RealInstaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp.router(
        title: 'Real Insta',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.bg,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.text,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.accent,
            surface: AppColors.bg,
          ),
          dividerColor: AppColors.border,
          fontFamily: '-apple-system',
        ),
        routerConfig: _router,
      ),
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  refreshListenable: _authNotifier,
  redirect: (context, state) {
    final loggedIn = AuthService.currentUser != null;
    final loggingIn = state.matchedLocation == '/login';

    if (!loggedIn && !loggingIn) return '/login';
    if (loggedIn && loggingIn) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/post/:id', builder: (_, state) => PostDetailScreen(postId: state.pathParameters['id']!)),
    GoRoute(path: '/profile/:id', builder: (_, state) => ProfileScreen(userId: state.pathParameters['id']!)),
    GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/hashtag/:tag', builder: (_, state) => HashtagScreen(tag: state.pathParameters['tag']!)),
    GoRoute(path: '/inbox', builder: (_, __) => const InboxScreen()),
    GoRoute(path: '/thread/:conversationId', builder: (_, state) => ThreadScreen(conversationId: state.pathParameters['conversationId']!)),
  ],
);
