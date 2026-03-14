import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/github_storage_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/image_upload_service.dart';
import '../../core/utils/string_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';

class TeachersManagementScreen extends StatefulWidget {
  const TeachersManagementScreen({super.key});

  @override
  State<TeachersManagementScreen> createState() =>
      _TeachersManagementScreenState();
}

class _TeachersManagementScreenState extends State<TeachersManagementScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _filteredTeachers = [];
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _expandedCards =
      {}; // Track expanded state for each teacher

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final teachers = await _db.getAllTeachers(forceRefresh: true);
      final courses = await _db.getCourses();

      // Load teacher courses for each teacher
      for (var teacher in teachers) {
        final userId = teacher['users']?['id'];
        if (userId != null) {
          try {
            // Get courses assigned to this specific teacher directly from courses table
            // This ensures consistency with what the Teacher sees on their dashboard
            final teacherCourses = await _db.getCourses(
              includeDrafts: true,
              instructorId: userId,
            );

            // Map to the structure expected by the UI card
            teacher['teacher_courses'] = teacherCourses
                .map((c) => {'course_id': c['id'], 'courses': c})
                .toList();
          } catch (e) {
            teacher['teacher_courses'] = [];
          }
        }
      }

      setState(() {
        _teachers = teachers;
        _filteredTeachers = teachers;
        _courses = courses;
        _isLoading = false;
      });
      _onSearchChanged(); // Apply search if controller is not empty
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

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTeachers = _teachers.where((teacher) {
        final user = teacher['users'] as Map<String, dynamic>?;
        final fullName = (user?['full_name'] as String? ?? '').toLowerCase();
        final email = (user?['email'] as String? ?? '').toLowerCase();
        return fullName.contains(query) || email.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                _buildHeader(context),
                _buildSearchBar(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : _filteredTeachers.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: _filteredTeachers.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildTeacherCard(
                                        context, _filteredTeachers[index]),
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

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.3),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _onSearchChanged(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'البحث عن مدرس بالاسم أو البريد...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
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
              'إدارة المدرسين',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_filteredTeachers.length} مدرس',
              style: TextStyle(
                color: AppColors.getTextColor(context),
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCard(BuildContext context, Map<String, dynamic> teacher) {
    final user = teacher['users'] as Map<String, dynamic>?;
    final teacherCourses = teacher['teacher_courses'] as List? ?? [];
    final teacherId = user?['id'] ?? '';
    final isExpanded = _expandedCards[teacherId] ?? false;

    return ClipRRect(
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
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with teacher info
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.purple.withOpacity(0.3),
                      radius: 28,
                      child: user?['avatar_url'] != null
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: GitHubStorageService.toRawUrl(user!['avatar_url']),
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                                placeholder: (context, url) => const Icon(
                                    Icons.school,
                                    color: Colors.purple,
                                    size: 28),
                                errorWidget: (context, url, error) => const Icon(
                                    Icons.school,
                                    color: Colors.purple,
                                    size: 28),
                              ),
                            )
                          : const Icon(Icons.school,
                              color: Colors.purple, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            StringUtils.cleanTeacherName(
                                user?['full_name'] ?? 'مدرس'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                          Text(
                            user?['email'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 3, 91, 255)
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${teacherCourses.length} دورة',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 250, 250, 250),
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Edit profile button
                        InkWell(
                          onTap: () => _showEditTeacherDialog(user),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.getGlassColor(context,
                                  opacity: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit,
                              color: AppColors.getTextColor(context),
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bio - Show under teacher name
                if (user?['bio'] != null &&
                    (user!['bio'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getGlassColor(context, opacity: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.getGlassColor(context, opacity: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      user['bio'],
                      style: TextStyle(
                        color:
                            AppColors.getTextColor(context).withOpacity(0.85),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                // Courses list - Expandable
                if (teacherCourses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedCards[teacherId] = !isExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.getGlassColor(context, opacity: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.getGlassColor(context, opacity: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: AppColors.getTextColor(context),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'الدورات المرتبطة (${teacherCourses.length})',
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 8),
                    ...teacherCourses.map((tc) {
                      final course = tc['courses'] as Map<String, dynamic>?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                AppColors.getGlassColor(context, opacity: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.getGlassColor(context,
                                  opacity: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.book,
                                color: AppColors.getTextColor(context,
                                    secondary: true),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  course?['title'] ?? 'دورة',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              // Delete course button
                              InkWell(
                                onTap: () => _confirmRemoveCourse(
                                  user?['id'],
                                  tc['course_id'],
                                  course?['title'] ?? 'الدورة',
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],

                const SizedBox(height: 16),
                // Add course button
                _buildActionButton(
                  context: context,
                  icon: Icons.add,
                  label: 'ربط بدورة جديدة',
                  onTap: () => _showAssignCourseDialog(user?['id']),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon,
                          color: AppColors.getTextColor(context), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
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
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
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
                    width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school,
                      color: AppColors.getTextColor(context), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'لا يوجد مدرسون',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.getTextColor(context).withOpacity(0.8),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmRemoveCourse(
      String? teacherId, String? courseId, String courseName) {
    if (teacherId == null || courseId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryPurple,
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من إلغاء ربط المدرس بدورة "$courseName"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await _db.removeTeacherFromCourse(teacherId, courseId);
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('تم إلغاء الربط بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditTeacherDialog(Map<String, dynamic>? user) {
    if (user == null) return;

    final nameController = TextEditingController(text: user['full_name'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final avatarController =
        TextEditingController(text: user['avatar_url'] ?? '');
    final bioController = TextEditingController(text: user['bio'] ?? '');
    bool isAvatarUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.primaryPurple,
          title: const Text('تعديل بروفايل المدرس',
              style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full Name
                const Text(
                  'الاسم الكامل',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'أدخل الاسم الكامل',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Email
                const Text(
                  'البريد الإلكتروني',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  enabled: false, // Email usually shouldn't be editable
                  decoration: InputDecoration(
                    hintText: 'البريد الإلكتروني',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: const Icon(Icons.lock_outline,
                        color: Colors.white54, size: 18),
                  ),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 16),

                // Avatar URL
                const Text(
                  'رابط الصورة الشخصية',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: avatarController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          hintText: 'https://example.com/image.jpg',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.link,
                              color: Colors.white54, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        setState(() => isAvatarUploading = true);
                        try {
                          final imageService = ImageUploadService();
                          final imageFile = await imageService.pickImage();
                          if (imageFile != null) {
                            final url = await imageService.uploadImageToGitHub(
                              imageFile,
                              folder: 'images/teachers',
                            );
                            avatarController.text = url;
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      ErrorUtils.getFriendlyErrorMessage(e)),
                                  backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setState(() => isAvatarUploading = false);
                        }
                      },
                      icon: isAvatarUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_a_photo),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'اترك فارغاً لاستخدام الصورة الافتراضية',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),

                // Bio
                const Text(
                  'السيرة الذاتية',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: bioController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'نبذة مختصرة عن المدرس...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('إلغاء', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                // Validate
                if (nameController.text.trim().isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('الاسم الكامل مطلوب'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  // Update user data
                  await SupabaseService.instance.client.from('users').update({
                    'full_name': nameController.text.trim(),
                    'avatar_url': avatarController.text.trim().isEmpty
                        ? null
                        : avatarController.text.trim(),
                    'bio': bioController.text.trim().isEmpty
                        ? null
                        : bioController.text.trim(),
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', user['id']);

                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث البروفايل بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignCourseDialog(String? teacherId) {
    if (teacherId == null) return;

    // Get teacher's current courses
    final teacher = _teachers.firstWhere(
      (t) => t['users']?['id'] == teacherId,
      orElse: () => {},
    );
    final teacherCourses = teacher['teacher_courses'] as List? ?? [];
    final assignedCourseIds =
        teacherCourses.map((tc) => tc['course_id']).toSet();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryPurple,
        title: const Text('ربط بدورة', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: _courses.isEmpty
              ? const Center(
                  child: Text(
                    'لا توجد دورات متاحة',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _courses.length,
                  itemBuilder: (context, index) {
                    final course = _courses[index];
                    final isAssigned = assignedCourseIds.contains(course['id']);

                    return ListTile(
                      title: Text(
                        course['title'] ?? '',
                        style: TextStyle(
                          color: isAssigned
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white,
                        ),
                      ),
                      trailing: isAssigned
                          ? const Icon(Icons.check_circle,
                              color: Colors.green, size: 20)
                          : null,
                      enabled: !isAssigned,
                      onTap: isAssigned
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await _db.assignTeacherToCourse(
                                    teacherId, course['id']);
                                if (mounted) {
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('تم الربط بنجاح'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _loadData();
                                }
                              } catch (e) {
                                if (mounted) {
                                  navigator.pop();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          ErrorUtils.getFriendlyErrorMessage(
                                              e)),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
