enum NotificationType {
  newLesson,
  exam,
  reply,
  achievement,
  announcement,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime time;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.time,
    required this.isRead,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: _parseNotificationType(json['type']),
      time: DateTime.parse(json['created_at']),
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'created_at': time.toIso8601String(),
      'is_read': isRead,
    };
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'newLesson':
        return NotificationType.newLesson;
      case 'exam':
        return NotificationType.exam;
      case 'reply':
        return NotificationType.reply;
      case 'achievement':
        return NotificationType.achievement;
      case 'announcement':
        return NotificationType.announcement;
      default:
        return NotificationType.announcement;
    }
  }
}
