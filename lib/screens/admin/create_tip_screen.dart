import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/tip.dart';
import '../../models/course.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';

class CreateTipScreen extends StatefulWidget {
  final Tip? tip;
  const CreateTipScreen({super.key, this.tip});

  @override
  State<CreateTipScreen> createState() => _CreateTipScreenState();
}

class _CreateTipScreenState extends State<CreateTipScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _videoUrlController;
  late TextEditingController _thumbnailUrlController;
  
  String? _selectedCourseId;
  List<Course> _allCourses = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.tip?.title ?? '');
    _videoUrlController = TextEditingController(text: widget.tip?.videoUrl ?? '');
    _thumbnailUrlController = TextEditingController(text: widget.tip?.thumbnailUrl ?? '');
    _selectedCourseId = widget.tip?.courseId;
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final coursesData = await _db.getCourses();
      if (mounted) {
        setState(() {
          _allCourses = coursesData.map((e) => Course.fromJson(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading courses: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (widget.tip == null) {
        await _db.createTip(
          title: _titleController.text,
          videoUrl: _videoUrlController.text,
          thumbnailUrl: _thumbnailUrlController.text.isEmpty ? null : _thumbnailUrlController.text,
          courseId: _selectedCourseId,
        );
      } else {
        await _db.updateTip(
          id: widget.tip!.id,
          title: _titleController.text,
          videoUrl: _videoUrlController.text,
          thumbnailUrl: _thumbnailUrlController.text.isEmpty ? null : _thumbnailUrlController.text,
          courseId: _selectedCourseId,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();
    _thumbnailUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.tip == null ? 'إضافة نصيحة' : 'تعديل النصيحة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DynamicGradientBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 120, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: _titleController,
                  label: 'عنوان النصيحة',
                  icon: Icons.title,
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال العنوان' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _videoUrlController,
                  label: 'رابط الفيديو (Direct URL or Youtube)',
                  icon: Icons.video_collection,
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال رابط الفيديو' : null,
                  hint: 'https://example.com/video.mp4',
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _thumbnailUrlController,
                  label: 'رابط الصورة المصغرة (Thumbnail)',
                  icon: Icons.image_outlined,
                  hint: 'اختياري',
                ),
                const SizedBox(height: 20),
                
                // Course Picker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      dropdownColor: Colors.deepPurple.shade900,
                      value: _selectedCourseId,
                      decoration: const InputDecoration(
                        labelText: 'اربط بدورة معينة (CTA)',
                        labelStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.link, color: AppColors.secondaryGold),
                      ),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('بدون ارتباط'),
                        ),
                        ..._allCourses.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.title, overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (val) => setState(() => _selectedCourseId = val),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.tip == null ? 'إضافة' : 'حفظ التغييرات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white10),
        ),
      ),
    );
  }
}
