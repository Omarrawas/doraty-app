import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/database_service.dart';
import '../../core/services/file_upload_service.dart';
import '../../core/services/github_storage_service.dart';
import '../../core/services/github_api_service.dart';
import '../../core/config/github_config.dart';
import '../../widgets/video_preview_widget.dart';

class CreateLessonScreen extends StatefulWidget {
  final String courseId;
  final String? lessonId;
  final Map<String, dynamic>? lessonData;

  const CreateLessonScreen({
    super.key,
    required this.courseId,
    this.lessonId,
    this.lessonData,
  });

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _videoUrlController;
  late TextEditingController _durationController;
  late TextEditingController _contentController;

  bool _isFree = false;
  bool _isSaving = false;
  bool _isUploadingToGitHub = false;
  final List<Map<String, String>> _attachments = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.lessonData?['title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.lessonData?['description'] ?? '',
    );
    _videoUrlController = TextEditingController(
      text: widget.lessonData?['video_url'] ?? '',
    );
    _durationController = TextEditingController(
      text: widget.lessonData?['duration']?.toString() ?? '',
    );
    _contentController = TextEditingController(
      text: widget.lessonData?['content'] ?? '',
    );
    _isFree = widget.lessonData?['is_free'] ?? false;

    if (widget.lessonData?['attachments'] != null) {
      for (var item in widget.lessonData!['attachments']) {
        _attachments.add(Map<String, String>.from(item));
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    _durationController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.lessonId != null;

    return Theme(
      data: AppTheme.adminLightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'تعديل الدرس' : 'إضافة درس جديد'),
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
                      labelText: 'عنوان الدرس',
                      hintText: 'مثال: الدرس الأول - مقدمة',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال عنوان الدرس';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'وصف الدرس',
                      hintText: 'وصف مختصر عن محتوى الدرس',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _videoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الفيديو',
                      hintText: 'https://youtube.com/watch?v=...',
                      prefixIcon: Icon(Icons.video_library),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال رابط الفيديو';
                      }
                      return null;
                    },
                  ),
                  if (_videoUrlController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    VideoPreviewWidget(
                      videoUrl: _videoUrlController.text,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'مدة الفيديو (بالثواني)',
                      hintText: '1800 (30 دقيقة)',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال مدة الفيديو';
                      }
                      if (int.tryParse(value) == null &&
                          !RegExp(r'^\d+:\d{2}(:\d{2})?$').hasMatch(value)) {
                        return 'أدخل رقم (ثواني) أو تنسيق MM:SS';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'محتوى الدرس (اختياري)',
                      hintText: 'شرح نصي، أمثلة، تمارين...',
                      prefixIcon: Icon(Icons.article),
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),
                  _buildAttachmentsSection(),
                  const SizedBox(height: 24),
                  _buildFreeSwitch(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveLesson,
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
                      label: Text(isEditing ? 'حفظ التعديلات' : 'إضافة الدرس'),
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

  Widget _buildAttachmentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_file, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'المرفقات (GitHub)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // GitHub automatic upload
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_upload, color: Colors.grey.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'رفع تلقائي إلى GitHub',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!GitHubConfig.isConfigured)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'يجب تعيين GITHUB_TOKEN في ملف .env',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingToGitHub ? null : _uploadToGitHub,
                        icon: _isUploadingToGitHub
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(
                          _isUploadingToGitHub ? 'جاري الرفع...' : 'اختر ملفات للرفع',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._attachments.map((attachment) => ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(
                      attachment['name'] ?? '',
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      attachment['size'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _attachments.remove(attachment);
                        });
                      },
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFreeSwitch() {
    return SwitchListTile(
      title: const Text(
        'درس مجاني',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: const Text('متاح لجميع الطلاب بدون اشتراك'),
      secondary: const Icon(Icons.lock_open),
      value: _isFree,
      onChanged: (value) => setState(() => _isFree = value),
      activeColor: AppColors.success,
    );
  }

  Future<void> _uploadToGitHub() async {
    setState(() => _isUploadingToGitHub = true);

    try {
      final fileService = FileUploadService();
      final files = await fileService.pickFiles(
        allowedExtensions: ['pdf', 'mp3', 'wav', 'ogg', 'm4a', 'html', 'htm'],
      );

      if (files.isEmpty) {
        setState(() => _isUploadingToGitHub = false);
        return;
      }

      final githubService = GitHubApiService(token: GitHubConfig.token);
      int successCount = 0;
      int failCount = 0;

      for (var file in files) {
        try {
          // Check file size (GitHub has 100MB limit)
          if (file.lengthSync() > 100 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'الملف ${path.basename(file.path)} أكبر من 100 ميجابايت',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            failCount++;
            continue;
          }

          // Generate path and upload
          final remotePath = GitHubApiService.generatePath(file);
          final rawUrl = await githubService.uploadFile(
            file: file,
            remotePath: remotePath,
          );

          // Add to attachments
          final resourceMap = {
            'name': path.basename(file.path),
            'url': rawUrl,
            'type': GitHubStorageService.getFileType(rawUrl).name,
          };

          _attachments.add(resourceMap);
          successCount++;
        } catch (e) {
          debugPrint('Error uploading file ${path.basename(file.path)}: $e');
          failCount++;
        }
      }

      setState(() => _isUploadingToGitHub = false);

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم رفع $successCount ملف(ات) إلى GitHub بنجاح${failCount > 0 ? ' (فشل $failCount)' : ''}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل رفع الملفات'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingToGitHub = false);
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

  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'course_id': widget.courseId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'video_url': _videoUrlController.text.trim(),
        'duration': _parseDuration(_durationController.text),
        'content': _contentController.text.trim(),
        'is_free': _isFree,
        if (_attachments.isNotEmpty) 'attachments': _attachments,
      };

      if (widget.lessonId != null) {
        await _db.updateLesson(widget.lessonId!, data);
      } else {
        final lessons = await _db.getCourseLessons(widget.courseId);
        data['order_index'] = lessons.length + 1;
        await _db.createLesson(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.lessonId != null
                  ? 'تم تحديث الدرس بنجاح'
                  : 'تم إضافة الدرس بنجاح',
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

  int _parseDuration(String text) {
    text = text.trim();
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length == 2) {
        final minutes = int.tryParse(parts[0]) ?? 0;
        final seconds = int.tryParse(parts[1]) ?? 0;
        return minutes * 60 + seconds;
      } else if (parts.length == 3) {
        final hours = int.tryParse(parts[0]) ?? 0;
        final minutes = int.tryParse(parts[1]) ?? 0;
        final seconds = int.tryParse(parts[2]) ?? 0;
        return hours * 3600 + minutes * 60 + seconds;
      }
    }
    return int.tryParse(text) ?? 0;
  }
}
