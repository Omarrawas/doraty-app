import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/services/image_upload_service.dart';
import '../../models/category_model.dart';
import '../../widgets/dynamic_gradient_background.dart';

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
  late TextEditingController _displayInstructorController;
  late TextEditingController _durationController;

  bool _isPublished = false;
  bool _isSaving = false;
  bool _isUploading = false;

  List<Map<String, dynamic>> _teachers = [];
  String? _selectedTeacherId;
  List<String> _selectedCategoryIds = [];
  List<CategoryModel> _categories = [];
  bool _isLoadingTeachers = true;
  bool _isLoadingCategories = true;
  String _selectedCurrency = 'ل.س';

  @override
  void initState() {
    super.initState();
    _selectedTeacherId =
        widget.preselectedInstructorId ?? widget.courseData?['instructor_id'];

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
    _displayInstructorController = TextEditingController(
      text: _selectedTeacherId == null
          ? 'غير محدد'
          : widget.courseData?['instructor_name'] ?? '',
    );
    _durationController = TextEditingController(
      text: widget.courseData?['duration_hours']?.toString() ?? '0',
    );

    _isPublished = widget.courseData?['is_published'] ?? false;
    _selectedCurrency = widget.courseData?['currency'] ?? 'ل.س';
    
    // Multi-category support
    final categoryIds = widget.courseData?['category_ids'] as List?;
    if (categoryIds != null) {
      _selectedCategoryIds = List<String>.from(categoryIds);
    } else {
      final singleId = widget.courseData?['category_id'] as String?;
      if (singleId != null) {
        _selectedCategoryIds = [singleId];
      }
    }
    
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
    _displayInstructorController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.courseId != null;
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isEditing),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGlassContainer(
                            title: 'المعلومات الأساسية',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  decoration: _inputDecoration(
                                    label: 'عنوان الدورة',
                                    hint: 'مثال: دورة الرياضيات المتقدمة',
                                    icon: Icons.title,
                                  ),
                                  style: const TextStyle(color: Colors.white),
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
                                  decoration: _inputDecoration(
                                    label: 'وصف الدورة',
                                    hint: 'وصف مفصل عن محتوى الدورة',
                                    icon: Icons.description,
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 4,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال وصف الدورة';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            title: 'التصنيفات والبيانات الضمنية',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'اختر التصنيفات المناسبة (يمكن اختيار أكثر من واحد):',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _isLoadingCategories
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _categories.map((cat) {
                                          final isSelected =
                                              _selectedCategoryIds
                                                  .contains(cat.id);
                                          return FilterChip(
                                            label: Text(cat.name),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setState(() {
                                                if (selected) {
                                                  _selectedCategoryIds
                                                      .add(cat.id);
                                                } else {
                                                  _selectedCategoryIds
                                                      .remove(cat.id);
                                                }
                                              });
                                            },
                                            selectedColor: AppColors
                                                .primaryPurple
                                                .withOpacity(0.5),
                                            checkmarkColor: Colors.white,
                                            labelStyle: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontSize: 13,
                                            ),
                                            backgroundColor:
                                                Colors.white.withOpacity(0.05),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              side: BorderSide(
                                                color: isSelected
                                                    ? AppColors.primaryPurple
                                                    : Colors.white
                                                        .withOpacity(0.1),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _subjectController,
                                        decoration: _inputDecoration(
                                          label: 'المادة',
                                          hint: 'مثال: فيزياء',
                                          icon: Icons.book,
                                        ),
                                        style: const TextStyle(
                                            color: Colors.white),
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
                                        decoration: _inputDecoration(
                                          label: 'المستوى',
                                          icon: Icons.signal_cellular_alt,
                                        ),
                                        dropdownColor: const Color(0xFF1A1A2E),
                                        style: const TextStyle(
                                            color: Colors.white),
                                        items: ['مبتدئ', 'متوسط', 'متقدم']
                                            .map((item) {
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            title: 'الصور والهوية البصرية',
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _imageUrlController,
                                    decoration: _inputDecoration(
                                      label: 'رابط صورة الدورة',
                                      hint: 'https://example.com/image.jpg',
                                      icon: Icons.image,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 56,
                                    width: 56,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.primaryPurple,
                                          Colors.blueAccent
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      onPressed:
                                          _isUploading ? null : _uploadImage,
                                      icon: _isUploading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.add_photo_alternate,
                                              color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            title: 'بيانات التسعير والوقت',
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _priceController,
                                    decoration: _inputDecoration(
                                      label: 'السعر',
                                      hint: '0 للمجاني',
                                      icon: Icons.attach_money,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCurrency,
                                    isExpanded: true,
                                    decoration: _inputDecoration(
                                      label: 'العملة',
                                      icon: Icons.payments_outlined,
                                    ),
                                    dropdownColor: const Color(0xFF1A1A2E),
                                    style: const TextStyle(color: Colors.white),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'ل.س', child: Text('ل.س')),
                                      DropdownMenuItem(
                                          value: r'$', child: Text(r'$')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedCurrency = v);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _durationController,
                                    decoration: _inputDecoration(
                                      label: 'الساعات',
                                      hint: '40',
                                      icon: Icons.access_time,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            title: 'المدرس والظهور',
                            child: Column(
                              children: [
                                _isLoadingTeachers
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : TextFormField(
                                        key: ValueKey(_selectedTeacherId),
                                        readOnly: true,
                                        onTap: widget.preselectedInstructorId !=
                                                null
                                            ? null
                                            : _showTeacherPicker,
                                        controller:
                                            _displayInstructorController,
                                        decoration: _inputDecoration(
                                          label: 'المدرس المسئول',
                                          icon: Icons.person,
                                          hint: 'اختر مدرساً أو اتركه غير محدد',
                                        ).copyWith(
                                          suffixIcon: const Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.white70),
                                        ),
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                const SizedBox(height: 16),
                                _buildSwitchTile(
                                  title: 'نشر الدورة',
                                  subtitle:
                                      'جعل الدورة متاحة للطلاب على التطبيق',
                                  value: _isPublished,
                                  onChanged: (value) =>
                                      setState(() => _isPublished = value),
                                  icon: Icons.publish,
                                  activeColor: Colors.greenAccent,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          _buildSubmitButton(isEditing),
                          const SizedBox(height: 40),
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

  Widget _buildHeader(BuildContext context, bool isEditing) {
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
              isEditing ? 'تعديل الدورة' : 'إنشاء دورة جديدة',
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

  void _showTeacherPicker() {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredTeachers = _teachers.where((teacher) {
            final userData = teacher['users'] as Map<String, dynamic>;
            final name = (userData['full_name'] ?? userData['name'] ?? '')
                .toString()
                .toLowerCase();
            return name.contains(searchQuery.toLowerCase());
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'اختر المدرس المسئول',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.normal),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    decoration: _inputDecoration(
                      label: 'بحث عن مدرس...',
                      icon: Icons.search,
                    ),
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount:
                        (searchQuery.isEmpty ? 1 : 0) + filteredTeachers.length,
                    itemBuilder: (context, index) {
                      // Only show 'None' if not searching or if search matches 'None'
                      if (searchQuery.isEmpty && index == 0) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.withOpacity(0.1),
                            child: const Icon(Icons.person_off,
                                color: Colors.grey),
                          ),
                          title: const Text('غير محدد',
                              style: TextStyle(color: Colors.grey)),
                          onTap: () {
                            setState(() {
                              _selectedTeacherId = null;
                              _instructorController.text = '';
                              _displayInstructorController.text = 'غير محدد';
                            });
                            Navigator.pop(context);
                          },
                        );
                      }

                      final teacherIndex =
                          searchQuery.isEmpty ? index - 1 : index;
                      final teacher = filteredTeachers[teacherIndex];
                      final userData = teacher['users'] as Map<String, dynamic>;
                      final name =
                          userData['full_name'] ?? userData['name'] ?? 'مدرس';
                      final isSelected =
                          _selectedTeacherId == teacher['user_id'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primaryPurple.withOpacity(0.2),
                          child: const Icon(Icons.person,
                              color: AppColors.primaryPurple),
                        ),
                        title: Text(name,
                            style: const TextStyle(color: Colors.white)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: Colors.greenAccent)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedTeacherId = teacher['user_id'];
                            _instructorController.text = name;
                            _displayInstructorController.text = name;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.normal)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        secondary: Icon(icon, color: value ? activeColor : Colors.white70),
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSubmitButton(bool isEditing) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.primaryPurple, Colors.blueAccent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveCourse,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isEditing ? Icons.save : Icons.add, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'حفظ التعديلات' : 'إنشاء الدورة',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار تصنيف واحد على الأقل')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final courseData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category_id':
            _selectedCategoryIds.first, // Fallback for single category
        'category_ids': _selectedCategoryIds, // New multi-category field
        'subject': _subjectController.text,
        'level': _levelController.text,
        'image_url': _imageUrlController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'instructor_name': _instructorController.text,
        'instructor_id': _selectedTeacherId,
        'duration_hours': int.tryParse(_durationController.text) ?? 0,
        'is_published': _isPublished,
        'currency': _selectedCurrency,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.courseId == null) {
        courseData['created_at'] = DateTime.now().toIso8601String();
        await _db.supabaseClient.from('courses').insert(courseData);
      } else {
        await _db.supabaseClient
            .from('courses')
            .update(courseData)
            .eq('id', widget.courseId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.courseId == null
                ? 'تم إنشاء الدورة بنجاح'
                : 'تم تحديث الدورة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في حفظ البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadImage() async {
    setState(() => _isUploading = true);

    try {
      final imageService = ImageUploadService();
      final imageFile = await imageService.pickImage();
      
      if (imageFile != null) {
        final url = await imageService.uploadImageToGitHub(
          imageFile,
          folder: 'images/courses',
        );

        if (mounted) {
          setState(() {
            _imageUrlController.text = url;
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفع الصورة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) setState(() => _isUploading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
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
