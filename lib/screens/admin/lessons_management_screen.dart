import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'create_lesson_screen.dart';
import '../../models/chapter.dart';
import '../teacher/create_exam_screen.dart';
import '../teacher/manage_questions_screen.dart';

class LessonsManagementScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  LessonsManagementScreen({
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
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _lessons.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _loadLessons,
                              child: ReorderableListView.builder(
                                padding: EdgeInsets.all(20),
                                itemCount: _lessons.length,
                                onReorder: _reorderLessons,
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) {
                                  return AnimatedBuilder(
                                    animation: animation,
                                    builder: (context, child) {
                                      final double animValue = Curves.easeInOut
                                          .transform(animation.value);
                                      final double scale =
                                          lerpDouble(1, 1.02, animValue)!;
                                      final double elevation =
                                          lerpDouble(0, 6, animValue)!;
                                      return Transform.scale(
                                        scale: scale,
                                        child: Material(
                                          elevation: elevation,
                                          color: Colors.transparent,
                                          shadowColor:
                                              Colors.black.withOpacity(0.5),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: child,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final lesson = _lessons[index];
                                  final prevLesson =
                                      index > 0 ? _lessons[index - 1] : null;

                                  // Check if chapter changed to show header
                                  final bool showHeader = index == 0 ||
                                      lesson['chapter_id'] !=
                                          prevLesson?['chapter_id'];

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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (showHeader)
                                        _buildChapterHeader(
                                            context, chapter.title),
                                      Padding(
                                        padding:
                                            EdgeInsets.only(bottom: 12),
                                        child: _buildLessonCard(
                                            context, lesson, index),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
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
          icon: Icon(Icons.add, color: AppColors.getTextColor(context)),
          label: Text('إضافة درس',
              style: TextStyle(
                  color: AppColors.getTextColor(context), fontWeight: FontWeight.normal)),
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
                      width: 1),
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
                  'دروس الدورة',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  widget.courseTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context).withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
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
                      width: 1),
                ),
                child: IconButton(
                  onPressed: _manageChapters,
                  icon: Icon(Icons.category, color: AppColors.getTextColor(context)),
                  tooltip: 'إدارة الفصول',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(
      BuildContext context, Map<String, dynamic> lesson, int index) {
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson['title'] ?? 'درس',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: AppColors.getTextColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                color: AppColors.getTextColor(context)
                                    .withOpacity(1),
                                size: 14),
                            SizedBox(width: 4),
                            Text(
                              '$minutes دقيقة',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.getTextColor(context)
                                    .withOpacity(1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Drag Handle - Larger touch area and better icon
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.getMutedTextColor(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: AppColors.getTextColor(context),
                        size: 24,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  if (isFree)
                    Container(
                      padding:
                          EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.withOpacity(0.5), width: 1),
                      ),
                      child: Text(
                        'مجاني',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
              if (lesson['description'] != null &&
                  lesson['description'].toString().isNotEmpty) ...[
                SizedBox(height: 12),
                Text(
                  lesson['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextColor(context).withOpacity(0.85),
                  ),
                ),
              ],
              SizedBox(height: 16),

              // Exams Section
              if (_exams.any((e) => e['lesson_id'] == lesson['id'])) ...[
                Divider(color: AppColors.getTextColor(context).withOpacity(0.12)),
                Text(
                  'الاختبارات:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.orangeAccent,
                  ),
                ),
                SizedBox(height: 8),
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
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.assignment,
                              size: 16, color: Colors.orangeAccent),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exam['title'] ?? 'اختبار',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextColor(context),
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 16, color: AppColors.getTextColor(context)),
                        ],
                      ),
                    ),
                  );
                }),
              ],

              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      icon: Icons.edit,
                      label: 'تعديل',
                      color: Colors.blue,
                      onTap: () async {
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
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      icon: Icons.add_task,
                      label: 'إضافة اختبار',
                      color: Colors.orange,
                      onTap: () async {
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
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteLesson(lesson),
                    icon: Icon(Icons.delete, color: Colors.redAccent),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.25),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primaryPurple).withOpacity(0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (color ?? AppColors.primaryPurple).withOpacity(0.6),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: AppColors.getTextColor(context)),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.getGlassColor(context, opacity: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.3),
                    width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library,
                      color: AppColors.getTextColor(context), size: 64),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد دروس',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.getTextColor(context).withOpacity(0.8),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ابدأ بإضافة الدرس الأول',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextColor(context).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.getTextColor(context),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.getMutedTextColor(context),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: AppColors.getTextColor(context),
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
          SnackBar(
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
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteLesson(Map<String, dynamic> lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف الدرس'),
        content: Text(
          'هل أنت متأكد من حذف "${lesson['title']}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.deleteLesson(lesson['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حذف الدرس'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadLessons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
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
            title: Text('إدارة الفصول'),
            content: SizedBox(
              width: double.maxFinite,
              child: _chapters.isEmpty
                  ? Center(child: Text('لا توجد فصول بعد'))
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
                                icon: Icon(Icons.edit, size: 20),
                                onPressed: () async {
                                  // Edit chapter
                                  final controller = TextEditingController(
                                      text: chapter.title);
                                  final result = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('تعديل الفصل'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: InputDecoration(
                                            labelText: 'العنوان'),
                                      ),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: Text('إلغاء')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                              context, controller.text),
                                          child: Text('حفظ'),
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
                                icon: Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () async {
                                  // Confirm delete
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('حذف الفصل'),
                                      content: Text(
                                          'هل أنت متأكد؟ ستبقى الدروس ولكن بدون فصل.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: Text('إلغاء')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: Text('حذف',
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
                child: Text('إغلاق'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final controller = TextEditingController();
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('إضافة فصل'),
                      content: TextField(
                        controller: controller,
                        decoration: InputDecoration(labelText: 'العنوان'),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('إلغاء')),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(context, controller.text),
                          child: Text('إضافة'),
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
                child: Text('إضافة جديد'),
              ),
            ],
          );
        },
      ),
    );
  }
}
