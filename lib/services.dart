import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:js_interop';
import 'models.dart';

final supabase = Supabase.instance.client;

@JS('window._isInAppBrowser')
external bool? get _jsIsInAppBrowser;

bool get isInAppBrowser {
  if (!kIsWeb) return false;
  try {
    return _jsIsInAppBrowser ?? false;
  } catch (_) {
    return false;
  }
}

class AuthService {
  static User? get currentUser => supabase.auth.currentUser;
  static String? get userId => currentUser?.id;
  static Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  static Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _redirectUrl,
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
    final posts = <Post>[];
    for (final json in data) {
      final postId = json['id'] as String;
      final likesResult = await supabase.from('ri_likes').select('id').eq('post_id', postId).count(CountOption.exact);
      final commentsResult = await supabase.from('ri_comments').select('id').eq('post_id', postId).count(CountOption.exact);
      Map<String, dynamic>? likeCheck;
      if (currentUserId != null) {
        likeCheck = await supabase.from('ri_likes').select('id').eq('post_id', postId).eq('user_id', currentUserId).maybeSingle();
      }
      posts.add(Post.fromJson(
        json,
        likes: likesResult.count,
        comments: commentsResult.count,
        liked: likeCheck != null,
      ));
    }
    return posts;
  }

  static Future<Post> createPost({required Uint8List imageBytes, required String ext, String? caption, String? locationName}) async {
    final uid = AuthService.userId!;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
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

  static Future<void> deletePost(String postId) async {
    await supabase.from('ri_posts').delete().eq('id', postId);
  }

  static Future<bool> toggleLike(String postId) async {
    final uid = AuthService.userId!;
    final existing = await supabase.from('ri_likes').select('id').eq('post_id', postId).eq('user_id', uid).maybeSingle();
    if (existing != null) {
      await supabase.from('ri_likes').delete().eq('id', existing['id']);
      return false;
    } else {
      await supabase.from('ri_likes').insert({'user_id': uid, 'post_id': postId});
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

  static Future<Comment> addComment(String postId, String content) async {
    final data = await supabase.from('ri_comments').insert({
      'user_id': AuthService.userId!,
      'post_id': postId,
      'content': content,
    }).select('*, ri_profiles!inner(*)').single();
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

    final conversations = <Conversation>[];
    for (final json in (data as List)) {
      final conv = Conversation.fromJson(json);
      final otherId = conv.user1Id == uid ? conv.user2Id : conv.user1Id;
      conv.otherUser = await ProfileService.getProfile(otherId);

      final unread = await supabase
          .from('ri_messages')
          .select('id')
          .eq('conversation_id', conv.id)
          .neq('sender_id', uid)
          .eq('is_read', false)
          .count(CountOption.exact);
      conv.unreadCount = unread.count;
      conversations.add(conv);
    }
    return conversations;
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

  static Future<Message> sendMessage(String conversationId, String content) async {
    final data = await supabase.from('ri_messages').insert({
      'conversation_id': conversationId,
      'sender_id': AuthService.userId!,
      'content': content,
    }).select().single();
    return Message.fromJson(data);
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
}

class HashtagService {
  static Future<List<Map<String, dynamic>>> searchHashtags(String query) async {
    final data = await supabase
        .from('ri_hashtags')
        .select('name')
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
