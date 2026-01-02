import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../settings/settings_screen.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../admin/admin_dashboard_screen.dart';
import '../teacher/teacher_dashboard_screen.dart';
import '../courses/my_downloads_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<Map<String, dynamic>> _orders = [];
  int _selectedCoursesTab = 0; // 0: Current, 1: Completed
  String _userRole = 'student';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload profile data when returning from other screens
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        return;
      }

      // Get user data from users table (not from userMetadata)
      final userData = await SupabaseService.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      final stats = await _databaseService.getUserStats();
      final enrollments =
          await _databaseService.getEnrolledCoursesWithProgress();
      final orders = await _databaseService.getUserOrders();
      final role = await _databaseService.getUserRole();

      setState(() {
        _userProfile = userData ?? {};
        _stats = stats;
        _enrolledCourses = enrollments;
        _orders = orders;
        _userRole = role;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header with Settings Button
                _buildHeader(),

                const SizedBox(height: 20),

                // Profile Picture with Glass Effect
                _buildProfilePicture(),

                const SizedBox(height: 20),

                // User Name
                Text(
                  _userProfile?['full_name'] ?? 'المستخدم',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                // Branch Badge
                _buildBranchBadge(),

                const SizedBox(height: 30),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.book_outlined,
                        value: '${_stats['completed_courses'] ?? 0}',
                        label: 'دورة مكتملة',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.access_time,
                        value: (_stats['learning_hours'] as num?)?.toStringAsFixed(1) ?? '0.0',
                        label: 'ساعة تعلم',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.workspace_premium,
                        value: '${_stats['certificates'] ?? 0}',
                        label: 'شهادات',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // My Courses Section
                // My Courses Section
                _buildSectionTitle('دوراتي'),

                const SizedBox(height: 16),

                // Course Tabs
                Container(
                  padding: const EdgeInsets.all(4),
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
                        child: _buildCourseTab(
                          title: 'الحالية',
                          isSelected: _selectedCoursesTab == 0,
                          onTap: () => setState(() => _selectedCoursesTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildCourseTab(
                          title: 'المنتهية',
                          isSelected: _selectedCoursesTab == 1,
                          onTap: () => setState(() => _selectedCoursesTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Display filtered courses
                Builder(
                  builder: (context) {
                    final filteredCourses =
                        _enrolledCourses.where((enrollment) {
                      final progress =
                          (enrollment['progress'] as num?)?.toDouble() ?? 0.0;
                      final isCompleted = progress >= 100.0;
                      return _selectedCoursesTab == 0
                          ? !isCompleted
                          : isCompleted;
                    }).toList();

                    if (filteredCourses.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _selectedCoursesTab == 0
                              ? 'لا توجد دورات حالية'
                              : 'لم تكمل أي دورة بعد',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: filteredCourses.map((enrollment) {
                        final courseData = enrollment['courses'];
                        if (courseData == null) return const SizedBox();

                        final progress =
                            (enrollment['progress'] as num?)?.toDouble() ?? 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildCourseCard(
                            title: courseData['title'] ?? '',
                            teacher: courseData['instructor_name'] ?? '',
                            progress: progress / 100,
                            image: courseData['image_url'] ?? '',
                            isPublished: courseData['is_published'] ?? true,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // Orders Section
                _buildSectionTitle('طلباتي'),

                const SizedBox(height: 16),

                if (_orders.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'لا توجد طلبات سابقة',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Column(
                    children:
                        _orders.map((order) => _buildOrderCard(order)).toList(),
                  ),

                const SizedBox(height: 30),

                // Dashboard Button (for Admins & Teachers)
                if (_userRole == 'admin' ||
                    _userRole == 'super_admin' ||
                    _userRole == 'teacher') ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (_userRole == 'teacher') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const TeacherDashboardScreen(),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AdminDashboardScreen(),
                                  ),
                                );
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.dashboard, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'لوحة التحكم',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // My Downloads Button
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.offline_pin,
                        label: 'التنزيلات',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyDownloadsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.logout,
                        label: 'تسجيل الخروج',
                        onTap: () {},
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'الملف الشخصي',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 3,
        ),
      ),
      child: ClipOval(
        child: (_userProfile != null &&
                _userProfile?['avatar_url'] != null &&
                _userProfile!['avatar_url'].isNotEmpty)
            ? Image.network(
                _userProfile?['avatar_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  final userName = _userProfile?['full_name']?.trim() ?? 'User';
                  final fallbackUrl =
                      'https://ui-avatars.com/api/?name=${Uri.encodeComponent(userName)}&background=7B2CBF&color=fff&size=200';
                  return Image.network(
                    fallbackUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.white70,
                    ),
                  );
                },
              )
            : Image.network(
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_userProfile?['full_name']?.trim() ?? 'User')}&background=7B2CBF&color=fff&size=200',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.person,
                  size: 30,
                  color: Colors.white70,
                ),
              ),
      ),
    );
  }

  Widget _buildBranchBadge() {
    final branch = _userProfile?['branch'] ?? 'علمي';
    final branchText = branch == 'علمي'
        ? 'الفرع العلمي'
        : branch == 'أدبي'
            ? 'الفرع الأدبي'
            : 'الفرع $branch';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        branchText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCourseCard({
    required String title,
    required String teacher,
    required double progress,
    required String image,
    bool isPublished = true,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: Image.network(
                  image,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryPurple,
                          ),
                          minHeight: 6,
                        ),
                      ),
                      if (!isPublished)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'هذه الدورة غير متاحة حاليا',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.redAccent.withOpacity(0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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

  Widget _buildCourseTab({
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

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final amount = order['amount'] ?? 0;
    final createdAt = DateTime.parse(order['created_at']);
    final dateStr = '${createdAt.year}/${createdAt.month}/${createdAt.day}';

    Color statusColor;
    String statusText;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'مكتمل';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'فاشل';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'قيد المعالجة';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getGlassColor(context, opacity: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'طلب #${order['id'].toString().substring(0, 8)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amount ل.س',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
