import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import '../teacher/create_exam_screen.dart';
import '../teacher/manage_questions_screen.dart';

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
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
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
    return Theme(
      data: AppTheme.adminLightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            children: [
              const Text('إدارة الاختبارات'),
              Text(
                widget.courseTitle,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildFilterTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryPurple),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadExams,
                      child: _filteredExams.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredExams.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildExamCard(_filteredExams[index]),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateExamScreen(
                    initialCourseId: widget.courseId,
                    loadAllCourses: true,
                  ),
                ));
            if (result == true) _loadExams();
          },
          backgroundColor: AppColors.primaryPurple,
          icon: const Icon(Icons.add),
          label: const Text('إنشاء اختبار'),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildFilterTab('الكل', 'all'),
          const SizedBox(width: 8),
          _buildFilterTab('منشور', 'published'),
          const SizedBox(width: 8),
          _buildFilterTab('مسودة', 'draft'),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String value) {
    final isSelected = _filter == value;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryPurple : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    final isPublished = exam['is_published'] as bool? ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    exam['title'] ?? 'اختبار',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isPublished ? Colors.green : Colors.orange)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPublished ? Colors.green : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isPublished ? 'منشور' : 'مسودة',
                    style: TextStyle(
                      color: isPublished ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(Icons.access_time, '${exam['duration']} دقيقة'),
                const SizedBox(width: 12),
                _buildInfoChip(
                    Icons.assignment, '${exam['total_points']} نقطة'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateExamScreen(
                            examId: exam['id'],
                            examData: exam,
                            loadAllCourses: true,
                            initialCourseId: widget.courseId,
                          ),
                        ),
                      );
                      if (result == true) _loadExams();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isPublished ? Colors.orange : Colors.green,
                      side: BorderSide(
                          color: isPublished ? Colors.orange : Colors.green),
                    ),
                    onPressed: () => _togglePublish(exam),
                    icon: Icon(
                      isPublished ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    label: Text(isPublished ? 'إلغاء النشر' : 'نشر'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteExam(exam),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Go to questions buttom
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
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
                icon: const Icon(Icons.list),
                label: const Text('إدارة الأسئلة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryPurple, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryPurple,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assignment, color: AppColors.textLight, size: 64),
          SizedBox(height: 16),
          Text(
            'لا توجد اختبارات',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ابدأ بإنشاء اختبار جديد',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
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
            content: Text(isPublished ? 'تم إلغاء النشر' : 'تم النشر'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadExams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteExam(Map<String, dynamic> exam) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الاختبار'),
        content: const Text('هل أنت متأكد من حذف هذا الاختبار؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _db.deleteExam(exam['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الاختبار'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadExams();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
