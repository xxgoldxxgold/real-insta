import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../app.dart';
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/user_avatar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notifications = await NotificationService.getNotifications();
      await NotificationService.markAllRead();
      if (mounted) {
        context.read<AppState>().setUnreadNotifications(0);
        setState(() { _notifications = notifications; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('アクティビティ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('通知はありません', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return _buildNotificationItem(n);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationItem(AppNotification n) {
    String text;
    switch (n.type) {
      case 'like':
        text = 'あなたの投稿にいいね！しました';
        break;
      case 'comment':
        text = 'あなたの投稿にコメントしました';
        break;
      case 'follow':
        text = 'あなたをフォローしました';
        break;
      default:
        text = '';
    }

    return ListTile(
      leading: UserAvatar(
        url: n.actor?.avatarUrl,
        size: 44,
        onTap: () => context.push('/profile/${n.actorId}'),
      ),
      title: RichText(
        text: TextSpan(
          style: const TextStyle(color: AppColors.text, fontSize: 14),
          children: [
            TextSpan(
              text: n.actor?.username ?? n.actor?.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' $text'),
          ],
        ),
      ),
      subtitle: Text(
        timeago.format(n.createdAt, locale: 'ja'),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
      ),
      trailing: n.isRead ? null : Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
      ),
      onTap: () {
        if (n.postId != null) {
          context.push('/post/${n.postId}');
        } else {
          context.push('/profile/${n.actorId}');
        }
      },
    );
  }
}
