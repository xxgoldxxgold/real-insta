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
      margin: const EdgeInsets.only(bottom: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                UserAvatar(
                  url: author?.avatarUrl,
                  size: 32,
                  onTap: () => context.push('/profile/${post.userId}'),
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
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ),
                if (post.userId == AuthService.userId)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await PostService.deletePost(post.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: Text('削除', style: TextStyle(color: Colors.red))),
                    ],
                  ),
              ],
            ),
          ),
          // Image
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
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? AppColors.like : AppColors.text,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () => context.push('/post/${post.id}'),
                  child: const Icon(Icons.chat_bubble_outline, size: 22),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: () => context.push('/post/${post.id}'),
                  child: const Icon(Icons.send_outlined, size: 22),
                ),
              ],
            ),
          ),
          // Likes count
          if (_likesCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('いいね！$_likesCount件', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          // Caption
          if (post.caption != null && post.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: _buildCaption(context, author?.username ?? '', post.caption!),
            ),
          // Comments link
          if (post.commentsCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
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
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Text(
              timeago.format(post.createdAt, locale: 'ja'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
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
