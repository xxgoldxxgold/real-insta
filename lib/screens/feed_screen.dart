import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/logo_text.dart';
import '../widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Post> _posts = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await PostService.getFeed();
      if (mounted) {
        setState(() {
          _posts.clear();
          _posts.addAll(posts);
          _hasMore = posts.length >= 20;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    _loadingMore = true;
    try {
      final posts = await PostService.getFeed(offset: _posts.length);
      if (mounted) {
        setState(() {
          _posts.addAll(posts);
          _hasMore = posts.length >= 20;
        });
      }
    } catch (_) {}
    _loadingMore = false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const LogoText(fontSize: 24),
        centerTitle: false,
        actions: [
          // Heart notification icon - Instagram style
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border, size: 28),
                onPressed: () {},
              ),
              if (appState.unreadNotifications > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.like, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${appState.unreadNotifications}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Messenger icon - Instagram style
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.send_outlined, size: 26),
                onPressed: () => context.push('/inbox'),
              ),
              if (appState.unreadMessages > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: AppColors.like, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${appState.unreadMessages}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.text, width: 2),
                        ),
                        child: const Icon(Icons.photo_camera_outlined, size: 40, color: AppColors.text),
                      ),
                      const SizedBox(height: 20),
                      const Text('フィードに投稿がありません', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
                      const SizedBox(height: 8),
                      const Text('ユーザーをフォローして投稿を見よう', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return PostCard(post: _posts[index]);
                    },
                  ),
                ),
    );
  }
}
