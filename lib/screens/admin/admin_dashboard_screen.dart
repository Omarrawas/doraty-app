import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import 'users_management_screen.dart';
import 'teachers_management_screen.dart';
import 'courses_management_screen.dart';
import 'subscriptions_management_screen.dart';
import 'payment_receipts_screen.dart';
import 'categories_management_screen.dart';
import 'notifications_management_screen.dart';

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
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.adminLightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Column(
            children: [
              Text(_userRole == 'teacher'
                  ? 'لوحة تحكم المدرس'
                  : _userRole == 'super_admin'
                      ? 'لوحة تحكم المدير العام'
                      : 'لوحة تحكم الأدمن'),
              Text(
                _userRole == 'teacher'
                    ? 'إدارة دوراتك ومحتواك'
                    : _userRole == 'super_admin'
                        ? 'إدارة النظام الشاملة والرقابة'
                        : 'إدارة العمليات اليومية',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadStats,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryPurple,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadStats,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 24),
                      if (_userRole == 'teacher') ...[
                        _buildRecentAttempts(),
                        const SizedBox(height: 24),
                      ],
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildSystemInfo(),
                    ],
                  ),
                ),
              ),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إجراءات سريعة',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (_userRole != 'teacher') ...[
          _buildActionCard(
            icon: Icons.people_alt,
            title: 'إدارة المستخدمين',
            subtitle: 'عرض وإدارة جميع المستخدمين',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsersManagementScreen(),
                ),
              );
            },
          ),
          _buildActionCard(
            icon: Icons.category,
            title: 'إدارة التصنيفات',
            subtitle: 'إضافة وتعديل تصنيفات الدورات',
            color: Colors.pink,
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
            icon: Icons.school,
            title: 'إدارة المدرسين',
            subtitle: 'ربط المدرسين بالدورات',
            color: Colors.purple,
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
          icon: Icons.library_books,
          title: _userRole == 'teacher' ? 'إدارة دوراتي' : 'إدارة الدورات',
          subtitle: 'إنشاء وتعديل الدورات والدروس',
          color: Colors.teal,
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
            icon: Icons.card_membership,
            title: 'إدارة الاشتراكات',
            subtitle: 'عرض وإدارة جميع اشتراكات الطلاب',
            color: Colors.amber,
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
            icon: Icons.receipt_long,
            title: 'طلبات الدفع لإيصالات',
            subtitle: 'مراجعة وتأكيد إيصالات دفع الطلاب',
            color: Colors.orange,
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
            icon: Icons.notifications_active,
            title: 'إدارة الإشعارات',
            subtitle: 'إرسال إشعارات وتنبيهات',
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
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textLight,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'معلومات النظام',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: Colors.grey[50],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildInfoRow('الإصدار', '2.0.0'),
                const Divider(),
                _buildInfoRow('قاعدة البيانات', 'Supabase'),
                const Divider(),
                _buildInfoRow('الحالة', 'نشط', color: Colors.green),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttempts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أحدث محاولات الطلاب',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        if (_recentAttempts.isEmpty)
          Card(
            elevation: 0,
            color: Colors.grey[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'لا يوجد محاولات حديثة',
                  style: TextStyle(color: AppColors.textSecondary),
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

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user?['avatar_url'] != null
                        ? NetworkImage(user!['avatar_url'])
                        : null,
                    backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                    child: user?['avatar_url'] == null
                        ? const Icon(Icons.person,
                            color: AppColors.primaryPurple)
                        : null,
                  ),
                  title: Text(
                    user?['full_name'] ?? 'مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exam?['title'] ?? 'اختبار'),
                      Text(
                        '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$score / $total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPassed ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        isPassed ? 'ناجح' : 'راسب',
                        style: TextStyle(
                          fontSize: 12,
                          color: isPassed ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
