import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'add_question_screen.dart';
import 'dart:ui';

class ManageQuestionsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const ManageQuestionsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ManageQuestionsScreen> createState() => _ManageQuestionsScreenState();
}

class _ManageQuestionsScreenState extends State<ManageQuestionsScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final exam = await _db.getExamById(widget.examId);
      setState(() {
        _questions = List<Map<String, dynamic>>.from(exam?['questions'] ?? []);
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
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadQuestions,
                          child: _questions.isEmpty
                              ? _buildEmptyState()
                              : ReorderableListView.builder(
                                  padding: const EdgeInsets.all(20),
                                  itemCount: _questions.length,
                                  onReorder: _reorderQuestions,
                                  itemBuilder: (context, index) {
                                    return Padding(
                                      key: ValueKey(_questions[index]['id']),
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: _buildQuestionCard(
                                          _questions[index], index),
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
                builder: (context) => AddQuestionScreen(
                  examId: widget.examId,
                  orderIndex: _questions.length,
                ),
              ),
            );
            if (result == true) _loadQuestions();
          },
          backgroundColor: AppColors.primaryPurple,
          icon: const Icon(Icons.add, color: Colors.white),
          label:
              const Text('إضافة سؤال', style: TextStyle(color: Colors.white)),
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
                  'إدارة الأسئلة',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  widget.examTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.3), width: 1),
            ),
            child: Text(
              '${_questions.length} سؤال',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final questionType = question['question_type'] ?? 'multiple_choice';
    final points = question['points'] ?? 1;

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
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                  const Icon(Icons.drag_handle, color: Colors.white54),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primaryPurple.withOpacity(0.3)),
                  ),
                  child: Text(
                    'سؤال ${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                  ),
                  child: Text(
                    '$points نقطة',
                    style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question['question_text'] ?? '',
                style: TextStyle(
                fontSize: 16,
                  color: AppColors.getTextColor(context),
                  fontWeight: FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _buildQuestionTypeChip(questionType),
            if (question['explanation'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.lightbulb, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'يحتوي على شرح',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddQuestionScreen(
                            examId: widget.examId,
                            questionId: question['id'],
                            questionData: question,
                            orderIndex: index,
                          ),
                        ),
                      );
                      if (result == true) _loadQuestions();
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteQuestion(question['id']),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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

  Widget _buildQuestionTypeChip(String type) {
    String label;
    IconData icon;
    Color color;

    switch (type) {
      case 'multiple_choice':
        label = 'اختيار من متعدد';
        icon = Icons.radio_button_checked;
        color = Colors.purple;
        break;
      case 'true_false':
        label = 'صح/خطأ';
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case 'essay':
        label = 'مقالي';
        icon = Icons.edit_note;
        color = Colors.orange;
        break;
      default:
        label = type;
        icon = Icons.help;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.quiz, color: Colors.white.withOpacity(0.3), size: 64),
          SizedBox(height: 16),
          Text(
            'لا توجد أسئلة',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.getTextColor(context),
              fontWeight: FontWeight.normal,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'اضغط على الزر أدناه لإضافة سؤال',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextColor(context).withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _reorderQuestions(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final question = _questions.removeAt(oldIndex);
      _questions.insert(newIndex, question);
    });

    // Update order in database
    for (int i = 0; i < _questions.length; i++) {
      _db.updateQuestion(_questions[i]['id'], {'order_index': i});
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السؤال'),
        content: const Text('هل أنت متأكد من حذف هذا السؤال؟'),
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
      await _db.deleteQuestion(questionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف السؤال'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadQuestions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
