import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/error_utils.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

class AdminExamsManagementScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const AdminExamsManagementScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<AdminExamsManagementScreen> createState() =>
      _AdminExamsManagementScreenState();
}

class _AdminExamsManagementScreenState
    extends State<AdminExamsManagementScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, published, draft

  String _t(String key) => AppStrings.get(key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);
    try {
      final exams = await _db.getAllExamsForCourse(widget.courseId);
      setState(() {
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredExams {
    if (_filter == 'published') {
      return _exams.where((e) => e['is_published'] == true).toList();
    } else if (_filter == 'draft') {
      return _exams.where((e) => e['is_published'] == false).toList();
    }
    return _exams;
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
                _buildFilterTabs(),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: AppColors.getTextColor(context)),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadExams,
                          child: _filteredExams.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: EdgeInsets.all(20),
                                  itemCount: _filteredExams.length,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      padding:
                                          EdgeInsets.only(bottom: 16),
                                      child:
                                          _buildExamCard(_filteredExams[index]),
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
            final result = await context.push(
              '/admin/exams/create?courseId=${widget.courseId}',
            );
            if (result == true) _loadExams();
          },
          backgroundColor: AppColors.primaryPurple,
          icon: Icon(Icons.add, color: AppColors.getTextColor(context)),
          label:
              Text(_t('create_exam'), style: TextStyle(color: AppColors.getTextColor(context))),
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
                  _t('manage_exams'),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  widget.courseTitle,
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

  Widget _buildFilterTabs() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildFilterTab(_t('all'), 'all'),
          SizedBox(width: 12),
          _buildFilterTab(_t('published'), 'published'),
          SizedBox(width: 12),
          _buildFilterTab(_t('draft'), 'draft'),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _filter == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = value),
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
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.getTextColor(context).withOpacity(0.7),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final isPublished = exam['is_published'] as bool? ?? false;

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
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exam['title'] ?? _t('exam'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isPublished ? Colors.green : Colors.orange)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isPublished
                                ? Colors.greenAccent
                                : Colors.orangeAccent)
                            .withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      isPublished ? _t('published') : _t('draft'),
                      style: TextStyle(
                        color: isPublished
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                      Icons.access_time, '${exam['duration']} ${_t('minute')}'),
                  SizedBox(width: 12),
                  _buildInfoChip(
                      Icons.assignment_outlined,
                      '${exam['total_points']} ${_t('point')}'),
                ],
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final result = await context.push(
                          '/admin/exams/create?courseId=${widget.courseId}',
                          extra: exam,
                        );
                        if (result == true) _loadExams();
                      },
                      icon: Icon(Icons.edit, size: 18),
                      label: Text(_t('edit')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isPublished
                            ? Colors.orangeAccent
                            : Colors.greenAccent,
                        side: BorderSide(
                            color: (isPublished
                                    ? Colors.orangeAccent
                                    : Colors.greenAccent)
                                .withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _togglePublish(exam),
                      icon: Icon(
                        isPublished ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      label: Text(isPublished ? _t('unpublish') : _t('publish')),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteExam(exam),
                    icon: Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              // Go to questions buttom
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryPurple,
                        Colors.blueAccent.withOpacity(0.8)
                      ],
                    ),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await context.push(
                        '/admin/exams/questions/${exam['id']}?title=${Uri.encodeComponent(exam['title'] ?? _t('exam'))}',
                      );
                      if (result == true) _loadExams();
                    },
                    icon: Icon(Icons.list_alt, color: AppColors.getTextColor(context)),
                    label: Text(_t('manage_questions'),
                        style: TextStyle(color: AppColors.getTextColor(context))),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.getTextColor(context).withOpacity(0.70), size: 14),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.getTextColor(context).withOpacity(0.70),
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined,
                    color: AppColors.getMutedTextColor(context), size: 64),
                SizedBox(height: 24),
                Text(
                  _t('no_exams_found'),
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.getTextColor(context),
                    fontWeight: FontWeight.normal,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  _t('create_exam_prompt'),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _togglePublish(Map<String, dynamic> exam) async {
    try {
      final isPublished = exam['is_published'] as bool? ?? false;
      await _db.toggleExamPublish(exam['id'], !isPublished);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPublished ? _t('unpublish_success') : _t('publish_success')),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadExams();
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

  Future<void> _deleteExam(Map<String, dynamic> exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_exam_title')),
        content: Text(_t('delete_exam_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.deleteExam(exam['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_t('delete_exam_success')),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadExams();
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
}
