import 'package:flutter/material.dart';
import 'notification_settings_screen.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/notification_model.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../courses/course_loader_screen.dart';

class NotificationsScreen extends StatefulWidget {
  NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _databaseService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications =
              data.map((json) => NotificationModel.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      await _databaseService.markNotificationAsRead(notification.id);
      setState(() {
        notification.isRead = true;
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _databaseService.markAllNotificationsAsRead();
      setState(() {
        for (var n in _notifications) {
          n.isRead = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('مسح الكل'),
        content: Text('هل أنت متأكد من مسح جميع الإشعارات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _databaseService.deleteAllNotifications();
      setState(() {
        _notifications.clear();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم مسح جميع الإشعارات')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(unreadCount),

              SizedBox(height: 20),

              // Notifications List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                    : _notifications.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            child: _buildGroupedNotificationsList(),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedNotificationsList() {
    final grouped = _groupNotifications();

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final item = grouped[index];
        if (item is String) {
          return Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              item,
              style: TextStyle(
                color: AppColors.getTextColor(context, secondary: true),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          );
        } else if (item is NotificationModel) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _buildNotificationCard(item),
          );
        }
        return SizedBox.shrink();
      },
    );
  }

  List<dynamic> _groupNotifications() {
    final today = <NotificationModel>[];
    final yesterday = <NotificationModel>[];
    final older = <NotificationModel>[];

    final now = DateTime.now();
    for (var n in _notifications) {
      if (_isSameDay(n.time, now)) {
        today.add(n);
      } else if (_isSameDay(n.time, now.subtract(Duration(days: 1)))) {
        yesterday.add(n);
      } else {
        older.add(n);
      }
    }

    final list = <dynamic>[];
    if (today.isNotEmpty) {
      list.add('اليوم');
      list.addAll(today);
    }
    if (yesterday.isNotEmpty) {
      list.add('أمس');
      list.addAll(yesterday);
    }
    if (older.isNotEmpty) {
      list.add('أقدم');
      list.addAll(older);
    }
    return list;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }



  Widget _buildHeader(int unreadCount) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الإشعارات',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                if (unreadCount > 0)
                  Text(
                    '$unreadCount غير مقروء',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextColor(context, secondary: true),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              if (_notifications.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.getMutedTextColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.getMutedTextColor(context),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.delete_sweep_outlined,
                            color: AppColors.getTextColor(context)),
                        tooltip: 'مسح الكل',
                        onPressed: _clearAllNotifications,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getMutedTextColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.getMutedTextColor(context),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.settings_outlined,
                          color: AppColors.getTextColor(context)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              if (unreadCount > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.getMutedTextColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.getMutedTextColor(context),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.done_all, color: AppColors.getTextColor(context)),
                        tooltip: 'قراءة الكل',
                        onPressed: _markAllAsRead,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: notification.isRead
                  ? [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.1),
                    ]
                  : [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.2),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                _markAsRead(notification);
                _handleNotificationTap(notification);
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getNotificationColor(notification.category)
                            .withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getNotificationIcon(notification.category),
                        color: AppColors.getTextColor(context),
                        size: 24,
                      ),
                    ),

                    SizedBox(width: 16),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: notification.isRead
                                        ? FontWeight.w600
                                        : FontWeight.bold,
                                    color: AppColors.getTextColor(context),
                                  ),
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            notification.message,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextColor(context, secondary: true),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _formatTime(notification.time),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextColor(context, secondary: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: EdgeInsets.all(20),
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.white.withOpacity(0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getMutedTextColor(context),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  size: 80,
                  color: AppColors.getTextColor(context, secondary: true),
                ),
                SizedBox(height: 20),
                Text(
                  'لا توجد إشعارات',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'سيتم إعلامك بأي تحديثات جديدة هنا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.getTextColor(context, secondary: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notification) {
    if (notification.actionUrl == null || notification.actionUrl!.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(notification.actionUrl!);

      // Handle doraty:// scheme
      if (uri.scheme == 'doraty') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isEmpty) return;

        // doraty://course/{id}
        if (pathSegments[0] == 'course' && pathSegments.length > 1) {
          final courseId = pathSegments[1];
          // Navigate to Course Loader
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseLoaderScreen(courseId: courseId),
            ),
          );
        }
        // doraty://profile
        else if (pathSegments[0] == 'profile') {
          // Navigate to Profile
        }
      }
      // Handle https:// for external links
      else if (uri.scheme == 'https' || uri.scheme == 'http') {
        // Launch URL
        // launchUrl(uri);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening Link: ${uri.toString()}')),
        );
      }
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }

  IconData _getNotificationIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.newLesson:
        return Icons.play_circle_outline;
      case NotificationCategory.exam:
        return Icons.assignment_outlined;
      case NotificationCategory.reply:
        return Icons.chat_bubble_outline;
      case NotificationCategory.achievement:
        return Icons.emoji_events_outlined;
      case NotificationCategory.announcement:
        return Icons.campaign_outlined;
      case NotificationCategory.promo:
        return Icons.local_offer_outlined;
      case NotificationCategory.system:
        return Icons.settings_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color _getNotificationColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.newLesson:
        return AppColors.notifLesson;
      case NotificationCategory.exam:
        return AppColors.notifExam;
      case NotificationCategory.reply:
        return AppColors.notifReply;
      case NotificationCategory.achievement:
        return AppColors.notifAchievement;
      case NotificationCategory.announcement:
        return AppColors.notifAnnouncement;
      case NotificationCategory.promo:
        return AppColors.notifPromo;
      case NotificationCategory.system:
        return AppColors.notifSystem;
      default:
        return AppColors.notifDefault;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}
