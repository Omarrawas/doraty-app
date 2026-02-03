import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/offline_storage_service.dart';
import 'course_details_screen.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

class CoursesListScreen extends StatefulWidget {
  final bool showBackButton;

  const CoursesListScreen({
    super.key,
    this.showBackButton = true,
  });

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  List<Map<String, dynamic>> _enrolledCourses = [];
  Set<String> _offlineCourseIds = {};
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Current, 1: Completed

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
    _loadOfflineStatus();
  }

  Future<void> _loadOfflineStatus() async {
    final courses = await _offlineStorage.getAllCourses();
    if (mounted) {
      setState(() {
        _offlineCourseIds = courses.map((c) => c.id).toSet();
      });
    }
  }

  @override
  void didUpdateWidget(CoursesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload courses when widget updates
    _loadEnrolledCourses();
    _loadOfflineStatus();
  }


  Future<void> _loadEnrolledCourses() async {
    try {
      final enrollments =
          await _databaseService.getEnrolledCoursesWithProgress();

      debugPrint('📚 Loaded ${enrollments.length} enrollments');
      debugPrint('📚 User ID: ${SupabaseService.instance.currentUserId}');

      if (mounted) {
        setState(() {
          _enrolledCourses = enrollments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading enrolled courses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _unenrollCourse(String courseId, int index) async {
    try {
      await _databaseService.unenrollFromCourse(courseId);
      if (mounted) {
        setState(() {
          _enrolledCourses.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('unenroll_success'))),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('error_label')}: $e')),
        );
      }
      return false;
    }
  }

  Future<bool?> _showDeleteConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _t('confirm_delete_title'), // Replaced 'تأكيد الحذف'
          style: TextStyle(
            color: AppColors.getTextColor(context),
            fontWeight: FontWeight.normal,
          ),
          textAlign:
              TextAlign.center, // Changed from right for LTR/RTL consistency
        ),
        content: Text(
          _t('confirm_delete_message'), // Replaced 'هل تريد إزالة هذه الدورة من قائمتك؟'
          style: TextStyle(
              color: AppColors.getTextColor(context, secondary: true)),
          textAlign: TextAlign.center, // Changed from right
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              _t('cancel'), // Replaced 'إلغاء'
              style: const TextStyle(color: AppColors.primaryPurple),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t('delete')), // Replaced 'حذف'
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              const SizedBox(height: 20),

              // Courses List
              // Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context, opacity: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTab(
                          title: _t('current'),
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildTab(
                          title: _t('completed'),
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Courses List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadEnrolledCourses,
                  color: AppColors.primaryPurple,
                  backgroundColor: Colors.white,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Builder(
                          builder: (context) {
                            final filteredCourses =
                                _enrolledCourses.where((enrollment) {
                              final progress = (enrollment['progress'] as num?)
                                      ?.toDouble() ??
                                  0.0;
                              final isCompleted = progress >= 100.0;
                              return _selectedTab == 0
                                  ? !isCompleted
                                  : isCompleted;
                            }).toList();

                            if (filteredCourses.isEmpty) {
                              // Wrap empty state in SingleChildScrollView to allow refresh even when empty
                              return LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: _buildEmptyState(),
                                    ),
                                  );
                                },
                              );
                            }

                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: filteredCourses.length,
                              itemBuilder: (context, index) {
                                final enrollment = filteredCourses[index];
                                final courseData = enrollment['courses'];

                                if (courseData == null) return const SizedBox();

                                final course = Course(
                                  id: courseData['id'],
                                  title: courseData['title'] ?? '',
                                  titleEn: courseData['title_en'],
                                  description: courseData['description'] ?? '',
                                  descriptionEn: courseData['description_en'],
                                  instructorId: courseData['instructor_id'],
                                  instructorName:
                                      courseData['instructor_name'] ?? '',
                                  instructorFullNameEn:
                                      courseData['instructor_full_name_en'],
                                  instructorPhoto:
                                      courseData['instructor_photo'] ?? '',
                                  imageUrl: courseData['image_url'] ??
                                      courseData['thumbnail'] ??
                                      '',
                                  price: (courseData['price'] as num?)
                                          ?.toDouble() ??
                                      0,
                                  rating: (courseData['rating'] as num?)
                                          ?.toDouble() ??
                                      0,
                                  studentsCount:
                                      courseData['students_count'] ?? 0,
                                  lessonsCount:
                                      courseData['lessons_count'] ?? 0,
                                  durationHours: courseData['duration_hours']
                                          ?.toString() ??
                                      courseData['duration'],
                                  categories:
                                      courseData['categories_names'] != null
                                          ? List<String>.from(
                                              courseData['categories_names'])
                                          : (courseData['category'] != null
                                              ? [courseData['category']]
                                              : []),
                                  subject: courseData['subject'] ?? '',
                                  subjectEn: courseData['subject_en'],
                                  curriculum: const [],
                                  isEnrolled: true,
                                  isPublished: courseData['is_published'] ?? true,
                                );

                                final progress =
                                    (enrollment['progress'] as num?)
                                            ?.toDouble() ??
                                        0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child:
                                      _buildCourseCard(course, progress, index),
                                );
                              },
                            );
                          },
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          if (widget.showBackButton)
            ClipRRect(
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              _t('my_courses'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            _selectedTab == 0
                ? _t('no_active_courses') // Replaced 'لا توجد دورات حالية'
                : _t('no_completed_courses'), // Replaced 'لم تكمل أي دورة بعد'
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _selectedTab == 0
                  ? _t(
                      'start_learning_message') // Replaced 'ابدأ بإضافة دورات من الصفحة الرئيسية'
                  : _t(
                      'keep_learning_message'), // Replaced 'استمر في التعلم لإكمال دوراتك!'
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Course course, double progress, int index) {
    return Dismissible(
      key: Key(course.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmation();
      },
      onDismissed: (direction) {
        _unenrollCourse(course.id, index);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: course.isPublished
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CourseDetailsScreen(course: course),
                          ),
                        );
                      }
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course Image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: course.imageUrl ?? '',
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          height: 150,
                          color: Colors.white.withOpacity(0.2),
                          child: const Icon(
                            Icons.image,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.getLocalizedTitle(
                                Provider.of<LocaleProvider>(context).locale),
                            textAlign:
                                Provider.of<LocaleProvider>(context).locale ==
                                        'ar'
                                    ? TextAlign.right
                                    : TextAlign.left,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),

                          // Offline Badge
                          if (_offlineCourseIds.contains(course.id))
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.offline_pin, 
                                    color: Colors.greenAccent.shade400, 
                                    size: 16
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _t('offline_badge_label'), // Replaced 'محمّل على الجهاز'
                                    style: TextStyle(
                                      color: Colors.greenAccent.shade400,
                                      fontSize: 11,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (!course.isPublished)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: Colors.white70, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _t('course_unavailable_label'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  // Delete Button
                                  TextButton.icon(
                                    onPressed: () async {
                                      final confirmed =
                                          await _showDeleteConfirmation();
                                      if (confirmed == true) {
                                        _unenrollCourse(course.id, index);
                                      }
                                    },
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent, size: 18),
                                    label: Text(
                                      _t('unenroll_button_label'),
                                      style: const TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      backgroundColor:
                                          Colors.red.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 8),

                          // Instructor
                          Text(
                            course.getLocalizedInstructorName(
                                Provider.of<LocaleProvider>(context).locale),
                            textAlign:
                                Provider.of<LocaleProvider>(context).locale ==
                                        'ar'
                                    ? TextAlign.right
                                    : TextAlign.left,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Progress Bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _t('progress_label'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '${progress.toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress / 100,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryPurple,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
