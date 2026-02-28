import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/post_card.dart';
import '../widgets/user_avatar.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  List<Comment> _comments = [];
  final _commentController = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        PostService.getPost(widget.postId),
        CommentService.getComments(widget.postId),
      ]);
      if (mounted) {
        setState(() {
          _post = results[0] as Post?;
          _comments = results[1] as List<Comment>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment = await CommentService.addComment(widget.postId, text);
      if (mounted) {
        setState(() {
          _comments.add(comment);
          _commentController.clear();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('エラー: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_post == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('投稿が見つかりません')));

    return Scaffold(
      appBar: AppBar(title: const Text('投稿')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  PostCard(post: _post!),
                  const Divider(height: 1),
                  // Comments
                  ..._comments.map((c) => _buildComment(c)),
                  if (_comments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('まだコメントはありません', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
          ),
          // Comment input
          Container(
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'コメントを追加...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
                TextButton(
                  onPressed: _sending ? null : _sendComment,
                  child: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('投稿', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(Comment c) {
    final canDelete = c.userId == AuthService.userId || _post?.userId == AuthService.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            url: c.author?.avatarUrl,
            size: 32,
            onTap: () => context.push('/profile/${c.userId}'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: AppColors.text, fontSize: 13),
                    children: [
                      TextSpan(
                        text: '${c.author?.username ?? ""} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: c.content),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(c.createdAt, locale: 'ja'),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (canDelete)
            GestureDetector(
              onTap: () async {
                await CommentService.deleteComment(c.id);
                setState(() => _comments.remove(c));
              },
              child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
