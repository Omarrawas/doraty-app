import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/lesson.dart';
import '../../models/chapter.dart';
import '../lesson/lesson_screen.dart' as lesson_ui;

import '../../core/services/database_service.dart';
import '../../widgets/video_preview_widget.dart';
import '../subscription/payment_screen.dart';
import '../teacher/teacher_profile_screen.dart';
import '../../widgets/shimmer_loader.dart';
import '../../widgets/empty_state.dart';
import 'course_content_screen.dart';
import 'package:provider/provider.dart';
import '../../core/utils/error_utils.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/string_utils.dart';



class CourseDetailsScreen extends StatefulWidget {
  final Course course;

  final String? heroTag;

  const CourseDetailsScreen({
    super.key,
    required this.course,
    this.heroTag,
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
  Map<String, dynamic>? _userReview;
  String? _instructorPhoto;
  late String _instructorName;
  late int _studentsCount;
  final DatabaseService _databaseService = DatabaseService();

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _instructorPhoto = widget.course.instructorPhoto;
    _instructorName =
        StringUtils.cleanTeacherName(widget.course.instructorName);
    _loadLessons();
    _loadReviews();
    _checkEnrollment();
    _refreshInstructorInfo();
    _refreshCourseData();
    _studentsCount = widget.course.studentsCount; // Initialize students count
    _checkUserReview();


    debugPrint(
        '🏁 CourseDetailsScreen initialized for Course ID: ${widget.course.id}');
    debugPrint('👨‍🏫 Instructor ID: ${widget.course.instructorId}');
    debugPrint(
        '👨‍🏫 Instructor Name (passed): ${widget.course.instructorName}');
  }

  Future<void> _checkUserReview() async {
    try {
      final review =
          await _databaseService.getUserReviewForCourse(widget.course.id);
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
    try {
      final courseData = await _databaseService.getCourseById(widget.course.id);
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
    if (widget.course.instructorId == null) return;
    try {
      final profile =
          await _databaseService.getUserProfile(widget.course.instructorId!);
      if (mounted && profile.isNotEmpty) {
        setState(() {
          _instructorPhoto = profile['avatar_url'];
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
    try {
      final isEnrolled = await _databaseService.isEnrolled(widget.course.id);
      if (mounted) {
        setState(() {
          _isEnrolled = isEnrolled;
        });
      }
    } catch (e) {
      debugPrint('Error checking enrollment: $e');
    }
  }

  Future<void> _loadLessons() async {
    try {
      final results = await Future.wait([
        _databaseService.getLessons(widget.course.id),
        _databaseService.getChapters(widget.course.id),
      ]);

      final lessons = results[0] as List<Map<String, dynamic>>;
      final chapters = results[1] as List<Chapter>;

      if (mounted) {
        setState(() {
          _lessons = lessons;
          _chapters = chapters;
        });
      }
    } catch (e) {
      debugPrint('Error loading lessons or chapters: $e');
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _databaseService.getReviews(widget.course.id);
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
                      const SizedBox(height: 30),
                      _buildMainContent(isRTL),
                      const SizedBox(height: 50),
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

  Widget _buildTopNavBar(bool isRTL) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button (On the right for RTL)
          if (!isRTL) _buildNavBackButton(),
          
          // Logo
          Image.asset(
            'assets/images/logo.png', // Assuming this is the logo path
            height: 30,
            errorBuilder: (context, error, stackTrace) => const Text(
              'DAWRAT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          
          if (isRTL) _buildNavBackButton(),
        ],
      ),
    );
  }

  Widget _buildNavBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildHeroSection(bool isRTL) {
    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 800;

      if (isWide) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
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
                const SizedBox(width: 40),
                Expanded(
                  flex: 6,
                  child: _buildCourseHeroInfo(isRTL, isWide: true),
                ),
              ] else ...[
                Expanded(
                  flex: 6,
                  child: _buildCourseHeroInfo(isRTL, isWide: true),
                ),
                const SizedBox(width: 40),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          children: [
            _buildMediaPreview(),
            const SizedBox(height: 24),
            _buildCourseHeroInfo(isRTL),
          ],
        ),
      );
    });
  }

  Widget _buildMediaPreview({bool isSquare = false}) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: widget.course.videoUrl != null && widget.course.videoUrl!.isNotEmpty
          ? VideoPreviewWidget(
              videoUrl: widget.course.videoUrl!,
              showHeader: !isSquare, // Hide header if square (side-by-side)
              thumbnailUrl: widget.course.imageUrl, // تمرير صورة الدورة
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
          CachedNetworkImage(
            imageUrl: widget.course.imageUrl ?? '',
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) =>
                Container(color: Colors.grey[900]),
          ),
          Container(
            color: Colors.black26,
            child: const Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Colors.white, size: 64),
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
          widget.course.getLocalizedTitle(locale),
          style: TextStyle(
              fontSize: isWide ? 32 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.white),
          textAlign: isRTL ? TextAlign.right : TextAlign.left,
        ),
        if (widget.course.categories.isNotEmpty || widget.course.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: isRTL ? WrapAlignment.end : WrapAlignment.start,
              children: [
                ...widget.course.categories
                    .map((cat) => _buildTinyTag(cat, Colors.blueAccent)),
                ...widget.course.tags.map((tag) => _buildTinyTag(
                    '#${AppStrings.get(tag, locale)}', Colors.purpleAccent)),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _buildHeroStatsRow(isRTL),
        const SizedBox(height: 20),
        _buildInstructorSmallCard(isRTL),
        const SizedBox(height: 24),
        if (!_isEnrolled)
          _buildEnrollmentSection(isRTL)
        else
          _buildContinueLearningButton(isRTL),
      ],
    );
  }

  Widget _buildHeroStatsRow(bool isRTL) {
    return Row(
      mainAxisAlignment: isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        _buildStatBadge(Icons.bar_chart_rounded, _t(widget.course.level ?? 'all_levels')),
        const SizedBox(width: 12),
        _buildStatBadge(Icons.access_time_rounded, '${widget.course.durationHours ?? "0"} ${_t("hours_short")}'),
        const SizedBox(width: 12),
        _buildStatBadge(Icons.play_circle_outline_rounded, '${widget.course.lessonsCount} ${_t("lessons")}'),
      ],
    );
  }

  Widget _buildStatBadge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white60, size: 14),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _buildInstructorSmallCard(bool isRTL) {
    return InkWell(
      onTap: () {
        if (widget.course.instructorId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherProfileScreen(
                teacherId: widget.course.instructorId!,
                teacherName: _instructorName,
                teacherPhoto: _instructorPhoto,
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundImage: _instructorPhoto != null
                  ? CachedNetworkImageProvider(_instructorPhoto!)
                  : null,
              child: _instructorPhoto == null
                  ? const Icon(Icons.person, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              '${_t("instructor_title")} $_instructorName',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.5), size: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentSection(bool isRTL) {
    return Column(
      crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          _t('register_and_get'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildBenefitItem(Icons.all_inclusive_rounded, _t('unending_views')),
        _buildBenefitItem(Icons.workspace_premium_rounded, _t('completion_certificate')),
        _buildBenefitItem(Icons.chat_bubble_outline_rounded, _t('contact_coach')),
        
        const SizedBox(height: 30),
        
        // Main Subscribe Button
        ElevatedButton(
          onPressed: _handleEnrollment,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: AppColors.primaryPurple.withOpacity(0.5),
          ),
          child: Text(
            '${_t("subscribe_now_prefix")}${widget.course.getLocalizedPrice(Provider.of<LocaleProvider>(context).locale)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueLearningButton(bool isRTL) {
    return Column(
      crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 12),
              Text(
                _t('enrolled_already'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseContentScreen(
                  course: widget.course,
                  lessonsData: _lessons,
                  chapters: _chapters,
                  isEnrolled: true,
                ),
              ),
            );
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(_t('enter_course')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primaryPurple,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isRTL) {
    return Column(
      children: [
        _buildDetailSection(
            _t('about'), widget.course.description ?? '', isRTL),
        _buildCourseContentButton(isRTL),
        if (widget.course.outcomes.isNotEmpty)
          _buildListSection(
              _t('course_outcomes'), widget.course.outcomes, isRTL),
        if (widget.course.targetAudience.isNotEmpty)
          _buildListSection(
              _t('target_audience'), widget.course.targetAudience, isRTL),
        _buildReviewsSection(isRTL),
      ],
    );
  }



  Widget _buildDetailSection(String title, String content, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15, height: 1.6),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(String title, List<String> items, bool isRTL) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Column(
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, color: Colors.purpleAccent, size: 6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 15),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseContentButton(bool isRTL) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(_t('course_content'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseContentScreen(
                    course: widget.course,
                    lessonsData: _lessons,
                    chapters: _chapters,
                    isEnrolled: _isEnrolled, // تمرير حالة الاشتراك
                  ),
                ),
              );
            },
            icon: const Icon(Icons.list_alt_rounded),
            label: Text(_t('course_content')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.primaryPurple.withOpacity(0.5)),
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
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(_t('reviews'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
               if (_isEnrolled && _userReview == null)
                  TextButton(onPressed: _showAddReviewDialog, child: Text(_t('add_review'))),
            ],
          ),
        ),
        _buildReviewsTab(), // Reuse existing reviews builder
      ],
    );
  }
  Future<void> _handleEnrollment() async {
    if (_isEnrolled && _lessons.isNotEmpty) {
      final firstLesson = Lesson.fromJson(_lessons.first);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => lesson_ui.LessonScreen(
            lesson: firstLesson,
            courseTitle: widget.course.title,
            isEnrolled: true,
          ),
        ),
      );
      return;
    }

    // Navigate to payment screen directly for this course
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          amount: widget.course.discountedPrice,
          title: widget.course.title,
          course: widget.course,
        ),
      ),
    ).then((_) {
      // Re-check enrollment after returning
      _checkEnrollment();
    });
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return Column(
        children: List.generate(
          3,
          (index) => const Padding(
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
              margin: const EdgeInsets.only(bottom: 20),
              child: ElevatedButton.icon(
                onPressed: _showAddReviewDialog,
                icon: const Icon(Icons.rate_review),
                label: Text(_t('add_review')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.greenAccent),
                  const SizedBox(width: 8),
                  Text(
                    _t('reviewed_already'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
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
    final date = review['created_at'] != null
        ? DateTime.parse(review['created_at']).toString().split(' ')[0]
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage:
                          userImage != null ? NetworkImage(userImage) : null,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: userImage == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            date,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: index < rating ? Colors.amber : Colors.grey,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    comment,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
          backgroundColor: const Color(0xFF1E1E2C),
          title: Text(
            _t('add_review'),
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white),
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
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _t('your_comment_here'),
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
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
                    courseId: widget.course.id,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
}
