import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Profile? _profile;
  List<Post> _posts = [];
  bool _loading = true;

  bool get _isMe => widget.userId == AuthService.userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ProfileService.getProfile(widget.userId),
        PostService.getUserPosts(widget.userId),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Profile?;
          _posts = results[1] as List<Post>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_profile == null) return;
    final wasFollowing = _profile!.isFollowing;
    setState(() {
      _profile!.isFollowing = !wasFollowing;
      _profile!.followersCount += wasFollowing ? -1 : 1;
    });
    try {
      await FollowService.toggleFollow(widget.userId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _profile!.isFollowing = wasFollowing;
          _profile!.followersCount += wasFollowing ? 1 : -1;
        });
      }
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isMe) ...[
              ListTile(
                leading: const Icon(Icons.message_outlined),
                title: const Text('メッセージ'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final conv = await DMService.getOrCreateConversation(widget.userId);
                  if (mounted) context.push('/thread/${conv.id}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('ブロック', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await BlockService.blockUser(widget.userId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ブロックしました')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text('通報'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('通報理由'),
        children: ['spam', 'nudity', 'harassment', 'violence', 'other'].map((reason) {
          final labels = {
            'spam': 'スパム',
            'nudity': '不適切なコンテンツ',
            'harassment': 'ハラスメント',
            'violence': '暴力',
            'other': 'その他',
          };
          return SimpleDialogOption(
            child: Text(labels[reason]!),
            onPressed: () async {
              Navigator.pop(ctx);
              await ReportService.reportUser(widget.userId, reason);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('通報しました')));
              }
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return const Scaffold(body: Center(child: Text('ユーザーが見つかりません')));

    final p = _profile!;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.username ?? p.name),
        actions: [
          if (_isMe) ...[
            IconButton(icon: const Icon(Icons.add_box_outlined), onPressed: () => context.push('/inbox')),
            IconButton(icon: const Icon(Icons.menu), onPressed: () => context.push('/settings')),
          ] else
            IconButton(icon: const Icon(Icons.more_horiz), onPressed: _showMoreMenu),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(p)),
            SliverToBoxAdapter(
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.text,
                indicatorWeight: 1,
                labelColor: AppColors.text,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on, size: 24)),
                  Tab(icon: Icon(Icons.person_pin_outlined, size: 24)),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(1),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = _posts[index];
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
                  childCount: _posts.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Profile p) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(url: p.avatarUrl, size: 86),
              const SizedBox(width: 24),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statColumn('${p.postsCount}', '投稿'),
                    _statColumn('${p.followersCount}', 'フォロワー'),
                    _statColumn('${p.followingCount}', 'フォロー中'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.displayName?.isNotEmpty == true)
            Text(p.displayName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (p.bio?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(p.bio!, style: const TextStyle(fontSize: 14)),
            ),
          const SizedBox(height: 12),
          if (_isMe)
            SizedBox(
              width: double.infinity,
              height: 34,
              child: ElevatedButton(
                onPressed: () => context.push('/edit-profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonGrey,
                  foregroundColor: AppColors.text,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('プロフィールを編集', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _toggleFollow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.isFollowing ? AppColors.card : AppColors.accent,
                      foregroundColor: p.isFollowing ? AppColors.text : Colors.white,
                      side: p.isFollowing ? const BorderSide(color: AppColors.border) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(p.isFollowing ? 'フォロー中' : 'フォロー'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () async {
                      final conv = await DMService.getOrCreateConversation(widget.userId);
                      if (mounted) context.push('/thread/${conv.id}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonGrey,
                      foregroundColor: AppColors.text,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('メッセージ', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
