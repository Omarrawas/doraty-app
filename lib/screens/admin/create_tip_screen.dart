import 'package:flutter/material.dart';
import '../../core/services/database_service.dart';
import '../../models/tip.dart';
import '../../models/course.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../services/telegram_upload_service.dart';
import '../../core/services/image_upload_service.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _isUploading = false;
  bool _isUploadingThumbnail = false;
  final TelegramUploadService _telegramService = TelegramUploadService();
  final ImageUploadService _imageUploadService = ImageUploadService();

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

  Future<void> _pickAndUploadVideo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video == null) return;

    setState(() => _isUploading = true);
    try {
      final String? streamUrl = await _telegramService.uploadAndGetLink(video);
      
      if (streamUrl != null) {
        setState(() {
          _videoUrlController.text = streamUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم الرفع والحصول على الرابط بنجاح!')),
          );
        }
      } else {
        throw Exception('فشل الحصول على رابط البث');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الرفع: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickAndUploadThumbnail() async {
    try {
      final imageFile = await _imageUploadService.pickImage();
      if (imageFile == null) return;

      setState(() => _isUploadingThumbnail = true);

      final imageUrl = await _imageUploadService.uploadImageToGitHub(
        imageFile,
        folder: 'tips/thumbnails',
      );

      setState(() {
        _thumbnailUrlController.text = imageUrl;
        _isUploadingThumbnail = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم رفع الصورة بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingThumbnail = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الرفع: $e')),
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
          padding: EdgeInsets.fromLTRB(20, 120, 20, 40),
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
                SizedBox(height: 20),
                _buildTextField(
                  controller: _videoUrlController,
                  label: 'رابط الفيديو (Direct URL or Youtube)',
                  icon: Icons.video_collection,
                  validator: (v) => v!.isEmpty ? 'يرجى إدخال رابط الفيديو' : null,
                  hint: 'https://example.com/video.mp4',
                  suffix: _isUploading 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: Icon(Icons.cloud_upload, color: AppColors.secondaryGold),
                        onPressed: _pickAndUploadVideo,
                        tooltip: 'رفع إلى التلغرام تلقائياً',
                      ),
                ),
                SizedBox(height: 20),
                if (_thumbnailUrlController.text.isNotEmpty)
                  Container(
                    height: 150,
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                      image: DecorationImage(
                        image: NetworkImage(_thumbnailUrlController.text),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(Icons.close, color: AppColors.getTextColor(context)),
                        onPressed: () => setState(() => _thumbnailUrlController.clear()),
                        style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      ),
                    ),
                  ),
                _buildTextField(
                  controller: _thumbnailUrlController,
                  label: 'رابط الصورة المصغرة (Thumbnail)',
                  icon: Icons.image_outlined,
                  hint: 'اختياري',
                  suffix: _isUploadingThumbnail 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        icon: Icon(Icons.image_search_rounded, color: AppColors.secondaryGold),
                        onPressed: _pickAndUploadThumbnail,
                        tooltip: 'رفع صورة مصغرة محلياً',
                      ),
                ),
                SizedBox(height: 20),
                
                // Course Picker
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.getMutedTextColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<String>(
                      dropdownColor: Colors.deepPurple.shade900,
                      value: _selectedCourseId,
                      decoration: InputDecoration(
                        labelText: 'اربط بدورة معينة (CTA)',
                        labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54)),
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.link, color: AppColors.secondaryGold),
                      ),
                      style: TextStyle(color: AppColors.getTextColor(context)),
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
                
                SizedBox(height: 40),
                
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving 
                      ? CircularProgressIndicator(color: AppColors.getTextColor(context))
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
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: TextStyle(color: AppColors.getTextColor(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.24), fontSize: 13),
        labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.54)),
        prefixIcon: Icon(icon, color: AppColors.getTextColor(context).withOpacity(0.70)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white10),
        ),
      ),
    );
  }
}
