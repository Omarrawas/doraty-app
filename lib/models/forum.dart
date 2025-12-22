class ForumPost {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String courseId;
  final String courseName;
  final DateTime createdAt;
  final int likesCount;
  final int repliesCount;
  final bool isPinned;
  final bool isSolved;
  final List<String> tags;

  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.courseId,
    required this.courseName,
    required this.createdAt,
    this.likesCount = 0,
    this.repliesCount = 0,
    this.isPinned = false,
    this.isSolved = false,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'courseId': courseId,
      'courseName': courseName,
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'repliesCount': repliesCount,
      'isPinned': isPinned,
      'isSolved': isSolved,
      'tags': tags,
    };
  }

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      authorId: json['user_id'],
      authorName: json['users'] != null ? json['users']['full_name'] : 'مستخدم',
      authorPhoto: json['users'] != null ? json['users']['avatar_url'] : null,
      courseId: json['course_id'],
      courseName: json['courses'] != null ? json['courses']['title'] : '',
      createdAt: DateTime.parse(json['created_at']),
      likesCount: json['likes_count'] ?? 0,
      repliesCount: json['replies_count'] ?? 0,
      isPinned: json['is_pinned'] ?? false,
      isSolved: json['is_solved'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class ForumReply {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final DateTime createdAt;
  final int likesCount;
  final bool isAccepted;
  final bool isByInstructor;

  ForumReply({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.createdAt,
    this.likesCount = 0,
    this.isAccepted = false,
    this.isByInstructor = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'isAccepted': isAccepted,
      'isByInstructor': isByInstructor,
    };
  }

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
      id: json['id'],
      postId: json['post_id'],
      content: json['content'],
      authorId: json['user_id'],
      authorName: json['users'] != null ? json['users']['full_name'] : 'مستخدم',
      authorPhoto: json['users'] != null ? json['users']['avatar_url'] : null,
      createdAt: DateTime.parse(json['created_at']),
      likesCount: json['likes_count'] ?? 0,
      isAccepted: json['is_accepted'] ?? false,
      isByInstructor: json['is_by_instructor'] ?? false,
    );
  }
}
