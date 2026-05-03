import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'manage_exams_screen.dart';
import 'course_subscribers_screen.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import 'package:go_router/go_router.dart';

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

  final intl.NumberFormat _currencyFormat =
      intl.NumberFormat.currency(symbol: 'ل.س ', decimalDigits: 0);

  String _t(String key) {
    if (!mounted) return key;
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

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
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
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
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboardData,
                  color: AppColors.getTextColor(context),
                  backgroundColor: AppColors.primaryPurple,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        _buildHeader(context),

                        SizedBox(height: 24),

                        // Stats Cards
                        _buildStatsCards(context),

                        SizedBox(height: 24),

                        // Quick Actions
                        _buildQuickActions(context),

                        SizedBox(height: 24),

                        // Recent Exams
                        _buildRecentExams(context),

                        SizedBox(height: 24),

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
                    icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
            Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context, opacity: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.2),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.print, color: AppColors.getTextColor(context)),
                    onPressed: _showMonthSelectionDialog,
                    tooltip: _t('print_report'),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context, opacity: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.getTextColor(context)),
                    onPressed: _loadDashboardData,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Text(
          _t('teacher_dashboard'),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
        ),
        SizedBox(height: 8),
        Text(
          _t('teacher_dashboard_welcome'),
          style: TextStyle(fontSize: 16, color: AppColors.getTextColor(context).withOpacity(0.95)),
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
                label: _t('total_income'),
                value: _currencyFormat.format(_stats['total_revenue'] ?? 0),
                color: Colors.greenAccent,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.people,
                label: _t('total_students_stat'),
                value: '${_stats['total_students'] ?? 0}',
                color: Colors.orangeAccent,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.school,
                label: _t('courses_stat'),
                value: '${_stats['total_courses'] ?? 0}',
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.assignment,
                label: _t('exams_stat'),
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
          padding: EdgeInsets.all(20),
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
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 4),
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
          _t('quick_actions'),
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context)),
        ),
        SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(
              context: context,
              icon: Icons.assignment_rounded,
              label: _t('manage_exams'),
              color: Colors.deepOrangeAccent,
              onTap: () => context.push('/admin/exams/create'),
            ),
            _buildActionCard(
              context: context,
              icon: Icons.video_library_rounded,
              label: 'إضافة درس جديد',
              color: Colors.lightBlueAccent,
              onTap: () {
                final userId = SupabaseService.instance.currentUserId;
                context.push('/admin/courses?instructorId=$userId');
              },
            ),
            _buildActionCard(
              context: context,
              icon: Icons.people_alt_rounded,
              label: _t('student_results'),
              color: Colors.orangeAccent,
              onTap: () => context.push('/admin/results'),
            ),
            _buildActionCard(
              context: context,
              icon: Icons.people_rounded,
              label: 'مشتركو الدورات',
              color: Colors.pinkAccent,
              onTap: () {
                final userId = SupabaseService.instance.currentUserId;
                context.push('/admin/courses?instructorId=$userId');
              },
            ),
            _buildActionCard(
              context: context,
              icon: Icons.analytics_rounded,
              label: _t('statistics'),
              color: Colors.indigoAccent,
              onTap: () {
                final userId = SupabaseService.instance.currentUserId;
                context.push('/admin/subscriptions/teacher/$userId');
              },
            ),
            _buildActionCard(
              context: context,
              icon: Icons.account_balance_wallet_rounded,
              label: 'التقارير المالية',
              color: Colors.greenAccent,
              onTap: _showMonthSelectionDialog,
            ),
            _buildActionCard(
              context: context,
              icon: Icons.view_module_rounded,
              label: _t('manage_my_courses'),
              color: Colors.tealAccent,
              onTap: () {
                final userId = SupabaseService.instance.currentUserId;
                context.push('/admin/courses?instructorId=$userId');
              },
            ),
            _buildActionCard(
              context: context,
              icon: Icons.settings_rounded,
              label: 'الإعدادات',
              color: Colors.grey,
              onTap: () => context.push('/settings'),
            ),
          ],
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
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.18), // Increased opacity
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.4), // Increased border vibrancy
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 15,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
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
              _t('recent_exams'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ManageExamsScreen()));
              },
              child: Text(_t('view_all'), style: TextStyle(color: AppColors.getTextColor(context))),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (_recentExams.isEmpty)
          _buildEmptyState(context, _t('no_exams_assigned'))
        else
          ..._recentExams.map((exam) => Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _buildExamCard(context, exam),
              )),
      ],
    );
  }

  Widget _buildExamCard(BuildContext context, Map<String, dynamic> exam) {
    final isPublished = exam['is_published'] as bool? ?? false;
    final courseName = exam['courses']?['title'] ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
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
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam['title'] ?? '',
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
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
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: (isPublished ? Colors.green : Colors.orange)
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isPublished ? _t('published') : _t('draft'),
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
          _t('my_courses'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
        ),
        SizedBox(height: 12),
        if (_teacherCourses.isEmpty)
          _buildEmptyState(context, _t('no_courses_assigned'))
        else
          ..._teacherCourses.map((tc) {
            // Check if the data is wrapped in a 'courses' key (from joins) or direct
            final course = (tc['courses'] is Map<String, dynamic>) 
                ? tc['courses'] as Map<String, dynamic> 
                : tc;

            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: _buildCourseCard(context, course),
            );
          }),
      ],
    );
  }

  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    final studentCount = course['student_count'] ?? 0;
    final avgProgress = (course['average_progress'] as num? ?? 0).toDouble();
    final examCount = course['exam_count'] ?? 0;
    final revenue = (course['revenue'] as num? ?? 0).toDouble();
    final isPublished = course['is_published'] as bool? ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CourseSubscribersScreen(
                      courseId: course['id'],
                      courseTitle: course['title'],
                    ),
                  ),
                );
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.school, color: Colors.blue[300], size: 24),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course['title'] ?? 'دورة',
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isPublished ? Colors.green : Colors.orange)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isPublished ? 'منشور' : 'مسودة',
                                      style: TextStyle(
                                        color: isPublished
                                            ? Colors.green[300]
                                            : Colors.orange[300],
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_left, color: Colors.white54),
                      ],
                    ),
                    SizedBox(height: 20),
    
                    // Progress Section
                    Text(
                      'متوسط تقدم الطلاب: ${avgProgress.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: avgProgress / 100,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                        minHeight: 6,
                      ),
                    ),
    
                    SizedBox(height: 20),
    
                    // Stats Grid
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniStat(context, Icons.people, '$studentCount', 'طالب'),
                        _buildMiniStat(
                            context, Icons.assignment, '$examCount', 'اختبار'),
                        _buildMiniStat(context, Icons.payments,
                            _currencyFormat.format(revenue), 'دخل'),
                      ],
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

  Widget _buildMiniStat(
      BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryPurple.withOpacity(0.8)),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.getTextColor(context),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.getTextColor(context).withOpacity(0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(30),
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

  void _showMonthSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _MonthSelectionDialog(
        onGenerateReport: _generateAndPrintReport,
      ),
    );
  }

  Future<void> _generateAndPrintReport(List<DateTime> selectedMonths) async {
    if (selectedMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى اختيار شهر واحد على الأقل'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.getTextColor(context)),
      ),
    );

    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Sort months to get start and end dates
      selectedMonths.sort();
      final startDate =
          DateTime(selectedMonths.first.year, selectedMonths.first.month, 1);
      final endDate = DateTime(selectedMonths.last.year,
          selectedMonths.last.month + 1, 0, 23, 59, 59);

      // Fetch data from database
      final reportData = await _db.getTeacherMonthlyStatistics(
        userId,
        startDate: startDate,
        endDate: endDate,
      );

      // Generate PDF
      final pdf = await _createPDF(reportData, selectedMonths);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      //.Show print dialog
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'تقرير_المدرس_${intl.DateFormat('yyyy-MM').format(startDate)}.pdf',
      );
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<pw.Document> _createPDF(
      Map<String, dynamic> data, List<DateTime> selectedMonths) async {
    final pdf = pw.Document();

    // Load Arabic font
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    final monthlyBreakdown = data['monthly_breakdown'] as List? ?? [];

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBold,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.purple,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'تقرير إحصائيات المدرس',
                      style: pw.TextStyle(
                        fontSize: 24,
                        font: arabicBold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'الفترة: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(data['start_date']))} - ${intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(data['end_date']))}',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'التاريخ: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Summary Cards
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPDFStatCard(
                    'إجمالي الدخل',
                    _currencyFormat.format(data['total_revenue']),
                    arabicBold,
                  ),
                  _buildPDFStatCard(
                    'إجمالي الطلاب',
                    '${data['total_users']}',
                    arabicBold,
                  ),
                  _buildPDFStatCard(
                    'الاشتراكات',
                    '${data['total_enrollments']}',
                    arabicBold,
                  ),
                  _buildPDFStatCard(
                    'المحاولات',
                    '${data['total_attempts']}',
                    arabicBold,
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Monthly breakdown table
              pw.Text(
                'التفصيل الشهري',
                style: pw.TextStyle(
                  fontSize: 18,
                  font: arabicBold,
                ),
              ),

              pw.SizedBox(height: 15),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _buildTableCell('الشهر', arabicBold, isHeader: true),
                      _buildTableCell('الاشتراكات', arabicBold, isHeader: true),
                      _buildTableCell('الدخل', arabicBold, isHeader: true),
                      _buildTableCell('الطلاب', arabicBold, isHeader: true),
                      _buildTableCell('المحاولات', arabicBold, isHeader: true),
                    ],
                  ),
                  // Data rows
                  ...monthlyBreakdown.map((month) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(
                            _formatMonthYear(month['month']), arabicFont),
                        _buildTableCell('${month['enrollments']}', arabicFont),
                        _buildTableCell(
                            _currencyFormat.format(month['revenue']),
                            arabicFont),
                        _buildTableCell('${month['students']}', arabicFont),
                        _buildTableCell('${month['attempts']}', arabicFont),
                      ],
                    );
                  }),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(),
              pw.Text(
                'تم إنشاء هذا التقرير تلقائياً من منصة دراتي',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFStatCard(String label, String value, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.purple, width: 2),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 20,
              font: font,
              color: PdfColors.purple,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 12 : 10,
          font: font,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  String _formatMonthYear(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) return monthKey;

    final year = parts[0];
    final month = int.parse(parts[1]);

    const monthNames = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];

    return '${monthNames[month - 1]} $year';
  }
} // End of _TeacherDashboardScreenState

// Month Selection Dialog Widget
class _MonthSelectionDialog extends StatefulWidget {
  final Function(List<DateTime>) onGenerateReport;

  const _MonthSelectionDialog({required this.onGenerateReport});

  @override
  State<_MonthSelectionDialog> createState() => _MonthSelectionDialogState();
}

class _MonthSelectionDialogState extends State<_MonthSelectionDialog> {
  final Map<DateTime, bool> _selectedMonths = {};

  @override
  void initState() {
    super.initState();
    _initializeMonths();
  }

  void _initializeMonths() {
    final now = DateTime.now();
    // Last 12 months
    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      _selectedMonths[month] = false;
    }
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _selectedMonths.updateAll((key, _) => value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedMonths.values.where((v) => v).length;

    return Dialog(
      backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر الشهور المضمنة في التقرير',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // Select All / Deselect All buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _toggleSelectAll(true),
                  icon: Icon(Icons.check_box,
                      color: AppColors.primaryPurple),
                  label: Text('تحديد الكل'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryPurple,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _toggleSelectAll(false),
                  icon: Icon(Icons.check_box_outline_blank,
                      color: AppColors.textSecondary),
                  label: Text('إلغاء التحديد'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            Divider(),

            // Month list
            Expanded(
              child: ListView(
                children: _selectedMonths.entries.map((entry) {
                  final month = entry.key;
                  final isSelected = entry.value;

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        _selectedMonths[month] = value ?? false;
                      });
                    },
                    title: Text(
                      _formatMonthYear(month),
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                    activeColor: AppColors.primaryPurple,
                    checkColor: Colors.white,
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'إلغاء',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: selectedCount > 0
                      ? () {
                          final selected = _selectedMonths.entries
                              .where((e) => e.value)
                              .map((e) => e.key)
                              .toList();
                          Navigator.pop(context);
                          widget.onGenerateReport(selected);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.print, color: AppColors.getTextColor(context)),
                  label: Text(
                    'طباعة التقرير ($selectedCount)',
                    style: TextStyle(color: AppColors.getTextColor(context)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
    const monthNames = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];

    return '${monthNames[date.month - 1]} ${date.year}';
  }
}
