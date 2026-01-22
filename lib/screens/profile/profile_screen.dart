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
import '../auth/login_screen.dart';
import '../../widgets/empty_state.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/string_utils.dart';
import 'order_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  int _selectedCoursesTab = 0; // 0: Current, 1: Completed
  String _userRole = 'student';
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _enrolledCourses = [];

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

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
      String role = 'student';
      try {
        role = await _databaseService.getUserRole();
        // Also check userData table directly for role/is_admin fields
        if (userData != null) {
          // Priority: explicit role field, then is_admin flag
          if (userData['role'] != null &&
              userData['role'].toString().isNotEmpty) {
            role = userData['role'].toString();
          } else if (userData['is_admin'] == true) {
            role = 'admin';
          }
        }
      } catch (e) {
        debugPrint('Error fetching role: $e');
      }

      setState(() {
        _userProfile = userData ?? {};
        _stats = stats;
        _enrolledCourses = enrollments;
        _userRole = role;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('error_loading')}: $e')),
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
                  StringUtils.cleanTeacherName(
                      _userProfile?['full_name'] ?? _t('user')),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),



                const SizedBox(height: 30),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.book_outlined,
                        value: '${_stats['completed_courses'] ?? 0}',
                        label: _t('completed_courses_count_label'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.access_time,
                        value: (_stats['learning_hours'] as num?)?.toStringAsFixed(1) ?? '0.0',
                        label: _t('learning_hours'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.workspace_premium,
                        value: '${_stats['certificates'] ?? 0}',
                        label: _t('certificates'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // My Courses Section
                // My Courses Section
                _buildSectionTitle(_t('my_courses')),

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
                          title: _t('current'),
                          isSelected: _selectedCoursesTab == 0,
                          onTap: () => setState(() => _selectedCoursesTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildCourseTab(
                          title: _t('completed'),
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
                          (enrollment['progress_percentage'] as num?)
                                  ?.toDouble() ??
                              0.0;
                      final isCompleted = progress >= 100.0;
                      return _selectedCoursesTab == 0
                          ? !isCompleted
                          : isCompleted;
                    }).toList();

                    if (filteredCourses.isEmpty) {
                      return ProfessionalEmptyState(
                        title: _t(_selectedCoursesTab == 0
                            ? 'no_current_courses'
                            : 'no_completed_courses'),
                        message: _t(_selectedCoursesTab == 0
                            ? 'enrolled_courses_desc'
                            : 'courses_not_completed_desc'),
                        icon: _selectedCoursesTab == 0
                            ? Icons.book_rounded
                            : Icons.assignment_turned_in_rounded,
                      );
                    }

                    return Column(
                      children: filteredCourses.map((enrollment) {
                        final courseData = enrollment['courses'];
                        if (courseData == null) return const SizedBox();

                        final progress =
                            (enrollment['progress_percentage'] as num?)
                                    ?.toDouble() ??
                                0.0;

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
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.dashboard,
                                      color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    _userRole == 'teacher'
                                        ? _t('teacher_dashboard')
                                        : _t('admin_dashboard'),
                                    style: const TextStyle(
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

                // My Downloads & Orders Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.receipt_long_rounded,
                        label: _t('orders'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const OrderHistoryScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.offline_pin,
                        label: _t('my_downloads'),
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
                        label: _t('logout'),
                        onTap: () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(_t('logout')),
                              content: Text(_t('logout_confirm_desc')),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(_t('cancel')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(_t('logout')),
                                ),
                              ],
                            ),
                          );

                          if (confirmed != true) return;

                          if (!context.mounted) return;
                          final navigator = Navigator.of(context);
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);

                          try {
                            await SupabaseService.instance.signOut();

                            // Navigate to login screen and clear stack
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text('خطأ في تسجيل الخروج: $e')),
                            );
                          }
                        },
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
          Expanded(
            child: Text(
              _t('profile'),
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                child: Hero(
                  tag:
                      'profile_course_image_${title}_$teacher', // Unique enough fallback or better use course ID if available
                  child: Image.network(
                    image,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
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
}
