import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'create_course_screen.dart';
import 'lessons_management_screen.dart';
import 'exams_management_screen.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';

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
  String _filter = 'published'; // all, published, draft

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

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

      // Note: _db.getCourses() already joins with users!instructor_id and provides instructor_name.
      // We also map it for compatibility with the UI component's expectation of 'teacher' object if needed.
      for (var course in courses) {
        if (course['users'] != null && course['teacher'] == null) {
          course['teacher'] = course['users'];
        } else if (course['instructor_name'] != null && course['teacher'] == null) {
          course['teacher'] = {
            'full_name': course['instructor_name'],
            'avatar_url': course['instructor_photo'],
          };
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
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
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
                      ? Center(
                          child: CircularProgressIndicator(color: AppColors.primaryPurple),
                        )
                      : _filteredCourses.isEmpty
                          ? _buildEmptyState(context)
                          : RefreshIndicator(
                              onRefresh: _loadCourses,
                              displacement: 20,
                              color: AppColors.primaryPurple,
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                itemCount: _filteredCourses.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 16),
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
          icon: Icon(Icons.add),
          label: Text(_t('create_new_course'),
              style: TextStyle(fontWeight: FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.instructorId != null
                      ? _t('manage_my_courses')
                      : _t('manage_courses'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  _t('total_courses_count')
                      .replaceAll('{count}', _courses.length.toString()),
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
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
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
              hintText: _t('search_hint'),
              hintStyle:
                  TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 14),
              prefixIcon: Icon(Icons.search,
                  color: AppColors.getTextColor(context, secondary: true), size: 18),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          _buildFilterTab(context, 'الكل', 'all'),
          SizedBox(width: 10),
          _buildFilterTab(context, 'منشور', 'published'),
          SizedBox(width: 10),
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
              padding: EdgeInsets.symmetric(vertical: 12),
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
                          offset: Offset(0, 2),
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
                      : AppColors.getTextColor(context),
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
            tilePadding: EdgeInsets.all(16),
            childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: RoundedRectangleBorder(side: BorderSide.none),
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
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.category,
                              size: 14, color: AppColors.primaryBlue),
                          SizedBox(width: 4),
                          Text(
                            course['category'] ?? _t('general_specialization'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (course['discount_percentage'] != null &&
                    (course['discount_percentage'] as num) > 0)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    padding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '-${course['discount_percentage']}%',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    isPublished ? _t('published') : _t('draft'),
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
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                    child:
                        Icon(Icons.person, size: 14, color: AppColors.primaryPurple),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      course['teacher'] != null
                          ? (course['teacher']['full_name'] ??
                              course['teacher']['name'] ??
                              _t('unspecified_teacher'))
                          : _t('unspecified_teacher'),
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
              Divider(color: AppColors.getTextColor(context).withOpacity(0.10)),
              SizedBox(height: 12),
              Text(
                course['description'] ?? '',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextColor(context),
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.list_alt_rounded,
                      label: _t('lessons'),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LessonsManagementScreen(
                              courseId: course['id'],
                              courseTitle: course['title'] ?? _t('course'),
                            ),
                          ),
                        );
                        if (result == true) _loadCourses();
                      },
                      color: Colors.blueAccent,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.quiz_rounded,
                      label: _t('exams'),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminExamsManagementScreen(
                              courseId: course['id'],
                              courseTitle: course['title'] ?? _t('course'),
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
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      icon: Icons.edit_note_rounded,
                      label: _t('edit'),
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
                  SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.5)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.analytics_outlined,
                          color: Colors.blue),
                      onPressed: () => _showStatistics(course),
                    ),
                  ),
                  SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Colors.red),
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
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            SizedBox(width: 8),
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
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.getMutedTextColor(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 80,
                color: AppColors.getTextColor(context).withOpacity(0.2),
              ),
            ),
            SizedBox(height: 24),
            Text(
              _t('no_courses_current'),
              style: TextStyle(
                fontSize: 20,
                color: AppColors.getTextColor(context),
                fontWeight: FontWeight.normal,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _t('start_adding_first_course'),
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
        title: Text(_t('delete_course_title')),
        content: Text(_t('delete_course_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _t('delete'),
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
          SnackBar(
            content: Text(_t('course_removed')),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadCourses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showStatistics(Map<String, dynamic> course) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
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
                Icon(Icons.analytics),
                SizedBox(width: 8),
                Expanded(
                  child: Text('${_t('statistics')}: ${course['title']}'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow(_t('subscribers'), '${stats['total_enrollments']}'),
                Divider(),
                _buildStatRow(_t('completers'), '${stats['completed_enrollments']}'),
                Divider(),
                _buildStatRow(_t('lessons'), '${stats['total_lessons']}'),
                Divider(),
                _buildStatRow(_t('average_progress_label'), '${stats['average_progress']}%'),
                Divider(),
                _buildStatRow(_t('completion_rate_label'), '${stats['completion_rate']}%'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_t('close')),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
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
