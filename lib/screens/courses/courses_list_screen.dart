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
import '../../core/utils/error_utils.dart';

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
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
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
    final double screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    double childAspectRatio = 1.15; // Increased height for mobile

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.85;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 0.8;
    } else if (screenWidth > 550) {
      crossAxisCount = 2;
      childAspectRatio = 0.75;
    }

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Scrollbar(
            thickness: 6,
            radius: const Radius.circular(10),
            interactive: true,
            child: CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(child: _buildHeader()),

                // Tabs
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverToBoxAdapter(
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
                ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 10)),

                // Courses Grid
                _isLoading
                    ? SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white.withOpacity(0.5))),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final filteredCourses =
                              _enrolledCourses.where((enrollment) {
                            final progress =
                                (enrollment['progress'] as num?)?.toDouble() ??
                                    0.0;
                            final isCompleted = progress >= 100.0;
                            return _selectedTab == 0
                                ? !isCompleted
                                : isCompleted;
                          }).toList();

                          if (filteredCourses.isEmpty) {
                            return SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildEmptyState(),
                            );
                          }

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final enrollment = filteredCourses[index];
                                  final courseData = enrollment['courses'];

                                  if (courseData == null) {
                                    return const SizedBox();
                                  }

                                  final course = Course.fromJson(courseData);
                                  final progress =
                                      (enrollment['progress'] as num?)
                                              ?.toDouble() ??
                                          0;

                                  return _buildCourseCard(
                                      course, progress, index);
                                },
                                childCount: filteredCourses.length,
                              ),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: childAspectRatio,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 20,
                              ),
                            ),
                          );
                        },
                      ),

                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
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
    final locale = Provider.of<LocaleProvider>(context).locale;

    return Dismissible(
      key: Key(course.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (direction) async => await _showDeleteConfirmation(),
      onDismissed: (direction) => _unenrollCourse(course.id, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
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
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Info (Top)
                      Text(
                        course.getLocalizedTitle(locale),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        course.getLocalizedInstructorName(locale),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Progress Bar
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${progress.toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_offlineCourseIds.contains(course.id))
                                Icon(Icons.offline_pin,
                                    color: Colors.greenAccent.shade400,
                                    size: 12),
                            ],
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: Colors.white.withOpacity(0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primaryPurple,
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // Course Image (Bottom)
                      Expanded(
                        child: Center(
                          child: Hero(
                            tag: 'course_list_image_${course.id}',
                            child: AspectRatio(
                              aspectRatio: 1.8, // Shorter image to save space
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: course.imageUrl ?? '',
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: Colors.white10,
                                    child: const Icon(Icons.image,
                                        color: Colors.white24, size: 30),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (!course.isPublished)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _t('course_unavailable_label'),
                            style: const TextStyle(
                                color: Colors.redAccent, fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
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
