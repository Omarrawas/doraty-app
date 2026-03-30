import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/bundle.dart';
import '../../models/course.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/error_utils.dart';
import '../../core/services/image_upload_service.dart';

class CreateBundleScreen extends StatefulWidget {
  final Bundle? bundle;
  const CreateBundleScreen({super.key, this.bundle});

  @override
  State<CreateBundleScreen> createState() => _CreateBundleScreenState();
}

class _CreateBundleScreenState extends State<CreateBundleScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();
  final ImageUploadService _imageUploadService = ImageUploadService();
  
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;
  late TextEditingController _imageUrlController;
  
  List<Course> _allCourses = [];
  final List<String> _selectedCourseIds = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bundle?.title ?? '');
    _descriptionController = TextEditingController(text: widget.bundle?.description ?? '');
    _priceController = TextEditingController(text: widget.bundle?.price.toString() ?? '');
    _discountController = TextEditingController(text: widget.bundle?.discountPercentage.toString() ?? '0');
    _imageUrlController = TextEditingController(text: widget.bundle?.imageUrl ?? '');
    
    if (widget.bundle != null) {
      _selectedCourseIds.addAll(widget.bundle!.courses.map((c) => c.id));
    }
    
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final coursesData = await _db.searchCourses();
      if (mounted) {
        setState(() {
          _allCourses = coursesData.map((e) => Course.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _saveBundle() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الرجاء اختيار دورة واحدة على الأقل')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final title = _titleController.text;
      final description = _descriptionController.text;
      final price = double.parse(_priceController.text);
      final discount = int.parse(_discountController.text);
      final imageUrl = _imageUrlController.text;

      if (widget.bundle != null) {
        await _db.updateBundle(
          id: widget.bundle!.id,
          title: title,
          description: description,
          price: price,
          discountPercentage: discount,
          imageUrl: imageUrl,
          courseIds: _selectedCourseIds,
        );
      } else {
        await _db.createBundle(
          title: title,
          description: description,
          price: price,
          discountPercentage: discount,
          imageUrl: imageUrl,
          courseIds: _selectedCourseIds,
        );
      }

      if (mounted && context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
          );
        }
      }
    }
  }

  Future<void> _pickAndUploadBundleImage() async {
    try {
      final imageFile = await _imageUploadService.pickImage();
      if (imageFile == null) return;

      setState(() => _isUploadingImage = true);

      final imageUrl = await _imageUploadService.uploadImageToGitHub(
        imageFile,
        folder: 'bundles',
      );

      setState(() {
        _imageUrlController.text = imageUrl;
        _isUploadingImage = false;
      });

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم رفع الصورة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الرفع: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bundle == null ? 'إضافة باقة جديدة' : 'تعديل الباقة'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving ? CircularProgressIndicator(color: AppColors.getTextColor(context), strokeWidth: 2) : Icon(Icons.check),
              onPressed: _isSaving ? null : _saveBundle,
            ),
        ],
      ),
      body: DynamicGradientBackground(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTextField(_titleController, 'عنوان الباقة', 'مثال: باقة الأمان المالي'),
                      SizedBox(height: 16),
                      _buildTextField(_descriptionController, 'وصف الباقة', 'اكتب وصفاً مختصراً لمحتوى الباقة', maxLines: 3),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_priceController, 'السعر', '0.0', keyboardType: TextInputType.number)),
                          SizedBox(width: 16),
                          Expanded(child: _buildTextField(_discountController, 'نسبة الخصم (%)', '0', keyboardType: TextInputType.number)),
                        ],
                      ),
                      SizedBox(height: 16),
                      // Image Link and Upload Button together
                      if (_imageUrlController.text.isNotEmpty)
                        Container(
                          height: 150,
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.getBorderColor(context)),
                            image: DecorationImage(
                              image: NetworkImage(_imageUrlController.text),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: Icon(Icons.close, color: AppColors.getTextColor(context)),
                              onPressed: () => setState(() => _imageUrlController.clear()),
                              style: IconButton.styleFrom(backgroundColor: Colors.black45),
                            ),
                          ),
                        ),
                      _buildTextField(
                        _imageUrlController, 
                        'رابط الصورة', 
                        'رابط الصورة المباشر للباقة',
                        suffix: _isUploadingImage 
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(
                              icon: Icon(Icons.image_search_rounded, color: AppColors.primaryPurple),
                              onPressed: _pickAndUploadBundleImage,
                              tooltip: 'رفع صورة من المعرض',
                            ),
                      ),
                      SizedBox(height: 32),
                      Text(
                        'اختر الدورات المشمولة:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextColor(context)),
                      ),
                      SizedBox(height: 12),
                      Container(
                        height: 400,
                        decoration: BoxDecoration(
                          color: AppColors.getInputFillColor(context, stronger: true),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.getBorderColor(context)),
                        ),
                        child: ListView.builder(
                          itemCount: _allCourses.length,
                          itemBuilder: (context, index) {
                            final course = _allCourses[index];
                            final isSelected = _selectedCourseIds.contains(course.id);
                            return CheckboxListTile(
                              title: Text(course.title, style: TextStyle(color: AppColors.getTextColor(context))),
                              subtitle: Text(course.instructorName, style: TextStyle(color: AppColors.getTextColor(context, secondary: true))),
                              value: isSelected,
                              activeColor: AppColors.primaryPurple,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedCourseIds.add(course.id);
                                  } else {
                                    _selectedCourseIds.remove(course.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, Widget? suffix}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: (val) {
        if (label == 'رابط الصورة') setState(() {});
      },
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
        hintStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.30)),
        filled: true,
        fillColor: AppColors.getInputFillColor(context),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) return 'هذا الحقل مطلوب';
        return null;
      },
    );
  }
}
