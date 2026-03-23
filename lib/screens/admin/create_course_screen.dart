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
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import '../../services/youtube_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  late TextEditingController _videoUrlController; // Added
  late TextEditingController _priceController;
  late TextEditingController _instructorController;
  late TextEditingController _displayInstructorController;
  late TextEditingController _durationController;
  late TextEditingController _discountController;

  bool _isPublished = false;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isUploadingToYoutube = false;
  final YoutubeUploadService _youtubeService = YoutubeUploadService();

  List<Map<String, dynamic>> _teachers = [];
  String? _selectedTeacherId;
  List<String> _selectedCategoryIds = [];
  List<CategoryModel> _categories = [];
  bool _isLoadingTeachers = true;
  bool _isLoadingCategories = true;
  String _selectedCurrency = 'ل.س';

  // Course Setup Implementation
  final List<String> _availableTags = [
    'decision_making',
    'goal_achievement',
    'self_development',
    'order_priorities',
    'body_language'
  ];
  final List<String> _availableLevels = [
    'all_levels',
    'beginner',
    'intermediate',
    'expert'
  ];
  List<String> _selectedTags = [];
  bool _isFree = false;
  bool _isLoadingTags = false;
  
  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);
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
      text: widget.courseData?['level'] ?? 'beginner',
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
          ? _t('unspecified')
          : widget.courseData?['instructor_name'] ?? '',
    );
    _durationController = TextEditingController(
      text: widget.courseData?['duration_hours']?.toString() ?? '0',
    );
    _videoUrlController = TextEditingController(
      text: widget.courseData?['video_url'] ?? '',
    );
    _discountController = TextEditingController(
      text: widget.courseData?['discount_percentage']?.toString() ?? '0',
    );

    _isPublished = widget.courseData?['is_published'] ?? false;
    _selectedCurrency = widget.courseData?['currency'] ?? 'ل.س';
    
    // Calculate _isFree based on price
    final priceValue = double.tryParse(_priceController.text) ?? 0.0;
    _isFree = priceValue == 0;
    
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
    _loadCourseTags();
  }

  Future<void> _loadCourseTags() async {
    if (widget.courseId == null) return;
    
    setState(() => _isLoadingTags = true);
    try {
      final tags = await _db.getCourseTags(widget.courseId!);
      if (mounted) {
        setState(() {
          _selectedTags = tags;
          _isLoadingTags = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTags = false);
    }
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
    _videoUrlController.dispose();
    _priceController.dispose();
    _instructorController.dispose();
    _displayInstructorController.dispose();
    _durationController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadToYoutube() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video == null) return;

    setState(() => _isUploadingToYoutube = true);
    try {
      final String? ytUrl = await _youtubeService.uploadUnlistedVideo(
        File(video.path), 
        _titleController.text.isEmpty ? "New Course Video" : "${_titleController.text} Preview",
        "Course preview uploaded from Doraty App"
      );
      
      if (ytUrl != null) {
        setState(() {
          _videoUrlController.text = ytUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم الرفع إلى يوتيوب بنجاح!')),
          );
        }
      } else {
        throw Exception('فشل الحصول على رابط يوتيوب');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الرفع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingToYoutube = false);
    }
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
                            title: _t('basic_info_label'),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  decoration: _inputDecoration(
                                    label: _t('course_title_label'),
                                    hint: _t('course_title_hint'),
                                    icon: Icons.title,
                                  ),
                                  style: TextStyle(color: AppColors.getTextColor(context)),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return _t('error_enter_title');
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: _inputDecoration(
                                    label: _t('course_description'),
                                    hint: _t('course_description_hint'),
                                    icon: Icons.description,
                                  ),
                                  style: TextStyle(color: AppColors.getTextColor(context)),
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
                                            checkmarkColor: AppColors.getTextColor(context),
                                            labelStyle: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.getTextColor(context),
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
                                          label: _t('subject_label'),
                                          hint: _t('subject_hint'),
                                          icon: Icons.book,
                                        ),
                                        style: TextStyle(color: AppColors.getTextColor(context)),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _t('error_enter_subject');
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
                                            : 'beginner',
                                        decoration: _inputDecoration(
                                          label: _t('level_label'),
                                          icon: Icons.signal_cellular_alt,
                                        ),
                                        dropdownColor: const Color(0xFF1A1A2E),
                                        style: TextStyle(color: AppColors.getTextColor(context)),
                                        items: _availableLevels.map((item) {
                                          return DropdownMenuItem(
                                            value: item,
                                            child: Text(_t(item)),
                                          );
                                        }).toList(),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return _t('error_select_level');
                                          }
                                          return null;
                                        },
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
                                const SizedBox(height: 20),
                                Text(
                                  _t('tags_optional_label'),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _isLoadingTags
                                    ? const Center(
                                        child: CircularProgressIndicator())
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _availableTags.map((tag) {
                                          final isSelected =
                                              _selectedTags.contains(tag);
                                          return FilterChip(
                                            label: Text(_t(tag)),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setState(() {
                                                if (selected) {
                                                  _selectedTags.add(tag);
                                                } else {
                                                  _selectedTags.remove(tag);
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
                                              fontSize: 12,
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
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            title: 'الصور والهوية البصرية',
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _imageUrlController,
                                        decoration: _inputDecoration(
                                          label: _t('image_url_label'),
                                          hint: _t('image_url_hint'),
                                          icon: Icons.image_rounded,
                                        ),
                                        style: TextStyle(color: AppColors.getTextColor(context)),
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _videoUrlController,
                                        decoration: _inputDecoration(
                                          label: _t('video_url_label'),
                                          hint: _t('video_url_hint'),
                                          icon: Icons.video_collection_rounded,
                                          suffix: _isUploadingToYoutube 
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                            : IconButton(
                                                icon: const Icon(Icons.cloud_upload, color: Colors.redAccent),
                                                onPressed: _pickAndUploadToYoutube,
                                                tooltip: 'رفع إلى يوتيوب (غير مدرج)',
                                              ),
                                        ),
                                        style: TextStyle(color: AppColors.getTextColor(context)),
                                      ),
                                    ],
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
                                              color: AppColors.getTextColor(context)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            title: _t('pricing_time_data'),
                            child: Column(
                              children: [
                                _buildSwitchTile(
                                  title: _t('free_course'),
                                  subtitle: _t('free_course_desc'),
                                  value: _isFree,
                                  onChanged: (value) {
                                    setState(() {
                                      _isFree = value;
                                      if (value) {
                                        _priceController.text = '0';
                                      }
                                    });
                                  },
                                  icon: Icons.money_off,
                                  activeColor: Colors.blueAccent,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: _priceController,
                                        enabled: !_isFree,
                                        decoration: _inputDecoration(
                                          label: _t('price'),
                                          hint: _t('price_hint'),
                                          icon: Icons.attach_money,
                                        ).copyWith(
                                          fillColor: _isFree 
                                              ? AppColors.getGlassColor(context, opacity: 0.02)
                                              : AppColors.getGlassColor(context, opacity: 0.05),
                                        ),
                                        style: TextStyle(
                                          color: _isFree ? AppColors.getTextColor(context, secondary: true) : AppColors.getTextColor(context),
                                        ),
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
                                          label: _t('currency'),
                                          icon: Icons.payments_outlined,
                                        ),
                                        dropdownColor: const Color(0xFF1A1A2E),
                                        style: TextStyle(color: AppColors.getTextColor(context)),
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
                                        readOnly: true,
                                        decoration: _inputDecoration(
                                          label: _t('duration_label'),
                                          hint: 'تلقائي',
                                          icon: Icons.auto_awesome,
                                        ).copyWith(
                                          helperText: 'يُحسب تلقائياً من الدروس',
                                          helperStyle: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 10),
                                        ),
                                         style: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _discountController,
                                  enabled: !_isFree,
                                  decoration: _inputDecoration(
                                    label: _t('discount_percentage'),
                                    hint: _t('enter_discount'),
                                    icon: Icons.percent,
                                  ).copyWith(
                                    fillColor: _isFree 
                                        ? Colors.white.withOpacity(0.02)
                                        : Colors.white.withOpacity(0.05),
                                  ),
                                  style: TextStyle(
                                     color: _isFree ? AppColors.getTextColor(context, secondary: true) : AppColors.getTextColor(context),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) return null;
                                    final discount = int.tryParse(value);
                                    if (discount == null) return _t('error_label');
                                    if (discount < 0 || discount > 100) return _t('discount_range_error');
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGlassContainer(
                            title: _t('instructor_and_visibility'),
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
                                        style: TextStyle(color: AppColors.getTextColor(context)),
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
                   icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isEditing ? _t('edit_course') : _t('create_new_course'),
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
              color: AppColors.getSurfaceColor(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context, opacity: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                  child: Text(
                    _t('select_teacher'),
                    style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.normal),
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextFormField(
                    decoration: _inputDecoration(
                      label: _t('search_teacher'),
                      icon: Icons.search,
                    ),
                    style: TextStyle(color: AppColors.getTextColor(context)),
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
                              style: TextStyle(color: AppColors.getTextColor(context))),
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
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.getTextColor(context, secondary: true)),
      suffixIcon: suffix,
      labelStyle: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
      hintStyle: TextStyle(color: AppColors.getTextColor(context, secondary: true).withOpacity(0.5)),
      filled: true,
      fillColor: AppColors.getGlassColor(context, opacity: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.getGlassColor(context, opacity: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.getGlassColor(context, opacity: 0.1)),
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
        color: AppColors.getGlassColor(context, opacity: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.1)),
      ),
      child: SwitchListTile(
        title: Text(title,
            style: TextStyle(
                color: AppColors.getTextColor(context), fontWeight: FontWeight.normal)),
        subtitle: Text(subtitle,
            style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 12)),
        secondary: Icon(icon, color: value ? activeColor : AppColors.getTextColor(context, secondary: true)),
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
                    isEditing ? _t('save_changes') : _t('create_new_course'),
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
        SnackBar(content: Text(_t('select_at_least_one_category'))),
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
        // NOTE: 'category_ids' is NOT a column in `courses` table.
        // Multi-category is managed through course_category_junction below.
        'subject': _subjectController.text,
        'level': _levelController.text,
        'image_url': _imageUrlController.text,
        'video_url': _videoUrlController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'instructor_name': _instructorController.text,
        'instructor_id': _selectedTeacherId,
        'duration_hours': int.tryParse(_durationController.text) ?? 0,
        'is_published': _isPublished,
        'currency': _selectedCurrency,
        'discount_percentage': int.tryParse(_discountController.text) ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      String courseId;

      if (widget.courseId == null) {
        courseData['created_at'] = DateTime.now().toIso8601String();
        final response = await _db.supabaseClient
            .from('courses')
            .insert(courseData)
            .select('id')
            .single();
        courseId = response['id'];
        await _db.addCourseTags(courseId, _selectedTags);
        // Insert new category junction rows
        await _updateCourseCategories(courseId, _selectedCategoryIds);
      } else {
        courseId = widget.courseId!;
        await _db.supabaseClient
            .from('courses')
            .update(courseData)
            .eq('id', courseId);
        await _db.updateCourseTags(courseId, _selectedTags);
        // Replace category junction rows
        await _updateCourseCategories(courseId, _selectedCategoryIds);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.courseId == null
                ? _t('course_created_success')
                : _t('course_updated_success')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('error_saving_data')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Syncs the course_category_junction table for this course.
  Future<void> _updateCourseCategories(
      String courseId, List<String> categoryIds) async {
    try {
      // Delete old junctions
      await _db.supabaseClient
          .from('course_category_junction')
          .delete()
          .eq('course_id', courseId);

      // Insert new junctions
      if (categoryIds.isNotEmpty) {
        final rows = categoryIds
            .map((catId) => {'course_id': courseId, 'category_id': catId})
            .toList();
        await _db.supabaseClient
            .from('course_category_junction')
            .insert(rows);
      }
    } catch (e) {
      debugPrint('Error updating course categories: $e');
      rethrow;
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
        if (context.mounted) {
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
}
