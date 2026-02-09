import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';

class CreateExamScreen extends StatefulWidget {
  final String? examId;
  final Map<String, dynamic>? examData;
  final String? initialCourseId;
  final String? lessonId; // Added lessonId
  final bool loadAllCourses;

  const CreateExamScreen({
    super.key,
    this.examId,
    this.examData,
    this.initialCourseId,
    this.lessonId, // Added lessonId
    this.loadAllCourses = false,
  });

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _totalPointsController = TextEditingController();
  final _passingScoreController = TextEditingController();
  final _maxAttemptsController = TextEditingController();

  String? _selectedCourseId;
  String? _selectedLessonId;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _lessons = [];
  bool _shuffleQuestions = false;
  bool _shuffleOptions = false;
  bool _isLoading = false;
  bool _isLoadingLessons = false;

  bool get _isEditing => widget.examId != null;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    if (widget.initialCourseId != null && _selectedCourseId == null) {
      _selectedCourseId = widget.initialCourseId;
      _loadLessons(_selectedCourseId!);
    }
    if (widget.lessonId != null && _selectedLessonId == null) {
      _selectedLessonId = widget.lessonId;
    }
    if (_isEditing && widget.examData != null) {
      _loadExamData();
    }
  }

  void _loadExamData() {
    final exam = widget.examData!;
    _titleController.text = exam['title'] ?? '';
    _descriptionController.text = exam['description'] ?? '';
    _durationController.text = exam['duration']?.toString() ?? '';
    _totalPointsController.text = exam['total_points']?.toString() ?? '';
    _passingScoreController.text = exam['passing_score']?.toString() ?? '';
    _maxAttemptsController.text = exam['max_attempts']?.toString() ?? '';
    _selectedCourseId = exam['course_id'];
    _selectedLessonId = exam['lesson_id'];
    if (_selectedCourseId != null) {
      _loadLessons(_selectedCourseId!);
    }
    _shuffleQuestions = exam['shuffle_questions'] ?? false;
    _shuffleOptions = exam['shuffle_options'] ?? false;
  }

  Future<void> _loadLessons(String courseId) async {
    setState(() {
      _isLoadingLessons = true;
      _lessons = [];
    });
    try {
      final lessons = await _db.getLessons(courseId);
      setState(() {
        _lessons = lessons;
        _isLoadingLessons = false;
      });
    } catch (e) {
      setState(() => _isLoadingLessons = false);
      debugPrint('Error loading lessons: $e');
    }
  }

  Future<void> _loadCourses() async {
    try {
      final courses = widget.loadAllCourses
          ? await _db.getCourses()
          : await _db.getTeacherCourses();
      setState(() {
        _courses = courses;
        if (_courses.isNotEmpty && _selectedCourseId == null) {
          if (widget.loadAllCourses) {
            // For Admin, better not to auto-select unless we have initialCourseId
            if (widget.initialCourseId != null) {
              _selectedCourseId = widget.initialCourseId;
              _loadLessons(_selectedCourseId!);
            }
          } else {
            _selectedCourseId = _courses.first['courses']?['id'];
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading courses: $e');
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
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGlassContainer(
                            title: 'معلومات أساسية',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  style: TextStyle(
                                      color: AppColors.getTextColor(context)),
                                  decoration: _inputDecoration(
                                    label: 'عنوان الاختبار',
                                    hint: 'مثال: اختبار الفصل الأول',
                                    icon: Icons.title,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال عنوان الاختبار';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _descriptionController,
                                  style: TextStyle(
                                      color: AppColors.getTextColor(context)),
                                  decoration: _inputDecoration(
                                    label: 'الوصف',
                                    hint: 'وصف مختصر للاختبار',
                                    icon: Icons.description_outlined,
                                  ),
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                _buildCourseDropdown(),
                                const SizedBox(height: 16),
                                _buildLessonDropdown(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildGlassContainer(
                            title: 'إعدادات الاختبار',
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _durationController,
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context)),
                                        decoration: _inputDecoration(
                                          label: 'المدة (بالدقائق)',
                                          hint: '60',
                                          icon: Icons.access_time,
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'مطلوب';
                                          }
                                          if (int.tryParse(value) == null) {
                                            return 'رقم غير صحيح';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _totalPointsController,
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context)),
                                        decoration: _inputDecoration(
                                          label: 'إجمالي النقاط',
                                          hint: '100',
                                          icon: Icons.grade_outlined,
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'مطلوب';
                                          }
                                          if (int.tryParse(value) == null) {
                                            return 'رقم غير صحيح';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _passingScoreController,
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context)),
                                        decoration: _inputDecoration(
                                          label: 'درجة النجاح (%)',
                                          hint: '60',
                                          icon: Icons.check_circle_outline,
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'مطلوب';
                                          }
                                          final score = int.tryParse(value);
                                          if (score == null ||
                                              score < 0 ||
                                              score > 100) {
                                            return 'من 0 إلى 100';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _maxAttemptsController,
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context)),
                                        decoration: _inputDecoration(
                                          label: 'عدد المحاولات',
                                          hint: '3',
                                          icon: Icons.repeat,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildGlassContainer(
                            title: 'خيارات متقدمة',
                            child: Column(
                              children: [
                                _buildSwitchTile(
                                  title: 'خلط الأسئلة',
                                  subtitle: 'عرض الأسئلة بترتيب عشوائي',
                                  icon: Icons.shuffle,
                                  value: _shuffleQuestions,
                                  onChanged: (value) {
                                    setState(() => _shuffleQuestions = value);
                                  },
                                ),
                                const Divider(color: Colors.white10),
                                _buildSwitchTile(
                                  title: 'خلط الخيارات',
                                  subtitle: 'عرض خيارات الإجابة بترتيب عشوائي',
                                  icon: Icons.alt_route,
                                  value: _shuffleOptions,
                                  onChanged: (value) {
                                    setState(() => _shuffleOptions = value);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          _buildActionButtons(context),
                          const SizedBox(height: 20),
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
            child: Text(
              _isEditing ? 'تعديل الاختبار' : 'إنشاء اختبار جديد',
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
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 16),
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
      prefixIcon: Icon(icon, color: Colors.white70),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
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
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.normal,
              color: AppColors.getTextColor(context))),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12,
              color: AppColors.getTextColor(context).withOpacity(0.6))),
      secondary: Icon(icon, color: Colors.blueAccent),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blueAccent,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<String>(
      dropdownColor: AppColors.primaryPurple,
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: _inputDecoration(
        label: 'الدورة',
        icon: Icons.school_outlined,
      ),
      items: _courses.map((tc) {
        final courseMap = (tc['courses'] as Map<String, dynamic>?) ?? tc;
        final id = widget.loadAllCourses ? tc['id'] : courseMap['id'];
        final title = widget.loadAllCourses
            ? tc['title']
            : (courseMap['title'] ?? 'دورة');
        return DropdownMenuItem<String>(
          value: id,
          child: Text(title),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCourseId = value;
          _selectedLessonId = null;
        });
        if (value != null) {
          _loadLessons(value);
        }
      },
      value: _courses.any((tc) {
        final courseMap = (tc['courses'] as Map<String, dynamic>?) ?? tc;
        final id = widget.loadAllCourses ? tc['id'] : courseMap['id'];
        return id == _selectedCourseId;
      })
          ? _selectedCourseId
          : null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'الرجاء اختيار الدورة';
        }
        return null;
      },
    );
  }

  Widget _buildLessonDropdown() {
    if (_selectedCourseId == null) return const SizedBox.shrink();

    return DropdownButtonFormField<String>(
      dropdownColor: AppColors.primaryPurple,
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: _inputDecoration(
        label: 'الدرس (اختياري)',
        icon: Icons.book_outlined,
      ).copyWith(
        suffixIcon: _isLoadingLessons
            ? Container(
                width: 20,
                height: 20,
                padding: const EdgeInsets.all(12),
                child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.blueAccent),
              )
            : null,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('عام (بدون درس محدد)'),
        ),
        ..._lessons.map((lesson) {
          return DropdownMenuItem<String>(
            value: lesson['id'],
            child: Text(lesson['title'] ?? 'درس'),
          );
        }),
      ],
      value: (_selectedLessonId == null ||
              _lessons.any((l) => l['id'] == _selectedLessonId))
          ? _selectedLessonId
          : null,
      onChanged: (value) {
        setState(() => _selectedLessonId = value);
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: TextButton.icon(
              onPressed: () => _saveExam(publish: false),
              icon: const Icon(Icons.save, color: Colors.orangeAccent),
              label: const Text('حفظ كمسودة',
                  style: TextStyle(color: Colors.orangeAccent)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Colors.green, Colors.teal],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _saveExam(publish: true),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(_isEditing ? Icons.check : Icons.publish,
                      color: Colors.white),
              label: Text(_isEditing ? 'حفظ التغييرات' : 'حفظ ونشر',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.normal)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveExam({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // Update existing exam
        await _db.updateExam(widget.examId!, {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'course_id': _selectedCourseId,
          'lesson_id': _selectedLessonId,
          'duration': int.parse(_durationController.text),
          'total_points': int.parse(_totalPointsController.text),
          'passing_score': int.parse(_passingScoreController.text),
          'max_attempts': _maxAttemptsController.text.isEmpty
              ? null
              : int.parse(_maxAttemptsController.text),
          'shuffle_questions': _shuffleQuestions,
          'shuffle_options': _shuffleOptions,
          'is_published': publish,
        });
      } else {
        // Create new exam
        await _db.createExam(
          courseId: _selectedCourseId!,
          lessonId: _selectedLessonId, // Use selected lesson ID
          title: _titleController.text,
          description: _descriptionController.text,
          duration: int.parse(_durationController.text),
          totalPoints: int.parse(_totalPointsController.text),
          passingScore: int.parse(_passingScoreController.text),
          maxAttempts: _maxAttemptsController.text.isEmpty
              ? null
              : int.parse(_maxAttemptsController.text),
          shuffleQuestions: _shuffleQuestions,
          shuffleOptions: _shuffleOptions,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'تم التحديث بنجاح' : 'تم الإنشاء بنجاح'),
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _totalPointsController.dispose();
    _passingScoreController.dispose();
    _maxAttemptsController.dispose();
    super.dispose();
  }
}
