import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../models/course.dart';
import '../../models/chapter.dart';
import '../../models/lesson.dart';
import '../lesson/lesson_screen.dart' as lesson_ui;
import '../../widgets/empty_state.dart';
import '../../core/services/auth_service.dart';
import '../auth/login_screen.dart';

class CourseContentScreen extends StatefulWidget {
  final Course course;
  final List<Map<String, dynamic>> lessonsData;
  final List<Chapter> chapters;
  final bool isEnrolled;

  const CourseContentScreen({
    super.key,
    required this.course,
    required this.lessonsData,
    required this.chapters,
    this.isEnrolled = true,
  });

  @override
  State<CourseContentScreen> createState() => _CourseContentScreenState();
}

class _CourseContentScreenState extends State<CourseContentScreen> {
  final Map<int, bool> _expandedSections = {0: true};

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_t('course_content')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F0F1E),
              Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _buildContentList(isRTL),
          ),
        ),
      ),
    );
  }

  Widget _buildContentList(bool isRTL) {
    if (widget.lessonsData.isEmpty) {
      return ProfessionalEmptyState(
        title: _t('no_lessons_yet'),
        message: _t('course_content_working'),
        icon: Icons.auto_stories_rounded,
      );
    }

    // Group lessons by chapters
    final sections = <Map<String, dynamic>>[];

    if (widget.chapters.isNotEmpty) {
      final sortedChapters = List<Chapter>.from(widget.chapters);
      sortedChapters.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (var chapter in sortedChapters) {
        final chapterLessons = widget.lessonsData.where((l) {
          return l['chapter_id'] == chapter.id;
        }).toList();

        if (chapterLessons.isNotEmpty) {
          sections.add({
            'title': chapter.title,
            'lessons': chapterLessons,
          });
        }
      }

      final uncategorizedLessons = widget.lessonsData.where((l) {
        return l['chapter_id'] == null;
      }).toList();

      if (uncategorizedLessons.isNotEmpty) {
        sections.add({
          'title': _t('other_lessons'),
          'lessons': uncategorizedLessons,
        });
      }
    } else {
      sections.add({
        'title': _t('course_content'),
        'lessons': widget.lessonsData,
      });
    }

    return Column(
      children: sections.asMap().entries.map((entry) {
        final index = entry.key;
        final section = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCurriculumSection(
            title: section['title'],
            lessons: List<Map<String, dynamic>>.from(section['lessons']),
            sectionIndex: index,
            isRTL: isRTL,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCurriculumSection({
    required String title,
    required List<Map<String, dynamic>> lessons,
    required int sectionIndex,
    required bool isRTL,
  }) {
    final isExpanded = _expandedSections[sectionIndex] ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _expandedSections[sectionIndex] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.primaryPurple,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isExpanded)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = Lesson.fromJson(lessons[index]);
                    return _buildLessonItem(lesson, index == lessons.length - 1, isRTL);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonItem(Lesson lesson, bool isLast, bool isRTL) {
    return Column(
      children: [
        Divider(height: 1, color: Colors.white.withOpacity(0.1)),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final authService = Provider.of<AuthService>(context, listen: false);
              
              if (!authService.isAuthenticated && !lesson.isFree) {
                _showLoginRequiredDialog(context);
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => lesson_ui.LessonScreen(
                    lesson: lesson,
                    courseTitle: widget.course.title,
                    isEnrolled: widget.isEnrolled,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.primaryPurple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (lesson.duration.isNotEmpty)
                          Text(
                            lesson.duration,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (lesson.isCompleted)
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: Text(
          _t('login_required_title'),
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        content: Text(
          _t('login_required_desc'),
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel'), style: const TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: Text(_t('login_now'), style: const TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
