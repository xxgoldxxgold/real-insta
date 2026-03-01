import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import 'user_avatar.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback? onLikeChanged;

  const PostCard({super.key, required this.post, this.onLikeChanged});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _liked;
  late int _likesCount;
  bool _showHeart = false;
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likesCount = widget.post.likesCount;
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likesCount += _liked ? 1 : -1;
    });
    try {
      final result = await PostService.toggleLike(widget.post.id);
      if (result != _liked) {
        setState(() {
          _liked = result;
          _likesCount = widget.post.likesCount + (result ? 1 : 0);
        });
      }
      widget.onLikeChanged?.call();
    } catch (_) {
      setState(() {
        _liked = !_liked;
        _likesCount += _liked ? 1 : -1;
      });
    }
  }

  void _onDoubleTap() {
    if (!_liked) _toggleLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post.author;

    return Container(
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - Instagram style: avatar + username/location + three-dot menu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Avatar with story-like ring
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: UserAvatar(
                    url: author?.avatarUrl,
                    size: 32,
                    onTap: () => context.push('/profile/${post.userId}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/profile/${post.userId}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author?.username ?? author?.name ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (post.locationName != null)
                          Text(
                            post.locationName!,
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                ),
                // Three-dot menu - always visible like Instagram
                GestureDetector(
                  onTap: () => _showPostMenu(context, post),
                  child: const Icon(Icons.more_horiz, size: 20, color: AppColors.text),
                ),
              ],
            ),
          ),
          // Image - full bleed
          GestureDetector(
            onDoubleTap: _onDoubleTap,
            onTap: () => context.push('/post/${post.id}'),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.border),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.border,
                      child: const Icon(Icons.broken_image, size: 48, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                if (_showHeart)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (_, value, child) => Transform.scale(scale: value, child: child),
                    child: const Icon(Icons.favorite, color: Colors.white, size: 80),
                  ),
              ],
            ),
          ),
          // Action buttons - Instagram layout: heart comment share ... bookmark
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                _actionButton(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? AppColors.like : AppColors.text,
                  onTap: _toggleLike,
                ),
                const SizedBox(width: 16),
                _actionButton(
                  icon: Icons.chat_bubble_outline,
                  onTap: () => context.push('/post/${post.id}'),
                ),
                const SizedBox(width: 16),
                _actionButton(
                  icon: Icons.send_outlined,
                  onTap: () {},
                ),
                const Spacer(),
                _actionButton(
                  icon: _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  onTap: () => setState(() => _bookmarked = !_bookmarked),
                ),
              ],
            ),
          ),
          // Likes count
          if (_likesCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text('いいね！$_likesCount件', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          // Caption
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: _buildCaption(context, author?.username ?? '', post.caption!),
            ),
          // Comments link
          if (post.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: GestureDetector(
                onTap: () => context.push('/post/${post.id}'),
                child: Text(
                  'コメント${post.commentsCount}件をすべて見る',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ),
          // Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Text(
              timeago.format(post.createdAt, locale: 'ja'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, Color? color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 26, color: color ?? AppColors.text),
      ),
    );
  }

  void _showPostMenu(BuildContext context, Post post) {
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
            if (post.userId == AuthService.userId)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('削除', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await PostService.deletePost(post.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
                  }
                },
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('リンクをコピー'),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('シェア'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption(BuildContext context, String username, String caption) {
    final parts = <InlineSpan>[];
    parts.add(TextSpan(
      text: '$username ',
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      recognizer: null,
    ));

    final regex = RegExp(r'#([a-zA-Z0-9\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF_]+)');
    int lastEnd = 0;
    for (final match in regex.allMatches(caption)) {
      if (match.start > lastEnd) {
        parts.add(TextSpan(text: caption.substring(lastEnd, match.start)));
      }
      final tag = match.group(1)!;
      parts.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => context.push('/hashtag/$tag'),
          child: Text('#$tag', style: const TextStyle(color: AppColors.accent, fontSize: 13)),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < caption.length) {
      parts.add(TextSpan(text: caption.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.4),
        children: parts,
      ),
    );
  }
}
