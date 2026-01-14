import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import 'create_lesson_screen.dart';
import '../../models/chapter.dart';
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
  List<Chapter> _chapters = [];
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
      final chapters = await _db.getChapters(widget.courseId);
      final exams = await _db.getAllExamsForCourse(widget.courseId);

      // Sort lessons by chapter order first, then by lesson order
      lessons.sort((a, b) {
        final chapterIdA = a['chapter_id'];
        final chapterIdB = b['chapter_id'];

        if (chapterIdA == chapterIdB) {
          final int orderA = (a['order_index'] as num?)?.toInt() ?? 0;
          final int orderB = (b['order_index'] as num?)?.toInt() ?? 0;
          return orderA.compareTo(orderB);
        }

        final chapterA = chapters.firstWhere(
          (c) => c.id == chapterIdA,
          orElse: () =>
              Chapter(id: '', courseId: '', title: '', orderIndex: 999),
        );
        final chapterB = chapters.firstWhere(
          (c) => c.id == chapterIdB,
          orElse: () =>
              Chapter(id: '', courseId: '', title: '', orderIndex: 999),
        );

        if (chapterA.orderIndex != chapterB.orderIndex) {
          return chapterA.orderIndex.compareTo(chapterB.orderIndex);
        }

        final int orderA = (a['order_index'] as num?)?.toInt() ?? 0;
        final int orderB = (b['order_index'] as num?)?.toInt() ?? 0;
        return orderA.compareTo(orderB);
      });

      setState(() {
        _lessons = lessons;
        _chapters = chapters;
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
            IconButton(
              onPressed: _manageChapters,
              icon: const Icon(Icons.category, color: AppColors.primaryPurple),
              tooltip: 'إدارة الفصول',
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
                        final lesson = _lessons[index];
                        final prevLesson =
                            index > 0 ? _lessons[index - 1] : null;

                        // Check if chapter changed to show header
                        final bool showHeader = index == 0 ||
                            lesson['chapter_id'] != prevLesson?['chapter_id'];

                        // Find chapter info
                        final chapterId = lesson['chapter_id'];
                        final chapter = _chapters.firstWhere(
                          (c) => c.id == chapterId,
                          orElse: () => Chapter(
                              id: '',
                              courseId: widget.courseId,
                              title: 'دروس أخرى',
                              orderIndex: 999),
                        );

                        return Column(
                          key: ValueKey(lesson['id']),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showHeader) _buildChapterHeader(chapter.title),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildLessonCard(lesson, index),
                            ),
                          ],
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

  Widget _buildChapterHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryPurple,
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

      // Chapter adoption: if moved to a new position, adopt the chapter of the neighbor
      if (newIndex > 0) {
        item['chapter_id'] = _lessons[newIndex - 1]['chapter_id'];
      } else if (_lessons.length > 1) {
        item['chapter_id'] = _lessons[newIndex + 1]['chapter_id'];
      }

      // Update order_index for all lessons
      for (int i = 0; i < _lessons.length; i++) {
        _lessons[i]['order_index'] = i + 1;
      }
    });

    try {
      // Save new order and chapter to database
      final updates = _lessons
          .map((lesson) => {
                'id': lesson['id'],
                'order_index': lesson['order_index'],
                'chapter_id': lesson['chapter_id'],
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

  Future<void> _manageChapters() async {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('إدارة الفصول'),
            content: SizedBox(
              width: double.maxFinite,
              child: _chapters.isEmpty
                  ? const Center(child: Text('لا توجد فصول بعد'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = _chapters[index];
                        return ListTile(
                          title: Text(chapter.title),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () async {
                                  // Edit chapter
                                  final controller = TextEditingController(
                                      text: chapter.title);
                                  final result = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('تعديل الفصل'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                            labelText: 'العنوان'),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('إلغاء')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                              context, controller.text),
                                          child: const Text('حفظ'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (result != null &&
                                      result.isNotEmpty &&
                                      result != chapter.title) {
                                    await _db.updateChapter(
                                        chapterId: chapter.id, title: result);
                                    if (context.mounted) {
                                      _loadLessons();
                                      Navigator.pop(context);
                                      _manageChapters();
                                    }
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () async {
                                  // Confirm delete
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('حذف الفصل'),
                                      content: const Text(
                                          'هل أنت متأكد؟ ستبقى الدروس ولكن بدون فصل.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('إلغاء')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('حذف',
                                                style: TextStyle(
                                                    color: Colors.red))),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    if (context.mounted) {
                                      _loadLessons();
                                      Navigator.pop(context);
                                      _manageChapters();
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final controller = TextEditingController();
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('إضافة فصل'),
                      content: TextField(
                        controller: controller,
                        decoration: const InputDecoration(labelText: 'العنوان'),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('إلغاء')),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          child: const Text('إضافة'),
                        ),
                      ],
                    ),
                  );

                  if (result != null && result.isNotEmpty && context.mounted) {
                    await _db.createChapter(
                        courseId: widget.courseId, title: result);
                    if (context.mounted) {
                      _loadLessons();
                      Navigator.pop(context);
                      _manageChapters();
                    }
                  }
                },
                child: const Text('إضافة جديد'),
              ),
            ],
          );
        },
      ),
    );
  }
}
