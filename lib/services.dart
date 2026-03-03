import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'models.dart';

final supabase = Supabase.instance.client;

@JS('navigator.userAgent')
external JSString get _jsUserAgent;

bool get isInAppBrowser {
  if (!kIsWeb) return false;
  try {
    final ua = _jsUserAgent.toDart;
    return RegExp(r'Line/|FBAV/|FBAN/|Instagram|Twitter|MicroMessenger', caseSensitive: false).hasMatch(ua);
  } catch (_) {
    return false;
  }
}

/// Fire-and-forget push notification for likes, comments, follows
void _sendActivityPush({
  required String type,
  required String receiverId,
  String? postId,
  String? commentText,
}) {
  try {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) return;
    final profile = supabase.auth.currentUser?.userMetadata;
    final actorName = profile?['display_name']?.toString() ??
        profile?['full_name']?.toString() ??
        profile?['name']?.toString() ??
        'Someone';
    final xhr = html.HttpRequest();
    xhr.open('POST', 'https://real-insta.com/api/notify-activity.php');
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('Authorization', 'Bearer $token');
    xhr.send(jsonEncode({
      'type': type,
      'receiver_id': receiverId,
      'actor_name': actorName,
      'post_id': postId ?? '',
      'comment_text': commentText ?? '',
    }));
  } catch (_) {}
}

class AuthService {
  static User? get currentUser => supabase.auth.currentUser;
  static String? get userId => currentUser?.id;
  static Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  static Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
      queryParams: {'prompt': 'select_account'},
    );
  }

  static Future<void> signInWithApple() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _redirectUrl,
    );
  }

  static Future<void> signInWithEmail(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signUpWithEmail(String email, String password) async {
    await supabase.auth.signUp(email: email, password: password);
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  static Future<void> deleteAccount() async {
    final uid = userId;
    if (uid == null) return;
    // Delete user data in order (respecting foreign keys)
    await supabase.from('ri_notifications').delete().eq('user_id', uid);
    await supabase.from('ri_notifications').delete().eq('actor_id', uid);
    await supabase.from('ri_likes').delete().eq('user_id', uid);
    await supabase.from('ri_comments').delete().eq('user_id', uid);
    await supabase.from('ri_post_hashtags').delete().inFilter(
      'post_id',
      (await supabase.from('ri_posts').select('id').eq('user_id', uid) as List)
          .map((r) => r['id'] as String).toList(),
    );
    await supabase.from('ri_posts').delete().eq('user_id', uid);
    await supabase.from('ri_follows').delete().eq('follower_id', uid);
    await supabase.from('ri_follows').delete().eq('following_id', uid);
    await supabase.from('ri_messages').delete().eq('sender_id', uid);
    await supabase.from('ri_conversations').delete().or('user1_id.eq.$uid,user2_id.eq.$uid');
    await supabase.from('ri_profiles').delete().eq('id', uid);
    await signOut();
  }

  static String get _redirectUrl {
    return 'https://real-insta.com/';
  }
}

class ProfileService {
  static Future<Profile?> getProfile(String userId) async {
    final data = await supabase.from('ri_profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    final profile = Profile.fromJson(data);
    await _loadCounts(profile);
    return profile;
  }

  static Future<void> _loadCounts(Profile profile) async {
    final results = await Future.wait([
      supabase.from('ri_posts').select('id').eq('user_id', profile.id).count(CountOption.exact),
      supabase.from('ri_follows').select('id').eq('following_id', profile.id).count(CountOption.exact),
      supabase.from('ri_follows').select('id').eq('follower_id', profile.id).count(CountOption.exact),
    ]);
    profile.postsCount = results[0].count;
    profile.followersCount = results[1].count;
    profile.followingCount = results[2].count;

    if (AuthService.userId != null && AuthService.userId != profile.id) {
      final follow = await supabase
          .from('ri_follows')
          .select('id')
          .eq('follower_id', AuthService.userId!)
          .eq('following_id', profile.id)
          .maybeSingle();
      profile.isFollowing = follow != null;
    }
  }

  static Future<Profile?> getProfileByUsername(String username) async {
    final data = await supabase.from('ri_profiles').select().eq('username', username).maybeSingle();
    if (data == null) return null;
    final profile = Profile.fromJson(data);
    await _loadCounts(profile);
    return profile;
  }

  static Future<bool> isUsernameTaken(String username) async {
    final data = await supabase.from('ri_profiles').select('id').eq('username', username).maybeSingle();
    return data != null;
  }

  static Future<void> updateProfile({String? username, String? displayName, String? bio, String? avatarUrl}) async {
    final updates = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    if (username != null) updates['username'] = username;
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    await supabase.from('ri_profiles').update(updates).eq('id', AuthService.userId!);
  }

  static Future<String> uploadAvatar(Uint8List bytes, String ext) async {
    final path = '${AuthService.userId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('ri-avatars').uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return supabase.storage.from('ri-avatars').getPublicUrl(path);
  }

  static Future<List<Profile>> searchUsers(String query) async {
    final data = await supabase
        .from('ri_profiles')
        .select()
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .limit(20);
    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }
}

class PostService {
  static Future<List<Post>> getFeed({int offset = 0, int limit = 20}) async {
    final uid = AuthService.userId!;
    // Get following IDs + self
    final followData = await supabase.from('ri_follows').select('following_id').eq('follower_id', uid);
    final followingIds = (followData as List).map((e) => e['following_id'] as String).toList();
    followingIds.add(uid);

    final data = await supabase
        .from('ri_posts')
        .select('*, ri_profiles!inner(*)')
        .inFilter('user_id', followingIds)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return _enrichPosts(data as List, uid);
  }

  static Future<List<Post>> getUserPosts(String userId, {int offset = 0, int limit = 30}) async {
    final data = await supabase
        .from('ri_posts')
        .select('*, ri_profiles!inner(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _enrichPosts(data as List, AuthService.userId);
  }

  static Future<List<Post>> getUserCameraPosts(String userId, {int offset = 0, int limit = 30}) async {
    final data = await supabase
        .from('ri_posts')
        .select('*, ri_profiles!inner(*)')
        .eq('user_id', userId)
        .like('image_url', '%/cam_%')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _enrichPosts(data as List, AuthService.userId);
  }

  static Future<List<Post>> getExplorePosts({int offset = 0, int limit = 30}) async {
    final data = await supabase
        .from('ri_posts')
        .select('*, ri_profiles!inner(*)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _enrichPosts(data as List, AuthService.userId);
  }

  static Future<Post?> getPost(String postId) async {
    final data = await supabase.from('ri_posts').select('*, ri_profiles!inner(*)').eq('id', postId).maybeSingle();
    if (data == null) return null;
    final posts = await _enrichPosts([data], AuthService.userId);
    return posts.first;
  }

  static Future<List<Post>> _enrichPosts(List data, String? currentUserId) async {
    if (data.isEmpty) return [];

    final postIds = data.map((j) => j['id'] as String).toList();

    // Batch: get all likes counts, comments counts, and user's likes in parallel
    final results = await Future.wait([
      supabase.from('ri_likes').select('post_id').inFilter('post_id', postIds),
      supabase.from('ri_comments').select('post_id').inFilter('post_id', postIds),
      if (currentUserId != null)
        supabase.from('ri_likes').select('post_id').inFilter('post_id', postIds).eq('user_id', currentUserId)
      else
        Future.value(<Map<String, dynamic>>[]),
    ]);

    // Count likes per post
    final likesMap = <String, int>{};
    for (final row in (results[0] as List)) {
      final pid = row['post_id'] as String;
      likesMap[pid] = (likesMap[pid] ?? 0) + 1;
    }

    // Count comments per post
    final commentsMap = <String, int>{};
    for (final row in (results[1] as List)) {
      final pid = row['post_id'] as String;
      commentsMap[pid] = (commentsMap[pid] ?? 0) + 1;
    }

    // User's liked posts
    final likedSet = <String>{};
    for (final row in (results[2] as List)) {
      likedSet.add(row['post_id'] as String);
    }

    return data.map((json) {
      final postId = json['id'] as String;
      return Post.fromJson(
        json,
        likes: likesMap[postId] ?? 0,
        comments: commentsMap[postId] ?? 0,
        liked: likedSet.contains(postId),
      );
    }).toList();
  }

  static Future<Post> createPost({required Uint8List imageBytes, required String ext, String? caption, String? locationName, bool fromCamera = false}) async {
    // AI image check
    await _checkImageWithAI(imageBytes, ext);

    final uid = AuthService.userId!;
    final prefix = fromCamera ? 'cam_' : '';
    final path = '$uid/$prefix${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('ri-posts').uploadBinary(path, imageBytes, fileOptions: const FileOptions(upsert: true));
    final imageUrl = supabase.storage.from('ri-posts').getPublicUrl(path);

    final data = await supabase.from('ri_posts').insert({
      'user_id': uid,
      'image_url': imageUrl,
      'caption': caption,
      'location_name': locationName,
    }).select('*, ri_profiles!inner(*)').single();

    return Post.fromJson(data);
  }

  static Future<String> _resizeForCheck(Uint8List imageBytes) async {
    final blob = html.Blob([imageBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final img = html.ImageElement();
    final completer = Completer<void>();
    img.onLoad.listen((_) => completer.complete());
    img.onError.listen((_) => completer.complete());
    img.src = url;
    await completer.future;
    html.Url.revokeObjectUrl(url);
    final w = img.naturalWidth;
    final h = img.naturalHeight;
    if (w == 0 || h == 0) return '';
    const maxSize = 1024;
    final scale = (w > h ? maxSize / w : maxSize / h).clamp(0.0, 1.0);
    final nw = (w * scale).round();
    final nh = (h * scale).round();
    final canvas = html.CanvasElement(width: nw, height: nh);
    canvas.context2D.drawImageScaled(img, 0, 0, nw, nh);
    return canvas.toDataUrl('image/jpeg', 0.8);
  }

  static Future<void> _checkImageWithAI(Uint8List imageBytes, String ext) async {
    final b64 = await _resizeForCheck(imageBytes);
    if (b64.isEmpty) return; // resize failed -> allow

    // Step 1: Send request (network errors -> allow posting)
    String responseBody = '';
    try {
      final xhr = await html.HttpRequest.request(
        'https://real-insta.com/api/check-image.php',
        method: 'POST',
        requestHeaders: {'Content-Type': 'application/json'},
        sendData: jsonEncode({'image': b64}),
      );
      responseBody = xhr.responseText ?? '';
    } catch (_) {
      return; // Network error -> fail open
    }

    if (responseBody.isEmpty) return;

    // Step 2: Parse response (parse errors -> allow posting)
    Map<String, dynamic> data;
    try {
      data = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      return; // JSON parse error -> fail open
    }

    // Step 3: Block if server says not allowed
    // This throw is OUTSIDE any try-catch — guaranteed to propagate
    if (data['allowed'] == false) {
      throw Exception('AI加工された画像は投稿できません。${data['reason'] ?? ''}');
    }

    // Delay to let XHR connection fully close before Supabase upload
    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> deletePost(String postId) async {
    await supabase.from('ri_posts').delete().eq('id', postId);
  }

  static Future<bool> toggleLike(String postId, {String? postOwnerId}) async {
    final uid = AuthService.userId!;
    final existing = await supabase.from('ri_likes').select('id').eq('post_id', postId).eq('user_id', uid).maybeSingle();
    if (existing != null) {
      await supabase.from('ri_likes').delete().eq('id', existing['id']);
      return false;
    } else {
      await supabase.from('ri_likes').insert({'user_id': uid, 'post_id': postId});
      // Push notification
      if (postOwnerId != null && postOwnerId != uid && kIsWeb) {
        _sendActivityPush(type: 'like', receiverId: postOwnerId, postId: postId);
      }
      return true;
    }
  }

  static Future<List<Post>> getHashtagPosts(String tag, {int offset = 0, int limit = 30}) async {
    final hashtagData = await supabase.from('ri_hashtags').select('id').eq('name', tag.toLowerCase()).maybeSingle();
    if (hashtagData == null) return [];
    final postHashtags = await supabase
        .from('ri_post_hashtags')
        .select('post_id')
        .eq('hashtag_id', hashtagData['id'])
        .range(offset, offset + limit - 1);
    if ((postHashtags as List).isEmpty) return [];
    final postIds = postHashtags.map((e) => e['post_id'] as String).toList();
    final data = await supabase
        .from('ri_posts')
        .select('*, ri_profiles!inner(*)')
        .inFilter('id', postIds)
        .order('created_at', ascending: false);
    return _enrichPosts(data as List, AuthService.userId);
  }
}

class CommentService {
  static Future<List<Comment>> getComments(String postId, {int offset = 0, int limit = 50}) async {
    final data = await supabase
        .from('ri_comments')
        .select('*, ri_profiles!inner(*)')
        .eq('post_id', postId)
        .order('created_at')
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => Comment.fromJson(e)).toList();
  }

  static Future<Comment> addComment(String postId, String content, {String? postOwnerId}) async {
    final uid = AuthService.userId!;
    final data = await supabase.from('ri_comments').insert({
      'user_id': uid,
      'post_id': postId,
      'content': content,
    }).select('*, ri_profiles!inner(*)').single();
    // Push notification
    if (postOwnerId != null && postOwnerId != uid && kIsWeb) {
      _sendActivityPush(type: 'comment', receiverId: postOwnerId, postId: postId, commentText: content);
    }
    return Comment.fromJson(data);
  }

  static Future<void> deleteComment(String commentId) async {
    await supabase.from('ri_comments').delete().eq('id', commentId);
  }
}

class FollowService {
  static Future<bool> toggleFollow(String targetUserId) async {
    final uid = AuthService.userId!;
    final existing = await supabase
        .from('ri_follows')
        .select('id')
        .eq('follower_id', uid)
        .eq('following_id', targetUserId)
        .maybeSingle();
    if (existing != null) {
      await supabase.from('ri_follows').delete().eq('id', existing['id']);
      return false;
    } else {
      await supabase.from('ri_follows').insert({'follower_id': uid, 'following_id': targetUserId});
      if (kIsWeb) {
        _sendActivityPush(type: 'follow', receiverId: targetUserId);
      }
      return true;
    }
  }

  static Future<List<Profile>> getFollowers(String userId) async {
    final data = await supabase
        .from('ri_follows')
        .select('follower_id, ri_profiles!ri_follows_follower_id_fkey(*)')
        .eq('following_id', userId);
    return (data as List).map((e) => Profile.fromJson(e['ri_profiles'])).toList();
  }

  static Future<List<Profile>> getFollowing(String userId) async {
    final data = await supabase
        .from('ri_follows')
        .select('following_id, ri_profiles!ri_follows_following_id_fkey(*)')
        .eq('follower_id', userId);
    return (data as List).map((e) => Profile.fromJson(e['ri_profiles'])).toList();
  }
}

class BlockService {
  static Future<void> blockUser(String targetId) async {
    await supabase.from('ri_blocks').insert({'blocker_id': AuthService.userId!, 'blocked_id': targetId});
  }

  static Future<void> unblockUser(String targetId) async {
    await supabase.from('ri_blocks').delete().eq('blocker_id', AuthService.userId!).eq('blocked_id', targetId);
  }

  static Future<List<Profile>> getBlockedUsers() async {
    final data = await supabase
        .from('ri_blocks')
        .select('blocked_id, ri_profiles!ri_blocks_blocked_id_fkey(*)')
        .eq('blocker_id', AuthService.userId!);
    return (data as List).map((e) => Profile.fromJson(e['ri_profiles'])).toList();
  }

  static Future<bool> isBlocked(String userId) async {
    final data = await supabase
        .from('ri_blocks')
        .select('id')
        .or('and(blocker_id.eq.${AuthService.userId},blocked_id.eq.$userId),and(blocker_id.eq.$userId,blocked_id.eq.${AuthService.userId})')
        .maybeSingle();
    return data != null;
  }
}

class NotificationService {
  static Future<List<AppNotification>> getNotifications({int offset = 0, int limit = 30}) async {
    final data = await supabase
        .from('ri_notifications')
        .select('*, actor:ri_profiles!ri_notifications_actor_id_fkey(*)')
        .eq('user_id', AuthService.userId!)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => AppNotification.fromJson(e)).toList();
  }

  static Future<void> markAllRead() async {
    await supabase
        .from('ri_notifications')
        .update({'is_read': true})
        .eq('user_id', AuthService.userId!)
        .eq('is_read', false);
  }

  static Future<int> getUnreadCount() async {
    final result = await supabase
        .from('ri_notifications')
        .select('id')
        .eq('user_id', AuthService.userId!)
        .eq('is_read', false)
        .count(CountOption.exact);
    return result.count;
  }
}

class ReportService {
  static Future<void> reportPost(String postId, String reason, {String? details}) async {
    await supabase.from('ri_reports').insert({
      'reporter_id': AuthService.userId!,
      'post_id': postId,
      'reason': reason,
      'details': details,
    });
  }

  static Future<void> reportUser(String userId, String reason, {String? details}) async {
    await supabase.from('ri_reports').insert({
      'reporter_id': AuthService.userId!,
      'reported_user_id': userId,
      'reason': reason,
      'details': details,
    });
  }
}

class DMService {
  static Future<List<Conversation>> getConversations() async {
    final uid = AuthService.userId!;
    final data = await supabase
        .from('ri_conversations')
        .select()
        .or('user1_id.eq.$uid,user2_id.eq.$uid')
        .order('last_message_at', ascending: false);

    final convList = (data as List).map((j) => Conversation.fromJson(j)).toList();
    if (convList.isEmpty) return convList;

    // Batch: get all other user profiles at once
    final otherIds = convList.map((c) => c.user1Id == uid ? c.user2Id : c.user1Id).toSet().toList();
    final profilesData = await supabase
        .from('ri_profiles')
        .select()
        .inFilter('id', otherIds);
    final profilesMap = <String, Profile>{};
    for (final p in (profilesData as List)) {
      final profile = Profile.fromJson(p);
      profilesMap[profile.id] = profile;
    }

    // Batch: get unread counts per conversation
    final convIds = convList.map((c) => c.id).toList();
    final unreadData = await supabase
        .from('ri_messages')
        .select('conversation_id')
        .inFilter('conversation_id', convIds)
        .neq('sender_id', uid)
        .eq('is_read', false);
    final unreadMap = <String, int>{};
    for (final row in (unreadData as List)) {
      final cid = row['conversation_id'] as String;
      unreadMap[cid] = (unreadMap[cid] ?? 0) + 1;
    }

    for (final conv in convList) {
      final otherId = conv.user1Id == uid ? conv.user2Id : conv.user1Id;
      conv.otherUser = profilesMap[otherId];
      conv.unreadCount = unreadMap[conv.id] ?? 0;
    }
    return convList;
  }

  static Future<Conversation> getOrCreateConversation(String otherUserId) async {
    final uid = AuthService.userId!;
    final id1 = uid.compareTo(otherUserId) < 0 ? uid : otherUserId;
    final id2 = uid.compareTo(otherUserId) < 0 ? otherUserId : uid;

    final existing = await supabase
        .from('ri_conversations')
        .select()
        .eq('user1_id', id1)
        .eq('user2_id', id2)
        .maybeSingle();

    if (existing != null) return Conversation.fromJson(existing);

    final data = await supabase.from('ri_conversations').insert({
      'user1_id': id1,
      'user2_id': id2,
    }).select().single();
    return Conversation.fromJson(data);
  }

  static Future<List<Message>> getMessages(String conversationId, {int offset = 0, int limit = 50}) async {
    final data = await supabase
        .from('ri_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (data as List).map((e) => Message.fromJson(e)).toList();
  }

  static Future<Message> sendMessage(String conversationId, String content, {String? receiverId, String? senderName}) async {
    final data = await supabase.from('ri_messages').insert({
      'conversation_id': conversationId,
      'sender_id': AuthService.userId!,
      'content': content,
    }).select().single();
    final msg = Message.fromJson(data);

    // Fire-and-forget push notification
    if (receiverId != null && kIsWeb) {
      _sendPushNotification(conversationId, receiverId, senderName ?? '', content);
    }

    return msg;
  }

  static void _sendPushNotification(String conversationId, String receiverId, String senderName, String content) {
    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) return;
      final xhr = html.HttpRequest();
      xhr.open('POST', 'https://real-insta.com/api/notify-dm.php');
      xhr.setRequestHeader('Content-Type', 'application/json');
      xhr.setRequestHeader('Authorization', 'Bearer $token');
      xhr.send(jsonEncode({
        'receiver_id': receiverId,
        'sender_name': senderName,
        'message_text': content,
        'conversation_id': conversationId,
      }));
    } catch (_) {}
  }

  static Future<void> markMessagesRead(String conversationId) async {
    await supabase
        .from('ri_messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', AuthService.userId!)
        .eq('is_read', false);
  }

  static Future<int> getTotalUnreadCount() async {
    final uid = AuthService.userId!;
    final convData = await supabase
        .from('ri_conversations')
        .select('id')
        .or('user1_id.eq.$uid,user2_id.eq.$uid');
    if ((convData as List).isEmpty) return 0;
    final convIds = convData.map((e) => e['id'] as String).toList();
    final result = await supabase
        .from('ri_messages')
        .select('id')
        .inFilter('conversation_id', convIds)
        .neq('sender_id', uid)
        .eq('is_read', false)
        .count(CountOption.exact);
    return result.count;
  }

  static RealtimeChannel subscribeToMessages(String conversationId, void Function(Message) onMessage) {
    return supabase.channel('messages:$conversationId').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'ri_messages',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'conversation_id', value: conversationId),
      callback: (payload) {
        onMessage(Message.fromJson(payload.newRecord));
      },
    ).subscribe();
  }

  static RealtimeChannel subscribeToAllMessages(void Function(Message) onMessage) {
    return supabase.channel('all_messages').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'ri_messages',
      callback: (payload) {
        try {
          final msg = Message.fromJson(payload.newRecord);
          onMessage(msg);
        } catch (e) {
          print('DM realtime parse error: $e, payload: ${payload.newRecord}');
        }
      },
    ).subscribe();
  }
}

class HashtagService {
  static Future<List<Map<String, dynamic>>> searchHashtags(String query) async {
    final data = await supabase
        .from('ri_hashtags')
        .select('id, name')
        .ilike('name', '%${query.toLowerCase()}%')
        .limit(20);
    // Add post count for each hashtag
    final results = <Map<String, dynamic>>[];
    for (final tag in (data as List)) {
      final count = await supabase
          .from('ri_post_hashtags')
          .select('post_id')
          .eq('hashtag_id', tag['id'] ?? '')
          .count(CountOption.exact);
      results.add({'name': tag['name'], 'count': count.count});
    }
    return results;
  }
}

class PushNotificationService {
  static const _vapidPublicKey =
      'BGGf5nZk_gEp04f7wqJ4zxFZzGkTj_5n-CPzzCj9GbfHhAw57vRb1XXDQguYPIONAgLBztERbye06JyYPnw-Lgs';

  static bool _firebaseReady = false;
  static bool _subscribed = false;
  static bool _onMessageRegistered = false;
  static StreamSubscription? _tokenRefreshSub;

  static Future<void> _ensureFirebase() async {
    if (_firebaseReady) return;
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    _firebaseReady = true;
    debugPrint('[FCM] Firebase initialized');
  }

  /// Call from initState — if permission already granted, subscribe silently
  static Future<void> initialize() async {
    if (_subscribed || !kIsWeb) return;
    try {
      if (!html.Notification.supported) {
        debugPrint('[FCM] Notification not supported');
        return;
      }
      final perm = html.Notification.permission;
      debugPrint('[FCM] Current permission: $perm');
      if (perm == 'granted') {
        await _subscribe();
      }
    } catch (e) {
      debugPrint('[FCM] Init error: $e');
    }
  }

  /// Whether we should show the permission dialog
  static bool shouldPromptPermission() {
    if (!kIsWeb) return false;
    if (!html.Notification.supported) return false;
    if (html.window.navigator.serviceWorker == null) return false;
    return html.Notification.permission == 'default';
  }

  /// Request permission then subscribe — MUST be called from user gesture (button tap)
  static Future<bool> requestPermissionAndSubscribe() async {
    if (!kIsWeb) return false;
    try {
      final permission = await html.Notification.requestPermission();
      debugPrint('[FCM] requestPermission result: $permission');
      if (permission != 'granted') return false;
      await _subscribe();
      return true;
    } catch (e) {
      debugPrint('[FCM] Permission request error: $e');
      return false;
    }
  }

  static Future<void> _subscribe() async {
    if (_subscribed) return;
    _subscribed = true;
    try {
      await _ensureFirebase();

      final messaging = FirebaseMessaging.instance;

      // Get FCM token — vapidKey is REQUIRED for web push to work
      final token = await messaging.getToken(vapidKey: _vapidPublicKey);
      debugPrint('[FCM] getToken result: ${token == null ? "null" : "${token.substring(0, 20)}..."}');
      if (token == null || token.isEmpty) {
        debugPrint('[FCM] No token received');
        _subscribed = false;
        return;
      }

      // Register token with backend
      await _registerToken(token);

      // Listen for token refresh
      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed');
        _registerToken(newToken);
      });

      // Handle notification click from service worker postMessage
      html.window.navigator.serviceWorker?.addEventListener('message', (event) {
        try {
          final me = event as html.MessageEvent;
          final data = me.data;
          if (data is Map && data['type'] == 'notification_click') {
            final url = data['url']?.toString() ?? '/';
            if (url.isNotEmpty && url != '/') {
              html.window.location.hash = url;
            }
          }
        } catch (_) {}
      });

      // Handle foreground messages — show browser notification manually
      // (data-only messages don't auto-display in foreground)
      if (!_onMessageRegistered) {
        _onMessageRegistered = true;
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('[FCM] Foreground message: ${message.data}');
          if (!html.Notification.supported) return;
          final title = message.data['title'] ?? 'Real-Insta';
          final body = message.data['body'] ?? '';
          try {
            final n = html.Notification(title, body: body, icon: '/favicon.png');
            n.onClick.listen((_) {
              try {
                html.document.documentElement?.focus();
                final url = message.data['url']?.toString();
                if (url != null && url.isNotEmpty) {
                  html.window.location.hash = url;
                }
              } catch (_) {}
            });
          } catch (_) {}
        });
      }
      debugPrint('[FCM] Subscribe complete');
    } catch (e, st) {
      debugPrint('[FCM] Subscribe error: $e\n$st');
      _subscribed = false;
    }
  }

  static Future<void> _registerToken(String fcmToken) async {
    try {
      final authToken = supabase.auth.currentSession?.accessToken;
      if (authToken == null) {
        debugPrint('[FCM] No auth token, skipping registration');
        return;
      }
      final response = await html.HttpRequest.request(
        'https://real-insta.com/api/push-subscribe.php',
        method: 'POST',
        requestHeaders: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        sendData: jsonEncode({'token': fcmToken, 'platform': 'web'}),
      );
      debugPrint('[FCM] Token registered: ${response.status} ${response.responseText}');
    } catch (e) {
      debugPrint('[FCM] Token registration error: $e');
    }
  }
}
