import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/string_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'course_enrollments_screen.dart';
import 'teacher_enrollment_stats_screen.dart';

class SubscriptionsManagementScreen extends StatefulWidget {
  const SubscriptionsManagementScreen({super.key});

  @override
  State<SubscriptionsManagementScreen> createState() =>
      _SubscriptionsManagementScreenState();
}

class _SubscriptionsManagementScreenState
    extends State<SubscriptionsManagementScreen> {
  final DatabaseService _db = DatabaseService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: 'ل.س ', decimalDigits: 0);


  List<Map<String, dynamic>> _coursesGrouped = [];
  List<Map<String, dynamic>> _teachersGrouped = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final String _selectedStatus = 'all';
  int _selectedTabIndex = 0; // 0: By Course, 1: By Teacher
  DateTime? _selectedMonth;
  int? _selectedYear;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      DateTime? startDate;
      DateTime? endDate;

      if (_selectedMonth != null) {
        startDate = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
        endDate = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 1);
      } else if (_selectedYear != null) {
        startDate = DateTime(_selectedYear!, 1, 1);
        endDate = DateTime(_selectedYear! + 1, 1, 1);
      }

      Map<String, dynamic> stats;
      if (_selectedMonth != null || _selectedYear != null) {
        final report = await _db.getDetailedFinancialReport(
          startDate: startDate,
          endDate: endDate,
        );
        stats = {
          'total_revenue': report['total_revenue'],
          'active_subscriptions': report['total_enrollments'],
          'monthly_revenue': report['total_revenue'],
          'total_enrollments': report['total_enrollments'],
        };
      } else {
        stats = await _db.getSubscriptionStats();
      }
      final coursesGrouped = await _db.getEnrollmentsGroupedByCourse(
        status: _selectedStatus,
        searchQuery: _searchQuery,
        startDate: startDate,
        endDate: endDate,
      );
      final teachersGrouped = await _db.getEnrollmentsGroupedByTeacher(
        status: _selectedStatus,
        searchQuery: _searchQuery,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;
      setState(() {

        _stats = stats;
        _coursesGrouped = coursesGrouped;
        _teachersGrouped = teachersGrouped;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
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
                _buildStatsSection(),
                _buildFiltersSection(),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.primaryPurple,
                          child: _buildMainContent(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_selectedTabIndex == 0) {
      if (_coursesGrouped.isEmpty) return _buildEmptyState();
      return ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: _coursesGrouped.length,
        itemBuilder: (context, index) {
          return _buildCourseSummaryCard(_coursesGrouped[index]);
        },
      );
    } else {
      if (_teachersGrouped.isEmpty) return _buildEmptyState();
      return ListView.builder(
        padding: EdgeInsets.all(20),
        itemCount: _teachersGrouped.length,
        itemBuilder: (context, index) {
          return _buildTeacherSummaryCard(_teachersGrouped[index]);
        },
      );
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.all(20),
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
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'إدارة الاشتراكات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
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
                      width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.print, color: AppColors.getTextColor(context)),
                      onPressed: _printReport,
                      tooltip: 'طباعة التقرير',
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: AppColors.getTextColor(context).withOpacity(0.24),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppColors.getTextColor(context)),
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      height: 100,
      margin: EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatItem(
            'الدخل الكلي',
            _currencyFormat.format(_stats['total_revenue'] ?? 0),
            Colors.greenAccent,
            Icons.account_balance_wallet,
          ),
          _buildStatItem(
            'دخل هذا الشهر',
            _currencyFormat.format(_stats['monthly_revenue'] ?? 0),
            Color(0xFF00E5FF),
            Icons.speed,
          ),
          _buildStatItem(
            'نشطة',
            '${_stats['active_subscriptions'] ?? 0}',
            Colors.blueAccent,
            Icons.check_circle,
          ),
          _buildStatItem(
            'إجمالي الطلاب',
            '${_stats['total_enrollments'] ?? 0}',
            Colors.purpleAccent,
            Icons.people,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, Color color, IconData icon) {
    return Container(
      width: 150,
      margin: EdgeInsets.only(left: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.15),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 14),
                    SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
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

  Widget _buildFiltersSection() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.2),
                      width: 1.5),
                ),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                        _loadData();
                      },
                      style: TextStyle(color: AppColors.getTextColor(context)),
                      decoration: InputDecoration(
                        hintText: 'بحث باسم الطالب أو الدورة...',
                        hintStyle: TextStyle(
                            color: AppColors.getTextColor(context)
                                .withOpacity(0.4)),
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.getTextColor(context)
                                .withOpacity(0.6)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                    ),
                    Divider(height: 1, color: AppColors.getTextColor(context).withOpacity(0.12)),
                    InkWell(
                      onTap: _showFilterDatePicker,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month,
                                color: AppColors.getTextColor(context)
                                    .withOpacity(0.6),
                                size: 20),
                            SizedBox(width: 8),
                            Text(
                              _selectedMonth == null && _selectedYear == null
                                  ? 'تصفية حسب التاريخ: الكل'
                                  : _selectedMonth != null
                                      ? 'تصفية: ${DateFormat('MMMM yyyy', 'ar').format(_selectedMonth!)}'
                                      : 'تصفية: سنة $_selectedYear',
                              style: TextStyle(
                                color: AppColors.getTextColor(context)
                                    .withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                            Spacer(),
                            if (_selectedMonth != null || _selectedYear != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedMonth = null;
                                    _selectedYear = null;
                                  });
                                  _loadData();
                                },
                                child: Icon(Icons.close,
                                    color: AppColors.getTextColor(context).withOpacity(0.54), size: 18),
                              ),
                            Icon(Icons.arrow_drop_down,
                                color: AppColors.getTextColor(context).withOpacity(0.54)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildViewTabs(),
      ],
    );
  }

  Widget _buildViewTabs() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'حسب الدورة', Icons.book),
          _buildTabItem(1, 'حسب المدرس', Icons.person),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, IconData icon) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isSelected
                      ? Colors.white
                      : AppColors.getTextColor(context).withOpacity(0.6),
                  size: 16),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.getTextColor(context).withOpacity(0.6),
                  fontWeight:
                      isSelected ? FontWeight.normal : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildEnrollmentCard(Map<String, dynamic> enrollment,
      {bool showCourseInfo = true}) {
    final userData = enrollment['users'] as Map<String, dynamic>?;
    final courseData = enrollment['courses'] as Map<String, dynamic>?;
    final DateTime? enrolledAt = enrollment['enrolled_at'] != null
        ? DateTime.parse(enrollment['enrolled_at'])
        : null;
    final String status = enrollment['status'] ?? 'active';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.3),
                  width: 1.5),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  if (showCourseInfo) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            image: courseData?['thumbnail'] != null
                                ? DecorationImage(
                                    image:
                                        NetworkImage(courseData!['thumbnail']),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: courseData?['thumbnail'] == null
                              ? Icon(Icons.book, color: AppColors.getTextColor(context).withOpacity(0.24))
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseData?['title'] ?? 'دورة غير منسوبة',
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontWeight: FontWeight.normal,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: AppColors.primaryPurple,
                                    backgroundImage: userData?['avatar_url'] !=
                                            null
                                        ? NetworkImage(userData!['avatar_url'])
                                        : null,
                                    child: userData?['avatar_url'] == null
                                        ? Text(
                                            (userData?['full_name']?[0] ?? 'U')
                                                .toUpperCase(),
                                            style: TextStyle(
                                                fontSize: 8,
                                                color: AppColors.getTextColor(context)),
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      StringUtils.cleanTeacherName(
                                          userData?['full_name'] ?? 'مستخدم'),
                                      style: TextStyle(
                                        color: AppColors.getTextColor(context)
                                            .withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                  ] else ...[
                    // Minimal student info when showCourseInfo is false
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primaryPurple,
                          backgroundImage: userData?['avatar_url'] != null
                              ? NetworkImage(userData!['avatar_url'])
                              : null,
                          child: userData?['avatar_url'] == null
                              ? Text(
                                  (userData?['full_name']?[0] ?? 'U')
                                      .toUpperCase(),
                                  style: TextStyle(color: AppColors.getTextColor(context)),
                                )
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                StringUtils.cleanTeacherName(
                                    userData?['full_name'] ?? 'طالب'),
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontWeight: FontWeight.normal,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                userData?['email'] ?? '',
                                style: TextStyle(
                                  color: AppColors.getTextColor(context)
                                      .withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildStatusBadge(status),
                      ],
                    ),
                  ],
                  Divider(height: 24, color: AppColors.getTextColor(context).withOpacity(0.12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تاريخ الاشتراك',
                            style: TextStyle(
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            enrolledAt != null
                                ? DateFormat('yyyy/MM/dd').format(enrolledAt)
                                : '-',
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'المبلغ',
                            style: TextStyle(
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(courseData?['price'] ?? 0),
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (status == 'active') ...[
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            _confirmChangeStatus(enrollment['id'], 'cancelled'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: Colors.redAccent, width: 1.5),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('إلغاء الاشتراك',
                            style: TextStyle(fontWeight: FontWeight.normal)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'نشط';
        break;
      case 'expired':
        color = Colors.orange;
        label = 'منتهي';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'ملغي';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildCourseSummaryCard(Map<String, dynamic> item) {
    final course = item['course'] as Map<String, dynamic>?;
    final List<dynamic> enrollments = item['enrollments'] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.3),
                  width: 1.5),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  dividerTheme:
                      DividerThemeData(color: Colors.transparent)),
              child: ExpansionTile(
                title: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: course?['thumbnail'] != null
                            ? DecorationImage(
                                image: NetworkImage(course!['thumbnail']),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: Colors.black26,
                      ),
                      child: course?['thumbnail'] == null
                          ? Icon(Icons.book, color: AppColors.getTextColor(context).withOpacity(0.24))
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course?['title'] ?? 'دورة غير منسوبة',
                            style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontWeight: FontWeight.normal,
                                fontSize: 16),
                          ),
                          Text(
                            'السعر: ${_currencyFormat.format(course?['price'] ?? 0)}',
                            style: TextStyle(
                                color: AppColors.getTextColor(context)
                                    .withOpacity(0.6),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      _buildSummaryItem(
                          'الطلاب', '${item['enrollment_count']}', Icons.person,
                          color: Colors.blueAccent),
                      SizedBox(width: 8),
                      _buildSummaryItem(
                          'الدخل',
                          _currencyFormat.format(item['total_revenue']),
                          Icons.payments,
                          color: Colors.greenAccent),
                    ],
                  ),
                ),
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                childrenPadding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Divider(color: AppColors.getTextColor(context).withOpacity(0.12)),
                  ...enrollments.map((e) => _buildEnrollmentCard(
                      e as Map<String, dynamic>,
                      showCourseInfo: false)),
                  if (enrollments.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CourseEnrollmentsScreen(
                              courseId: course?['id'] ?? '',
                              courseTitle:
                                  course?['title'] ?? 'دورة غير منسوبة',
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.open_in_new, size: 14),
                      label: Text('إدارة تفصيلية',
                          style: TextStyle(fontSize: 12)),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white70),
                    ),
                    SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherSummaryCard(Map<String, dynamic> item) {
    final teacher = item['teacher'] as Map<String, dynamic>?;
    final List<dynamic> enrollments = item['enrollments'] ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.3),
                  width: 1.5),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  dividerTheme:
                      DividerThemeData(color: Colors.transparent)),
              child: ExpansionTile(
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: AppColors.primaryPurple,
                      backgroundImage: teacher?['avatar_url'] != null
                          ? NetworkImage(teacher!['avatar_url'])
                          : null,
                      child: teacher?['avatar_url'] == null
                          ? Icon(Icons.person, color: AppColors.getTextColor(context))
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            StringUtils.cleanTeacherName(
                                teacher?['full_name'] ?? 'مدرس مجهول'),
                            style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontWeight: FontWeight.normal,
                                fontSize: 16),
                          ),
                          Text(
                            'عدد الكورسات: ${item['course_count']}',
                            style: TextStyle(
                                color: AppColors.getTextColor(context)
                                    .withOpacity(0.6),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      _buildSummaryItem(
                          'الطلاب', '${item['student_count']}', Icons.people,
                          color: Colors.orangeAccent),
                      SizedBox(width: 8),
                      _buildSummaryItem(
                          'الدخل',
                          _currencyFormat.format(item['total_revenue']),
                          Icons.account_balance,
                          color: Colors.blueAccent),
                    ],
                  ),
                ),
                iconColor: Colors.white70,
                collapsedIconColor: Colors.white54,
                childrenPadding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Divider(color: AppColors.getTextColor(context).withOpacity(0.12)),
                  ...enrollments.map((e) => _buildEnrollmentCard(
                      e as Map<String, dynamic>,
                      showCourseInfo:
                          true)), // Show course info for teacher view
                  if (enrollments.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TeacherEnrollmentStatsScreen(
                              teacherId: teacher?['id'] ?? '',
                              teacherName:
                                  teacher?['full_name'] ?? 'مدرس مجهول',
                              avatarUrl: teacher?['avatar_url'],
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.open_in_new, size: 14),
                      label: Text('إحصائيات المدرس',
                          style: TextStyle(fontSize: 12)),
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.white70),
                    ),
                    SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon,
      {Color? color}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 14),
          ),
          SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.5),
                        fontSize: 10)),
                Text(value,
                    style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontWeight: FontWeight.normal,
                        fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              color: AppColors.getTextColor(context).withOpacity(0.3),
              size: 60),
          SizedBox(height: 16),
          Text(
            'لا توجد اشتراكات مطابقة',
            style: TextStyle(
              color: AppColors.getTextColor(context).withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmChangeStatus(String enrollmentId, String newStatus) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.getGlassColor(context, opacity: 0.9),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white24)),
          title: Text('تأكيد الإجراء',
              style:
                  TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
          content: Text(
            'هل أنت متأكد من تغيير حالة الاشتراك لهذا الطالب؟ سيؤدي هذا لإلغاء وصوله للمحتوى.',
            style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  Text('إلغاء', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60))),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Colors.redAccent, Colors.red]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  try {
                    await _db.updateEnrollmentStatus(enrollmentId, newStatus);
                    _loadData();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('تم تحديث حالة الاشتراك بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
                          backgroundColor: Colors.red),
                    );
                  }
                },
                child: Text('تأكيد الإلغاء',
                    style: TextStyle(
                        color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDatePicker() async {
    final now = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: AppColors.getGlassColor(context, opacity: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white24),
            ),
            titlePadding: EdgeInsets.zero,
            title: Column(
              children: [
                SizedBox(height: 16),
                Text('اختر فترة التصفية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                TabBar(
                  indicatorColor: AppColors.primaryPurple,
                  labelColor: AppColors.primaryPurple,
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(text: 'شهري'),
                    Tab(text: 'سنوي'),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: TabBarView(
                children: [
                  // Month Picker
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final month = DateTime(now.year, now.month - index, 1);
                      final monthName =
                          DateFormat('MMMM yyyy', 'ar').format(month);
                      bool isSelected = _selectedMonth?.year == month.year &&
                          _selectedMonth?.month == month.month;

                      return ListTile(
                        title: Text(monthName,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : Colors.white,
                              fontSize: 14,
                            )),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: AppColors.primaryPurple)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedMonth = month;
                            _selectedYear = null;
                          });
                          _loadData();
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                  // Year Picker
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      final year = now.year - index;
                      bool isSelected = _selectedYear == year;

                      return ListTile(
                        title: Text('سنة $year',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : Colors.white,
                              fontSize: 14,
                            )),
                        trailing: isSelected
                            ? Icon(Icons.check,
                                color: AppColors.primaryPurple)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedYear = year;
                            _selectedMonth = null;
                          });
                          _loadData();
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _printReport() async {
    DateTime? startDate;
    DateTime? endDate;

    if (_selectedMonth != null) {
      startDate = DateTime(_selectedMonth!.year, _selectedMonth!.month, 1);
      endDate = DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 1);
    } else if (_selectedYear != null) {
      startDate = DateTime(_selectedYear!, 1, 1);
      endDate = DateTime(_selectedYear! + 1, 1, 1);
    }

    if (_selectedMonth == null && _selectedYear == null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('طباعة التقرير'),
          content: Text(
              'لم يتم تحديد فترة تصفية (شهر أو سنة). سيتم طباعة تقرير لجميع الاشتراكات.\nهل تريد المتابعة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('متابعة'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      final reportData = await _db.getDetailedFinancialReport(
        startDate: startDate,
        endDate: endDate,
      );

      await Printing.layoutPdf(
        onLayout: (format) => _generatePdf(format, reportData),
        name:
            'Financial_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('فشل إنشاء التقرير: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Uint8List> _generatePdf(
      PdfPageFormat format, Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // Load fonts
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final ttfBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(
            base: ttf,
            bold: ttfBold,
          ),
          textDirection: pw.TextDirection.rtl,
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        build: (context) => [
          _buildPdfHeader(data, ttfBold),
          pw.SizedBox(height: 20),
          _buildPdfSummary(data, ttfBold),
          pw.SizedBox(height: 20),
          _buildPdfTable(data, ttfBold),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader(Map<String, dynamic> data, pw.Font fontBold) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('التقرير المالي',
                  style: pw.TextStyle(
                      fontSize: 24, font: fontBold, color: PdfColors.purple)),
              pw.Text('منصة دوراتي التعليمية',
                  style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('الفترة: ${data['period']}',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text(
                  'تاريخ الطباعة: ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummary(Map<String, dynamic> data, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildPdfSummaryItem(
              'إجمالي الإيرادات',
              '${(data['total_revenue'] as double).toStringAsFixed(0)} ل.س',
              fontBold),
          _buildPdfSummaryItem(
              'عدد الاشتراكات', '${data['total_enrollments']}', fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(label,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 18, font: fontBold, color: PdfColors.purple)),
      ],
    );
  }

  pw.Widget _buildPdfTable(Map<String, dynamic> data, pw.Font fontBold) {
    final items = data['enrollments'] as List<dynamic>;

    return pw.Table.fromTextArray(
      headers: ['الرقم', 'التاريخ', 'الطالب', 'الدورة', 'طريقة الدفع', 'السعر'],
      data: List<List<dynamic>>.generate(items.length, (index) {
        final item = items[index];
        
        String dateStr = '-';
        if (item['enrolled_at'] != null) {
          try {
            dateStr = DateFormat('yyyy/MM/dd')
                .format(DateTime.parse(item['enrolled_at']));
          } catch (_) {}
        }

        return [
          '${index + 1}',
          dateStr,
          item['user_full_name'] ?? item['student_name'] ?? '-',
          item['course_title'] ?? '-',
          item['payment_method'] ?? 'نقدي',
          '${item['course_price'] ?? 0} ل.س',
        ];
      }),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellStyle: const pw.TextStyle(fontSize: 10),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(3),
        3: const pw.FlexColumnWidth(3),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(2),
      },
    );
  }
}
