import '../core/utils/safe_parser.dart';

enum SessionStatus { upcoming, liveNow, completed, cancelled }

enum SessionPlatform { zoom, meet, youtube, teams, other }

class Session {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? joinUrl;
  final SessionPlatform platform;
  final String? location;
  final String? recordingUrl;
  final SessionStatus status;
  final int? maxAttendees;
  final String? createdBy;
  final DateTime? createdAt;

  Session({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.durationMinutes = 60,
    this.joinUrl,
    this.platform = SessionPlatform.zoom,
    this.location,
    this.recordingUrl,
    this.status = SessionStatus.upcoming,
    this.maxAttendees,
    this.createdBy,
    this.createdAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: SafeParser.toStringSafe(json['id']),
      courseId: SafeParser.toStringSafe(json['course_id']),
      title: SafeParser.toStringSafe(json['title']),
      description: SafeParser.toStringSafe(json['description']),
      scheduledAt: SafeParser.toDateTime(json['scheduled_at']) ?? DateTime.now(),
      durationMinutes: SafeParser.toInt(json['duration_minutes'], fallback: 60),
      joinUrl: SafeParser.toStringSafe(json['join_url']),
      platform: _parsePlatform(SafeParser.toStringSafe(json['platform'])),
      location: SafeParser.toStringSafe(json['location']),
      recordingUrl: SafeParser.toStringSafe(json['recording_url']),
      status: _parseStatus(SafeParser.toStringSafe(json['status'])),
      maxAttendees: json['max_attendees'] != null
          ? SafeParser.toInt(json['max_attendees'])
          : null,
      createdBy: SafeParser.toStringSafe(json['created_by']),
      createdAt: SafeParser.toDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'course_id': courseId,
        'title': title,
        'description': description,
        'scheduled_at': scheduledAt.toIso8601String(),
        'duration_minutes': durationMinutes,
        'join_url': joinUrl,
        'platform': platform.name,
        'location': location,
        'recording_url': recordingUrl,
        'status': _statusToString(status),
        'max_attendees': maxAttendees,
      };

  static SessionStatus _parseStatus(String? s) => switch (s) {
        'live_now' => SessionStatus.liveNow,
        'completed' => SessionStatus.completed,
        'cancelled' => SessionStatus.cancelled,
        _ => SessionStatus.upcoming,
      };

  static String _statusToString(SessionStatus s) => switch (s) {
        SessionStatus.liveNow => 'live_now',
        SessionStatus.completed => 'completed',
        SessionStatus.cancelled => 'cancelled',
        _ => 'upcoming',
      };

  static SessionPlatform _parsePlatform(String? s) => switch (s) {
        'meet' => SessionPlatform.meet,
        'youtube' => SessionPlatform.youtube,
        'teams' => SessionPlatform.teams,
        'other' => SessionPlatform.other,
        _ => SessionPlatform.zoom,
      };

  String get platformLabel => switch (platform) {
        SessionPlatform.zoom => 'Zoom',
        SessionPlatform.meet => 'Google Meet',
        SessionPlatform.youtube => 'YouTube Live',
        SessionPlatform.teams => 'Microsoft Teams',
        _ => 'رابط مخصص',
      };

  String get statusLabel => switch (status) {
        SessionStatus.liveNow => '🔴 مباشر الآن',
        SessionStatus.completed => '✅ منتهية',
        SessionStatus.cancelled => '❌ ملغاة',
        _ => '🕐 قادمة',
      };

  bool get isUpcoming => status == SessionStatus.upcoming;
  bool get isLiveNow => status == SessionStatus.liveNow;
  bool get isJoinable => isUpcoming || isLiveNow;

  /// Auto-detect if session should be marked live now
  bool get shouldBeLiveNow {
    final now = DateTime.now();
    final end = scheduledAt.add(Duration(minutes: durationMinutes));
    return now.isAfter(scheduledAt) && now.isBefore(end);
  }
}
