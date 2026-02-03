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

  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> _coursesGrouped = [];
  List<Map<String, dynamic>> _teachersGrouped = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final String _selectedStatus = 'all';
  int _selectedTabIndex = 0; // 0: All, 1: By Course, 2: By Teacher

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final enrollments = await _db.getAllEnrollments(
        status: _selectedStatus,
        searchQuery: _searchQuery,
      );
      final stats = await _db.getSubscriptionStats();
      final coursesGrouped = await _db.getEnrollmentsGroupedByCourse();
      final teachersGrouped = await _db.getEnrollmentsGroupedByTeacher();

      if (!mounted) return;
      setState(() {
        _enrollments = enrollments;
        _stats = stats;
        _coursesGrouped = coursesGrouped;
        _teachersGrouped = teachersGrouped;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
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
                      ? const Center(
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
      if (_enrollments.isEmpty) return _buildEmptyState();
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _enrollments.length,
        itemBuilder: (context, index) {
          return _buildEnrollmentCard(_enrollments[index]);
        },
      );
    } else if (_selectedTabIndex == 1) {
      if (_coursesGrouped.isEmpty) return _buildEmptyState();
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _coursesGrouped.length,
        itemBuilder: (context, index) {
          return _buildCourseSummaryCard(_coursesGrouped[index]);
        },
      );
    } else {
      if (_teachersGrouped.isEmpty) return _buildEmptyState();
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _teachersGrouped.length,
        itemBuilder: (context, index) {
          return _buildTeacherSummaryCard(_teachersGrouped[index]);
        },
      );
    }
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
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1),
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
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadData,
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
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
            const Color(0xFF00E5FF),
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
      margin: const EdgeInsets.only(left: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
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
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
                child: TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                    _loadData();
                  },
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم الطالب أو الدورة...',
                    hintStyle: TextStyle(
                        color:
                            AppColors.getTextColor(context).withOpacity(0.4)),
                    prefixIcon: Icon(Icons.search,
                        color:
                            AppColors.getTextColor(context).withOpacity(0.6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'الكل', Icons.list),
          _buildTabItem(1, 'حسب الدورة', Icons.book),
          _buildTabItem(2, 'حسب المدرس', Icons.person),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              const SizedBox(width: 8),
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



  Widget _buildEnrollmentCard(Map<String, dynamic> enrollment) {
    final userData = enrollment['users'] as Map<String, dynamic>?;
    final courseData = enrollment['courses'] as Map<String, dynamic>?;
    final DateTime? enrolledAt = enrollment['enrolled_at'] != null
        ? DateTime.parse(enrollment['enrolled_at'])
        : null;
    final String status = enrollment['status'] ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                                  image: NetworkImage(courseData!['thumbnail']),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: courseData?['thumbnail'] == null
                            ? const Icon(Icons.book, color: Colors.white24)
                            : null,
                      ),
                      const SizedBox(width: 12),
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
                            const SizedBox(height: 4),
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
                                          style: const TextStyle(
                                              fontSize: 8, color: Colors.white),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
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
                  const Divider(height: 24, color: Colors.white12),
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
                            style: const TextStyle(
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            _confirmChangeStatus(enrollment['id'], 'cancelled'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.redAccent, width: 1.5),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('إلغاء الاشتراك',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    return GestureDetector(
      onTap: () {
        if (course != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CourseEnrollmentsScreen(
                courseId: course['id'],
                courseTitle: course['title'] ?? 'دورة غير منسوبة',
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
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
                            ? const Icon(Icons.book, color: Colors.white24)
                            : null,
                      ),
                      const SizedBox(width: 12),
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
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem(
                          'الطلاب', '${item['enrollment_count']}', Icons.person,
                          color: Colors.blueAccent),
                      _buildSummaryItem(
                          'إجمالي الدخل',
                          _currencyFormat.format(item['total_revenue']),
                          Icons.payments,
                          color: Colors.greenAccent),
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

  Widget _buildTeacherSummaryCard(Map<String, dynamic> item) {
    final teacher = item['teacher'] as Map<String, dynamic>?;
    return GestureDetector(
      onTap: () {
        if (teacher != null && teacher['id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeacherEnrollmentStatsScreen(
                teacherId: teacher['id'],
                teacherName: teacher['full_name'] ?? 'مدرس مجهول',
                avatarUrl: teacher['avatar_url'],
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: AppColors.primaryPurple,
                        backgroundImage: teacher?['avatar_url'] != null
                            ? NetworkImage(teacher!['avatar_url'])
                            : null,
                        child: teacher?['avatar_url'] == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
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
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('إجمالي الطلاب',
                          '${item['student_count']}', Icons.people,
                          color: Colors.orangeAccent),
                      _buildSummaryItem(
                          'إجمالي الدخل',
                          _currencyFormat.format(item['total_revenue']),
                          Icons.account_balance,
                          color: Colors.blueAccent),
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

  Widget _buildSummaryItem(String label, String value, IconData icon,
      {Color? color}) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color ?? Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
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
          const SizedBox(height: 16),
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
              side: const BorderSide(color: Colors.white24)),
          title: const Text('تأكيد الإجراء',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'هل أنت متأكد من تغيير حالة الاشتراك لهذا الطالب؟ سيؤدي هذا لإلغاء وصوله للمحتوى.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
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
                      const SnackBar(
                        content: Text('تم تحديث حالة الاشتراك بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text('حدث خطأ: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('تأكيد الإلغاء',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
