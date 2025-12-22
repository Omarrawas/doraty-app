import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';

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
    return Theme(
      data: AppTheme.adminLightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'تعديل الاختبار' : 'إنشاء اختبار جديد'),
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
                  _buildSectionTitle('معلومات أساسية'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الاختبار',
                      hintText: 'مثال: اختبار الفصل الأول',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال عنوان الاختبار';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      hintText: 'وصف مختصر للاختبار',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  _buildCourseDropdown(),
                  const SizedBox(height: 12),
                  _buildLessonDropdown(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('إعدادات الاختبار'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          decoration: const InputDecoration(
                            labelText: 'المدة (بالدقائق)',
                            hintText: '60',
                            prefixIcon: Icon(Icons.access_time),
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
                          decoration: const InputDecoration(
                            labelText: 'إجمالي النقاط',
                            hintText: '100',
                            prefixIcon: Icon(Icons.grade),
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _passingScoreController,
                          decoration: const InputDecoration(
                            labelText: 'درجة النجاح (%)',
                            hintText: '60',
                            prefixIcon: Icon(Icons.check_circle),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'مطلوب';
                            }
                            final score = int.tryParse(value);
                            if (score == null || score < 0 || score > 100) {
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
                          decoration: const InputDecoration(
                            labelText: 'عدد المحاولات',
                            hintText: '3',
                            prefixIcon: Icon(Icons.repeat),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('خيارات متقدمة'),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('خلط الأسئلة',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('عرض الأسئلة بترتيب عشوائي'),
                          value: _shuffleQuestions,
                          onChanged: (value) {
                            setState(() => _shuffleQuestions = value);
                          },
                          activeColor: AppColors.primaryPurple,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('خلط الخيارات',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle:
                              const Text('عرض خيارات الإجابة بترتيب عشوائي'),
                          value: _shuffleOptions,
                          onChanged: (value) {
                            setState(() => _shuffleOptions = value);
                          },
                          activeColor: AppColors.primaryPurple,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCourseId,
      decoration: const InputDecoration(
        labelText: 'الدورة',
        prefixIcon: Icon(Icons.school),
      ),
      items: _courses.map((tc) {
        final course = tc['courses'] as Map<String, dynamic>?;
        return DropdownMenuItem<String>(
          value: widget.loadAllCourses ? tc['id'] : course?['id'],
          child: Text(
            widget.loadAllCourses ? tc['title'] : course?['title'] ?? 'دورة',
          ),
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
      value: _selectedLessonId,
      decoration: InputDecoration(
        labelText: 'الدرس (اختياري)',
        prefixIcon: const Icon(Icons.book),
        suffixIcon: _isLoadingLessons
            ? const SizedBox(
                width: 20,
                height: 20,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
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
      onChanged: (value) {
        setState(() => _selectedLessonId = value);
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _saveExam(publish: false),
            icon: const Icon(Icons.save),
            label: const Text('حفظ كمسودة'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
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
                : Icon(_isEditing ? Icons.check : Icons.publish),
            label: Text(_isEditing ? 'حفظ التغييرات' : 'حفظ ونشر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
            content: Text('خطأ: $e'),
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
