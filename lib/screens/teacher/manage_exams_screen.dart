import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import 'create_exam_screen.dart';
import 'manage_questions_screen.dart';

class ManageExamsScreen extends StatefulWidget {
  const ManageExamsScreen({super.key});

  @override
  State<ManageExamsScreen> createState() => _ManageExamsScreenState();
}

class _ManageExamsScreenState extends State<ManageExamsScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _exams = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, published, draft

  String _t(String key) {
    if (!mounted) return key;
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);

    try {
      final exams = await _db.getTeacherExams();
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient(context)),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildFilterTabs(),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
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
                                    padding: EdgeInsets.only(bottom: 12),
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
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateExamScreen(),
            ),
          );
          if (result == true) _loadExams();
        },
        backgroundColor: AppColors.primaryPurple,
        icon: Icon(Icons.add),
        label: Text(_t('create_exam')),
      ),
    );
  }

  Widget _buildHeader() {
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
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
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
          SizedBox(width: 16),
          Expanded(
            child: Text(
              _t('exams_management'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterTab(_t('all'), 'all'),
          SizedBox(width: 8),
          _buildFilterTab(_t('published'), 'published'),
          SizedBox(width: 8),
          _buildFilterTab(_t('draft'), 'draft'),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _filter == value;

    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: isSelected ? AppColors.primaryGradient : null,
              color: isSelected ? null : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.getMutedTextColor(context),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _filter = value),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
    final courseName = exam['courses']?['title'] ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageQuestionsScreen(
                      examId: exam['id'],
                      examTitle: exam['title'] ?? 'اختبار',
                    ),
                  ),
                );
                if (result == true) _loadExams();
              },
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exam['title'] ?? 'اختبار',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextColor(context),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                courseName,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextColor(context, secondary: true),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: (isPublished ? Colors.green : Colors.orange)
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isPublished ? Colors.green : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            exam['is_published'] == true ? _t('published') : _t('draft'),
                            style: TextStyle(
                              color: isPublished ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.access_time,
                          '${exam['duration']} ${_t('minute')}',
                        ),
                        SizedBox(width: 12),
                        _buildInfoChip(
                          Icons.assignment,
                          '${exam['total_points']} ${_t('points')}',
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.edit,
                            label: 'تعديل',
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateExamScreen(
                                    examId: exam['id'],
                                    examData: exam,
                                  ),
                                ),
                              );
                              if (result == true) _loadExams();
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildActionButton(
                            icon: isPublished
                                ? Icons.visibility_off
                                : Icons.visibility,
                            label: isPublished ? _t('unpublish') : _t('publish'),
                            color: isPublished ? Colors.orange : Colors.green,
                            onTap: () => _togglePublish(exam),
                          ),
                        ),
                        SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.delete,
                          label: '',
                          color: Colors.red,
                          onTap: () => _deleteExam(exam),
                        ),
                      ],
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.getTextColor(context), size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.getTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (color ?? Colors.white).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color ?? Colors.white, size: 18),
                    if (label.isNotEmpty) ...[
                      SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: color ?? Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.getMutedTextColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.getMutedTextColor(context),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment, color: AppColors.getTextColor(context), size: 64),
                  SizedBox(height: 16),
                  Text(
                    _t('no_exams'),
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.getTextColor(context, secondary: true),
                      fontWeight: FontWeight.bold,
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
        backgroundColor: AppColors.primaryPurple,
        title: Text(_t('delete_exam'), style: TextStyle(color: AppColors.getTextColor(context))),
        content: Text(
          _t('confirm_delete_exam'),
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel'), style: TextStyle(color: AppColors.getTextColor(context))),
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
