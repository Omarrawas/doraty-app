import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/string_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:intl/intl.dart';

class TeacherEnrollmentStatsScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String? avatarUrl;

  const TeacherEnrollmentStatsScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    this.avatarUrl,
  });

  @override
  State<TeacherEnrollmentStatsScreen> createState() => _TeacherEnrollmentStatsScreenState();
}

class _TeacherEnrollmentStatsScreenState extends State<TeacherEnrollmentStatsScreen> {
  final DatabaseService _db = DatabaseService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: 'ل.س ', decimalDigits: 0);

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final stats = await _db.getTeacherDetailedStats(widget.teacherId);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الإحصائيات: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : RefreshIndicator(
                          onRefresh: _loadStats,
                          color: AppColors.primaryPurple,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            children: [
                              _buildStatsGrid(),
                              const SizedBox(height: 24),
                              _buildSectionTitle('أداء الكورسات'),
                              const SizedBox(height: 12),
                              ...(_stats['courses_breakdown'] as List? ?? [])
                                  .map((course) => _buildCourseStatCard(course)),
                              const SizedBox(height: 24),
                              _buildSectionTitle('أحدث الاشتراكات (آخر 10)'),
                              const SizedBox(height: 12),
                              ...(_stats['recent_enrollments'] as List? ?? [])
                                  .map((enrollment) => _buildRecentEnrollmentCard(enrollment)),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إحصائيات المدرس',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                Text(
                  StringUtils.cleanTeacherName(widget.teacherName),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 24,
            backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
            child: widget.avatarUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'إجمالي الدخل',
          _currencyFormat.format(_stats['total_revenue'] ?? 0),
          Icons.payments,
          Colors.greenAccent,
        ),
        _buildSummaryCard(
          'إجمالي الطلاب',
          '${_stats['student_count'] ?? 0}',
          Icons.people,
          Colors.blueAccent,
        ),
        _buildSummaryCard(
          'عدد الكورسات',
          '${_stats['course_count'] ?? 0}',
          Icons.book,
          Colors.orangeAccent,
        ),
        _buildSummaryCard(
          'متوسط دخل الكورس',
          _currencyFormat.format((_stats['total_revenue'] ?? 0) /
              ((_stats['course_count'] ?? 1) == 0 ? 1 : (_stats['course_count'] ?? 1))),
          Icons.analytics,
          Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
    );
  }

  Widget _buildCourseStatCard(Map<String, dynamic> course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: course['image_url'] != null
                        ? DecorationImage(image: NetworkImage(course['image_url']), fit: BoxFit.cover)
                        : null,
                    color: Colors.black26,
                  ),
                  child: course['image_url'] == null ? const Icon(Icons.book, color: Colors.white24) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course['title'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.blueAccent, size: 12),
                          const SizedBox(width: 4),
                          Text('${course['student_count']} طالب',
                              style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.payments, color: Colors.greenAccent, size: 12),
                          const SizedBox(width: 4),
                          Text(_currencyFormat.format(course['revenue']),
                              style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
    );
  }

  Widget _buildRecentEnrollmentCard(Map<String, dynamic> enrollment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        tileColor: Colors.white.withOpacity(0.03),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
          child: Text((enrollment['user_full_name']?[0] ?? 'U').toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
        title: Text(enrollment['user_full_name'] ?? 'مستخدم',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.normal)),
        subtitle: Text(enrollment['course_title'] ?? '',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        trailing: Text(
          DateFormat('MM/dd').format(DateTime.parse(enrollment['enrolled_at'])),
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ),
    );
  }
}
