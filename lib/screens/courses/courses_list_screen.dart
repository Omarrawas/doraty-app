import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../widgets/course_card.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/error_utils.dart';

class CoursesListScreen extends StatefulWidget {
  final bool showBackButton;

  CoursesListScreen({
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

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

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
              style: TextStyle(color: AppColors.primaryPurple),
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
    int crossAxisCount;
    double childAspectRatio;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 0.85;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 0.8;
    } else if (screenWidth > 550) {
      crossAxisCount = 2;
      childAspectRatio = 0.75;
    } else {
      crossAxisCount = 2; // Show 2 per row even on mobile
      childAspectRatio = 0.65;
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
                      EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.all(4),
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

                SliverPadding(padding: EdgeInsets.only(bottom: 10)),

                // Courses Grid
                _isLoading
                    ? SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.getTextColor(context, secondary: true))),
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
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final enrollment = filteredCourses[index];
                                  final courseData = enrollment['courses'];

                                  if (courseData == null) {
                                    return SizedBox();
                                  }

                                  final course = Course.fromJson(courseData);
                                  final progress =
                                      (enrollment['progress'] as num?)
                                              ?.toDouble() ??
                                          0;

                                  return Dismissible(
                                    key: Key(course.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerLeft,
                                      padding: EdgeInsets.only(left: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Icon(Icons.delete,
                                          color: AppColors.getTextColor(context), size: 32),
                                    ),
                                    confirmDismiss: (direction) async =>
                                        await _showDeleteConfirmation(),
                                    onDismissed: (direction) =>
                                        _unenrollCourse(course.id, index),
                                    child: CourseCard(
                                      course: course,
                                      progress: progress,
                                      heroTag: 'course_list_image_${course.id}',
                                    ),
                                  );
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

                SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          if (widget.showBackButton)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                    icon: Icon(
                      Provider.of<LocaleProvider>(context, listen: false).locale == 'ar'
                          ? Icons.arrow_forward_ios_rounded
                          : Icons.arrow_back_ios_new_rounded,
                      color: AppColors.getTextColor(context),
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            )
          else
            SizedBox(width: 48),
          Expanded(
            child: Text(
              _t('my_courses'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          SizedBox(width: 48),
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
            color: AppColors.getTextColor(context, secondary: true),
          ),
          SizedBox(height: 20),
          Text(
            _selectedTab == 0
                ? _t('no_active_courses') // Replaced 'لا توجد دورات حالية'
                : _t('no_completed_courses'), // Replaced 'لم تكمل أي دورة بعد'
            style: TextStyle(
              fontSize: 18,
              color: AppColors.getTextColor(context, secondary: true),
              fontWeight: FontWeight.normal,
            ),
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _selectedTab == 0
                  ? _t(
                      'start_learning_message') // Replaced 'ابدأ بإضافة دورات من الصفحة الرئيسية'
                  : _t(
                      'keep_learning_message'), // Replaced 'استمر في التعلم لإكمال دوراتك!'
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextColor(context, secondary: true),
              ),
            ),
          ),
        ],
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
        padding: EdgeInsets.symmetric(vertical: 10),
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
