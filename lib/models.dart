class Profile {
  final String id;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  int followersCount;
  int followingCount;
  int postsCount;
  bool isFollowing;

  Profile({
    required this.id,
    this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    required this.createdAt,
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    this.isFollowing = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        username: json['username'],
        displayName: json['display_name'],
        bio: json['bio'],
        avatarUrl: json['avatar_url'],
        createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      );

  String get name => displayName?.isNotEmpty == true ? displayName! : (username ?? 'User');
}

class Post {
  final String id;
  final String userId;
  final String imageUrl;
  final String? caption;
  final String? locationName;
  final DateTime createdAt;
  Profile? author;
  int likesCount;
  int commentsCount;
  bool isLiked;

  Post({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.caption,
    this.locationName,
    required this.createdAt,
    this.author,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isLiked = false,
  });

  factory Post.fromJson(Map<String, dynamic> json, {Profile? author, int likes = 0, int comments = 0, bool liked = false}) => Post(
        id: json['id'],
        userId: json['user_id'],
        imageUrl: json['image_url'],
        caption: json['caption'],
        locationName: json['location_name'],
        createdAt: DateTime.parse(json['created_at']),
        author: author ?? (json['ri_profiles'] != null ? Profile.fromJson(json['ri_profiles']) : null),
        likesCount: json['likes_count'] ?? likes,
        commentsCount: json['comments_count'] ?? comments,
        isLiked: json['is_liked'] ?? liked,
      );
}

class Comment {
  final String id;
  final String userId;
  final String postId;
  final String content;
  final DateTime createdAt;
  Profile? author;

  Comment({
    required this.id,
    required this.userId,
    required this.postId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'],
        userId: json['user_id'],
        postId: json['post_id'],
        content: json['content'],
        createdAt: DateTime.parse(json['created_at']),
        author: json['ri_profiles'] != null ? Profile.fromJson(json['ri_profiles']) : null,
      );
}

class AppNotification {
  final String id;
  final String userId;
  final String actorId;
  final String type;
  final String? postId;
  final bool isRead;
  final DateTime createdAt;
  Profile? actor;

  AppNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    this.postId,
    this.isRead = false,
    required this.createdAt,
    this.actor,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'],
        userId: json['user_id'],
        actorId: json['actor_id'],
        type: json['type'],
        postId: json['post_id'],
        isRead: json['is_read'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
        actor: json['actor'] != null ? Profile.fromJson(json['actor']) : null,
      );
}

class Conversation {
  final String id;
  final String user1Id;
  final String user2Id;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  Profile? otherUser;
  int unreadCount;

  Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessageText,
    this.lastMessageAt,
    this.otherUser,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'],
        user1Id: json['user1_id'],
        user2Id: json['user2_id'],
        lastMessageText: json['last_message_text'],
        lastMessageAt: json['last_message_at'] != null ? DateTime.parse(json['last_message_at']) : null,
      );
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'],
        conversationId: json['conversation_id'],
        senderId: json['sender_id'],
        content: json['content'],
        isRead: json['is_read'] ?? false,
        createdAt: DateTime.parse(json['created_at']),
      );
}
