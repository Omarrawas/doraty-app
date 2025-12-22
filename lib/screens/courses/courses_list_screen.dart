import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import 'course_details_screen.dart';
import '../../widgets/dynamic_gradient_background.dart';

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
  List<Map<String, dynamic>> _enrolledCourses = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Current, 1: Completed

  @override
  void initState() {
    super.initState();
    _loadEnrolledCourses();
  }

  @override
  void didUpdateWidget(CoursesListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload courses when widget updates
    _loadEnrolledCourses();
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

  Future<void> _unenrollCourse(String courseId, int index) async {
    try {
      await _databaseService.unenrollFromCourse(courseId);
      setState(() {
        _enrolledCourses.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إزالة الدورة من قائمتك')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
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
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTab(
                          title: 'الحالية',
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildTab(
                          title: 'المنتهية',
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
                                  description: courseData['description'] ?? '',
                                  instructorId: courseData['instructor_id'],
                                  instructorName:
                                      courseData['instructor_name'] ?? '',
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
                                  category: courseData['category'] ?? '',
                                  subject: courseData['subject'] ?? '',
                                  curriculum: [],
                                  isEnrolled: true,
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
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
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
          const Expanded(
            child: Text(
              'دوراتي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
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
            _selectedTab == 0 ? 'لا توجد دورات حالية' : 'لم تكمل أي دورة بعد',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedTab == 0
                ? 'ابدأ بإضافة دورات من الصفحة الرئيسية'
                : 'استمر في التعلم لإكمال دوراتك!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
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
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: const Text(
              'تأكيد الحذف',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.right,
            ),
            content: const Text(
              'هل تريد إزالة هذه الدورة من قائمتك؟',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
        );
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CourseDetailsScreen(course: course),
                    ),
                  );
                },
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
                          // Course Title
                          Text(
                            course.title,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Instructor
                          Text(
                            course.instructorName,
                            textAlign: TextAlign.right,
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
                                    '${progress.toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'التقدم',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
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
