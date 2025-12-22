import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';

class AddQuestionScreen extends StatefulWidget {
  final String examId;
  final String? questionId;
  final Map<String, dynamic>? questionData;
  final int orderIndex;

  const AddQuestionScreen({
    super.key,
    required this.examId,
    this.questionId,
    this.questionData,
    required this.orderIndex,
  });

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _pointsController = TextEditingController(text: '1');

  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  String _questionType = 'multiple_choice';
  int _correctAnswer = 0;
  bool _isLoading = false;

  bool get _isEditing => widget.questionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing && widget.questionData != null) {
      _loadQuestionData();
    }
  }

  void _loadQuestionData() {
    final q = widget.questionData!;
    _questionController.text = q['question_text'] ?? '';
    _explanationController.text = q['explanation'] ?? '';
    _pointsController.text = q['points']?.toString() ?? '1';
    _questionType = q['question_type'] ?? 'multiple_choice';

    final options = q['options'] as List?;
    if (options != null) {
      _optionControllers.clear();
      for (var option in options) {
        _optionControllers.add(TextEditingController(text: option.toString()));
      }
    }

    final correctAns = q['correct_answer'];
    if (correctAns is int) {
      _correctAnswer = correctAns;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.adminLightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'تعديل السؤال' : 'إضافة سؤال'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuestionTypeSelector(),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _questionController,
                    decoration: const InputDecoration(
                      labelText: 'نص السؤال',
                      hintText: 'اكتب السؤال هنا',
                      prefixIcon: Icon(Icons.quiz),
                    ),
                    maxLines: 3,
                    validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_questionType != 'essay') ...[
                    _buildOptionsSection(),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _pointsController,
                    decoration: const InputDecoration(
                      labelText: 'النقاط',
                      hintText: '1',
                      prefixIcon: Icon(Icons.grade),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'مطلوب';
                      if (int.tryParse(v) == null) return 'رقم غير صحيح';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _explanationController,
                    decoration: const InputDecoration(
                      labelText: 'الشرح (اختياري)',
                      hintText: 'شرح الإجابة الصحيحة',
                      prefixIcon: Icon(Icons.lightbulb),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveQuestion,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isEditing ? 'حفظ التعديلات' : 'إضافة السؤال',
                      ),
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

  Widget _buildQuestionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع السؤال',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                'اختيار من متعدد',
                'multiple_choice',
                Icons.radio_button_checked,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTypeButton(
                'صح/خطأ',
                'true_false',
                Icons.check_circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTypeButton(
                'مقالي',
                'essay',
                Icons.edit_note,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton(String label, String type, IconData icon) {
    final isSelected = _questionType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _questionType = type;
          if (type == 'true_false') {
            _optionControllers.clear();
            _optionControllers.add(TextEditingController(text: 'صح'));
            _optionControllers.add(TextEditingController(text: 'خطأ'));
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الخيارات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_questionType == 'multiple_choice')
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _optionControllers.add(TextEditingController());
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('إضافة خيار'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ..._optionControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOptionField(index, controller),
          );
        }),
      ],
    );
  }

  Widget _buildOptionField(int index, TextEditingController controller) {
    final isCorrect = _correctAnswer == index;
    return Container(
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.grey[300]!,
          width: isCorrect ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Radio<int>(
            value: index,
            groupValue: _correctAnswer,
            onChanged: (value) {
              setState(() => _correctAnswer = value!);
            },
            activeColor: Colors.green,
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'الخيار ${index + 1}',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
            ),
          ),
          if (_questionType == 'multiple_choice' &&
              _optionControllers.length > 2)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                setState(() {
                  _optionControllers.removeAt(index);
                  if (_correctAnswer >= _optionControllers.length) {
                    _correctAnswer = 0;
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final options = _optionControllers.map((c) => c.text).toList();

      if (_isEditing) {
        await _db.updateQuestion(widget.questionId!, {
          'question_text': _questionController.text,
          'question_type': _questionType,
          'options': _questionType == 'essay' ? [] : options,
          'correct_answer': _questionType == 'essay' ? '' : _correctAnswer,
          'explanation': _explanationController.text.isEmpty
              ? null
              : _explanationController.text,
          'points': int.parse(_pointsController.text),
        });
      } else {
        await _db.addQuestion(
          examId: widget.examId,
          questionText: _questionController.text,
          questionType: _questionType,
          options: _questionType == 'essay' ? [] : options,
          correctAnswer: _questionType == 'essay' ? '' : _correctAnswer,
          explanation: _explanationController.text.isEmpty
              ? null
              : _explanationController.text,
          points: int.parse(_pointsController.text),
          orderIndex: widget.orderIndex,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم التحديث' : 'تمت الإضافة'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
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
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _pointsController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
