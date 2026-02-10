import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/services/file_upload_service.dart';
import '../../core/services/github_storage_service.dart';
import '../../core/services/github_api_service.dart';
import '../../core/config/github_config.dart';
import '../../widgets/video_preview_widget.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../models/chapter.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/rich_text_editor.dart';

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
  late TextEditingController _videoUrlController;
  late TextEditingController _durationController;
  
  String _descriptionHtml = '';
  String _contentHtml = '';

  bool _isFree = false;
  bool _isSaving = false;
  bool _isUploadingToGitHub = false;
  final List<Map<String, String>> _attachments = [];
  
  // Chapters
  List<Chapter> _chapters = [];
  String? _selectedChapterId;
  bool _isLoadingChapters = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.lessonData?['title'] ?? '',
    );
    _videoUrlController = TextEditingController(
      text: widget.lessonData?['video_url'] ?? '',
    );
    _durationController = TextEditingController(
      text: widget.lessonData?['duration']?.toString() ?? '',
    );
    _descriptionHtml = widget.lessonData?['description'] ?? '';
    _contentHtml = widget.lessonData?['content'] ?? '';
    _isFree = widget.lessonData?['is_free'] ?? false;

    if (widget.lessonData?['resources'] != null) {
      for (var item in widget.lessonData!['resources']) {
        _attachments.add(Map<String, String>.from(item));
      }
    }
    
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoadingChapters = true);
    try {
      final chapters = await _db.getChapters(widget.courseId);
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoadingChapters = false;

          if (widget.lessonData?['chapter_id'] != null) {
            _selectedChapterId = widget.lessonData?['chapter_id'];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChapters = false);
        debugPrint('Error loading chapters: $e');
      }
    }
  }

  Future<void> _createNewChapter() async {
    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة فصل جديد'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'عنوان الفصل',
            hintText: 'مثال: المقدمة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              try {
                // Show local loading if needed, or just await
                await _db.createChapter(
                  courseId: widget.courseId,
                  title: titleController.text.trim(),
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                debugPrint('Error creating chapter: $e');
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result == true) {
      _loadChapters();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _videoUrlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.lessonId != null;
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
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chapter Selection
                          _buildGlassContainer(
                            title: 'الفصل',
                            action: TextButton.icon(
                              onPressed: _createNewChapter,
                              icon: const Icon(Icons.add,
                                  size: 18, color: Colors.blueAccent),
                              label: const Text('فصل جديد',
                                  style: TextStyle(color: Colors.blueAccent)),
                            ),
                            child: _isLoadingChapters
                                ? const Center(child: LinearProgressIndicator())
                                : DropdownButtonFormField<String>(
                                    dropdownColor: isDark
                                        ? AppColors.primaryPurple
                                        : Colors.white,
                                    value: _selectedChapterId,
                                    decoration: _inputDecoration(
                                      hint: 'اختر الفصل',
                                      icon: Icons.category_outlined,
                                    ),
                                    style: TextStyle(
                                        color: AppColors.getTextColor(context)),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('بدون فصل (عام)'),
                                      ),
                                      ..._chapters.map((chapter) {
                                        return DropdownMenuItem<String>(
                                          value: chapter.id,
                                          child: Text(chapter.title),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedChapterId = value;
                                      });
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),

                          _buildGlassContainer(
                            title: 'معلومات الدرس',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _titleController,
                                  style: TextStyle(
                                      color: AppColors.getTextColor(context)),
                                  decoration: _inputDecoration(
                                    label: 'عنوان الدرس',
                                    hint: 'مثال: الدرس الأول - مقدمة',
                                    icon: Icons.title,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال عنوان الدرس';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text('وصف الدرس',
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context))),
                                  ),
                                ),
                                Theme(
                                  data: ThemeData.light(),
                                  child: RichTextEditor(
                                    initialHtml: _descriptionHtml,
                                    height: 150,
                                    onContentChanged: (html) {
                                      _descriptionHtml = html;
                                    },
                                    placeholder: 'وصف مختصر عن محتوى الدرس...',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildGlassContainer(
                            title: 'الفيديو والمحتوى',
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _videoUrlController,
                                  style: TextStyle(
                                      color: AppColors.getTextColor(context)),
                                  decoration: _inputDecoration(
                                    label: 'رابط الفيديو',
                                    hint: 'https://youtube.com/watch?v=...',
                                    icon: Icons.video_library_outlined,
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
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: VideoPreviewWidget(
                                      videoUrl: _videoUrlController.text,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _durationController,
                                  style: TextStyle(
                                      color: AppColors.getTextColor(context)),
                                  decoration: _inputDecoration(
                                    label: 'مدة الفيديو (بالثواني)',
                                    hint: '1800 (30 دقيقة)',
                                    icon: Icons.access_time,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال مدة الفيديو';
                                    }
                                    if (int.tryParse(value) == null &&
                                        !RegExp(r'^\d+:\d{2}(:\d{2})?$')
                                            .hasMatch(value)) {
                                      return 'أدخل رقم (ثواني) أو تنسيق MM:SS';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Text('محتوى الدرس (اختياري)',
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context))),
                                  ),
                                ),
                                Theme(
                                  data: ThemeData.light(),
                                  child: RichTextEditor(
                                    initialHtml: _contentHtml,
                                    height: 250,
                                    onContentChanged: (html) {
                                      _contentHtml = html;
                                    },
                                    placeholder: 'شرح نصي، أمثلة، تمارين...',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildAttachmentsSection(context),
                          const SizedBox(height: 16),

                          _buildFreeSwitchGlass(context),
                          const SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: _buildSubmitButton(isEditing),
                          ),
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
              isEditing ? 'تعديل الدرس' : 'إضافة درس جديد',
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
    Widget? action,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  if (action != null) action,
                ],
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

  Widget _buildSubmitButton(bool isEditing) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
        onPressed: _isSaving ? null : _saveLesson,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    isEditing ? 'حفظ التعديلات' : 'إضافة الدرس',
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

  Widget _buildFreeSwitchGlass(BuildContext context) {
    return _buildGlassContainer(
      title: 'إعدادات الوصول',
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isFree
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _isFree ? Icons.lock_open : Icons.lock,
              color: _isFree ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'درس مجاني',
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  'متاح لجميع الطلاب بدون اشتراك',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextColor(context).withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isFree,
            onChanged: (value) => setState(() => _isFree = value),
            activeColor: Colors.greenAccent,
            activeTrackColor: Colors.green.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(BuildContext context) {
    return _buildGlassContainer(
      title: 'المرفقات (GitHub)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_upload, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'رفع تلقائي إلى GitHub',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: AppColors.getTextColor(context),
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
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning,
                            color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يجب تعيين GITHUB_TOKEN في ملف .env',
                            style: TextStyle(
                                fontSize: 12, color: Colors.orangeAccent),
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
                        _isUploadingToGitHub
                            ? 'جاري الرفع...'
                            : 'اختر ملفات للرفع',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._attachments.map((attachment) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file,
                        color: Colors.white70),
                    title: Text(
                      attachment['name'] ?? '',
                      style: TextStyle(
                          color: AppColors.getTextColor(context), fontSize: 13),
                    ),
                    subtitle: Text(
                      attachment['size'] ?? '',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.redAccent, size: 20),
                      onPressed: () {
                        setState(() {
                          _attachments.remove(attachment);
                        });
                      },
                    ),
                  ),
                )),
          ],
        ],
      ),
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
          final fileBytes = file.bytes;
          final fileName = file.name;
          final fileSize = file.size;

          if (fileBytes == null) {
            debugPrint('Error: File bytes are null for $fileName');
            failCount++;
            continue;
          }

          // Check file size (GitHub has 100MB limit)
          if (fileSize > 100 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'الملف $fileName أكبر من 100 ميجابايت',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            failCount++;
            continue;
          }

          // Generate path and upload
          final remotePath = GitHubApiService.generatePath(fileName);
          final rawUrl = await githubService.uploadFile(
            bytes: fileBytes,
            fileName: fileName,
            remotePath: remotePath,
          );

          // Add to attachments
          final resourceMap = {
            'name': fileName,
            'url': rawUrl,
            'type': GitHubStorageService.getFileType(rawUrl).name,
          };

          _attachments.add(resourceMap);
          successCount++;
        } catch (e) {
          debugPrint('Error uploading file ${file.name}: $e');
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
      if (mounted) {
        setState(() => _isUploadingToGitHub = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
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
      final durationText = _durationController.text.trim();
      int duration;
      if (durationText.contains(':')) {
        final parts = durationText.split(':');
        if (parts.length == 2) {
          duration = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        } else if (parts.length == 3) {
          duration = int.parse(parts[0]) * 3600 +
              int.parse(parts[1]) * 60 +
              int.parse(parts[2]);
        } else {
          duration = 0; // Invalid format, default to 0
        }
      } else {
        duration = int.tryParse(durationText) ?? 0;
      }

      if (widget.lessonId != null) {
        await _db.updateLesson(widget.lessonId!, {
          'chapter_id': _selectedChapterId,
          'title': _titleController.text.trim(),
          'description': _descriptionHtml,
          'video_url': _videoUrlController.text.trim(),
          'duration': duration,
          'content': _contentHtml,
          'is_free': _isFree,
          'resources': _attachments,
        });
      } else {
        await _db.createLesson({
          'course_id': widget.courseId,
          'chapter_id': _selectedChapterId,
          'title': _titleController.text.trim(),
          'description': _descriptionHtml,
          'video_url': _videoUrlController.text.trim(),
          'duration': duration,
          'content': _contentHtml,
          'is_free': _isFree,
          'resources': _attachments,
        });
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
          SnackBar(
              content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
