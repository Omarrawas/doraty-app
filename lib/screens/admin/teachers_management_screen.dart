import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import 'courses_management_screen.dart';

class TeachersManagementScreen extends StatefulWidget {
  const TeachersManagementScreen({super.key});

  @override
  State<TeachersManagementScreen> createState() =>
      _TeachersManagementScreenState();
}

class _TeachersManagementScreenState extends State<TeachersManagementScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch approved teachers and pending requests separately.
      final teachers = await _db.getAllTeachers();
      final pendingRequests = await _db.getPendingTeacherRequests();

      // 2. Fetch all courses (to group them by teacher later) - optimized batch call
      final allCourses = await _db.getCourses(includeDrafts: true);

      // Group courses by instructor_id for efficiency
      final Map<String, List<Map<String, dynamic>>> teacherCoursesMap = {};
      for (var course in allCourses) {
        final instructorId = course['instructor_id'];
        if (instructorId != null) {
          teacherCoursesMap.putIfAbsent(instructorId, () => []).add(course);
        }
      }

      // Attach courses to their respective teachers
      for (var teacher in teachers) {
        final teacherId = teacher['id'];
        teacher['teacher_courses'] = teacherCoursesMap[teacherId] ?? [];
      }

      final currentTeachers =
          teachers.where((t) => t['teacher_status'] != 'pending').toList();

      setState(() {
        _teachers = currentTeachers;
        _requests = pendingRequests;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    return _teachers.where((t) {
      final name = (t['full_name'] ?? t['name'] ?? '').toString().toLowerCase();
      final bio = (t['bio'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) ||
          bio.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

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
                _buildTabBar(context),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTeachersList(context),
                      _buildRequestsList(context),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          _buildGlassIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.pop(context),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('teachers_management_title'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  'إدارة المدربين والطلبات',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(15),
        border:
            Border.all(color: AppColors.getGlassColor(context, opacity: 0.2)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: AppColors.primaryPurple.withOpacity(0.8),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.getTextColor(context).withOpacity(0.6),
        labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(text: _t('current_teachers')),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_t('pending_requests')),
                if (_requests.isNotEmpty) ...[
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle),
                    child: Text(
                      _requests.length.toString(),
                      style: TextStyle(color: AppColors.getTextColor(context), fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachersList(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator());
    if (_filteredTeachers.isEmpty) {
      return _buildEmptyState(context, 'لا يوجد مدربين حالياً');
    }

    return Column(
      children: [
        _buildSearchBar(context),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _filteredTeachers.length,
              itemBuilder: (context, index) =>
                  _buildTeacherCard(context, _filteredTeachers[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator());
    if (_requests.isEmpty) {
      return _buildEmptyState(context, 'لا توجد طلبات انضمام معلقة');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: _requests.length,
        itemBuilder: (context, index) =>
            _buildRequestCard(context, _requests[index]),
      ),
    );
  }

  Widget _buildTeacherCard(BuildContext context, Map<String, dynamic> teacher) {
    final courses = teacher['teacher_courses'] as List<dynamic>? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: _glassDecoration(context),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
          backgroundImage: teacher['avatar_url'] != null
              ? NetworkImage(teacher['avatar_url'])
              : null,
          child: teacher['avatar_url'] == null
              ? Icon(Icons.person, color: AppColors.primaryPurple)
              : null,
        ),
        title: Text(teacher['full_name'] ?? teacher['name'] ?? 'مدرب',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(teacher['specialization'] ?? 'تخصص غير محدد',
            style: TextStyle(fontSize: 12)),
        children: [
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                    Icons.email_outlined, teacher['email'] ?? 'بدون بريد'),
                SizedBox(height: 8),
                _buildInfoRow(
                    Icons.school_outlined, 'عدد الكورسات: ${courses.length}'),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        label: 'إدارة الكورسات',
                        icon: Icons.auto_stories,
                        color: Colors.blueAccent,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CoursesManagementScreen(
                                  instructorId: teacher['id'])),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: _glassDecoration(context),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                child:
                    Icon(Icons.person_add, color: AppColors.primaryBlue),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request['full_name'] ?? 'طلب جديد',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(request['email'] ?? '',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextColor(context)
                                .withOpacity(0.6))),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (request['bio'] != null)
            Text(request['bio'],
                style: TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionBtn(
                  label: 'موافقة',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  onTap: () => _handleStatusUpdate(request['id'], 'approved'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _buildActionBtn(
                  label: 'رفض',
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  onTap: () => _handleStatusUpdate(request['id'], 'rejected'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleStatusUpdate(String teacherId, String status) async {
    try {
      await _db.updateTeacherStatus(teacherId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(status == 'approved'
                ? 'تمت الموافقة على الطلب'
                : 'تم رفض الطلب'),
            backgroundColor:
                status == 'approved' ? Colors.green : Colors.orange),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  // Helper widgets (Glass components)
  BoxDecoration _glassDecoration(BuildContext context) => BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.getGlassColor(context, opacity: 0.2), width: 1.5),
      );

  Widget _buildInfoRow(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryPurple),
          SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.getTextColor(context).withOpacity(0.8))),
        ],
      );

  Widget _buildActionBtn(
          {required String label,
          required IconData icon,
          required Color color,
          required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

  Widget _buildGlassIconButton(
          {required IconData icon, required VoidCallback onTap}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.getGlassColor(context, opacity: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.3))),
            child: IconButton(
                icon: Icon(icon, color: AppColors.getTextColor(context)),
                onPressed: onTap),
          ),
        ),
      );

  Widget _buildSearchBar(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          decoration: _glassDecoration(context),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: _t('search_hint'),
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
      );

  Widget _buildEmptyState(BuildContext context, String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                size: 64,
                color: AppColors.getTextColor(context).withOpacity(0.2)),
            SizedBox(height: 16),
            Text(message,
                style: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.5))),
          ],
        ),
      );
}
