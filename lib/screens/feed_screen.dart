import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../constants.dart';
import '../models.dart';
import '../services.dart';
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
        title: const Text('Real-Insta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          Badge(
            isLabelVisible: appState.unreadMessages > 0,
            label: Text('${appState.unreadMessages}', style: const TextStyle(fontSize: 10)),
            child: IconButton(
              icon: const Icon(Icons.send_outlined),
              onPressed: () => context.push('/inbox'),
            ),
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
                      const Icon(Icons.photo_camera_outlined, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      const Text('フィードに投稿がありません', style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      const Text('ユーザーをフォローして投稿を見よう', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
