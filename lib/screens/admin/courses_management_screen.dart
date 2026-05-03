import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/utils/safe_parser.dart'; // Add this import
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'sessions_management_screen.dart';

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
  String _typeFilter = 'all'; // all, recorded, live, in_person
  String? _errorMessage;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final courses = await _db.getCourses(
        includeDrafts: true,
        instructorId: widget.instructorId,
        forceRefresh: forceRefresh,
      );

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
        _errorMessage = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyErrorMessage(e);
        });
        debugPrint('Error loading courses: $e');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCourses {
    var filtered = _courses;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((course) {
        final title = course['title']?.toString().toLowerCase() ?? '';
        final description =
            course['description']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    if (_filter == 'published') {
      filtered = filtered.where((c) => SafeParser.toBool(c['is_published'])).toList();
    } else if (_filter == 'draft') {
      filtered = filtered.where((c) => !SafeParser.toBool(c['is_published'])).toList();
    }

    if (_typeFilter != 'all') {
      filtered = filtered.where((c) => c['delivery_mode'] == _typeFilter).toList();
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
                _buildTypeFilterTabs(context),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: AppColors.primaryPurple),
                        )
                      : _errorMessage != null
                          ? _buildErrorState()
                          : _filteredCourses.isEmpty
                              ? _buildEmptyState(context)
                              : RefreshIndicator(
                                  onRefresh: () => _loadCourses(forceRefresh: true),
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
            final instructorParam =
                widget.instructorId != null ? '?instructorId=${widget.instructorId}' : '';
            final result = await context.push('/admin/courses/create$instructorParam');
            if (result == true) _loadCourses(forceRefresh: true);
          },
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 8,
          icon: const Icon(Icons.add),
          label: Text(_t('create_new_course'),
              style: const TextStyle(fontWeight: FontWeight.normal)),
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
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
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
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: _t('search_hint'),
                hintStyle: TextStyle(
                  color: AppColors.getTextColor(context, secondary: true),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.getTextColor(context, secondary: true),
                  size: 18,
                ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _buildFilterTab(context, _t('all'), 'all'),
          const SizedBox(width: 10),
          _buildFilterTab(context, _t('published'), 'published'),
          const SizedBox(width: 10),
          _buildFilterTab(context, _t('draft'), 'draft'),
        ],
      ),
    );
  }

  Widget _buildTypeFilterTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          _buildTypeFilterTab(context, _t('all'), 'all'),
          const SizedBox(width: 8),
          _buildTypeFilterTab(context, _t('recorded'), 'recorded'),
          const SizedBox(width: 8),
          _buildTypeFilterTab(context, _t('live'), 'live'),
          const SizedBox(width: 8),
          _buildTypeFilterTab(context, _t('in_person'), 'in_person'),
        ],
      ),
    );
  }

  Widget _buildTypeFilterTab(BuildContext context, String label, String value) {
    final isSelected = _typeFilter == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _typeFilter = value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryPurple.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryPurple.withOpacity(0.4)
                  : AppColors.getGlassColor(context, opacity: 0.1),
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? AppColors.primaryPurple
                  : AppColors.getTextColor(context, secondary: true),
              fontWeight: isSelected ? FontWeight.normal : FontWeight.normal,
            ),
          ),
        ),
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
                  color: isSelected ? Colors.white : AppColors.getTextColor(context),
                  fontWeight: FontWeight.normal,
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
    final imageUrl = course['image_url'] ?? course['imageUrl'];
    final instructor = course['teacher'];
    final instructorName = instructor != null
        ? (instructor['full_name'] ??
            instructor['full_name_en'] ??
            instructor['name'] ??
            _t('unspecified_teacher'))
        : _t('unspecified_teacher');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.15),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final deliveryMode = course['delivery_mode']?.toString() ?? 'recorded';
                
                if (deliveryMode == 'recorded') {
                  // Recorded courses manage lessons
                  final title = Uri.encodeComponent(course['title'] ?? '');
                  final result = await context.push('/admin/courses/${course['id']}/lessons?title=$title');
                  if (result == true) _loadCourses(forceRefresh: true);
                } else {
                  // Live and In-Person courses manage sessions
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SessionsManagementScreen(
                        courseId: course['id'],
                        courseTitle: course['title'] ?? '',
                      ),
                    ),
                  );
                  if (result == true) _loadCourses(forceRefresh: true);
                }
              },
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Course Image
                    Container(
                      width: 100,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.getGlassColor(context, opacity: 0.1),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: imageUrl != null && imageUrl.toString().isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.getGlassColor(context, opacity: 0.1),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.getGlassColor(context, opacity: 0.1),
                                  child: Icon(Icons.image, color: AppColors.getTextColor(context).withOpacity(0.2)),
                                ),
                              )
                            : Container(
                                color: AppColors.getGlassColor(context, opacity: 0.1),
                                child: Icon(Icons.school, color: AppColors.getTextColor(context).withOpacity(0.2)),
                              ),
                      ),
                    ),

                    // Course Details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course['title'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              instructorName,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.getTextColor(context, secondary: true),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isPublished ? Colors.green : Colors.orange)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isPublished ? _t('published') : _t('draft'),
                                    style: TextStyle(
                                      color: isPublished
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildCourseTypeTag(context, course['delivery_mode']?.toString() ?? 'recorded'),
                                if (course['category'] != null) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      course['category'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.getMutedTextColor(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons Column
                    Container(
                      width: 48,
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: AppColors.getGlassColor(context, opacity: 0.1),
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                color: AppColors.getTextColor(context, secondary: true), size: 20),
                            onPressed: () async {
                              final result = await context.push(
                                '/admin/courses/edit/${course['id']}',
                                extra: course,
                              );
                              if (result == true) _loadCourses(forceRefresh: true);
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.people_outline,
                                color: AppColors.getTextColor(context, secondary: true), size: 20),
                            onPressed: () {
                              context.push('/admin/subscribers?courseId=${course['id']}&courseTitle=${Uri.encodeComponent(course['title'] ?? '')}');
                            },
                            tooltip: 'مشتركو الدورة',
                          ),
                          IconButton(
                            icon: Icon(Icons.quiz_outlined,
                                color: AppColors.getTextColor(context, secondary: true), size: 20),
                            onPressed: () async {
                              final result = await context.push(
                                '/admin/courses/${course['id']}/exams?title=${Uri.encodeComponent(course['title'] ?? '')}',
                              );
                              if (result == true) _loadCourses();
                            },
                            tooltip: 'الاختبارات',
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                                color: AppColors.getTextColor(context, secondary: true), size: 20),
                            onSelected: (value) {
                              if (value == 'delete') _deleteCourse(course);
                              if (value == 'stats') _showStatistics(course);
                              if (value == 'subscribers') {
                                context.push('/admin/subscribers?courseId=${course['id']}&courseTitle=${Uri.encodeComponent(course['title'] ?? '')}');
                              }
                              if (value == 'sessions') {
                                final mode = course['delivery_mode'] ?? 'recorded';
                                if (mode == 'live' || mode == 'in_person') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SessionsManagementScreen(
                                        courseId: course['id'],
                                        courseTitle: course['title'] ?? '',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              // Show sessions option only for live/in_person courses
                              if ((course['delivery_mode'] ?? 'recorded') != 'recorded')
                                const PopupMenuItem(
                                  value: 'sessions',
                                  child: Row(
                                    children: [
                                      Icon(Icons.live_tv_outlined,
                                          size: 20, color: Color(0xFFEF4444)),
                                      SizedBox(width: 8),
                                      Text('إدارة الجلسات',
                                          style: TextStyle(color: Color(0xFFEF4444))),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'subscribers',
                                child: Row(
                                  children: [
                                    const Icon(Icons.people_outline, size: 20),
                                    const SizedBox(width: 8),
                                    const Text('مشتركو الدورة'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'stats',
                                child: Row(
                                  children: [
                                    const Icon(Icons.bar_chart, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_t('statistics')),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_t('delete'),
                                        style: const TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
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



  Widget _buildCourseTypeTag(BuildContext context, String mode) {
    Color color;
    String label;
    IconData icon;

    switch (mode) {
      case 'live':
        color = Colors.blueAccent;
        label = _t('live');
        icon = Icons.sensors_rounded;
        break;
      case 'in_person':
        color = Colors.orangeAccent;
        label = _t('in_person');
        icon = Icons.location_on_rounded;
        break;
      case 'recorded':
      default:
        color = AppColors.primaryPurple;
        label = _t('recorded');
        icon = Icons.play_circle_fill_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
                color: AppColors.getMutedTextColor(context).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 80,
                color: AppColors.getTextColor(context).withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _t('no_courses_current'),
              style: TextStyle(
                fontSize: 20,
                color: AppColors.getTextColor(context),
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 12),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage ?? _t('error_loading'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.getTextColor(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadCourses(forceRefresh: true),
              icon: const Icon(Icons.refresh),
              label: Text(_t('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              style: const TextStyle(color: Colors.red),
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

      _loadCourses(forceRefresh: true);
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
                  child: Text('${_t('statistics')}: ${course['title']}'),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatRow(_t('subscribers'), '${stats['total_enrollments']}'),
                const Divider(),
                _buildStatRow(_t('completers'), '${stats['completed_enrollments']}'),
                const Divider(),
                _buildStatRow(_t('lessons'), '${stats['total_lessons']}'),
                const Divider(),
                _buildStatRow(_t('average_progress_label'), '${stats['average_progress']}%'),
                const Divider(),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
