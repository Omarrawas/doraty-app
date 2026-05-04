import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:intl/intl.dart' as intl;

class CourseSubscribersScreen extends StatefulWidget {
  final String? courseId;
  final String? courseTitle;

  const CourseSubscribersScreen({
    super.key,
    this.courseId,
    this.courseTitle,
  });

  @override
  State<CourseSubscribersScreen> createState() =>
      _CourseSubscribersScreenState();
}

class _CourseSubscribersScreenState extends State<CourseSubscribersScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscribers = [];
  final intl.DateFormat _dateFormat = intl.DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    _loadSubscribers();
  }

  Future<void> _loadSubscribers() async {
    setState(() => _isLoading = true);
    try {
      if (widget.courseId != null) {
        _subscribers = await _db.getCourseSubscribers(widget.courseId!);
      } else {
        final teacherId = _db.currentUserId;
        if (teacherId != null) {
          _subscribers = await _db.getTeacherSubscribers(teacherId);
        }
      }
    } catch (e) {
      debugPrint('Error loading subscribers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeStudent(
      String userId, String courseId, String studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف الطالب', textAlign: TextAlign.right),
        content: Text('هل أنت متأكد من حذف الطالب $studentName من الدورة؟',
            textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _db.removeStudentFromCourse(userId, courseId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الطالب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadSubscribers();
      } catch (e) {
        debugPrint('Error removing student: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ أثناء حذف الطالب'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : _subscribers.isEmpty
                        ? _buildEmptyState(context)
                        : RefreshIndicator(
                            onRefresh: _loadSubscribers,
                            child: ListView.builder(
                              padding: EdgeInsets.all(20),
                              itemCount: _subscribers.length,
                              itemBuilder: (context, index) {
                                return _buildSubscriberCard(
                                    context, _subscribers[index]);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: AppColors.getTextColor(context)),
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
                  widget.courseId != null ? 'طلاب الدورة' : 'إدارة الطلاب',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                if (widget.courseTitle != null)
                  Text(
                    widget.courseTitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextColor(context).withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriberCard(
      BuildContext context, Map<String, dynamic> subscriber) {
    final user = subscriber['users'] as Map<String, dynamic>? ?? {};
    final fullName = user['full_name'] ?? 'طالب';
    final email = user['email'] ?? '';
    final avatarUrl = user['avatar_url'];
    final enrolledAt = subscriber['enrolled_at'] != null
        ? DateTime.parse(subscriber['enrolled_at']).toLocal()
        : null;
    final progress =
        (subscriber['progress_percentage'] as num? ?? 0).toDouble();
    final courseTitle = subscriber['courses']?['title'];

    final userId = subscriber['user_id']?.toString() ?? '';
    final courseId = subscriber['course_id']?.toString() ?? '';
    final paidAmount = subscriber['paid_amount'] as num?;
    final status = subscriber['status']?.toString() ?? 'active';

    String subscriptionType = 'مجاني';
    if (paidAmount != null && paidAmount > 0) {
      subscriptionType = 'مدفوع ($paidAmount ل.س)';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                      backgroundImage:
                          avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null
                          ? Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  fullName,
                                  style: TextStyle(
                                    color: AppColors.getTextColor(context),
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (userId.isNotEmpty && courseId.isNotEmpty)
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.redAccent, size: 22),
                                  constraints: BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => _removeStudent(
                                      userId, courseId, fullName),
                                ),
                            ],
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                color: AppColors.getTextColor(context)
                                    .withOpacity(0.6),
                                fontSize: 13,
                              ),
                            ),
                          if (courseTitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                courseTitle,
                                style: TextStyle(
                                  color: Colors.blueAccent[100],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        (paidAmount != null && paidAmount > 0)
                                            ? Colors.orange.withOpacity(0.2)
                                            : Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          (paidAmount != null && paidAmount > 0)
                                              ? Colors.orange.withOpacity(0.5)
                                              : Colors.green.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    subscriptionType,
                                    style: TextStyle(
                                      color:
                                          (paidAmount != null && paidAmount > 0)
                                              ? Colors.orange
                                              : Colors.greenAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                if (status != 'active')
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.red.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(color: Colors.white.withOpacity(0.1)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'التقدم في الدورة',
                                style: TextStyle(
                                  color: AppColors.getTextColor(context)
                                      .withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${progress.toInt()}%',
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.greenAccent),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (enrolledAt != null) ...[
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'تاريخ الانضمام',
                            style: TextStyle(
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _dateFormat.format(enrolledAt),
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 80, color: Colors.white.withOpacity(0.3)),
          SizedBox(height: 16),
          Text(
            'لا يوجد طلاب مسجلين حالياً',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
