import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/lesson.dart';
import '../../core/services/database_service.dart';
import '../../widgets/video_preview_widget.dart';
import '../teacher/teacher_profile_screen.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/empty_state.dart';
import '../../core/providers/cart_provider.dart';
import 'package:provider/provider.dart';
import '../../core/utils/error_utils.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/string_utils.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/theme_provider.dart';
import 'course_content_screen.dart';
import '../../models/chapter.dart';
import 'package:share_plus/share_plus.dart';

class CourseDetailsScreen extends StatefulWidget {
  final Course? course;
  final String? courseId;
  final String? heroTag;
  final bool startAtContent;

  const CourseDetailsScreen({
    super.key,
    this.course,
    this.courseId,
    this.heroTag,
    this.startAtContent = false,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  // Lessons data
  List<Map<String, dynamic>> _lessons = [];
  List<Chapter> _chapters = [];

  // Reviews data
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;

  bool _isEnrolled = false;
  bool _isFavorite = false;
  bool _isDescriptionExpanded = false; // Added for Read More
  Map<String, dynamic>? _userReview;
  String? _instructorPhoto;
  late String _instructorName;
  late int _studentsCount;
  final DatabaseService _databaseService = DatabaseService();

  List<Course> _similarCourses = []; // Added for similar courses

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  bool _isLoadingCourse = false;
  Course? _course;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    if (_course != null) {
      _initCourseData();
    } else if (widget.courseId != null) {
      _fetchAndInitCourse(widget.courseId!);
    }
  }

  @override
  void didUpdateWidget(CourseDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.courseId != widget.courseId || oldWidget.course != widget.course) {
      if (widget.courseId != null) {
        _fetchAndInitCourse(widget.courseId!);
      }
    }
  }

  Future<void> _fetchAndInitCourse(String id) async {
    setState(() => _isLoadingCourse = true);
    try {
      final json = await _databaseService.getCourseById(id);
      if (json != null) {
        setState(() {
          _course = Course.fromJson(json);
          _isLoadingCourse = false;
        });

        // Redirection removed to prevent redundant re-mounts and navigation errors.
        // The router will handle the display. We only fetch if needed.
        _initCourseData();
      }
    } catch (e) {
      debugPrint('Error loading course by id: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCourse = false);
    }
  }

  void _initCourseData() {
    if (_course == null) return;
    _instructorPhoto = _course!.instructorPhoto;
    _instructorName =
        StringUtils.cleanTeacherName(_course!.instructorName);
    _loadLessons();
    _loadChapters();
    _loadReviews();
    _checkEnrollment();
    _refreshInstructorInfo();
    _refreshCourseData();
    _studentsCount = _course!.studentsCount; // Initialize students count
    _checkUserReview();
    _checkFavoriteStatus();
    _loadSimilarCourses();

    debugPrint(
        '🏁 CourseDetailsScreen initialized for Course ID: ${_course!.id}');
    debugPrint('👨‍🏫 Instructor ID: ${_course!.instructorId}');
    debugPrint(
        '👨‍🏫 Instructor Name (passed): ${_course!.instructorName}');
  }

  Future<void> _checkUserReview() async {
    if (_course == null) return;
    try {
      final review =
          await _databaseService.getUserReviewForCourse(_course!.id);
      if (mounted) {
        setState(() {
          _userReview = review;
        });
      }
    } catch (e) {
      debugPrint('Error checking user review: $e');
    }
  }

  Future<void> _refreshCourseData() async {
    if (_course == null) return;
    try {
      final courseData = await _databaseService.getCourseById(_course!.id);
      if (mounted && courseData != null) {
        setState(() {
          _studentsCount = courseData['students_count'] ?? _studentsCount;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing course data: $e');
    }
  }

  Future<void> _refreshInstructorInfo() async {
    if (_course == null || _course!.instructorId == null || _course!.instructorId!.trim().isEmpty) return;
    try {
      final profile =
          await _databaseService.getUserProfile(_course!.instructorId!);
      if (mounted && profile.isNotEmpty) {
        setState(() {
          _instructorPhoto = (profile['avatar_url'] != null && profile['avatar_url'].toString().isNotEmpty) 
              ? profile['avatar_url'] 
              : null;
          _instructorName = StringUtils.cleanTeacherName(
              profile['full_name'] ?? _instructorName);
          debugPrint('📸 Instructor Photo URL: $_instructorPhoto');
        });
      }
    } catch (e) {
      debugPrint('Error refreshing instructor info: $e');
    }
  }

  Future<void> _checkEnrollment() async {
    if (_course == null) return;
    try {
      final isEnrolled =
          await _databaseService.hasCourseAccess(_course!.id);
      if (mounted) {
        setState(() {
          _isEnrolled = isEnrolled;
        });
      }
    } catch (e) {
      debugPrint('Error checking enrollment: $e');
    }
  }

  Future<void> _checkFavoriteStatus() async {
    if (_course == null) return;
    try {
      final isFavorite = await _databaseService.isFavorite(_course!.id);
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_course == null) return;
    if (!_checkAuthAndShowDialog()) return;
    try {
      final newStatus = await _databaseService.toggleFavorite(
        _course!.id,
        !_isFavorite,
      );
      if (mounted) {
        setState(() {
          _isFavorite = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isFavorite ? 'تمت الإضافة للمفضلة' : 'تمت الإزالة من المفضلة'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'فشل تحديث المفضلة: ${ErrorUtils.getFriendlyErrorMessage(e)}')),
        );
      }
    }
  }

  Future<void> _loadLessons() async {
    if (_course == null) return;
    try {
      if (_course!.deliveryMode == 'live' || _course!.deliveryMode == 'in_person') {
        final sessions = await _databaseService.getCourseSessions(_course!.id);
        if (mounted) {
          setState(() {
            _lessons = sessions;
          });
        }
      } else {
        final lessons = await _databaseService.getLessons(_course!.id);
        if (mounted) {
          setState(() {
            _lessons = lessons;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading lessons or sessions: $e');
    }
  }

  Future<void> _loadChapters() async {
    if (_course == null) return;
    try {
      final chapters = await _databaseService.getChapters(_course!.id);

      if (mounted) {
        setState(() {
          _chapters = chapters;
        });
      }
    } catch (e) {
      debugPrint('Error loading chapters: $e');
    }
  }

  Future<void> _loadReviews() async {
    if (_course == null) return;
    try {
      final reviews = await _databaseService.getReviews(_course!.id);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isRTL = Provider.of<LocaleProvider>(context).locale == 'ar';

    if (_isLoadingCourse) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_course == null) {
      return Scaffold(
        body: Center(
          child: ProfessionalEmptyState(
            icon: Icons.error_outline,
            title: 'الكورس غير موجود',
            message: 'تعذر العثور على الكورس المطلوب بخصائص هذا الرابط',
          ),
        ),
      );
    }

    // Direct redirection to Content Screen if requested via route
    if (widget.startAtContent) {
      return CourseContentScreen(
        course: _course!,
        lessonsData: _lessons,
        chapters: _chapters,
        isEnrolled: _isEnrolled,
      );
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopNavBar(isRTL),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeroSection(isRTL),
                      SizedBox(height: 30),
                      _buildMainContent(isRTL),
                      SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSimilarCourses() async {
    try {
      final courses = await _databaseService.getSimilarCourses(
          _course!.id, _course!.categoryIds);
      if (mounted) {
        setState(() {
          _similarCourses = courses;
        });
      }
    } catch (e) {
      debugPrint('Error loading similar courses: $e');
    }
  }

  Widget _buildTopNavBar(bool isRTL) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Actions Group
          Row(
            children:
                isRTL ? [_buildActionButtons(isRTL)] : [_buildNavBackButton()],
          ),

          // Logo
          Image.asset(
            'assets/images/logo.png',
            height: 30,
            errorBuilder: (context, error, stackTrace) => Text(
              'DAWRAT',
              style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
          ),

          // Right Actions Group
          Row(
            children:
                isRTL ? [_buildNavBackButton()] : [_buildActionButtons(isRTL)],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isRTL) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.share_rounded, color: AppColors.getTextColor(context), size: 22),
          onPressed: () async {
            if (_course != null) {
              final String courseIdentifier = (_course!.slug.isNotEmpty) ? _course!.slug : _course!.id;
              final String courseUrl = Uri.encodeFull('https://doraty-app.vercel.app/course/$courseIdentifier');
              final String locale = Provider.of<LocaleProvider>(context, listen: false).locale;
              final String shareText = locale == 'ar' 
                  ? 'تحقق من هذه الدورة في أكاديمية دوراتي: ${_course!.getLocalizedTitle(locale)}\n$courseUrl'
                  : 'Check out this course on Doraty Academy: ${_course!.getLocalizedTitle(locale)}\n$courseUrl';
              
              await Share.share(shareText);
            }
          },
        ),
        IconButton(
          icon: Icon(
            _isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_outline_rounded,
            color: _isFavorite ? Colors.redAccent : Colors.white,
            size: 22,
          ),
          onPressed: _toggleFavorite,
        ),
        IconButton(
          icon: Icon(
              Provider.of<ThemeProvider>(context).isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: AppColors.getTextColor(context),
              size: 22),
          onPressed: () {
            Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
          },
        ),
      ],
    );
  }

  Widget _buildNavBackButton() {
    return IconButton(
      icon: Icon(
        Provider.of<LocaleProvider>(context, listen: false).locale == 'ar'
            ? Icons.arrow_forward_ios_rounded
            : Icons.arrow_back_ios_new_rounded,
        color: AppColors.getTextColor(context),
        size: 20,
      ),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildHeroSection(bool isRTL) {
    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 800;

      if (isWide) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isRTL) ...[
                Expanded(
                  flex: 5,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildMediaPreview(isSquare: false),
                  ),
                ),
                SizedBox(width: 40),
                Expanded(
                  flex: 6,
                  child: _buildCourseHeroInfo(isRTL, isWide: true),
                ),
              ] else ...[
                Expanded(
                  flex: 6,
                  child: _buildCourseHeroInfo(isRTL, isWide: true),
                ),
                SizedBox(width: 40),
                Expanded(
                  flex: 5,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildMediaPreview(isSquare: false),
                  ),
                ),
              ],
            ],
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            _buildMediaPreview(),
            SizedBox(height: 24),
            _buildCourseHeroInfo(isRTL),
          ],
        ),
      );
    });
  }

  Widget _buildMediaPreview({bool isSquare = false}) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child:
          _course!.videoUrl != null && _course!.videoUrl!.isNotEmpty
              ? VideoPreviewWidget(
                  videoUrl: _course!.videoUrl!,
                  showHeader: !isSquare, // Hide header if square (side-by-side)
                  thumbnailUrl: _course!.imageUrl, // تمرير صورة الدورة
                )
              : _buildCourseImagePlaceholder(isSquare: isSquare),
    );
  }

  Widget _buildCourseImagePlaceholder({bool isSquare = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          (_course!.imageUrl != null && _course!.imageUrl!.isNotEmpty) 
          ? CachedNetworkImage(
            imageUrl: _course!.imageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                Container(color: AppColors.getElevatedSurfaceColor(context)),
          )
          : Container(color: AppColors.getElevatedSurfaceColor(context)),
          Container(
            color: Colors.black26,
            child: Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: AppColors.getTextColor(context), size: 64),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHeroInfo(bool isRTL, {bool isWide = false}) {
    String locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return Column(
      crossAxisAlignment:
          isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _course!.getLocalizedTitle(locale),
          style: TextStyle(
              fontSize: isWide ? 32 : 24,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context)),
          textAlign: isRTL ? TextAlign.right : TextAlign.left,
        ),
        if (_course!.categories.isNotEmpty ||
            _course!.tags.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8, bottom: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: isRTL ? WrapAlignment.end : WrapAlignment.start,
              children: [
                ..._course!.categories
                    .map((cat) => _buildTinyTag(cat, Colors.blueAccent)),
                ..._course!.tags.map((tag) => _buildTinyTag(
                    '#${AppStrings.get(tag, locale)}', Colors.purpleAccent)),
              ],
            ),
          ),
        SizedBox(height: 12),
        _buildHeroStatsRow(isRTL),
        SizedBox(height: 20),
        _buildInstructorSmallCard(isRTL),
        SizedBox(height: 24),
        if (!_isEnrolled)
          _buildEnrollmentSection(isRTL)
        else
          _buildContinueLearningButton(isRTL),
      ],
    );
  }

  Widget _buildHeroStatsRow(bool isRTL) {
    return Row(
      mainAxisAlignment:
          isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        _buildStatBadge(
            Icons.bar_chart_rounded, _t(_course!.level ?? 'all_levels')),
        SizedBox(width: 12),
        if (!_isEnrolled) ...[
          _buildStatBadge(Icons.access_time_rounded,
              '${_course!.durationHours ?? "0"} ${_t("hours_short")}'),
          SizedBox(width: 12),
        ],
        // عداد الفصول
        _buildStatBadge(Icons.grid_view_rounded,
            '${_chapters.isNotEmpty ? _chapters.length : 0} ${_t("chapters")}'),
        SizedBox(width: 12),
        // عداد الدروس أو الجلسات
        _buildStatBadge(
            (_course!.deliveryMode == 'recorded') ? Icons.play_circle_outline_rounded : Icons.calendar_today_outlined,
            '${_lessons.isNotEmpty ? _lessons.length : _course!.lessonsCount} ${_t((_course!.deliveryMode == 'recorded') ? "lessons" : "live_sessions")}'),
      ],
    );
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.getTextColor(context).withOpacity(0.60), size: 14),
        SizedBox(width: 4),
        Text(label,
            style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60), fontSize: 12)),
      ],
    );
  }

  Widget _buildInstructorSmallCard(bool isRTL) {
    return InkWell(
      onTap: () {
        if (_course!.instructorId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherProfileScreen(
                teacherId: _course!.instructorId!,
                teacherName: _instructorName,
                teacherPhoto: _instructorPhoto,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.getElevatedSurfaceColor(context),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.getBorderColor(context)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                  backgroundImage: (_instructorPhoto != null && _instructorPhoto!.isNotEmpty)
                      ? CachedNetworkImageProvider(_instructorPhoto!)
                      : null,
                  child: (_instructorPhoto == null || _instructorPhoto!.isEmpty)
                      ? Icon(Icons.person, size: 18, color: AppColors.getTextColor(context))
                      : null,
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment:
                      isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _instructorName,
                      style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _t("instructor_title"),
                      style: TextStyle(
                          color: AppColors.getTextColor(context, secondary: true), fontSize: 11),
                    ),
                  ],
                ),
                SizedBox(width: 12),
                Icon(
                    isRTL
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_forward_ios_rounded,
                    color: AppColors.getMutedTextColor(context),
                    size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrollmentSection(bool isRTL) {
    final isEnrolled = _isEnrolled;
    final isRecorded = _course!.deliveryMode == 'recorded';
    final buttonLabel = isEnrolled 
        ? (isRecorded ? _t('start_course_now') : _t('sessions_tab'))
        : '${_t("course_subscribe_now_prefix")}${_course!.getLocalizedPrice(Provider.of<LocaleProvider>(context).locale)}';

    return Column(
      crossAxisAlignment:
          isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          _t('register_and_get'),
          style: TextStyle(
              color: AppColors.getTextColor(context), fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 12),
        _buildBenefitItem(
            Icons.all_inclusive_rounded, _t(isRecorded ? 'unending_views' : 'live_desc')),
        _buildBenefitItem(Icons.workspace_premium_rounded,
            _t('completion_certificate')),
        _buildBenefitItem(
            Icons.chat_bubble_outline_rounded, _t('contact_coach')),

        SizedBox(height: 30),

        // Main Subscribe/Start Button
        ElevatedButton(
          onPressed: _handleEnrollment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: AppColors.primaryPurple.withOpacity(0.5),
          ),
          child: Text(
            buttonLabel,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueLearningButton(bool isRTL) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
          SizedBox(width: 12),
          Text(
            _t('enrolled_already'),
            style: TextStyle(
                color: AppColors.getTextColor(context), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.getTextColor(context).withOpacity(0.70), size: 16),
          SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isRTL) {
    return Column(
      children: [
        _buildDescriptionSection(isRTL),
        _buildCourseContentButton(isRTL),
        if (_course!.outcomes.isNotEmpty)
          _buildListSection(
              _t('course_outcomes'), _course!.outcomes, isRTL),
        if (_course!.targetAudience.isNotEmpty)
          _buildListSection(
              _t('target_audience'), _course!.targetAudience, isRTL),
        _buildReviewsSection(isRTL),
        SizedBox(height: 40),
        _buildSimilarCoursesSection(isRTL),
        _buildInstructorFullSection(isRTL),
        SizedBox(height: 80),
      ],
    );
  }

  Widget _buildInstructorFullSection(bool isRTL) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.getElevatedSurfaceColor(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: (_course!.instructorPhoto != null && _course!.instructorPhoto!.isNotEmpty)
                ? CachedNetworkImageProvider(_course!.instructorPhoto!)
                : null,
            backgroundColor: AppColors.getElevatedSurfaceColor(context),
            child: (_course!.instructorPhoto == null || _course!.instructorPhoto!.isEmpty)
                ? Icon(Icons.person, color: AppColors.getTextColor(context).withOpacity(0.54), size: 50)
                : null,
          ),
          SizedBox(height: 16),
          Text(
            _course!.instructorName,
            style: TextStyle(
                color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            _t('teacher'),
            style:
                TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 14),
          ),
          SizedBox(height: 24),
          TextButton.icon(
            onPressed: () {},
            icon: Icon(isRTL ? Icons.arrow_back : Icons.arrow_forward,
                color: AppColors.getTextColor(context).withOpacity(0.70), size: 18),
            label: Text(
              _t('read_more'),
              style: TextStyle(
                  color: AppColors.getTextColor(context).withOpacity(0.70), fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(bool isRTL) {
    final description = _course!.description ?? '';
    if (description.isEmpty) return SizedBox.shrink();

    bool isLong = description.length > 200;
    String displayContent = isLong && !_isDescriptionExpanded
        ? '${description.substring(0, 200)}...'
        : description;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment:
            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            _t('course_content'), // Using 'course_content' or similar for 'About'
            style: TextStyle(
                color: AppColors.getTextColor(context), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Text(
            displayContent,
            style: TextStyle(
                color: AppColors.getTextColor(context, secondary: true),
                fontSize: 15,
                height: 1.6),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
          if (isLong)
            TextButton(
              onPressed: () => setState(
                  () => _isDescriptionExpanded = !_isDescriptionExpanded),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _isDescriptionExpanded ? _t('read_less') : _t('read_more'),
                style: TextStyle(
                    color: AppColors.primaryPurple,
                    fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSimilarCoursesSection(bool isRTL) {
    if (_similarCourses.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment:
          isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _t('similar_courses'),
            style: TextStyle(
                color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 290,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _similarCourses.length,
            itemBuilder: (context, index) {
              final course = _similarCourses[index];
              return Container(
                width: 200,
                margin: EdgeInsets.only(right: 12),
                child: _buildSimilarCourseCard(course),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarCourseCard(Course course) {
    return InkWell(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => CourseDetailsScreen(course: course)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.getElevatedSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: course.imageUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppColors.getElevatedSurfaceColor(context)),
                      errorWidget: (context, url, error) =>
                          Container(color: AppColors.getElevatedSurfaceColor(context)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_border_rounded,
                        color: AppColors.getTextColor(context), size: 16),
                  ),
                ),
                if (course.durationHours != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        course.durationHours!,
                        style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'تقديم ${course.instructorName}',
                    style: TextStyle(
                        color: AppColors.getTextColor(context, secondary: true), fontSize: 11),
                  ),
                  SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 36),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                      elevation: 0,
                    ),
                    child: Text(_t('buy_now'),
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildListSection(String title, List<String> items, bool isRTL) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment:
            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Column(
            children: items
                .map((item) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Icon(Icons.circle,
                                color: Colors.purpleAccent, size: 6),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item,
                              style: TextStyle(
                                  color: AppColors.getTextColor(context, secondary: true),
                                  fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseContentButton(bool isRTL) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment:
            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              final id = _course?.slug ?? _course?.id;
              if (id == null) return;
              
              final path = Uri.encodeFull('/course/$id/content');
              context.push(path, extra: {
                'course': _course,
                'lessonsData': _lessons,
                'chapters': _chapters,
                'isEnrolled': _isEnrolled,
              });
            },
            icon: Icon((_course!.deliveryMode == 'recorded') ? Icons.list_alt_rounded : Icons.calendar_month_rounded),
            label: Text(_t((_course!.deliveryMode == 'recorded') ? 'course_content' : 'sessions_tab')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side:
                    BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(bool isRTL) {
    return Column(
      crossAxisAlignment:
          isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Text(
            _t('reviews_tab'),
            style: TextStyle(
                color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        _buildReviewsTab(),
        if (_reviews.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _t('view_all_reviews'),
                style: TextStyle(color: AppColors.getTextColor(context)),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleEnrollment() async {
    if (!_checkAuthAndShowDialog()) return;

    // Check if enrolled first to jump to lessons or sessions
    if (_isEnrolled) {
      if (_course!.deliveryMode == 'recorded' && _lessons.isNotEmpty) {
        final firstLesson = Lesson.fromJson(_lessons.first);
        final courseId = _course?.slug ?? _course?.id;
        if (courseId == null) return;
        
        final path = Uri.encodeFull('/course/$courseId/lesson/${firstLesson.slug ?? firstLesson.id}');
        context.push(path);
      } else {
        // For Live or In-Person, go to content overview to see sessions list
        final courseId = _course?.slug ?? _course?.id;
        if (courseId == null) return;
        
        final path = Uri.encodeFull('/course/$courseId/content');
        context.push(path, extra: {
          'course': _course,
          'lessonsData': _lessons,
          'chapters': _chapters,
          'isEnrolled': _isEnrolled,
        });
      }
      return;
    }

    // New Behavior: Add to Cart and Go to Cart Screen
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.addItem(
      id: _course!.id,
      title: _course!.title,
      price: _course!.discountedPrice,
      originalPrice: _course!.price.toDouble(),
      discountAmount: _course!.hasDiscount
          ? (_course!.price - _course!.discountedPrice).toDouble()
          : 0,
      imageUrl: _course!.imageUrl,
      originalObject: _course!,
    );

    context.push('/cart');
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: ShimmerLoader.rectangular(height: 100),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Add Review Button (Only if enrolled)
        // Add Review Button (Only if enrolled)
        if (_isEnrolled)
          if (_userReview == null)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 20),
              child: ElevatedButton.icon(
                onPressed: _showAddReviewDialog,
                icon: Icon(Icons.rate_review),
                label: Text(_t('add_review')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text(
                    _t('reviewed_already'),
                    style: TextStyle(
                        color: AppColors.getTextColor(context), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

        if (_reviews.isEmpty)
          ProfessionalEmptyState(
            title: _t('no_reviews_yet'),
            message: _t('be_first_to_review'),
            icon: Icons.star_outline_rounded,
          )
        else
          ..._reviews.map((review) => _buildReviewCard(review)),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final user = review['users'] ?? {};
    final userName = user['full_name'] ?? _t('anonymous_user');
    final userImage = user['avatar_url'];
    final rating = (review['rating'] as num).toDouble();
    final comment = review['comment'] ?? '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getElevatedSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Icon(
                Icons.star_rounded,
                color: index < rating ? Colors.amber : Colors.white10,
                size: 24,
              );
            }),
          ),
          SizedBox(height: 20),
          Text(
            comment,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppColors.getTextColor(context), fontSize: 15, height: 1.6),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                userName,
                style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundImage: userImage != null
                    ? CachedNetworkImageProvider(userImage)
                    : null,
                backgroundColor: Colors.white10,
                child: userImage == null
                    ? Icon(Icons.person, color: AppColors.getTextColor(context).withOpacity(0.54), size: 18)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddReviewDialog() {
    double selectedRating = 5.0;
    final commentController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setState) => AlertDialog(
          backgroundColor: AppColors.of(context).dialog,
          title: Text(
            _t('add_review'),
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.getTextColor(context)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        selectedRating = index + 1.0;
                      });
                    },
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),
              TextField(
                controller: commentController,
                style: TextStyle(color: AppColors.getTextColor(context)),
                decoration: InputDecoration(
                  hintText: _t('your_comment_here'),
                  hintStyle: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.pop(dialogContext); // Close dialog

                  // Show loading
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text(_t('adding_review'))),
                  );

                  await _databaseService.addReview(
                    courseId: _course!.id,
                    rating: selectedRating,
                    comment: commentController.text,
                  );

                  // Reload and show success
                  await _loadReviews();
                  await _refreshCourseData();
                  await _checkUserReview();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text(_t('review_added_success')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                          content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: Text(_t('publish')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTinyTag(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  bool _checkAuthAndShowDialog() {
    if (!Provider.of<AuthService>(context, listen: false).isAuthenticated) {
      _showLoginRequiredDialog();
      return false;
    }
    return true;
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).dialog,
        title: Text(
          _t('login_required_title'),
          style: TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        content: Text(
          _t('login_required_desc'),
          style: TextStyle(
              color: AppColors.getTextColor(context, secondary: true), fontFamily: 'Cairo'),
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text(_t('cancel'), style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: Text(_t('login_title'),
                style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}
