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
import '../../widgets/shimmer_loader.dart';
import '../../widgets/empty_state.dart';
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
  final Map<int, bool> _expandedSections = {};

  // Lessons data
  List<Map<String, dynamic>> _lessons = [];
  List<Chapter> _chapters = [];
  bool _isLoadingLessons = true;

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
          _isLoadingLessons = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading lessons or chapters: $e');
      if (mounted) {
        setState(() {
          _isLoadingLessons = false;
        });
      }
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          // Video Player
          if (widget.course.videoUrl != null)
            VideoPreviewWidget(videoUrl: widget.course.videoUrl!)
          else
            _buildCourseImagePlaceholder(),
          
          const SizedBox(height: 24),
          
          // Course Info Card
          _buildCourseHeroInfo(isRTL),
        ],
      ),
    );
  }

  Widget _buildCourseImagePlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: widget.course.imageUrl ?? '',
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
          ),
          Container(
            height: 200,
            color: Colors.black26,
            child: const Center(
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHeroInfo(bool isRTL) {
    String locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return Column(
      crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          widget.course.getLocalizedTitle(locale),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: isRTL ? TextAlign.right : TextAlign.left,
        ),
        const SizedBox(height: 12),
        _buildHeroStatsRow(isRTL),
        const SizedBox(height: 20),
        _buildInstructorSmallCard(isRTL),
        const SizedBox(height: 24),
        _buildEnrollmentSection(isRTL),
      ],
    );
  }

  Widget _buildHeroStatsRow(bool isRTL) {
    return Row(
      mainAxisAlignment: isRTL ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        _buildStatBadge(Icons.bar_chart_rounded, widget.course.level ?? _t('all_levels')),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundImage: _instructorPhoto != null ? CachedNetworkImageProvider(_instructorPhoto!) : null,
            child: _instructorPhoto == null ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 8),
          Text(
            '${_t("instructor_title")} $_instructorName',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
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
          ),
          child: Text(
            '${_t("subscribe_now_prefix")}${widget.course.getLocalizedPrice(Provider.of<LocaleProvider>(context).locale)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        
        const SizedBox(height: 16),
        Center(child: Text(_t('or'), style: const TextStyle(color: Colors.white60))),
        const SizedBox(height: 16),
        
        // Own Button
        OutlinedButton(
          onPressed: () {}, // Action for owning the course
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            '${_t("own_this_course")} ${widget.course.getLocalizedPrice(Provider.of<LocaleProvider>(context).locale)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          _buildDetailSection(_t('about'), widget.course.description ?? '', isRTL),
          _buildCurriculumSectionVertical(isRTL),
          if (widget.course.outcomes.isNotEmpty)
            _buildListSection(_t('course_outcomes'), widget.course.outcomes, isRTL),
          if (widget.course.targetAudience.isNotEmpty)
            _buildListSection(_t('target_audience'), widget.course.targetAudience, isRTL),
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

  Widget _buildCurriculumSectionVertical(bool isRTL) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(_t('course_content'), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildContentTab(), // Reuse existing curriculum builder
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
                label: const Text('أضف تقييمك'),
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.greenAccent),
                  SizedBox(width: 8),
                  Text(
                    'لقد قمت بتقييم هذه الدورة',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

        if (_reviews.isEmpty)
          const ProfessionalEmptyState(
            title: 'لا توجد تقييمات بعد',
            message: 'كن أول من يقيم هذه الدورة ويشارك تجربته مع الآخرين.',
            icon: Icons.star_outline_rounded,
          )
        else
          ..._reviews.map((review) => _buildReviewCard(review)),
      ],
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final user = review['users'] ?? {};
    final userName = user['full_name'] ?? 'مستخدم';
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

  Widget _buildContentTab() {
    if (_isLoadingLessons) {
      return Column(
        children: List.generate(
          5,
          (index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerLoader.rectangular(height: 60),
          ),
        ),
      );
    }

    if (_lessons.isEmpty) {
      return ProfessionalEmptyState(
        title: _t('no_lessons_yet'),
        message: _t('course_content_working'),
        icon: Icons.auto_stories_rounded,
      );
    }

    // Group lessons by chapters
    final sections = <Map<String, dynamic>>[];

    if (_chapters.isNotEmpty) {
      // 1. Group by Chapters
      // Sort chapters by orderIndex
      _chapters.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (var chapter in _chapters) {
        final chapterLessons = _lessons.where((l) {
          return l['chapter_id'] == chapter.id;
        }).toList();

        if (chapterLessons.isNotEmpty) {
          sections.add({
            'title': chapter.title,
            'lessons': chapterLessons,
          });
        }
      }

      // 2. Add lessons without chapter (Uncategorized)
      final uncategorizedLessons = _lessons.where((l) {
        return l['chapter_id'] == null;
      }).toList();

      if (uncategorizedLessons.isNotEmpty) {
        sections.add({
          'title': _t('other_lessons'),
          'lessons': uncategorizedLessons,
        });
      }
    } else {
      // Fallback: If no chapters, show as one list or keep old logic if preferred.
      // Current preference: Move away from "every 5".
      // If purely no chapters defined, show all in one "Course Content" section
      // unless the list is huge? Let's just show all.
      sections.add({
        'title': _t('course_content'),
        'lessons': _lessons,
      });
    }

    return Column(
      children: sections.asMap().entries.map((entry) {
        final index = entry.key;
        final section = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCurriculumSection(
            title: section['title'],
            lessons: List<Map<String, dynamic>>.from(section['lessons']),
            sectionIndex: index,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCurriculumSection({
    required String title,
    required List<Map<String, dynamic>> lessons,
    required int sectionIndex,
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
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lessons.length} ${_t('lessons')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isExpanded)
                ...lessons.map((lesson) => _buildLessonItem(lesson)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLessonItem(Map<String, dynamic> lesson) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final lessonObj = Lesson.fromJson(lesson);
    final title = lessonObj.getLocalizedTitle(locale);
    final duration = lesson['duration'] ?? '0:00';
    final isCompleted = lesson['is_completed'] ?? false;
    final isFree = lesson['is_free'] ?? false;
    final orderIndex = lesson['order_index'] ?? 0;

    // Check if this lesson is locked
    bool isLocked = false;
    String lockReason = '';

    if (!isFree && !_isEnrolled) {
      isLocked = true;
      lockReason = _t('must_subscribe');
    } else if (orderIndex > 1 && !isFree) {
      // Find the previous lesson
      final previousLesson = _lessons.firstWhere(
        (l) => (l['order_index'] ?? 0) == orderIndex - 1,
        orElse: () => {},
      );

      // Lock if previous lesson is not completed
      if (previousLesson.isNotEmpty) {
        if (!(previousLesson['is_completed'] ?? false)) {
          isLocked = true;
          lockReason = _t('must_complete_previous');
        }
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLocked
            ? () {
                // Show message that lesson is locked
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lockReason,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontFamily: 'Cairo'),
                    ),
                    backgroundColor: Colors.orange.shade400,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            : () async {
                // Convert lesson map to Lesson object
                final lessonObj = Lesson.fromJson(lesson);

                // Convert all lessons to Lesson objects
                final allLessons =
                    _lessons.map((l) => Lesson.fromJson(l)).toList();

                // Navigate to lesson view
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => lesson_ui.LessonScreen(
                      lesson: lessonObj,
                      allLessons: allLessons,
                      courseTitle: widget.course.getLocalizedTitle(locale),
                      isEnrolled: _isEnrolled,
                    ),
                  ),
                );

                // Reload lessons after returning to update progress
                _loadLessons();
              },
        child: Opacity(
          opacity: isLocked ? 0.5 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Completion Icon
                Icon(
                  isLocked
                      ? Icons.lock_outline_rounded
                      : (isCompleted
                          ? Icons.check_circle_rounded
                          : (isFree ? Icons.play_circle_fill_rounded : Icons.play_circle_outline_rounded)),
                  color: isLocked
                      ? Colors.white24
                      : (isCompleted ? Colors.greenAccent : Colors.white70),
                  size: 24,
                ),
                const SizedBox(width: 16),
                
                // Lesson Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isLocked ? Colors.white38 : Colors.white,
                        ),
                        textAlign: locale == 'ar' ? TextAlign.right : TextAlign.left,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            lessonObj.contentType == 'video' 
                                ? Icons.videocam_outlined 
                                : Icons.description_outlined,
                            size: 14,
                            color: Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            duration,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                          ),
                          if (isFree) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _t('free'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Extra indicator or arrow
                if (!isLocked)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.2),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
