import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/user_avatar.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  List<Post> _explorePosts = [];
  List<Profile> _userResults = [];
  bool _loading = true;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadExplore();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExplore() async {
    try {
      final posts = await PostService.getExplorePosts();
      if (mounted) setState(() { _explorePosts = posts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() { _query = ''; _searching = false; _userResults = []; });
      return;
    }
    setState(() { _query = query; _searching = true; });

    if (query.startsWith('#')) {
      // Hashtag search - navigate
      return;
    }

    try {
      final users = await ProfileService.searchUsers(query);
      if (mounted && _query == query) {
        setState(() { _userResults = users; _searching = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '検索',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: const Color(0xFFEFEFEF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            isDense: true,
          ),
          onChanged: _search,
          onSubmitted: (q) {
            if (q.startsWith('#') && q.length > 1) {
              context.push('/hashtag/${q.substring(1)}');
            }
          },
        ),
        toolbarHeight: 56,
      ),
      body: _query.isNotEmpty ? _buildSearchResults() : _buildExploreGrid(),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) return const Center(child: CircularProgressIndicator());
    if (_userResults.isEmpty) {
      return const Center(child: Text('結果が見つかりません', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return ListTile(
          leading: UserAvatar(url: user.avatarUrl, size: 44),
          title: Text(user.username ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(user.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          onTap: () => context.push('/profile/${user.id}'),
        );
      },
    );
  }

  Widget _buildExploreGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_explorePosts.isEmpty) {
      return const Center(child: Text('投稿がありません', style: TextStyle(color: AppColors.textSecondary)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: _explorePosts.length,
      itemBuilder: (context, index) {
        final post = _explorePosts[index];
        return GestureDetector(
          onTap: () => context.push('/post/${post.id}'),
          child: CachedNetworkImage(
            imageUrl: post.imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppColors.border),
            errorWidget: (_, __, ___) => Container(color: AppColors.border),
          ),
        );
      },
    );
  }
}
