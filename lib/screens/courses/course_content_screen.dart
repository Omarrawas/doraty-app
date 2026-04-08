import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../models/course.dart';
import '../../models/chapter.dart';
import '../../models/lesson.dart';
import '../lesson/lesson_screen.dart' as lesson_ui;
import '../../widgets/empty_state.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/safe_parser.dart';
import '../../core/providers/cart_provider.dart';
import '../../models/session.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
  final DatabaseService _databaseService = DatabaseService();
  late List<Map<String, dynamic>> _lessonsData;
  late List<Chapter> _chapters;
  bool _isLoadingContent = false;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _lessonsData = List<Map<String, dynamic>>.from(widget.lessonsData);
    _chapters = List<Chapter>.from(widget.chapters);
    _ensureContentLoaded();
  }

  @override
  void didUpdateWidget(CourseContentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final hasNewLessons =
        widget.lessonsData.isNotEmpty && widget.lessonsData != oldWidget.lessonsData;
    final hasNewChapters =
        widget.chapters.isNotEmpty && widget.chapters != oldWidget.chapters;

    if (hasNewLessons || hasNewChapters) {
      setState(() {
        if (hasNewLessons) {
          _lessonsData = List<Map<String, dynamic>>.from(widget.lessonsData);
        }
        if (hasNewChapters) {
          _chapters = List<Chapter>.from(widget.chapters);
        }
      });
    }
  }

  Future<void> _ensureContentLoaded() async {
    if (_lessonsData.isNotEmpty) return;

    setState(() {
      _isLoadingContent = true;
    });

    try {
      if (widget.course.deliveryMode == 'live' ||
          widget.course.deliveryMode == 'in_person') {
        final sessions =
            await _databaseService.getCourseSessions(widget.course.id);
        if (!mounted) return;
        setState(() {
          _lessonsData = sessions;
        });
        return;
      }

      final results = await Future.wait([
        _databaseService.getLessons(widget.course.id),
        _databaseService.getChapters(widget.course.id),
      ]);

      if (!mounted) return;

      setState(() {
        _lessonsData = SafeParser.safeMapList(results[0]);
        _chapters = results[1] as List<Chapter>;
      });
    } catch (e) {
      debugPrint('Error loading course content: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
      }
    }
  }

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
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: _buildContentList(isRTL),
          ),
        ),
      ),
    );
  }

  Widget _buildContentList(bool isRTL) {
    if (_isLoadingContent && _lessonsData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                _t('course_content'),
                style: TextStyle(
                  color: AppColors.getTextColor(context, secondary: true),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_lessonsData.isEmpty) {
      return ProfessionalEmptyState(
        title: (widget.course.deliveryMode == 'live' || widget.course.deliveryMode == 'in_person') 
            ? _t('no_sessions_yet') 
            : _t('no_lessons_yet'),
        message: _t('course_content_working'),
        icon: Icons.auto_stories_rounded,
      );
    }

    if (widget.course.deliveryMode == 'live' || widget.course.deliveryMode == 'in_person') {
      return _buildSessionsList(isRTL);
    }

    // Group lessons by chapters
    final sections = <Map<String, dynamic>>[];

    if (_chapters.isNotEmpty) {
      final sortedChapters = List<Chapter>.from(_chapters);
      sortedChapters.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (var chapter in sortedChapters) {
        final chapterLessons = _lessonsData.where((l) {
          return l['chapter_id'] == chapter.id;
        }).toList();

        if (chapterLessons.isNotEmpty) {
          sections.add({
            'title': chapter.title,
            'lessons': chapterLessons,
          });
        }
      }

      final uncategorizedLessons = _lessonsData.where((l) {
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
        'lessons': _lessonsData,
      });
    }

    return Column(
      children: sections.asMap().entries.map((entry) {
        final index = entry.key;
        final section = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: _buildCurriculumSection(
            title: section['title'],
            lessons: SafeParser.safeMapList(section['lessons']),
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
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark ? [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ] : [
                Colors.white.withOpacity(0.8),
                Colors.white.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
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
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
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
                  physics: NeverScrollableScrollPhysics(),
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
    final canAccess = lesson.isFree || widget.isEnrolled;
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    return Column(
      children: [
        Divider(height: 1, color: AppColors.getMutedTextColor(context).withOpacity(isDark ? 0.3 : 0.15)),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final authService = Provider.of<AuthService>(context, listen: false);
              final canAccess = lesson.isFree || widget.isEnrolled;
              
              if (!authService.isAuthenticated && !lesson.isFree) {
                _showLoginRequiredDialog(context);
                return;
              }

              if (!canAccess) {
                _showSubscriptionRequiredDialog(context);
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
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: canAccess 
                          ? AppColors.primaryPurple.withOpacity(0.2)
                          : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      canAccess ? Icons.play_arrow_rounded : Icons.lock_outline,
                      color: canAccess ? AppColors.primaryPurple : (isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.4)),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (lesson.duration.isNotEmpty)
                          Text(
                            lesson.duration,
                            style: TextStyle(
                              color: AppColors.getTextColor(context, secondary: true),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (lesson.isCompleted)
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSubscriptionRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_person_rounded, color: Colors.orangeAccent),
            SizedBox(width: 10),
            Text(
              _t('login_required_title'), // Or a more specific string if available
              style: TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
            ),
          ],
        ),
        content: Text(
          _t('must_subscribe'),
          style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel'), style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle adding to cart
              final cart = Provider.of<CartProvider>(context, listen: false);
              cart.addItem(
                id: widget.course.id,
                title: widget.course.title,
                price: widget.course.discountedPrice,
                originalPrice: widget.course.price.toDouble(),
                discountAmount: widget.course.hasDiscount ? (widget.course.price - widget.course.discountedPrice).toDouble() : 0,
                imageUrl: widget.course.imageUrl,
                originalObject: widget.course,
              );

              context.push('/cart');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_t('buy_now'), style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('login_required_title'),
          style: TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        content: Text(
          _t('login_required_desc'),
          style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel'), style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(_t('login_now'), style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(bool isRTL) {
    if (_lessonsData.isEmpty) {
      return ProfessionalEmptyState(
        title: _t('no_sessions_yet'),
        message: _t('course_content_working'),
        icon: Icons.calendar_month_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            _t('live_sessions'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _lessonsData.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) {
            final sessionMap = _lessonsData[index];
            final session = Session.fromJson(sessionMap);
            return _buildSessionItem(session, isRTL);
          },
        ),
      ],
    );
  }

  Widget _buildSessionItem(Session session, bool isRTL) {
    final statusColor = session.status == SessionStatus.upcoming 
        ? Colors.orange 
        : session.status == SessionStatus.liveNow || session.shouldBeLiveNow
            ? Colors.red 
            : session.status == SessionStatus.completed 
                ? Colors.green 
                : Colors.grey;

    final isLiveOrUpcoming = session.status == SessionStatus.liveNow || session.shouldBeLiveNow || session.status == SessionStatus.upcoming;
    final hasRecording = session.status == SessionStatus.completed && session.recordingUrl != null && session.recordingUrl!.isNotEmpty;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            session.platform == SessionPlatform.zoom ? Icons.videocam : Icons.computer,
            color: statusColor,
            size: 24,
          ),
        ),
        title: Text(
          session.title,
          style: TextStyle(
            color: AppColors.getTextColor(context),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(session.scheduledAt.toLocal()),
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (session.location != null && session.location!.isNotEmpty) ...[
                  SizedBox(width: 12),
                  Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      session.location!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                session.statusLabel,
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        trailing: (isLiveOrUpcoming || hasRecording)
            ? ElevatedButton(
                onPressed: () {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  
                  if (!authService.isAuthenticated) {
                    _showLoginRequiredDialog(context);
                    return;
                  }

                  if (!widget.isEnrolled) {
                    _showSubscriptionRequiredDialog(context);
                    return;
                  }

                  if (hasRecording) {
                    launchUrl(Uri.parse(session.recordingUrl!), mode: LaunchMode.externalApplication);
                  } else if (session.joinUrl != null && session.joinUrl!.isNotEmpty) {
                    launchUrl(Uri.parse(session.joinUrl!), mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasRecording ? AppColors.primaryPurple : statusColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(hasRecording ? _t('watch_recording') : _t('join')),
              )
            : null,
      ),
    );
  }
}
