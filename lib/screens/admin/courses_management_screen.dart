import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'create_course_screen.dart';
import 'lessons_management_screen.dart';
import 'exams_management_screen.dart';

class CoursesManagementScreen extends StatefulWidget {
  final String? instructorId; // Added

  const CoursesManagementScreen({super.key, this.instructorId});

  @override
  State<CoursesManagementScreen> createState() =>
      _CoursesManagementScreenState();
}

class _CoursesManagementScreenState extends State<CoursesManagementScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filter = 'all'; // all, published, draft

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() => _isLoading = true);
    try {
      final courses = await _db.getCourses(
        includeDrafts: true,
        instructorId: widget.instructorId,
      );

      // Load teacher for each course
      for (var course in courses) {
        try {
          // Get teacher assignment from teacher_courses table
          final teacherCourseData = await SupabaseService.instance.client
              .from('teacher_courses')
              .select('teacher_id')
              .eq('course_id', course['id'])
              .maybeSingle();

          if (teacherCourseData != null) {
            // Get teacher user data
            final teacherData = await SupabaseService.instance.client
                .from('users')
                .select('*')
                .eq('id', teacherCourseData['teacher_id'])
                .maybeSingle();

            if (teacherData != null) {
              course['teacher'] = teacherData;
            } else {
              course['teacher'] = null;
            }
          } else {
            course['teacher'] = null;
          }
        } catch (e) {
          debugPrint('Error loading teacher for course ${course['id']}: $e');
          course['teacher'] = null;
        }
      }

      setState(() {
        _courses = courses;
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

  List<Map<String, dynamic>> get _filteredCourses {
    var filtered = _courses;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((course) {
        final title = course['title']?.toString().toLowerCase() ?? '';
        final description =
            course['description']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    // Filter by status
    if (_filter == 'published') {
      filtered = filtered.where((c) => c['is_published'] == true).toList();
    } else if (_filter == 'draft') {
      filtered = filtered.where((c) => c['is_published'] == false).toList();
    }

    return filtered;
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
                _buildFilterTabs(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : _filteredCourses.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _loadCourses,
                              displacement: 20,
                              color: AppColors.primaryPurple,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                itemCount: _filteredCourses.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildCourseCard(
                                        context, _filteredCourses[index]),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateCourseScreen(
                  preselectedInstructorId: widget.instructorId,
                ),
              ),
            );
            if (result == true) _loadCourses();
          },
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 8,
          icon: const Icon(Icons.add),
          label: const Text('إنشاء دورة',
              style: TextStyle(fontWeight: FontWeight.normal)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.instructorId != null
                      ? 'إدارة دوراتي'
                      : 'إدارة الدورات',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  'إجمالي ${_courses.length} دورة تعليمية',
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

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: ClipRRect(
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
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'بحث عن دورة...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon:
                    Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
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

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          _buildFilterTab(context, 'الكل', 'all'),
          const SizedBox(width: 10),
          _buildFilterTab(context, 'منشور', 'published'),
          const SizedBox(width: 10),
          _buildFilterTab(context, 'مسودة', 'draft'),
        ],
      ),
    );
  }

  Widget _buildFilterTab(BuildContext context, String label, String value) {
    final isSelected = _filter == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryPurple.withOpacity(0.8)
                    : AppColors.getGlassColor(context, opacity: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryPurple.withOpacity(0.5)
                      : AppColors.getGlassColor(context, opacity: 0.2),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primaryPurple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.getTextColor(context).withOpacity(0.7),
                  fontWeight:
                      isSelected ? FontWeight.normal : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCard(BuildContext context, Map<String, dynamic> course) {
    final isPublished = course['is_published'] as bool? ?? false;

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
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['title'] ?? 'دورة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.category,
                              size: 14, color: Colors.white.withOpacity(0.5)),
                          const SizedBox(width: 4),
                          Text(
                            course['category'] ?? 'تخصص عام',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        (isPublished ? Colors.greenAccent : Colors.orangeAccent)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isPublished
                              ? Colors.greenAccent
                              : Colors.orangeAccent)
                          .withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    isPublished ? 'منشور' : 'مسودة',
                    style: TextStyle(
                      color: isPublished
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                    child:
                        const Icon(Icons.person, size: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      course['teacher'] != null
                          ? (course['teacher']['full_name'] ??
                              course['teacher']['name'] ??
                              'مدرس غير محدد')
                          : 'مدرس غير محدد',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.getTextColor(context).withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            children: [
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              Text(
                course['description'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextColor(context).withOpacity(0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.list_alt_rounded,
                      label: 'الدروس',
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LessonsManagementScreen(
                              courseId: course['id'],
                              courseTitle: course['title'] ?? 'دورة',
                            ),
                          ),
                        );
                        if (result == true) _loadCourses();
                      },
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.quiz_rounded,
                      label: 'الاختبارات',
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminExamsManagementScreen(
                              courseId: course['id'],
                              courseTitle: course['title'] ?? 'دورة',
                            ),
                          ),
                        );
                        if (result == true) _loadCourses();
                      },
                      color: Colors.purpleAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.edit_note_rounded,
                      label: 'تعديل',
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateCourseScreen(
                              courseId: course['id'],
                              courseData: course,
                            ),
                          ),
                        );
                        if (result == true) _loadCourses();
                      },
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.analytics_outlined,
                          color: Colors.blueAccent),
                      onPressed: () => _showStatistics(course),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent),
                      onPressed: () => _deleteCourse(course),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 80,
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد دورات حالياً',
              style: TextStyle(
                fontSize: 20,
                color: AppColors.getTextColor(context),
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ابدأ بإضافة أول دورة تعليمية للمنصة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextColor(context).withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCourse(Map<String, dynamic> course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدورة'),
        content: const Text(
          'هل أنت متأكد من حذف هذه الدورة؟ سيتم حذف جميع الدروس المرتبطة بها.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.deleteCourse(course['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الدورة'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadCourses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showStatistics(Map<String, dynamic> course) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final stats = await _db.getCourseStatistics(course['id']);

      if (mounted) {
        Navigator.pop(context);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.analytics),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('إحصائيات: ${course['title']}'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow('المشتركين', '${stats['total_enrollments']}'),
                const Divider(),
                _buildStatRow('المكملين', '${stats['completed_enrollments']}'),
                const Divider(),
                _buildStatRow('الدروس', '${stats['total_lessons']}'),
                const Divider(),
                _buildStatRow('متوسط التقدم', '${stats['average_progress']}%'),
                const Divider(),
                _buildStatRow('معدل الإكمال', '${stats['completion_rate']}%'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
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
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
