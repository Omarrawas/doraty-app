import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import '../../core/services/image_upload_service.dart';
import '../../models/category_model.dart';

class CreateCourseScreen extends StatefulWidget {
  final String? courseId;
  final Map<String, dynamic>? courseData;

  final String? preselectedInstructorId;

  const CreateCourseScreen({
    super.key,
    this.courseId,
    this.courseData,
    this.preselectedInstructorId,
  });

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController
      _subjectController; // Renamed from _categoryController
  late TextEditingController _levelController;
  late TextEditingController _imageUrlController;
  late TextEditingController _priceController;
  late TextEditingController _instructorController;
  late TextEditingController _durationController;

  bool _isPublished = false;
  bool _isSaving = false;
  bool _isUploading = false;

  List<Map<String, dynamic>> _teachers = [];
  String? _selectedTeacherId;
  String? _selectedCategoryId;
  List<CategoryModel> _categories = [];
  bool _isLoadingTeachers = true;
  bool _isLoadingCategories = true;
  String _selectedCurrency = 'ل.س';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.courseData?['title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.courseData?['description'] ?? '',
    );
    _subjectController = TextEditingController(
      text: widget.courseData?['subject'] ?? '', // Load subject from DB
    );
    _levelController = TextEditingController(
      text: widget.courseData?['level'] ?? 'مبتدئ',
    );
    _imageUrlController = TextEditingController(
      text: widget.courseData?['image_url'] ?? '',
    );
    _priceController = TextEditingController(
      text: widget.courseData?['price']?.toString() ?? '0',
    );
    // Instructor Name will be handled by selection, but keep controller for fallback or display
    _instructorController = TextEditingController(
      text: widget.courseData?['instructor_name'] ?? '',
    );
    _durationController = TextEditingController(
      text: widget.courseData?['duration_hours']?.toString() ?? '0',
    );

    _isPublished = widget.courseData?['is_published'] ?? false;
    _selectedCurrency = widget.courseData?['currency'] ?? 'ل.س';
    _selectedCategoryId = widget.courseData?['category_id']; // Load ID
    _selectedTeacherId =
        widget.preselectedInstructorId ?? widget.courseData?['instructor_id'];
    
    _loadTeachers();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final data = await _db.getCategories();
      if (mounted) {
        setState(() {
          _categories = data.map((e) => CategoryModel.fromJson(e)).toList();
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await _db.getAllTeachers();

      // If editing, get the assigned teacher from teacher_courses
      if (widget.courseId != null) {
        try {
          final teacherCourseData = await _db.supabaseClient
              .from('teacher_courses')
              .select('teacher_id')
              .eq('course_id', widget.courseId!)
              .maybeSingle();

          if (teacherCourseData != null) {
            _selectedTeacherId = teacherCourseData['teacher_id'];
          }
        } catch (e) {
          debugPrint('Error loading assigned teacher: $e');
        }
      }

      if (mounted) {
        setState(() {
          _teachers = teachers;
          _isLoadingTeachers = false;

          // If we have a selected teacher, update the instructor controller
          if (_selectedTeacherId != null) {
            final selectedTeacher = teachers.firstWhere(
              (t) => t['user_id'] == _selectedTeacherId,
              orElse: () => {},
            );
            if (selectedTeacher.isNotEmpty) {
              final userData = selectedTeacher['users'] as Map<String, dynamic>;
              _instructorController.text =
                  userData['full_name'] ?? userData['name'] ?? '';
            }
          }

          // If we have an existing instructor name but no ID (legacy data), try to match it
          if (_selectedTeacherId == null &&
              _instructorController.text.isNotEmpty) {
            final match = teachers.firstWhere(
              (t) {
                final userData = t['users'] as Map<String, dynamic>;
                return userData['name'] == _instructorController.text ||
                    userData['full_name'] == _instructorController.text;
              },
              orElse: () => {},
            );
            if (match.isNotEmpty) {
              _selectedTeacherId = match['user_id'];
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading teachers: $e');
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _levelController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    _instructorController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.courseId != null;

    return Theme(
      data: AppTheme.adminLightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الدورة' : 'إنشاء دورة جديدة'),
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
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الدورة',
                      hintText: 'مثال: دورة الرياضيات المتقدمة',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال عنوان الدورة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'وصف الدورة',
                      hintText: 'وصف مفصل عن محتوى الدورة',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 4,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال وصف الدورة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _isLoadingCategories
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<String>(
                                value: _selectedCategoryId,
                                decoration: const InputDecoration(
                                  labelText: 'التصنيف',
                                  prefixIcon: Icon(Icons.category),
                                ),
                                items: _categories.map((cat) {
                                  return DropdownMenuItem(
                                    value: cat.id,
                                    child: Text(cat.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategoryId = value;
                                    });
                                  }
                                },
                                validator: (value) => value == null
                                    ? 'الرجاء اختيار تصنيف'
                                    : null,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _subjectController,
                          decoration: const InputDecoration(
                            labelText: 'المادة',
                            hintText: 'مثال: فيزياء',
                            prefixIcon: Icon(Icons.book),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال اسم المادة';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _levelController.text.isNotEmpty
                              ? _levelController.text
                              : 'مبتدئ',
                          decoration: const InputDecoration(
                            labelText: 'المستوى',
                            prefixIcon: Icon(Icons.signal_cellular_alt),
                          ),
                          items: ['مبتدئ', 'متوسط', 'متقدم'].map((item) {
                            return DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _levelController.text = value;
                              });
                            }
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
                          controller: _imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'رابط صورة الدورة',
                            hintText: 'https://example.com/image.jpg',
                            prefixIcon: Icon(Icons.image),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _isUploading ? null : _uploadImage,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'السعر',
                            hintText: '0 للمجاني',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCurrency,
                          decoration: const InputDecoration(
                            labelText: 'العملة',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ل.س', child: Text('ل.س')),
                            DropdownMenuItem(value: r'$', child: Text(r'$')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedCurrency = v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          decoration: const InputDecoration(
                            labelText: 'عدد الساعات',
                            hintText: '40',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  _isLoadingTeachers
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String?>(
                          value: _selectedTeacherId,
                          decoration: const InputDecoration(
                            labelText: 'المدرس',
                            prefixIcon: Icon(Icons.person),
                            hintText: 'اختر مدرساً أو اتركه غير محدد',
                          ),
                          items: [
                            // Add "Not Assigned" option
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'غير محدد',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            // Add all teachers
                            ..._teachers.map((teacher) {
                              final userData =
                                  teacher['users'] as Map<String, dynamic>;
                              final teacherName = userData['full_name'] ??
                                  userData['name'] ??
                                  'مدرس';
                              return DropdownMenuItem<String?>(
                                value: teacher['user_id'] as String,
                                child: Text(teacherName),
                              );
                            }),
                          ],
                          onChanged: widget.preselectedInstructorId != null
                              ? null
                              : (value) {
                            setState(() {
                              _selectedTeacherId = value;
                              // Update controller text for consistency/fallback
                              if (value == null) {
                                _instructorController.text = '';
                              } else {
                                final selectedTeacher = _teachers.firstWhere(
                                  (t) => t['user_id'] == value,
                                  orElse: () => {},
                                );
                                if (selectedTeacher.isNotEmpty) {
                                  final userData = selectedTeacher['users']
                                      as Map<String, dynamic>;
                                  _instructorController.text =
                                      userData['full_name'] ??
                                          userData['name'] ??
                                          '';
                                }
                              }
                            });
                          },
                          // No validator - teacher is optional
                        ),
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text(
                      'نشر الدورة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('جعل الدورة متاحة للطلاب'),
                    secondary: const Icon(Icons.publish),
                    value: _isPublished,
                    onChanged: (value) => setState(() => _isPublished = value),
                    activeColor: AppColors.success,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveCourse,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isEditing ? Icons.save : Icons.add),
                      label: Text(isEditing ? 'حفظ التعديلات' : 'إنشاء الدورة'),
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

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category_id': _selectedCategoryId,
        'category': _categories
            .firstWhere((c) => c.id == _selectedCategoryId,
                orElse: () => _categories.first)
            .name,
        'subject': _subjectController.text.trim(), // Subject column
        'level': _levelController.text,
        'image_url': _imageUrlController.text.trim(),
        'price': int.tryParse(_priceController.text) ?? 0,
        'instructor_name': _instructorController.text.trim(),
        'instructor_id': _selectedTeacherId,
        'duration_hours': _durationController.text.trim(),
        'is_published': _isPublished,
        'currency': _selectedCurrency,
      };

      if (widget.courseId != null) {
        // Update existing course
        await _db.updateCourse(widget.courseId!, data);
      } else {
        // Create new course
        await _db.createCourse(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.courseId != null
                  ? 'تم تحديث الدورة بنجاح'
                  : 'تم إنشاء الدورة بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    setState(() => _isUploading = true);

    try {
      final imageService = ImageUploadService();
      final imageFile = await imageService.pickImage();

      if (imageFile != null) {
        final url = await imageService.uploadImage(
          imageFile,
          'course-images',
          folder: 'courses',
        );

        setState(() {
          _imageUrlController.text = url;
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفع الصورة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
