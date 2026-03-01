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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.username ?? p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_isMe) ...[
            IconButton(icon: const Icon(Icons.add_box_outlined, size: 26), onPressed: () {}),
            IconButton(icon: const Icon(Icons.menu, size: 28), onPressed: () => context.push('/settings')),
          ] else
            IconButton(icon: const Icon(Icons.more_horiz), onPressed: _showMoreMenu),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(p)),
            // Instagram-style tab bar
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.text,
                  indicatorWeight: 1,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.text,
                  unselectedLabelColor: AppColors.textSecondary,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on, size: 26)),
                    Tab(icon: Icon(Icons.person_pin_outlined, size: 26)),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.zero,
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = _posts[index];
                    return GestureDetector(
                      onTap: () => context.push('/post/${post.id}'),
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.buttonGrey),
                        errorWidget: (_, __, ___) => Container(color: AppColors.buttonGrey),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + Stats row
          Row(
            children: [
              // Avatar with ring
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: UserAvatar(url: p.avatarUrl, size: 80),
              ),
              const SizedBox(width: 28),
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
          const SizedBox(height: 10),
          // Name + Bio
          if (p.displayName?.isNotEmpty == true)
            Text(p.displayName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          if (p.bio?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(p.bio!, style: const TextStyle(fontSize: 13)),
            ),
          const SizedBox(height: 14),
          // Action Buttons - Instagram style
          if (_isMe)
            Row(
              children: [
                Expanded(child: _greyButton('プロフィールを編集', () => context.push('/edit-profile'))),
                const SizedBox(width: 6),
                Expanded(child: _greyButton('プロフィールをシェア', () {})),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: p.isFollowing ? AppColors.buttonGrey : AppColors.accent,
                        foregroundColor: p.isFollowing ? AppColors.text : Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        p.isFollowing ? 'フォロー中' : 'フォローする',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _greyButton('メッセージ', () async {
                    final conv = await DMService.getOrCreateConversation(widget.userId);
                    if (mounted) context.push('/thread/${conv.id}');
                  }),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonGrey,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Icon(Icons.person_add_outlined, size: 16, color: AppColors.text),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _greyButton(String text, VoidCallback onTap) {
    return SizedBox(
      height: 34,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.buttonGrey,
          foregroundColor: AppColors.text,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _statColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
