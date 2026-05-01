import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../models/chapter.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

import '../../widgets/glass_card.dart';

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  Future<void> _loadLessons() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final lessons = await _db.getCourseLessons(widget.courseId);
      final chapters = await _db.getChapters(widget.courseId);
      final exams = await _db.getAllExamsForCourse(widget.courseId, includeQuestions: false);

      if (mounted) {
        setState(() {
          _lessons = lessons;
          _chapters = chapters;
          _exams = exams;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyErrorMessage(e);
        });
        debugPrint('Error loading lessons: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final double width = MediaQuery.of(context).size.width;
    final bool isSmallScreen = width < 900;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                _buildTopActions(context),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryPurple,
                          ),
                        )
                      : _errorMessage != null
                          ? _buildErrorState()
                          : RefreshIndicator(
                              onRefresh: _loadLessons,
                              child: isSmallScreen
                                  ? _buildMobileView()
                                  : _buildDesktopView(),
                            ),
                ),
              ],
            ),
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
                  _t('course_lessons'),
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
        ],
      ),
    );
  }

  Widget _buildTopActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildHeaderActionButton(
              context: context,
              icon: Icons.create_new_folder_rounded,
              label: _t('add_chapter'),
              color: Colors.blueAccent,
              onTap: _addChapter,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _buildHeaderActionButton(
              context: context,
              icon: Icons.video_call_rounded,
              label: _t('add_lesson'),
              color: AppColors.primaryPurple,
              onTap: () async {
                final result = await context
                    .push('/admin/lessons/create/${widget.courseId}');
                if (result == true) _loadLessons();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GlassCard(
      opacity: 0.25,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileView() {
    if (_chapters.isEmpty && _lessons.isEmpty) {
      return _buildEmptyState(context);
    }

    final sortedChapters = [..._chapters]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: sortedChapters.length + 1,
        itemBuilder: (context, index) {
          if (index < sortedChapters.length) {
            final chapter = sortedChapters[index];
            return _buildChapterExpansionTile(chapter, index, sortedChapters.length);
          } else {
            final unorganizedLessons = _lessons.where((l) => l['chapter_id'] == null).toList();
            if (unorganizedLessons.isEmpty) return SizedBox.shrink();
            return _buildUnorganizedLessonsTile(unorganizedLessons);
          }
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, color: AppColors.getTextColor(context).withOpacity(0.3), size: 80),
            SizedBox(height: 16),
            Text(
              _t('no_lessons'),
              style: TextStyle(fontSize: 20, color: AppColors.getTextColor(context), fontWeight: FontWeight.normal),
            ),
            SizedBox(height: 8),
            Text(
              _t('start_adding_first_lesson'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context).withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            ),
            SizedBox(height: 24),
            Text(
              _errorMessage ?? _t('error_loading'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.getTextColor(context)),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLessons,
              icon: Icon(Icons.refresh),
              label: Text(_t('retry') ?? 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterExpansionTile(Chapter chapter, int index, int total) {
    final chapterLessons = _lessons.where((l) => l['chapter_id'] == chapter.id).toList();
    chapterLessons.sort((a, b) => ((a['order_index'] as num?)?.toInt() ?? 0)
        .compareTo((b['order_index'] as num?)?.toInt() ?? 0));

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          shape: Border(),
          backgroundColor: Colors.transparent,
          iconColor: AppColors.getTextColor(context),
          collapsedIconColor: AppColors.getTextColor(context, secondary: true),
          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            chapter.title,
            style: TextStyle(fontSize: 16, color: AppColors.getTextColor(context)),
          ),
          subtitle: Text(
            '${chapterLessons.length} ${_t('lessons_count_label')}',
            style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context, secondary: true)),
          ),
          trailing: _buildChapterActions(chapter, index, total),
          children: chapterLessons.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _buildLessonExpansionTile(entry.value, entry.key, chapterLessons.length, chapter.id),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildUnorganizedLessonsTile(List<Map<String, dynamic>> lessons) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          shape: Border(),
          title: Text(
            _t('other_lessons'),
            style: TextStyle(fontSize: 16, color: AppColors.getTextColor(context, secondary: true)),
          ),
          children: lessons.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _buildLessonExpansionTile(entry.value, entry.key, lessons.length, null),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLessonExpansionTile(Map<String, dynamic> lesson, int index, int total, String? chapterId) {
    final lessonExams = _exams.where((e) => e['lesson_id'] == lesson['id']).toList();
    final isFree = lesson['is_free'] as bool? ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          shape: Border(),
          leading: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(fontSize: 12, color: AppColors.primaryPurple),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  lesson['title'] ?? '',
                  style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context)),
                ),
              ),
              if (isFree)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _t('free'),
                    style: TextStyle(fontSize: 9, color: Colors.greenAccent),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            '${lessonExams.length} ${_t('exams_label').replaceAll(':', '')}',
            style: TextStyle(fontSize: 11, color: AppColors.getMutedTextColor(context)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0)
                IconButton(
                  icon: Icon(Icons.arrow_upward, size: 16, color: AppColors.getTextColor(context, secondary: true)),
                  onPressed: () => _moveLesson(chapterId, index, index - 1),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              if (index < total - 1)
                IconButton(
                  icon: Icon(Icons.arrow_downward, size: 16, color: AppColors.getTextColor(context, secondary: true)),
                  onPressed: () => _moveLesson(chapterId, index, index + 1),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              SizedBox(width: 8),
              Icon(Icons.expand_more, color: AppColors.getTextColor(context, secondary: true)),
            ],
          ),
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildExamsList(lessonExams),
                  SizedBox(height: 12),
                  _buildLessonActionButtons(lesson),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamsList(List<Map<String, dynamic>> exams) {
    if (exams.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, size: 14, color: Colors.orangeAccent),
            SizedBox(width: 6),
            Text(
              _t('exams_label'),
              style: TextStyle(fontSize: 11, color: Colors.orangeAccent),
            ),
          ],
        ),
        SizedBox(height: 6),
        ...exams.map((exam) => Container(
              margin: EdgeInsets.only(bottom: 6),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.getGlassColor(context, opacity: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.getBorderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_rounded, size: 14, color: AppColors.getTextColor(context, secondary: true)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      exam['title'] ?? '',
                      style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context)),
                    ),
                  ),
                  _buildExamActions(exam),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildChapterActions(Chapter chapter, int index, int total) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (index > 0)
          IconButton(
            onPressed: () => _moveChapter(index, index - 1),
            icon: Icon(Icons.arrow_drop_up_rounded, color: AppColors.getTextColor(context, secondary: true)),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        if (index < total - 1)
          IconButton(
            onPressed: () => _moveChapter(index, index + 1),
            icon: Icon(Icons.arrow_drop_down_rounded, color: AppColors.getTextColor(context, secondary: true)),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
        SizedBox(width: 4),
        IconButton(
          onPressed: () => _editChapter(chapter),
          icon: Icon(Icons.edit_note_rounded, color: AppColors.getTextColor(context, secondary: true), size: 20),
          tooltip: _t('edit_chapter'),
        ),
        IconButton(
          onPressed: () => _deleteChapter(chapter),
          icon: Icon(Icons.delete_sweep_rounded, color: Colors.redAccent.withOpacity(0.7), size: 20),
          tooltip: _t('delete_chapter'),
        ),
      ],
    );
  }

  Widget _buildExamActions(Map<String, dynamic> exam) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
          onPressed: () => context.push(
            '/admin/exams/questions/${exam['id']}?title=${Uri.encodeComponent(exam['title'] ?? '')}',
          ),
          icon: Icon(Icons.settings_suggest_rounded, color: Colors.blueAccent, size: 18),
        ),
        SizedBox(width: 12),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(),
          onPressed: () => _deleteExam(exam),
          icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent.withOpacity(0.6), size: 18),
        ),
      ],
    );
  }

  Widget _buildLessonActionButtons(Map<String, dynamic> lesson) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: Icons.edit_rounded,
            label: _t('edit'),
            color: Colors.blue,
            onTap: () async {
              final result = await context.push(
                '/admin/lessons/edit/${lesson['id']}?courseId=${widget.courseId}',
                extra: lesson,
              );
              if (result == true) _loadLessons();
            },
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildActionButton(
            context: context,
            icon: Icons.add_task_rounded,
            label: _t('add_exam'),
            color: Colors.orange,
            onTap: () async {
              final result = await context.push(
                '/admin/exams/create?courseId=${widget.courseId}&lessonId=${lesson['id']}',
              );
              if (result == true) _loadLessons();
            },
          ),
        ),
        SizedBox(width: 8),
        IconButton(
          onPressed: () => _deleteLesson(lesson),
          icon: Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 24),
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
            padding: EdgeInsets.all(8),
          ),
        ),
      ],
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

  Widget _buildDesktopView() {
    final sortedChapters = [..._chapters]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    
    return Padding(
      padding: EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: _buildDesktopColumn(
              title: _t('manage_chapters'),
              icon: Icons.folder_copy_rounded,
              child: ListView.builder(
                itemCount: sortedChapters.length,
                itemBuilder: (context, index) => _buildChapterDesktopCard(sortedChapters[index], index, sortedChapters.length),
              ),
            ),
          ),
          SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: _buildDesktopColumn(
              title: _t('course_lessons'),
              icon: Icons.library_books_rounded,
              child: _buildMobileView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopColumn({required String title, required IconData icon, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.getTextColor(context), size: 20),
            SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(fontSize: 18, color: AppColors.getTextColor(context), fontWeight: FontWeight.normal),
            ),
          ],
        ),
        SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: child,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChapterDesktopCard(Chapter chapter, int index, int total) {
    return Container(
      margin: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: ListTile(
        title: Text(chapter.title, style: TextStyle(color: AppColors.getTextColor(context))),
        trailing: _buildChapterActions(chapter, index, total),
      ),
    );
  }

  // Action Methods
  Future<void> _addChapter() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('add_chapter')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: _t('title')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            child: Text(_t('save'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      await _db.createChapter(Chapter(
        id: '',
        courseId: widget.courseId,
        title: controller.text,
        orderIndex: _chapters.length + 1,
      ));
      _loadLessons();
    }
  }

  Future<void> _editChapter(Chapter chapter) async {
    final controller = TextEditingController(text: chapter.title);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('edit_chapter')),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
            child: Text(_t('save'), style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true && controller.text.isNotEmpty) {
      await _db.updateChapter(Chapter(
        id: chapter.id,
        courseId: chapter.courseId,
        title: controller.text,
        orderIndex: chapter.orderIndex,
      ));
      _loadLessons();
    }
  }

  Future<void> _moveChapter(int fromIndex, int toIndex) async {
    final sortedChapters = [..._chapters]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    if (fromIndex < 0 || toIndex < 0 || fromIndex >= sortedChapters.length || toIndex >= sortedChapters.length) return;

    setState(() => _isLoading = true);
    try {
      final ch1 = sortedChapters[fromIndex];
      final ch2 = sortedChapters[toIndex];

      final updates = [
        {'id': ch1.id, 'order_index': ch2.orderIndex},
        {'id': ch2.id, 'order_index': ch1.orderIndex},
      ];

      await _db.reorderChapters(updates);
      await _loadLessons();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _moveLesson(String? chapterId, int fromIndex, int toIndex) async {
    final chapterLessons = _lessons.where((l) => l['chapter_id'] == chapterId).toList();
    chapterLessons.sort((a, b) => ((a['order_index'] as num?)?.toInt() ?? 0)
        .compareTo((b['order_index'] as num?)?.toInt() ?? 0));

    if (fromIndex < 0 || toIndex < 0 || fromIndex >= chapterLessons.length || toIndex >= chapterLessons.length) return;

    setState(() => _isLoading = true);
    try {
      final l1 = chapterLessons[fromIndex];
      final l2 = chapterLessons[toIndex];

      final updates = [
        {'id': l1['id'], 'order_index': l2['order_index']},
        {'id': l2['id'], 'order_index': l1['order_index']},
      ];

      await _db.reorderLessons(updates);
      await _loadLessons();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_chapter')),
        content: Text(_t('delete_chapter_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteChapter(chapter.id);
      _loadLessons();
    }
  }

  Future<void> _deleteLesson(Map<String, dynamic> lesson) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_lesson')),
        content: Text(_t('delete_lesson_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteLesson(lesson['id']);
      _loadLessons();
    }
  }

  Future<void> _deleteExam(Map<String, dynamic> exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_exam_title')),
        content: Text(_t('delete_exam_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.deleteExam(exam['id']);
      _loadLessons();
    }
  }
}
