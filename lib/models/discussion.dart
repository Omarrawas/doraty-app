class DiscussionThread {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String courseId;
  final String title;
  final String content;
  final DateTime createdAt;
  final int repliesCount;

  DiscussionThread({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.courseId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.repliesCount = 0,
  });

  factory DiscussionThread.fromJson(Map<String, dynamic> json) {
    return DiscussionThread(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['users']?['full_name'] ?? 'طالب',
      userAvatar: json['users']?['avatar_url'],
      courseId: json['course_id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      repliesCount: json['replies_count'] ?? 0,
    );
  }
}

class DiscussionReply {
  final String id;
  final String threadId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String content;
  final DateTime createdAt;

  DiscussionReply({
    required this.id,
    required this.threadId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.content,
    required this.createdAt,
  });

  factory DiscussionReply.fromJson(Map<String, dynamic> json) {
    return DiscussionReply(
      id: json['id'] ?? '',
      threadId: json['thread_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['users']?['full_name'] ?? 'طالب',
      userAvatar: json['users']?['avatar_url'],
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }
}
