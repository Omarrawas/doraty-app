import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import 'create_lesson_screen.dart';
import '../teacher/create_exam_screen.dart';
import '../teacher/manage_questions_screen.dart';

class LessonsManagementScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const LessonsManagementScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<LessonsManagementScreen> createState() =>
      _LessonsManagementScreenState();
}

class _LessonsManagementScreenState extends State<LessonsManagementScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _lessons = [];
  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    setState(() => _isLoading = true);
    try {
      final lessons = await _db.getCourseLessons(widget.courseId);
      final exams = await _db.getAllExamsForCourse(widget.courseId);

      setState(() {
        _lessons = lessons;
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.adminLightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Column(
            children: [
              const Text('دروس الدورة'),
              Text(
                widget.courseTitle,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.normal),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_lessons.length} درس',
                style: const TextStyle(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryPurple),
              )
            : _lessons.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadLessons,
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _lessons.length,
                      onReorder: _reorderLessons,
                      itemBuilder: (context, index) {
                        return Padding(
                          key: ValueKey(_lessons[index]['id']),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildLessonCard(_lessons[index], index),
                        );
                      },
                    ),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateLessonScreen(
                  courseId: widget.courseId,
                ),
              ),
            );
            if (result == true) _loadLessons();
          },
          backgroundColor: AppColors.primaryPurple,
          icon: const Icon(Icons.add),
          label: const Text('إضافة درس'),
        ),
      ),
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson, int index) {
    final isFree = lesson['is_free'] as bool? ?? false;
    int durationInSeconds = 0;
    final durationData = lesson['duration'];
    if (durationData is int) {
      durationInSeconds = durationData;
    } else if (durationData is String) {
      if (int.tryParse(durationData) != null) {
        durationInSeconds = int.parse(durationData);
      } else if (durationData.contains(':')) {
        final parts =
            durationData.split(':').map((e) => int.tryParse(e) ?? 0).toList();
        if (parts.length == 2) {
          durationInSeconds = parts[0] * 60 + parts[1];
        } else if (parts.length == 3) {
          durationInSeconds = parts[0] * 3600 + parts[1] * 60 + parts[2];
        }
      }
    }
    final minutes = (durationInSeconds / 60).round();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson['title'] ?? 'درس',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              color: AppColors.textSecondary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '$minutes دقيقة',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isFree)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: const Text(
                      'مجاني',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (lesson['description'] != null &&
                lesson['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                lesson['description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Exams Section
            if (_exams.any((e) => e['lesson_id'] == lesson['id'])) ...[
              const Divider(),
              const Text(
                'الاختبارات:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ..._exams
                  .where((e) => e['lesson_id'] == lesson['id'])
                  .map((exam) {
                return InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageQuestionsScreen(
                          examId: exam['id'],
                          examTitle: exam['title'],
                        ),
                      ),
                    );
                    if (result == true) _loadLessons();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.assignment,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exam['title'] ?? 'اختبار',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.textLight),
                      ],
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateLessonScreen(
                            courseId: widget.courseId,
                            lessonId: lesson['id'],
                            lessonData: lesson,
                          ),
                        ),
                      );
                      if (result == true) _loadLessons();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateExamScreen(
                            initialCourseId: widget.courseId,
                            lessonId: lesson['id'],
                            loadAllCourses: true,
                          ),
                        ),
                      );
                      if (result == true) _loadLessons();
                    },
                    icon: const Icon(Icons.add_task,
                        size: 18, color: Colors.orange),
                    label: const Text('إضافة اختبار',
                        style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteLesson(lesson),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library, color: AppColors.textLight, size: 64),
          SizedBox(height: 16),
          Text(
            'لا توجد دروس',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ابدأ بإضافة الدرس الأول',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reorderLessons(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _lessons.removeAt(oldIndex);
      _lessons.insert(newIndex, item);

      // Update order_index for all lessons
      for (int i = 0; i < _lessons.length; i++) {
        _lessons[i]['order_index'] = i + 1;
      }
    });

    try {
      // Save new order to database
      final updates = _lessons
          .map((lesson) => {
                'id': lesson['id'].toString(),
                'order_index': lesson['order_index'].toString(),
              })
          .toList();

      await _db.reorderLessons(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الترتيب'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      _loadLessons();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteLesson(Map<String, dynamic> lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدرس'),
        content: Text(
          'هل أنت متأكد من حذف "${lesson['title']}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.deleteLesson(lesson['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الدرس'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadLessons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
