import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import 'users_management_screen.dart';
import 'teachers_management_screen.dart';
import 'courses_management_screen.dart';
import 'subscriptions_management_screen.dart';
import 'payment_receipts_screen.dart';
import 'categories_management_screen.dart';
import 'notifications_management_screen.dart';
import '../../widgets/dynamic_gradient_background.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DatabaseService _db = DatabaseService();

  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentAttempts = [];
  String? _userRole;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final user = SupabaseService.instance.currentUser;
      if (user != null) {
        _userId = user.id;
        final role = await _db.getUserRole(user.id);
        setState(() {
          _userRole = role;
        });
        _loadStats();
      }
    } catch (e) {
      debugPrint('Error loading user role: $e');
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> stats;
      if (_userRole == 'teacher' && _userId != null) {
        stats = await _db.getTeacherStatistics(_userId!);
      } else {
        stats = await _db.getSystemStatistics();
      }

      List<Map<String, dynamic>> attempts = [];
      if (_userRole == 'teacher' && _userId != null) {
        attempts = await _db.getRecentTeacherExamAttempts(_userId!);
      }
      
      setState(() {
        _stats = stats;
        _recentAttempts = attempts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadStats,
                          displacement: 20,
                          color: AppColors.primaryPurple,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStatsGrid(),
                                const SizedBox(height: 24),
                                if (_userRole == 'teacher') ...[
                                  _buildRecentAttempts(),
                                  const SizedBox(height: 24),
                                ],
                                _buildQuickActions(),
                                const SizedBox(height: 24),
                                _buildSystemInfo(),
                                const SizedBox(height: 40),
                              ],
                            ),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userRole == 'teacher'
                      ? 'لوحة تحكم المدرس'
                      : _userRole == 'super_admin'
                          ? 'لوحة تحكم المدير العام'
                          : 'لوحة تحكم الأدمن',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  _userRole == 'teacher'
                      ? 'إدارة دوراتك ومحتواك التعليمي'
                      : _userRole == 'super_admin'
                          ? 'إدارة النظام والرقابة الشاملة'
                          : 'إدارة العمليات اليومية للمنصة',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextColor(context).withOpacity(0.7),
                  ),
                ),
              ],
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
                  onPressed: _loadStats,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3, // Increased height ratio to prevent overflow
      children: [
        _buildStatCard(
          icon: Icons.people,
          label: 'المستخدمين',
          value: '${_stats['total_users'] ?? 0}',
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.school,
          label: 'الدورات',
          value: '${_stats['total_courses'] ?? 0}',
          color: Colors.purple,
        ),
        _buildStatCard(
          icon: Icons.assignment,
          label: 'الاختبارات',
          value: '${_stats['total_exams'] ?? 0}',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.analytics,
          label: 'المحاولات',
          value: '${_stats['total_attempts'] ?? 0}',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.normal,
                  color: AppColors.getTextColor(context),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextColor(context).withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'الإجراءات السريعة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: AppColors.getTextColor(context),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_userRole != 'teacher') ...[
          _buildActionCard(
            icon: Icons.people_alt_rounded,
            title: 'إدارة المستخدمين',
            subtitle: 'عرض وإدارة جميع المستخدمين والطلاب',
            color: Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsersManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.category_rounded,
            title: 'إدارة التصنيفات',
            subtitle: 'إعداد وتعديل تصنيفات الدورات التعليمية',
            color: Colors.pinkAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoriesManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.school_rounded,
            title: 'إدارة المدرسين',
            subtitle: 'تعيين المدرسين للدورات وإدارة صلاحياتهم',
            color: Colors.deepPurpleAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeachersManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        _buildActionCard(
          icon: Icons.library_books_rounded,
          title: _userRole == 'teacher' ? 'إدارة دوراتي' : 'إدارة الدورات',
          subtitle: 'إنشاء وتعديل محتوى الدورات والدروس',
          color: Colors.tealAccent,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CoursesManagementScreen(
                  instructorId: _userRole == 'teacher' ? _userId : null,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        if (_userRole != 'teacher') ...[
          _buildActionCard(
            icon: Icons.card_membership_rounded,
            title: 'إدارة الاشتراكات',
            subtitle: 'متابعة اشتراكات الطلاب الفعالة والمنتهية',
            color: Colors.amberAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionsManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.receipt_long_rounded,
            title: 'طلبات الدفع',
            subtitle: 'مراجعة وتأكيد إيصالات التحويل البنكي',
            color: Colors.orangeAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PaymentReceiptsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildActionCard(
            icon: Icons.notifications_active_rounded,
            title: 'إدارة الإشعارات',
            subtitle: 'إرسال تنبيهات عامة أو خاصة للمستخدمين',
            color: Colors.redAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsManagementScreen(),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.2),
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextColor(context)
                                .withOpacity(0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            'معلومات النظام',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: AppColors.getTextColor(context),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getGlassColor(context, opacity: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow('إصدار التطبيق', '2.1.0 (BETA)',
                      icon: Icons.info_outline_rounded),
                  const Divider(color: Colors.white10),
                  _buildInfoRow('محرك البيانات', 'Supabase Realtime',
                      icon: Icons.storage_rounded),
                  const Divider(color: Colors.white10),
                  _buildInfoRow('حالة الخادم', 'متصل ويعمل',
                      color: Colors.greenAccent,
                      icon: Icons.check_circle_outline_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value,
      {Color? color, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextColor(context).withOpacity(0.6),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: color ?? AppColors.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttempts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أحدث محاولات الطلاب',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: AppColors.getTextColor(context),
                ),
              ),
              Text(
                'عرض الكل',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueAccent.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_recentAttempts.isEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    'لا توجد محاولات حديثة في سجل النظام',
                    style: TextStyle(
                        color: AppColors.getTextColor(context).withOpacity(0.5),
                        fontSize: 14),
                  ),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentAttempts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final attempt = _recentAttempts[index];
              final user = attempt['users'] as Map<String, dynamic>?;
              final exam = attempt['exams'] as Map<String, dynamic>?;
              final score = attempt['score'];
              final total = attempt['total_points'];
              final isPassed = attempt['is_passed'] == true;
              final date = DateTime.parse(attempt['submitted_at']).toLocal();

              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.getGlassColor(context, opacity: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.getGlassColor(context, opacity: 0.2),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage: user?['avatar_url'] != null
                            ? NetworkImage(user!['avatar_url'])
                            : null,
                        backgroundColor:
                            AppColors.primaryPurple.withOpacity(0.2),
                        child: user?['avatar_url'] == null
                            ? const Icon(Icons.person,
                                color: Colors.white, size: 24)
                            : null,
                      ),
                      title: Text(
                        user?['full_name'] ?? 'طالب مجهول',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            exam?['title'] ?? 'اختبار غير معروف',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}/${date.month} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              (isPassed ? Colors.greenAccent : Colors.redAccent)
                                  .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$score/$total',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isPassed
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              isPassed ? 'ناجح' : 'راسب',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                                color: isPassed
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
