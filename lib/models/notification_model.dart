enum NotificationCategory {
  newLesson,
  exam,
  reply,
  achievement,
  announcement,
  promo,
  system,
  other,
}

enum NotificationType {
  transactional,
  learning,
  social,
  engagement,
  marketing,
  unknown
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationCategory category;
  final String? imageUrl;
  final String? actionUrl;
  final DateTime time;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.category,
    this.imageUrl,
    this.actionUrl,
    required this.time,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      message: json['body'] ??
          json['message'] ??
          '', // Support both for compatibility
      type: _parseNotificationType(json['type']),
      category:
          _parseNotificationCategory(json['category'] ?? json['data']?['type']),
      imageUrl: json['image_url'],
      actionUrl: json['action_url'] ?? json['data']?['click_action'],
      time: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': message,
      'type': type.name,
      'category': category.name,
      'image_url': imageUrl,
      'action_url': actionUrl,
      'created_at': time.toIso8601String(),
      'is_read': isRead,
    };
  }

  static NotificationType _parseNotificationType(String? type) {
    if (type == null) return NotificationType.unknown;
    try {
      return NotificationType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => NotificationType.unknown,
      );
    } catch (_) {
      return NotificationType.unknown;
    }
  }

  static NotificationCategory _parseNotificationCategory(String? category) {
    if (category == null) return NotificationCategory.announcement;

    // Map legacy types or string values to Category enum
    switch (category) {
      case 'newLesson':
      case 'new_lesson':
        return NotificationCategory.newLesson;
      case 'exam':
        return NotificationCategory.exam;
      case 'reply':
        return NotificationCategory.reply;
      case 'achievement':
        return NotificationCategory.achievement;
      case 'announcement':
        return NotificationCategory.announcement;
      case 'promo':
        return NotificationCategory.promo;
      case 'system':
        return NotificationCategory.system;
      default:
        return NotificationCategory.other;
    }
  }
}
