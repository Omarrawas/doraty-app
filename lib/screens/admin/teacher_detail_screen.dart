import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/string_utils.dart';
import 'package:go_router/go_router.dart';

class TeacherDetailAdminScreen extends StatefulWidget {
  final String teacherId;
  final Map<String, dynamic>? teacherData;

  const TeacherDetailAdminScreen({
    super.key,
    required this.teacherId,
    this.teacherData,
  });

  @override
  State<TeacherDetailAdminScreen> createState() => _TeacherDetailAdminScreenState();
}

class _TeacherDetailAdminScreenState extends State<TeacherDetailAdminScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  
  List<String> _specializations = [];
  List<Map<String, dynamic>> _courses = [];
  
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _teacher;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    
    if (widget.teacherData != null) {
      _teacher = widget.teacherData;
      _initControllers();
    }
    _loadData();
  }

  void _initControllers() {
    if (_teacher == null) return;
    _nameController.text = (_teacher!['full_name'] ?? _teacher!['name'] ?? '').toString();
    _bioController.text = (_teacher!['bio'] ?? '').toString();
    _emailController.text = (_teacher!['email'] ?? '').toString();
    _phoneController.text = (_teacher!['phone'] ?? '').toString();
    
    final rawSpec = _teacher!['specialization'];
    if (rawSpec is List) {
      _specializations = rawSpec.map((e) => e.toString()).toList();
    } else if (rawSpec != null && rawSpec.toString().isNotEmpty) {
      _specializations = [rawSpec.toString()];
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Refresh teacher data
      final teacher = await _db.getTeacherProfile(widget.teacherId, forceRefresh: true);
      if (teacher != null) {
        _teacher = teacher;
        _initControllers();
      }

      // Load teacher courses
      final allCourses = await _db.getCourses(includeDrafts: true);
      _courses = allCourses.where((c) => c['instructor_id'] == widget.teacherId).toList();

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading teacher details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final data = {
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'specialization': _specializations,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _db.updateTeacherProfile(widget.teacherId, data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('profile_updated_success')), backgroundColor: Colors.green),
        );
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _teacher == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
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
                        _buildAvatarSection(),
                        const SizedBox(height: 30),
                        _buildSectionTitle(_t('teacher_info_title')),
                        const SizedBox(height: 16),
                        _buildTextField(_nameController, _t('full_name'), Icons.person_outline),
                        const SizedBox(height: 16),
                        _buildTextField(_emailController, _t('email'), Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 16),
                        _buildTextField(_phoneController, _t('phone'), Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                        const SizedBox(height: 16),
                        _buildTextField(_bioController, _t('bio_label'), Icons.description_outlined, maxLines: 3),
                        const SizedBox(height: 24),
                        _buildSpecializationSection(),
                        const SizedBox(height: 40),
                        _buildSectionTitle(_t('courses')),
                        const SizedBox(height: 16),
                        _buildCoursesList(),
                        const SizedBox(height: 40),
                        _buildSaveButton(),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            color: AppColors.getTextColor(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _t('edit_teacher_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          if (_isSaving)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveChanges,
              color: AppColors.primaryPurple,
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    final avatarUrl = _teacher?['avatar_url']?.toString();
    
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3), width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: CircleAvatar(
              backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
              backgroundImage: avatarUrl != null && avatarUrl.startsWith('http')
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl != null && avatarUrl.startsWith('data:')
                  ? ClipOval(
                      child: Image.memory(
                        StringUtils.decodeBase64Image(avatarUrl),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    )
                  : (avatarUrl == null ? Icon(Icons.person, size: 60, color: AppColors.primaryPurple.withOpacity(0.5)) : null),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.getTextColor(context),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.2)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: AppColors.getTextColor(context)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.6)),
          prefixIcon: Icon(icon, color: AppColors.primaryPurple, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (value) => value == null || value.isEmpty ? _t('field_required') : null,
      ),
    );
  }

  Widget _buildSpecializationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle(_t('specialization_label')),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryPurple),
              onPressed: _showAddSpecializationDialog,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _specializations.map((spec) => Chip(
            label: Text(spec),
            backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
            labelStyle: const TextStyle(color: AppColors.primaryPurple, fontSize: 12),
            deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.primaryPurple),
            onDeleted: () {
              setState(() {
                _specializations.remove(spec);
              });
            },
          )).toList(),
        ),
      ],
    );
  }

  void _showAddSpecializationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('add_specialization')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: _t('specialization_hint')),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_t('cancel'))),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _specializations.add(controller.text.trim());
                });
              }
              Navigator.pop(context);
            },
            child: Text(_t('add')),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesList() {
    if (_courses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.getGlassColor(context, opacity: 0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.1), style: BorderStyle.none),
        ),
        child: Center(
          child: Text(
            _t('no_courses_found'),
            style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _courses.length,
      itemBuilder: (context, index) {
        final course = _courses[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.2)),
          ),
          child: ListTile(
            title: Text(course['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${_t('price')}: ${course['price']} ${_t('currency_label')}', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/admin/courses/edit/${course['id']}', extra: course),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(_t('save_changes_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
