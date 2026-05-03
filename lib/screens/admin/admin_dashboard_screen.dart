import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/error_utils.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

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
  String? _userName;

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
        _userName = user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'مستخدم';
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
                        ? Center(
                            child: CircularProgressIndicator(color: AppColors.primaryPurple),
                          )
                      : RefreshIndicator(
                          onRefresh: _loadStats,
                          displacement: 20,
                          color: AppColors.primaryPurple,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double width = constraints.maxWidth;
                              int statsCrossAxisCount = 2;
                              int actionsCrossAxisCount = 2;
                              double actionsAspectRatio = 1.55;

                              if (width > 1200) {
                                statsCrossAxisCount = 4;
                                actionsCrossAxisCount = 4;
                                actionsAspectRatio = 1.8;
                              } else if (width > 800) {
                                statsCrossAxisCount = 3;
                                actionsCrossAxisCount = 3;
                                actionsAspectRatio = 1.7;
                              }

                              return SingleChildScrollView(
                                physics: AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPerformanceSummary(width),
                                    SizedBox(height: 24),
                                    _buildStatsGrid(statsCrossAxisCount),
                                    SizedBox(height: 24),
                                    if (_userRole == 'teacher') ...[
                                      _buildRecentAttempts(),
                                      SizedBox(height: 24),
                                    ],
                                    _buildQuickActions(actionsCrossAxisCount,
                                        actionsAspectRatio),
                                    SizedBox(height: 24),
                                  ],
                                ),
                              );
                            },
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
      padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
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
                      color: AppColors.getGlassColor(context, opacity: 0.15),
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
                        color: AppColors.getGlassColor(context, opacity: 0.3),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.refresh, color: AppColors.getTextColor(context)),
                      onPressed: _loadStats,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            _userRole == 'teacher'
                ? _t('teacher_dashboard')
                : _userRole == 'super_admin'
                    ? '${_t('admin_dashboard')} (المدير العام)'
                    : _t('admin_dashboard'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
          SizedBox(height: 8),
          Text(
            _userRole == 'teacher'
                ? 'إدارة محتواك وطلابك باحترافية'
                : 'نظرة شاملة على أداء المنصة والعمليات',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.getTextColor(context).withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary(double screenWidth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              width: 1,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _t('performance_summary_title'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          _buildSummaryMiniItem('${_stats['total_users'] ?? 0}', _t('student'), Colors.greenAccent),
                          SizedBox(width: 16),
                          _buildSummaryMiniItem('${_stats['total_courses'] ?? 0}', _t('courses_count_title'), Colors.blueAccent),
                          SizedBox(width: 16),
                          _buildSummaryMiniItem('${_stats['total_attempts'] ?? 0}', _t('attempt_unit_label'), Colors.orangeAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                VerticalDivider(color: AppColors.getTextColor(context).withOpacity(0.1), width: 32),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 50,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(7, (index) {
                            final activity = (_stats['daily_activity'] as List?) ?? [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7];
                            double maxActivity = activity.cast<num>().reduce((a, b) => a > b ? a : b).toDouble();
                            if (maxActivity < 1) maxActivity = 1;
                            double heightFactor = (activity[index].toDouble() / maxActivity).clamp(0.1, 1.0);
                            return _buildChartBar(heightFactor, index == 6);
                          }),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${_t('weekly_growth_label')} +${_stats['weekly_growth'] ?? '0'}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.getTextColor(context).withOpacity(0.5),
                        ),
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

  Widget _buildSummaryMiniItem(String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: AppColors.getTextColor(context).withOpacity(0.5)),
        ),
      ],
    );
  }

  Widget _buildChartBar(double heightFactor, bool isLast) {
    return Container(
      width: 12,
      height: 50 * heightFactor,
      decoration: BoxDecoration(
        color: isLast 
            ? AppColors.primaryPurple 
            : AppColors.getTextColor(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStatsGrid(int crossAxisCount) {
    final List<Widget> cards = [
      _buildStatCard(
        icon: Icons.people,
        label: _t('admin_users'),
        value: '${_stats['total_users'] ?? 0}',
        color: Colors.blue,
      ),
      _buildStatCard(
        icon: Icons.bolt_rounded,
        label: _t('active_users_label'),
        value: '${_stats['active_users'] ?? 0}',
        color: Colors.amber,
      ),
      _buildStatCard(
        icon: Icons.school,
        label: _t('courses_count_title'),
        value: '${_stats['total_courses'] ?? 0}',
        color: Colors.purple,
      ),
      _buildStatCard(
        icon: Icons.assignment,
        label: _t('exams'),
        value: '${_stats['total_exams'] ?? 0}',
        color: Colors.orange,
      ),
      _buildStatCard(
        icon: Icons.analytics,
        label: _t('total_attempts_title'),
        value: '${_stats['total_attempts'] ?? 0}',
        color: Colors.green,
      ),
    ];

    if (_userRole == 'super_admin') {
      cards.add(
        _buildStatCard(
          icon: Icons.account_balance_wallet_rounded,
          label: _t('total_revenue_label'),
          value: '${((_stats['total_revenue'] ?? 0.0) as num).toInt()}',
          color: Colors.teal,
        ),
      );
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: cards,
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
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextColor(context).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  Widget _buildQuickActions(int crossAxisCount, double childAspectRatio) {
    final List<Map<String, dynamic>> actions = [
      if (_userRole == 'teacher') ...[
        {
          'icon': Icons.library_books_rounded,
          'title': 'إدارة دوراتي',
          'subtitle': 'إضافة وتعديل دروس دوراتك',
          'color': Colors.tealAccent,
          'onTap': () => context.push('/admin/courses?instructorId=$_userId'),
        },
        {
          'icon': Icons.analytics_rounded,
          'title': 'الإحصائيات',
          'subtitle': 'نظرة شاملة على الأداء والطلاب',
          'color': Colors.indigoAccent,
          'onTap': () => context.push('/admin/subscriptions/teacher/$_userId?name=${Uri.encodeComponent(_userName ?? "")}'),
        },
        {
          'icon': Icons.assessment_rounded,
          'title': _t('manage_reports'),
          'subtitle': 'تقارير الأرباح والتسجيلات الخاصة بي',
          'color': Colors.deepPurpleAccent,
          'onTap': () => context.push('/admin/reports/financial?instructorId=$_userId'),
        },
        {
          'icon': Icons.people_alt_rounded,
          'title': 'نتائج الطلاب',
          'subtitle': 'متابعة نتائج الاختبارات والدرجات',
          'color': Colors.orangeAccent,
          'onTap': () => context.push('/admin/results'),
        },
      ] else ...[
        // Full Admin Actions
        {
          'icon': Icons.people_rounded,
          'title': _t('manage_users'),
          'subtitle': _t('admin_users_desc'),
          'color': Colors.blueAccent,
          'onTap': () => context.push('/admin/users'),
        },
        {
          'icon': Icons.category_rounded,
          'title': _t('manage_categories'),
          'subtitle': _t('admin_categories_desc'),
          'color': Colors.purpleAccent,
          'onTap': () => context.push('/admin/categories'),
        },
        {
          'icon': Icons.school_rounded,
          'title': _t('manage_teachers'),
          'subtitle': _t('admin_teachers_desc'),
          'color': Colors.cyanAccent,
          'onTap': () => context.push('/admin/teachers'),
        },
        {
          'icon': Icons.people_alt_rounded,
          'title': 'نتائج الطلاب',
          'subtitle': 'متابعة كافة المشتركين',
          'color': Colors.orangeAccent,
          'onTap': () => context.push('/admin/results'),
        },
        {
          'icon': Icons.library_books_rounded,
          'title': _t('manage_courses'),
          'subtitle': _t('admin_courses_desc'),
          'color': Colors.tealAccent,
          'onTap': () => context.push('/admin/courses'),
        },
        {
          'icon': Icons.card_giftcard_rounded,
          'title': _t('manage_bundles'),
          'subtitle': _t('admin_bundles_desc'),
          'color': Colors.pinkAccent,
          'onTap': () => context.push('/admin/bundles'),
        },
        {
          'icon': Icons.lightbulb_rounded,
          'title': _t('tips'),
          'subtitle': _t('admin_tips_desc'),
          'color': Colors.amberAccent,
          'onTap': () => context.push('/admin/tips'),
        },
        {
          'icon': Icons.view_carousel_rounded,
          'title': _t('admin_banners_side'),
          'subtitle': _t('admin_banners_desc'),
          'color': Colors.lightBlueAccent,
          'onTap': () => context.push('/admin/banners'),
        },
        {
          'icon': Icons.share_rounded,
          'title': _t('admin_social_links_side'),
          'subtitle': _t('admin_social_links_desc'),
          'color': Colors.indigoAccent,
          'onTap': () => context.push('/admin/social-links'),
        },
        {
          'icon': Icons.subscriptions_rounded,
          'title': _t('manage_subscriptions'),
          'subtitle': _t('admin_subscriptions_desc'),
          'color': Colors.redAccent,
          'onTap': () => context.push('/admin/subscriptions'),
        },
        {
          'icon': Icons.payments_rounded,
          'title': _t('manage_payments'),
          'subtitle': _t('admin_payments_desc'),
          'color': Colors.greenAccent,
          'onTap': () => context.push('/admin/payments'),
        },
        {
          'icon': Icons.assessment_rounded,
          'title': _t('manage_reports'),
          'subtitle': _t('admin_reports_desc'),
          'color': Colors.deepPurpleAccent,
          'onTap': () => context.push('/admin/reports/financial'),
        },
        {
          'icon': Icons.notifications_active_rounded,
          'title': _t('manage_notifications'),
          'subtitle': _t('admin_notifications_desc'),
          'color': Colors.orangeAccent,
          'onTap': () => context.push('/admin/admin-notifications'),
        },
        {
          'icon': Icons.qr_code_rounded,
          'title': _t('manage_qr'),
          'subtitle': _t('admin_qr_desc'),
          'color': Colors.blueGrey,
          'onTap': () => context.push('/admin/qr'),
        },
        {
          'icon': Icons.system_update_rounded,
          'title': _t('manage_updates'),
          'subtitle': _t('admin_updates_desc'),
          'color': Colors.lightGreenAccent,
          'onTap': () => context.push('/admin/updates'),
        },
        {
          'icon': Icons.security_rounded,
          'title': _t('manage_security'),
          'subtitle': _t('admin_security_desc'),
          'color': Colors.redAccent,
          'onTap': () => context.push('/admin/security'),
        },
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            _t('admin_quick_actions'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: AppColors.getTextColor(context),
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return _buildActionCard(
              icon: action['icon'],
              title: action['title'],
              subtitle: action['subtitle'],
              color: action['color'],
              onTap: action['onTap'],
            );
          },
        ),
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
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.getTextColor(context).withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                _t('admin_recent_attempts'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                  color: AppColors.getTextColor(context),
                ),
              ),
              Text(
                _t('admin_view_all'),
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
                    _t('admin_no_attempts'),
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
                      ),
                      title: Text(
                        user?['full_name'] ?? _t('anonymous_user'),
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
                            exam?['title'] ?? _t('admin_unknown_exam'),
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
                              isPassed ? _t('admin_passed') : _t('admin_failed'),
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
