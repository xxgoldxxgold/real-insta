import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../constants.dart';
import '../models.dart';
import '../services.dart';
import '../widgets/user_avatar.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<Conversation> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final conversations = await DMService.getConversations();
      if (mounted) setState(() { _conversations = conversations; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メッセージ')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(child: Text('メッセージはありません', style: TextStyle(color: AppColors.textSecondary)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final conv = _conversations[index];
                      final other = conv.otherUser;
                      return ListTile(
                        leading: UserAvatar(url: other?.avatarUrl, size: 56),
                        title: Text(
                          other?.username ?? other?.name ?? '',
                          style: TextStyle(
                            fontWeight: conv.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: conv.lastMessageText != null
                            ? Text(
                                conv.lastMessageText!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: conv.unreadCount > 0 ? AppColors.text : AppColors.textSecondary,
                                  fontWeight: conv.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              )
                            : null,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (conv.lastMessageAt != null)
                              Text(
                                timeago.format(conv.lastMessageAt!, locale: 'ja'),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            if (conv.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${conv.unreadCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                        ),
                        onTap: () async {
                          await context.push('/thread/${conv.id}');
                          _load(); // Refresh on return
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
