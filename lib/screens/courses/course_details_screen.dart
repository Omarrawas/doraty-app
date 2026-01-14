import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart'
    hide DownloadProgress;
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/lesson.dart';
import '../../models/chapter.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/certificate_service.dart';
import '../lesson/lesson_screen.dart' as lesson_ui;
import '../teacher/teacher_profile_screen.dart';
import '../subscription/subscription_plans_screen.dart';
import '../../core/services/course_download_service.dart';
import '../../core/services/offline_storage_service.dart';
import '../../models/download_progress.dart';


class CourseDetailsScreen extends StatefulWidget {
  final Course course;

  const CourseDetailsScreen({
    super.key,
    required this.course,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
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
  bool _isCheckingEnrollment = true;
  String? _instructorPhoto;
  late String _instructorName;
  late double _currentRating;
  late int _reviewsCount;
  late int _studentsCount;
  final DatabaseService _databaseService = DatabaseService();
  String? _currentUserName;
  bool _isCertificateLoading = false;
  bool _isCourseCompleted = false;

  // Offline & Downloads
  bool _isDownloaded = false;
  DownloadProgress? _downloadProgress;
  StreamSubscription<DownloadProgress>? _downloadSubscription;
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  final CourseDownloadService _downloadService = CourseDownloadService();

  @override
  void initState() {
    super.initState();
    _checkOfflineStatus(); // Check if course is downloaded
    _instructorPhoto = widget.course.instructorPhoto;
    _instructorName = widget.course.instructorName;
    _currentRating = widget.course.rating;
    _reviewsCount = 0; // Will be updated by _loadReviews
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    _loadLessons();
    _loadReviews();
    _checkEnrollment();
    _refreshInstructorInfo();
    _refreshCourseData();
    _studentsCount = widget.course.studentsCount; // Initialize students count
    _checkUserReview();
    _fetchUserName();


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
          _currentRating = (courseData['rating'] as num).toDouble();
          _studentsCount = courseData['students_count'] ?? _studentsCount;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing course data: $e');
    }
  }

  Future<void> _fetchUserName() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId != null) {
        final profile = await _databaseService.getUserProfile(userId);
        if (mounted) {
          setState(() {
            _currentUserName = profile['full_name'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
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
          _instructorName = profile['full_name'] ?? _instructorName;
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
          _isCheckingEnrollment = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking enrollment: $e');
      if (mounted) {
        setState(() {
          _isCheckingEnrollment = false;
        });
      }
    }
  }

  Future<void> _loadLessons() async {
    try {
      final lessons = await _databaseService.getLessons(widget.course.id);
      final chapters = await _databaseService.getChapters(widget.course.id);

      if (mounted) {
        setState(() {
          _lessons = lessons;
          _chapters = chapters;
          _isLoadingLessons = false;
          // Check completion
          if (lessons.isNotEmpty) {
            _isCourseCompleted =
                lessons.every((l) => l['is_completed'] == true);
          }
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
          _reviewsCount = reviews.length;
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

  Future<void> _checkOfflineStatus() async {
    final offlineCourse = await _offlineStorage.getCourse(widget.course.id);
    if (mounted) {
      setState(() {
        _isDownloaded = offlineCourse != null;
      });
    }
  }

  void _downloadCourse() {
    // Only allow download if enrolled
    if (!_isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب الاشتراك في الدورة أولاً')),
      );
      return;
    }

    _downloadSubscription?.cancel();
    _downloadSubscription = _downloadService
        .downloadCourse(widget.course.id,
            includeVideos: false) // Optional: confirm/ask user
        .listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress = progress;
          if (progress.status == DownloadStatus.completed) {
            _isDownloaded = true;
            _downloadProgress = null;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحميل الدورة بنجاح')),
            );
          } else if (progress.status == DownloadStatus.failed) {
            _downloadProgress = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل التحميل: ${progress.error}')),
            );
          }
        });
      }
    });
  }

  Future<void> _deleteOfflineCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المحتوى المحلي'),
        content: const Text(
            'هل أنت متأكد من حذف هذه الدورة من الجهاز؟ ستحتاج إلى إنترنت لتصفحها مجدداً.'),
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

    if (confirmed == true) {
      await _offlineStorage.deleteCourse(widget.course.id);
      if (mounted) {
        setState(() {
          _isDownloaded = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المحتوى المحلي')),
        );
      }
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              // Header with Course Image
              _buildHeader(),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Course Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          widget.course.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Instructor Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildInstructorCard(),
                      ),

                      const SizedBox(height: 20),

                      // Subscribe Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSubscribeButton(),
                      ),

                      const SizedBox(height: 30),

                      // Tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildTabs(),
                      ),

                      const SizedBox(height: 20),

                      // Tab Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildTabContent(),
                      ),

                      const SizedBox(height: 30),
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

  Widget _buildHeader() {
    return Stack(
      children: [
        // Course Image
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: CachedNetworkImageProvider(widget.course.imageUrl ?? ''),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Back Button
        // Download Button
        Positioned(
          top: 10,
          left: 10,
          child: _buildDownloadButton(),
        ),

        // Back Button
        Positioned(
          top: 10,
          right: 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  },
                ),
              ),
            ),
          ),
        ),

        // Premium Badge
        if (widget.course.price > 0)
          Positioned(
            top: 60, // Moved down
            left: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Premium Course',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    if (_downloadProgress != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: _downloadProgress!.percentage,
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(_downloadProgress!.percentage * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (!_isEnrolled) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _isDownloaded
                ? Colors.green.withOpacity(0.2)
                : AppColors.getGlassColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDownloaded
                  ? Colors.green.withOpacity(0.5)
                  : AppColors.getGlassColor(context, opacity: 0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(
              _isDownloaded ? Icons.download_done : Icons.download,
              color: _isDownloaded ? Colors.green : Colors.white,
            ),
            onPressed: () {
              if (_isDownloaded) {
                _deleteOfflineCourse();
              } else {
                _downloadCourse();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInstructorCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              debugPrint(
                  '👆 Instructor card tapped. ID: ${widget.course.instructorId}');
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
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('لا يوجد ملف شخصي لهذا المدرب حالياً')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getGlassColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Instructor Photo
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: _instructorPhoto ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Image.network(
                          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_instructorName)}&background=random&color=fff&size=200',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Instructor Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الأستاذ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _instructorName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rating
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 24,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _currentRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_reviewsCount تقييم',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_studentsCount طالب',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    if (_isCheckingEnrollment) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_isCourseCompleted && _isEnrolled) {
      return Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)], // Gold for certificate
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _downloadCertificate,
            child: Center(
              child: _isCertificateLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.workspace_premium, color: Colors.black),
                        SizedBox(width: 8),
                        Text(
                          'تحميل الشهادة',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isEnrolled
              ? [Colors.green.shade400, Colors.green.shade600]
              : [const Color(0xFF7B2CBF), const Color(0xFF5A67D8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isEnrolled
                ? Colors.green.withOpacity(0.4)
                : const Color(0xFF7B2CBF).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _handleEnrollment,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isEnrolled) ...[
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isEnrolled
                      ? 'متابعة التعلم'
                      : 'اشترك الآن - ${widget.course.formattedPrice}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadCertificate() async {
    if (_currentUserName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديث الملف الشخصي أولاً')),
      );
      return;
    }

    setState(() {
      _isCertificateLoading = true;
    });

    try {
      await CertificateService().downloadCertificate(
        studentName: _currentUserName!,
        courseName: widget.course.title,
        instructorName: _instructorName,
        date: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error downloading certificate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تحميل الشهادة: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCertificateLoading = false;
        });
      }
    }
  }

  Future<void> _handleEnrollment() async {
    if (_isEnrolled) {
      _tabController.animateTo(1); // Switch to content tab
      return;
    }

    // Navigate to subscription plans instead of direct enrollment
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionPlansScreen(),
      ),
    ).then((_) {
      // Re-check enrollment after returning
      _checkEnrollment();
    });
  }

  Widget _buildTabs() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1,
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7B2CBF),
                  Color(0xFF5A67D8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'نظرة عامة'),
              Tab(text: 'المحتوى'),
              Tab(text: 'التقييمات'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildContentTab();
      case 2:
        return _buildReviewsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildOverviewTab() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
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
          child: Text(
            widget.course.description ?? 'لا يوجد وصف',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
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
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_border,
                  size: 64,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'لا توجد تقييمات بعد',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
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
          title: const Text(
            'أضف تقييمك',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white),
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
                  hintText: 'اكتب تعليقك هنا...',
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
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.pop(dialogContext); // Close dialog

                  // Show loading
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('جاري إضافة التقييم...')),
                  );

                  await _databaseService.addReview(
                    courseId: widget.course.id,
                    rating: selectedRating,
                    comment: commentController.text,
                  );

                  // Reload and show success
                  await _loadReviews();
                  await _refreshCourseData();
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم إضافة تقييمك بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('خطأ: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
              ),
              child: const Text('نشر'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTab() {
    if (_isLoadingLessons) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_lessons.isEmpty) {
      return Center(
        child: Text(
          'لا توجد دروس متاحة حالياً',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
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
          'title': 'دروس أخرى',
          'lessons': uncategorizedLessons,
        });
      }
    } else {
      // Fallback: If no chapters, show as one list or keep old logic if preferred.
      // Current preference: Move away from "every 5".
      // If purely no chapters defined, show all in one "Course Content" section
      // unless the list is huge? Let's just show all.
      sections.add({
        'title': 'محتوى الدورة',
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
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _expandedSections[sectionIndex] = !isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_left,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
    final title = lesson['title'] ?? '';
    final duration = lesson['duration'] ?? '0:00';
    final isCompleted = lesson['is_completed'] ?? false;
    final isFree = lesson['is_free'] ?? false;
    final orderIndex = lesson['order_index'] ?? 0;

    // Check if this lesson is locked
    bool isLocked = false;
    if (orderIndex > 1 && !isFree) {
      // Find the previous lesson
      final previousLesson = _lessons.firstWhere(
        (l) => (l['order_index'] ?? 0) == orderIndex - 1,
        orElse: () => {},
      );

      // Lock if previous lesson is not completed
      if (previousLesson.isNotEmpty) {
        isLocked = !(previousLesson['is_completed'] ?? false);
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
                    content: const Text(
                      'يجب إكمال الدرس السابق أولاً',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontFamily: 'Cairo'),
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
                      courseTitle: widget.course.title,
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
                Text(
                  duration,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (isFree)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withOpacity(0.5),
                      ),
                    ),
                    child: const Text(
                      'مجاني',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  isLocked
                      ? Icons.lock
                      : (isCompleted
                          ? Icons.check_circle
                          : Icons.play_circle_outline),
                  color: isLocked
                      ? Colors.orange
                      : (isCompleted ? Colors.greenAccent : Colors.white70),
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
