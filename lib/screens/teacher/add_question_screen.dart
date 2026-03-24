import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/error_utils.dart';
import 'dart:ui';
import '../../widgets/tex_view_widget.dart';
// import '../../widgets/math_symbol_toolbar.dart'; // No longer needed here as it's inside RichTextEditor

import '../../widgets/rich_text_editor.dart';

class AddQuestionScreen extends StatefulWidget {
  final String examId;
  final String? questionId;
  final Map<String, dynamic>? questionData;
  final int orderIndex;

  AddQuestionScreen({
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
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService.instance;

  // Controllers
  // _questionController removed in favor of _questionHtml
  String _questionHtml = '';
  // _explanationController removed in favor of _explanationHtml
  String _explanationHtml = '';
  final _pointsController = TextEditingController(text: '1');

  // _optionControllers removed in favor of _optionHtmls
  final List<String> _optionHtmls = ['', ''];

  String _questionType = 'multiple_choice';
  int _correctAnswer = 0;
  bool _isLoading = false;

  bool get _isEditing => widget.questionId != null;

  final ScrollController _toolbarScrollController = ScrollController();

  final FocusNode _explanationFocus = FocusNode();
  final FocusNode _pointsFocus = FocusNode();

  List<bool> _showOptionPreviews = [
    false,
    false
  ]; // Track preview state for each option (kept for consistency or rendering)

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadQuestionData();
    }
  }

  void _loadQuestionData() {
    final q = widget.questionData!;
    _questionHtml = q['question_text'] ?? '';
    _explanationHtml = q['explanation'] ?? '';
    _pointsController.text = q['points']?.toString() ?? '1';
    _questionType = q['question_type'] ?? 'multiple_choice';

    final options = q['options'] as List?;
    if (options != null) {
      _optionHtmls.clear();
      _showOptionPreviews.clear();

      for (var i = 0; i < options.length; i++) {
        _optionHtmls.add(options[i].toString());
        _showOptionPreviews.add(false);
      }
    }

    final correctAns = q['correct_answer'];
    if (correctAns is int) {
      _correctAnswer = correctAns;
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        20, 20, 20, 80), // Extra padding for toolbar
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGlassContainer(
                            title: 'إعدادات السؤال',
                            child: Column(
                              children: [
                                _buildQuestionTypeSelector(),
                                SizedBox(height: 16),
                                SizedBox(height: 16),
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8.0),
                                  child: Text('نص السؤال',
                                      style: TextStyle(
                                          color:
                                              AppColors.getTextColor(context))),
                                ),
                                RichTextEditor(
                                  initialHtml: _questionHtml,
                                  height: 200,
                                  textColor: Colors.black,
                                  onContentChanged: (html) {
                                    _questionHtml = html;
                                  },
                                  placeholder: 'اكتب السؤال هنا...',
                                ),
                                SizedBox(height: 16),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          if (_questionType != 'essay') ...[
                            _buildGlassContainer(
                              title: 'الخيارات والإجابة',
                              child: _buildOptionsSection(),
                            ),
                            SizedBox(height: 16),
                          ],
                          _buildGlassContainer(
                            title: 'معلومات إضافية',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _pointsController,
                                  focusNode: _pointsFocus,
                                  style: TextStyle(
                                      color: AppColors.getTextColor(context)),
                                  decoration: _inputDecoration(
                                    label: 'النقاط',
                                    hint: '1',
                                    icon: Icons.grade,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'مطلوب';
                                    if (int.tryParse(v) == null) {
                                      return 'رقم غير صحيح';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                Padding(
                                  padding: EdgeInsets.only(bottom: 8.0),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text('الشرح (اختياري)',
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context))),
                                  ),
                                ),
                                RichTextEditor(
                                  initialHtml: _explanationHtml,
                                  height: 120,
                                  isCompact: true,
                                  textColor: Colors.black,
                                  onContentChanged: (html) {
                                    _explanationHtml = html;
                                  },
                                  placeholder: 'شرح الإجابة الصحيحة...',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 12), // Reduced from 32
                          _buildSubmitButton(),
                          SizedBox(height: 40),
                        ],
                      ),
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
            child: Text(
              _isEditing ? 'تعديل السؤال' : 'إضافة سؤال جديد',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassContainer({
    required String title,
    required Widget child,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getGlassColor(context, opacity: 0.3),
              width: 1.5,
            ),
          ),
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: 12), // Reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.getTextColor(context).withOpacity(0.70)),
      labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
      hintStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.38)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple, Colors.blueAccent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveQuestion,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.getTextColor(context),
                ),
              )
            : Icon(Icons.check, color: AppColors.getTextColor(context)),
        label: Text(
          _isEditing ? 'حفظ التعديلات' : 'إضافة السؤال',
          style: TextStyle(
            color: AppColors.getTextColor(context),
            fontSize: 18,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'نوع السؤال',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: AppColors.getTextColor(context),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                'اختيار من متعدد',
                'multiple_choice',
                Icons.radio_button_checked,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildTypeButton(
                'صح/خطأ',
                'true_false',
                Icons.check_circle,
              ),
            ),
            SizedBox(width: 8),
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
            _optionHtmls.clear();
            _optionHtmls.add('صح');
            _optionHtmls.add('خطأ');
            _showOptionPreviews = [false, false];
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8), // Reduced from 12
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPurple
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryPurple
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 24),
            SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.normal,
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
            Text(
              'الخيارات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
            ),
            if (_questionType == 'multiple_choice')
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _optionHtmls.add('');
                    _showOptionPreviews.add(false);
                  });
                },
                icon: Icon(Icons.add),
                label: Text('إضافة خيار'),
              ),
          ],
        ),
        SizedBox(height: 12),
        ..._optionHtmls.asMap().entries.map((entry) {
          final index = entry.key;
          final optionHtml = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _buildOptionField(index, optionHtml),
          );
        }),
      ],
    );
  }

  Widget _buildOptionField(int index, String optionHtml) {
    final isCorrect = _correctAnswer == index;
    // Ensure list bounds
    if (index >= _showOptionPreviews.length) {
      _showOptionPreviews.add(false);
    }

    // No focus node management needed

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isCorrect
                ? Colors.green.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCorrect ? Colors.green : Colors.white.withOpacity(0.1),
              width: isCorrect ? 2 : 1,
            ),
          ),
          child: Theme(
            data: ThemeData.light(),
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
                  child: RichTextEditor(
                    initialHtml: optionHtml,
                    height: 40,
                    isCompact: true,
                    textColor: Colors.black,
                    onContentChanged: (html) {
                      _optionHtmls[index] = html;
                    },
                    placeholder: 'الخيار ${index + 1}',
                  ),
                ),
                IconButton(
                    icon: Icon(
                        _showOptionPreviews[index]
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.blueAccent,
                        size: 20),
                    onPressed: () {
                      setState(() {
                        _showOptionPreviews[index] =
                            !_showOptionPreviews[index];
                      });
                    }),
                if (_questionType == 'multiple_choice' &&
                    _optionHtmls.length > 2)
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _optionHtmls.removeAt(index);
                        _showOptionPreviews.removeAt(index);

                        // Focus node management removed

                        if (_correctAnswer >= _optionHtmls.length) {
                          _correctAnswer = 0;
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
        if (_showOptionPreviews[index] && optionHtml.isNotEmpty)
          Container(
            margin: EdgeInsets.only(top: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getTextColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            ),
            width: double.infinity,
            child: TexViewWidget(
              optionHtml,
              style: TextStyle(color: Colors.black87, fontSize: 16),
            ),
          ),
      ],
    );
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate options exist
    if (_questionType != 'essay' && _optionHtmls.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('الرجاء إضافة خيارات للسؤال'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final options = _optionHtmls;

      if (_isEditing) {
        await _db.updateQuestion(widget.questionId!, {
          'question_text': _questionHtml,
          'question_type': _questionType,
          'options': _questionType == 'essay' ? [] : options,
          'correct_answer': _questionType == 'essay' ? '' : _correctAnswer,
          'explanation': _explanationHtml.isEmpty ? null : _explanationHtml,
          'points': int.parse(_pointsController.text),
        });
      } else {
        await _db.addQuestion(
          examId: widget.examId,
          questionText: _questionHtml,
          questionType: _questionType,
          options: _questionType == 'essay' ? [] : options,
          correctAnswer: _questionType == 'essay' ? '' : _correctAnswer,
          explanation: _explanationHtml.isEmpty ? null : _explanationHtml,
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
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _toolbarScrollController.dispose();
    _explanationFocus.dispose();
    _pointsFocus.dispose();
    super.dispose();
  }
}
