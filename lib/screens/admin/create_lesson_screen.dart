import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
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
import '../../services/youtube_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../core/env/multi_env.dart';

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
  late TextEditingController _slugController;
  late TextEditingController _videoUrlController;
  late TextEditingController _durationController;
  
  String _descriptionHtml = '';
  String _contentHtml = '';

  bool _isFree = false;
  bool _isSaving = false;
  bool _isUploadingToYoutube = false;
  bool _isUploadingToGitHub = false;
  final YoutubeUploadService _youtubeService = YoutubeUploadService();
  final List<Map<String, String>> _attachments = [];
  
  // Chapters
  List<Chapter> _chapters = [];
  String? _selectedChapterId;
  bool _isLoadingChapters = false;

  Timer? _debounce;
  final http.Client _httpClient = http.Client();

  @override
  void initState() {
    super.initState();
    try {
      _titleController = TextEditingController(
        text: widget.lessonData?['title']?.toString() ?? '',
      );
      _slugController = TextEditingController(
        text: widget.lessonData?['slug']?.toString() ?? '',
      );
      _videoUrlController = TextEditingController(
        text: widget.lessonData?['video_url']?.toString() ?? '',
      );
      _durationController = TextEditingController(
        text: widget.lessonData?['duration']?.toString() ?? '',
      );
      _descriptionHtml = widget.lessonData?['description']?.toString() ?? '';
      _contentHtml = widget.lessonData?['content']?.toString() ?? '';
      _isFree = widget.lessonData?['is_free'] == true || widget.lessonData?['is_free'] == 'true';
    } catch (e) {
      debugPrint('Error in CreateLessonScreen initState variables: $e');
      _titleController = TextEditingController();
      _slugController = TextEditingController();
      _videoUrlController = TextEditingController();
      _durationController = TextEditingController();
    }

    try {
      if (widget.lessonData?['resources'] != null) {
        final rawResources = widget.lessonData!['resources'];
        if (rawResources is Iterable) {
          for (var item in rawResources) {
            try {
              if (item is Map) {
                _attachments.add(item.map((key, value) => 
                  MapEntry(key.toString(), value.toString())));
              }
            } catch (e) {
              debugPrint('Error parsing resource item: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error initializing resources: $e');
    }
    
    _loadChapters();
  }

  Future<void> _fetchYoutubeDuration(String url) async {
    if (url.isEmpty || (!url.contains('youtube.com') && !url.contains('youtu.be'))) return;
    
    if (_durationController.text.isNotEmpty && _durationController.text != '0' && _durationController.text != '0:00') {
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 1000), () async {
      if (kIsWeb) {
        await _fetchDurationViaYouTubeApi(url);
      } else {
        try {
          final yt = YoutubeExplode();
          final video = await yt.videos.get(url);
          final duration = video.duration;
          yt.close();

          if (duration != null && duration.inSeconds > 0 && mounted) {
            _applyDuration(duration);
          }
        } catch (e) {
          debugPrint('Failed to fetch youtube duration: $e');
        }
      }
    });
  }

  String? _extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com/(?:watch\?v=|embed/|shorts/)|youtu\.be/)([a-zA-Z0-9_-]{11})',
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<void> _fetchDurationViaYouTubeApi(String url) async {
    final videoId = _extractVideoId(url);
    if (videoId == null) {
      debugPrint('⚠️ Could not extract video ID from URL: $url');
      return;
    }

    final apiKey = Env.youtubeDataApiKey;
    if (apiKey.isEmpty) {
      debugPrint('⚠️ YouTube Data API key not configured.');
      return;
    }

    try {
      final apiUrl = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos'
        '?part=contentDetails'
        '&id=$videoId'
        '&key=$apiKey',
      );
      final response = await _httpClient.get(
        apiUrl,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = data['items'] as List<dynamic>?;
        if (items == null || items.isEmpty) {
          debugPrint('⚠️ YouTube API returned no items for video: $videoId');
          return;
        }
        final iso8601Duration =
            items[0]['contentDetails']['duration'] as String?;
        if (iso8601Duration != null) {
          final duration = _parseIso8601Duration(iso8601Duration);
          if (duration.inSeconds > 0) {
            _applyDuration(duration);
            debugPrint('✅ YouTube duration fetched: $iso8601Duration → ${duration.inSeconds}s');
          }
        }
      } else {
        debugPrint('❌ YouTube API error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch duration via YouTube API: $e');
    }
  }

  Duration _parseIso8601Duration(String iso) {
    final pattern = RegExp(
      r'P(?:(\d+)D)?T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?',
    );
    final match = pattern.firstMatch(iso);
    if (match == null) return Duration.zero;
    final days    = int.tryParse(match.group(1) ?? '0') ?? 0;
    final hours   = int.tryParse(match.group(2) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(3) ?? '0') ?? 0;
    final seconds = int.tryParse(match.group(4) ?? '0') ?? 0;
    return Duration(days: days, hours: hours, minutes: minutes, seconds: seconds);
  }

  void _applyDuration(Duration duration) {
    if (!mounted) return;
    setState(() {
      final h = duration.inHours;
      final m = duration.inMinutes % 60;
      final s = duration.inSeconds % 60;
      if (h > 0) {
        _durationController.text = '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      } else {
        _durationController.text = '$m:${s.toString().padLeft(2, '0')}';
      }
    });
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoadingChapters = true);
    try {
      final chapters = await _db.getChapters(widget.courseId);
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoadingChapters = false;

          final lessonChapterId = widget.lessonData?['chapter_id']?.toString();
          if (lessonChapterId != null) {
            final chapterExists = chapters.any((c) => c.id == lessonChapterId);
            if (chapterExists) {
              _selectedChapterId = lessonChapterId;
            } else {
              debugPrint('⚠️ Chapter ID $lessonChapterId from lesson data not found in chapters list');
              _selectedChapterId = null; 
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChapters = false);
        debugPrint('Error loading chapters: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createNewChapter() async {
    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة فصل جديد'),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'عنوان الفصل',
            hintText: 'مثال: المقدمة',
            labelStyle: TextStyle(color: AppColors.getTextColor(context)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              try {
                await _db.createChapter(
                  Chapter(
                    id: '',
                    courseId: widget.courseId,
                    title: titleController.text.trim(),
                    orderIndex: _chapters.length,
                  ),
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                debugPrint('Error creating chapter: $e');
              }
            },
            child: Text('إضافة'),
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
    _debounce?.cancel();
    _httpClient.close();
    _titleController.dispose();
    _slugController.dispose();
    _videoUrlController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadToYoutube() async {
    try {
      final bool signedIn = await _youtubeService.signIn();
      if (!signedIn) return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل تسجيل الدخول بـ Google. تأكد من إعداد OAuth.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video == null) return;

    setState(() => _isUploadingToYoutube = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('جاري الرفع إلى يوتيوب...'),
              ],
            ),
            duration: Duration(minutes: 5),
          ),
        );
      }

      final String? ytUrl = await _youtubeService.uploadUnlistedVideo(
        video, 
        _titleController.text.isEmpty ? 'New Lesson' : _titleController.text,
        'Lesson uploaded from Doraty App',
      );
      
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (ytUrl != null) {
        setState(() {
          _videoUrlController.text = ytUrl;
        });
        _durationController.clear();
        _fetchYoutubeDuration(ytUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم الرفع إلى يوتيوب بنجاح!'),
              backgroundColor: Colors.green.shade700,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('لم يتم الحصول على رابط الفيديو من يوتيوب');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        String message = 'خطأ في الرفع';
        final errStr = e.toString();
        if (errStr.contains('sign_in_failed') || errStr.contains('access_denied')) {
          message = '❌ فشل تسجيل الدخول بـ Google. تأكد من إعداد OAuth.';
        } else if (errStr.contains('quotaExceeded') || errStr.contains('403')) {
          message = '❌ تجاوزت حصة YouTube API اليومية.';
        } else if (errStr.contains('insufficientPermissions')) {
          message = '❌ صلاحيات غير كافية. تأكد من منح إذن الرفع.';
        } else if (errStr.contains('cancelled')) {
          message = 'تم إلغاء العملية.';
        } else {
          message = '❌ خطأ: ${errStr.length > 80 ? errStr.substring(0, 80) : errStr}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingToYoutube = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.lessonId != null;
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Builder(
        builder: (context) {
          try {
            return Scaffold(
              body: DynamicGradientBackground(
                child: SafeArea(
                  child: _buildContent(context, isEditing, isDark),
                ),
              ),
            );
          } catch (e) {
            debugPrint('❌ CreateLessonScreen Build Error: $e');
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 60),
                      SizedBox(height: 16),
                      Text('حدث خطأ أثناء تحميل الصفحة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(e.toString(), textAlign: TextAlign.center, style: TextStyle(color: Colors.red)),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('رجوع'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isEditing, bool isDark) {
    return Column(
      children: [
        _buildHeader(context, isEditing),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                          _buildGlassContainer(
                            title: 'الفصل',
                            action: TextButton.icon(
                              onPressed: _createNewChapter,
                              icon: Icon(Icons.add,
                                  size: 18, color: Colors.blueAccent),
                              label: Text('فصل جديد',
                                  style: TextStyle(color: Colors.blueAccent)),
                            ),
                            child: _isLoadingChapters
                                ? Center(child: LinearProgressIndicator())
                                : DropdownButtonFormField<String>(
                                    dropdownColor: isDark
                                        ? AppColors.darkCardSurface
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
                          SizedBox(height: 16),

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
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: _slugController,
                                  decoration: _inputDecoration(
                                    label: 'الرابط المخصص (Slug)',
                                    hint: 'مثال: intro-lesson-1',
                                    icon: Icons.link,
                                  ).copyWith(
                                    helperText: 'اتركه فارغاً ليتم توليده تلقائياً من الاسم.',
                                    helperStyle: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 11),
                                  ),
                                  style: TextStyle(color: AppColors.getTextColor(context)),
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty && !RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                                      return 'يجب أن يحتوي الرابط على أحرف إنجليزية صغيرة، أرقام وشرطات ( - ) فقط';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 8.0),
                                    child: Text('وصف الدرس',
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context))),
                                  ),
                                ),
                                RichTextEditor(
                                  initialHtml: _descriptionHtml,
                                  height: 150,
                                  onContentChanged: (html) {
                                    _descriptionHtml = html;
                                  },
                                  placeholder: 'وصف مختصر عن محتوى الدرس...',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

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
                                    suffix: _isUploadingToYoutube 
                                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                      : IconButton(
                                          icon: Icon(Icons.cloud_upload, color: Colors.redAccent),
                                          onPressed: _pickAndUploadToYoutube,
                                          tooltip: 'رفع إلى يوتيوب (غير مدرج)',
                                        ),
                                  ),
                                  onChanged: (val) {
                                    setState(() {});
                                    _fetchYoutubeDuration(val);
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'الرجاء إدخال رابط الفيديو';
                                    }
                                    return null;
                                  },
                                ),
                                if (_videoUrlController.text.isNotEmpty) ...[
                                  SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: VideoPreviewWidget(
                                      videoUrl: _videoUrlController.text,
                                      height: 150, // Small preview window
                                      onDurationFetched: (duration) {
                                        if (duration.inSeconds > 0 && (_durationController.text.isEmpty || _durationController.text == '0' || _durationController.text == '0:00')) {
                                          setState(() {
                                            final h = duration.inHours;
                                            final m = duration.inMinutes % 60;
                                            final s = duration.inSeconds % 60;
                                            if (h > 0) {
                                              _durationController.text = '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                                            } else {
                                              _durationController.text = '$m:${s.toString().padLeft(2, '0')}';
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: _durationController,
                                  style: TextStyle(
                                      color: AppColors.getTextColor(context)),
                                  decoration: _inputDecoration(
                                    label: 'مدة الفيديو (تلقائي)',
                                    hint: 'يتم جلبها تلقائياً عند وضع الرابط',
                                    icon: Icons.access_time,
                                  ).copyWith(
                                    helperText: 'يمكن تعديلها يدوياً إذا لزم الأمر',
                                    helperStyle: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 10,
                                    ),
                                  ),
                                  keyboardType: TextInputType.text,
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
                                SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 8.0),
                                    child: Text('محتوى الدرس (اختياري)',
                                        style: TextStyle(
                                            color: AppColors.getTextColor(
                                                context))),
                                  ),
                                ),
                                RichTextEditor(
                                  initialHtml: _contentHtml,
                                  height: 250,
                                  onContentChanged: (html) {
                                    _contentHtml = html;
                                  },
                                  placeholder: 'شرح نصي، أمثلة، تمارين...',
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),

                          _buildAttachmentsSection(context),
                          SizedBox(height: 16),

                          _buildFreeSwitchGlass(context),
                          SizedBox(height: 32),

                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: _buildSubmitButton(isEditing),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
  }

  Widget _buildHeader(BuildContext context, bool isEditing) {
    return Padding(
      padding: EdgeInsets.all(20),
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
          SizedBox(width: 16),
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
          padding: EdgeInsets.all(20),
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
              SizedBox(height: 16),
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
        borderSide: BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  Widget _buildSubmitButton(bool isEditing) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [AppColors.primaryPurple, Colors.blueAccent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
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
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.getTextColor(context),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isEditing ? Icons.save : Icons.add, color: AppColors.getTextColor(context)),
                  SizedBox(width: 8),
                  Text(
                    isEditing ? 'حفظ التعديلات' : 'إضافة الدرس',
                    style: TextStyle(
                      color: AppColors.getTextColor(context),
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
            padding: EdgeInsets.all(10),
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
          SizedBox(width: 16),
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.cloud_upload, color: Colors.blueAccent),
                    SizedBox(width: 8),
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
                SizedBox(height: 12),
                if (!GitHubConfig.isConfigured)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning,
                            color: Colors.orangeAccent, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يجب تعيين DORATY_GITHUB_TOKEN في ملف .env',
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
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.getTextColor(context),
                              ),
                            )
                          : Icon(Icons.upload_file),
                      label: Text(
                        _isUploadingToGitHub
                            ? 'جاري الرفع...'
                            : 'اختر ملفات للرفع',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.getGlassColor(context, opacity: 0.15),
                        foregroundColor: AppColors.getTextColor(context),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_attachments.isNotEmpty) ...[
            SizedBox(height: 12),
            ..._attachments.map((attachment) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context, opacity: 0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.insert_drive_file,
                        color: AppColors.getTextColor(context, secondary: true)),
                    title: Text(
                      attachment['name'] ?? '',
                      style: TextStyle(
                          color: AppColors.getTextColor(context), fontSize: 13),
                    ),
                    subtitle: Text(
                      attachment['size'] ?? '',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.getTextColor(context, secondary: true)),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete,
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
            SnackBar(
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
      // We use durationText directly in lessonData as a string
      if (durationText.isEmpty) {
        // Handle empty duration if needed
      }

      String slug = _slugController.text.trim();
      if (slug.isEmpty) {
        // Generate slug from title: support Arabic characters but replace spaces/special chars with dashes
        slug = _titleController.text.trim().toLowerCase()
            .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '')
            .replaceAll(RegExp(r'[\s_]+'), '-')
            .replaceAll(RegExp(r'-+'), '-');
        
        // Trim leading/trailing dashes
        if (slug.startsWith('-')) slug = slug.substring(1);
        if (slug.endsWith('-')) slug = slug.substring(0, slug.length - 1);
      }

      if (slug.isEmpty || slug == '-') {
        slug = 'lesson-${DateTime.now().millisecondsSinceEpoch}';
      }

      // Ensure slug is unique
      String finalSlug = slug;
      int suffix = 1;
      bool isUnique = false;
      while (!isUnique) {
        isUnique = await _db.isLessonSlugUnique(finalSlug, excludeId: widget.lessonId);
        if (!isUnique) {
          finalSlug = '$slug-${suffix++}';
        }
      }

      final lessonData = {
        'course_id': widget.courseId,
        'chapter_id': _selectedChapterId,
        'title': _titleController.text.trim(),
        'slug': finalSlug,
        'description': _descriptionHtml,
        'video_url': _videoUrlController.text.trim(),
        'duration': durationText,
        'content': _contentHtml, // Keep for backward compatibility/search
        'content_html': _contentHtml, // Store rich content here
        'is_free': _isFree,
        'resources': _attachments,
        'order_index': _chapters.length,
      };

      if (widget.lessonId != null) {
        await _db.updateLesson(widget.lessonId!, lessonData);
      } else {
        lessonData['course_id'] = widget.courseId;
        await _db.createLesson(lessonData);
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
