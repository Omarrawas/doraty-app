import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../admin/courses_management_screen.dart';
import 'manage_exams_screen.dart';
import 'students_results_screen.dart';
import 'package:intl/intl.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final DatabaseService _db = DatabaseService();

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentExams = [];
  List<Map<String, dynamic>> _teacherCourses = [];

  final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: 'ل.س ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Load teacher's courses
      final courses = await _db.getTeacherCourses();

      // Load teacher's exams
      final exams = await _db.getTeacherExams();

      // Calculate stats
      final publishedExams =
          exams.where((e) => e['is_published'] == true).length;
      final draftExams = exams.where((e) => e['is_published'] == false).length;

      // Load teacher's statistics
      final userId = SupabaseService.instance.currentUserId;
      Map<String, dynamic> teacherStats = {};
      if (userId != null) {
        teacherStats = await _db.getTeacherStatistics(userId);
      }

      setState(() {
        _teacherCourses = courses;
        _recentExams = exams.take(5).toList();
        _stats = {
          'total_courses': courses.length,
          'total_exams': exams.length,
          'published_exams': publishedExams,
          'draft_exams': draftExams,
          'total_revenue': teacherStats['total_revenue'] ?? 0.0,
          'total_students': teacherStats['total_users'] ?? 0,
          'total_attempts': teacherStats['total_attempts'] ?? 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  color: Colors.white,
                  backgroundColor: AppColors.primaryPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeader(context),

                        const SizedBox(height: 24),

                        // Stats Cards
                        _buildStatsCards(context),

                        const SizedBox(height: 24),

                        // Quick Actions
                        _buildQuickActions(context),

                        const SizedBox(height: 24),

                        // Recent Exams
                        _buildRecentExams(context),

                        const SizedBox(height: 24),

                        // My Courses
                        _buildMyCourses(context),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context, opacity: 0.2),
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
            ),
            const Spacer(),
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
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadDashboardData,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'لوحة تحكم المدرس',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'مرحباً بك في لوحة التحكم',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.getTextColor(context).withOpacity(0.95),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.payments,
                label: 'إجمالي الدخل',
                value: _currencyFormat.format(_stats['total_revenue'] ?? 0),
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.people,
                label: 'إجمالي الطلاب',
                value: '${_stats['total_students'] ?? 0}',
                color: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.school,
                label: 'الدورات',
                value: '${_stats['total_courses'] ?? 0}',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.assignment,
                label: 'الاختبارات',
                value: '${_stats['total_exams'] ?? 0}',
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextColor(context),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context: context,
                icon: Icons.add_circle,
                label: 'إنشاء اختبار',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageExamsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context: context,
                icon: Icons.people,
                label: 'نتائج الطلاب',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentsResultsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context: context,
          icon: Icons.school,
          label: 'إدارة دوراتي',
          color: Colors.blue,
          onTap: () {
            final userId = SupabaseService.instance.currentUserId;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CoursesManagementScreen(
                  instructorId: userId,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(icon, color: color, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

  Widget _buildRecentExams(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'الاختبارات الأخيرة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageExamsScreen(),
                  ),
                );
              },
              child: Text(
                'عرض الكل',
                style: TextStyle(color: AppColors.getTextColor(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_recentExams.isEmpty)
          _buildEmptyState(context, 'لا توجد اختبارات')
        else
          ..._recentExams.map((exam) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildExamCard(context, exam),
              )),
      ],
    );
  }

  Widget _buildExamCard(BuildContext context, Map<String, dynamic> exam) {
    final isPublished = exam['is_published'] as bool? ?? false;
    final courseName = exam['courses']?['title'] ?? 'دورة';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isPublished ? Colors.green : Colors.orange)
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPublished ? Icons.check_circle : Icons.edit,
                  color: isPublished ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam['title'] ?? 'اختبار',
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      courseName,
                      style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isPublished ? Colors.green : Colors.orange)
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPublished ? 'منشور' : 'مسودة',
                  style: TextStyle(
                    color: isPublished ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyCourses(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'دوراتي',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextColor(context),
          ),
        ),
        const SizedBox(height: 12),
        if (_teacherCourses.isEmpty)
          _buildEmptyState(context, 'لا توجد دورات مسندة')
        else
          ..._teacherCourses.map((tc) {
            final course = tc['courses'] as Map<String, dynamic>?;
            if (course == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCourseCard(context, course),
            );
          }),
      ],
    );
  }

  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  course['title'] ?? 'دورة',
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextColor(context).withOpacity(0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
