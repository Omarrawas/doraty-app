import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';
import '../../models/interactive_element.dart';
import '../../core/services/database_service.dart';

import 'lesson_exam_screen.dart';

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/lesson/youtube_player_web_windows.dart';
import '../../core/utils/error_utils.dart';
import '../lesson/pdf_viewer_screen.dart';
import '../lesson/interactive_quiz_screen.dart';
import '../../widgets/lesson/rich_content_viewer.dart';
import '../../widgets/lesson/external_video_player.dart';


class LessonViewScreen extends StatefulWidget {
  final Lesson lesson;
  final List<Lesson> allLessons;
  final String courseTitle;

  const LessonViewScreen({
    super.key,
    required this.lesson,
    required this.allLessons,
    required this.courseTitle,
  });

  @override
  State<LessonViewScreen> createState() => _LessonViewScreenState();
}

class _LessonViewScreenState extends State<LessonViewScreen>
    with SingleTickerProviderStateMixin {
  // Video Controllers
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLocalVideo = false;
  bool _isExternalPlayer = false;

  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _noteController = TextEditingController();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoadingNotes = true;
  int _currentLessonIndex = 0;
  bool _hasValidVideo = false;
  late TabController _tabController;

  // Throttling variables for progress updates
  int _lastUpdatePosition = 0;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentLessonIndex = widget.allLessons.indexOf(widget.lesson);
    _tabController = TabController(length: 3, vsync: this);
    _initializePlayer();
    _loadNotes();
  }

  Future<void> _initializePlayer() async {
    try {
      // Load Online Video
      final String? url = widget.lesson.videoUrl as String?;
      if (url == null || url.isEmpty) {
        if (mounted) {
          setState(() {
            _hasValidVideo = false;
          });
        }
        return;
      }

      if (url.contains('youtu.be') || url.contains('youtube.com')) {
        _initializeYoutube(url);
        return;
      }

      if (url.contains('avcaption.com') || 
          url.contains('vimeo.com') || 
          url.contains('drive.google.com') ||
          url.contains('facebook.com')) {
        _initializeExternalPlayer(url);
        return;
      }

      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: _videoController!.value.aspectRatio,
        allowFullScreen: true,
        fullScreenByDefault: false,
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );

      _videoController!.addListener(() {
        _updateProgress();
      });

      if (mounted) {
        setState(() {
          _hasValidVideo = true;
          _isLocalVideo = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _hasValidVideo = false;
        });
      }
    }
  }

  void _initializeYoutube(String url) {
    final String? videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null && videoId.isNotEmpty) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        if (mounted) {
          setState(() {
            _hasValidVideo = true;
            _isLocalVideo = false;
          });
        }
        return;
      }

      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: true,
        ),
      );

      _youtubeController!.addListener(() {
        if (mounted && _youtubeController!.value.isPlaying) {
          _updateProgress();
        }
      });

      if (mounted) {
        setState(() {
          _hasValidVideo = true;
          _isLocalVideo = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _hasValidVideo = false;
        });
      }
    }
  }

  void _initializeExternalPlayer(String url) {
    if (mounted) {
      setState(() {
        _hasValidVideo = true;
        _isLocalVideo = false;
        _isExternalPlayer = true;
      });
    }
  }


  Future<void> _loadNotes() async {
    try {
      final notes = await _databaseService.getNotes(widget.lesson.id);
      if (mounted) {
        setState(() {
          _notes = notes;
          _isLoadingNotes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
      if (mounted) {
        setState(() {
          _isLoadingNotes = false;
        });
      }
    }
  }

  Future<void> _updateProgress() async {
    try {
      int position = 0;
      bool isPlaying = false;

      if (_youtubeController != null) {
        position = _youtubeController!.value.position.inSeconds;
        isPlaying = _youtubeController!.value.isPlaying;
      } else if (_videoController != null) {
        position = _videoController!.value.position.inSeconds;
        isPlaying = _videoController!.value.isPlaying;
      }

      if (!isPlaying) return;

      final now = DateTime.now();

      // Update only if position changed by at least 5 seconds OR 5 seconds passed since last update
      // This prevents flooding the database with updates and potential UI freezes
      if ((position - _lastUpdatePosition).abs() >= 5 ||
          now.difference(_lastUpdateTime).inSeconds >= 5) {
        _lastUpdatePosition = position;
        _lastUpdateTime = now;

        await _databaseService.updateLessonProgress(
          lessonId: widget.lesson.id,
          lastPosition: position,
        );
      }
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }

  Future<void> _markAsCompleted() async {
    try {
      await _databaseService.markLessonAsCompleted(widget.lesson.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تعليم الدرس كمكتمل')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _addNote() async {
    if (_noteController.text.trim().isEmpty) return;

    try {
      int position = 0;
      if (_youtubeController != null) {
        position = _youtubeController!.value.position.inSeconds;
      } else if (_videoController != null) {
        position = _videoController!.value.position.inSeconds;
      }

      await _databaseService.createNote(
        lessonId: widget.lesson.id,
        courseId: widget.lesson.courseId,
        title: _noteController.text.trim().split('\n').first, // Use first line as title or logic
        content: _noteController.text.trim(),
        timestamp: position,
      );
      _noteController.clear();
      await _loadNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تمت إضافة الملاحظة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }



  void _navigateToLesson(int index) {
    if (index < 0 || index >= widget.allLessons.length) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LessonViewScreen(
          lesson: widget.allLessons[index],
          allLessons: widget.allLessons,
          courseTitle: widget.courseTitle,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          // في الوضع الأفقي، أظهر الفيديو فقط في وضع ملء الشاشة
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(child: _buildVideoPlayer()),
                // زر الخروج من الوضع الأفقي
                Positioned(
                  top: 20,
                  left: 20,
                  child: IconButton(
                    icon:
                        Icon(Icons.fullscreen_exit, color: AppColors.getTextColor(context)),
                    onPressed: () {
                      // إجبار الجهاز على العودة للوضع العمودي
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                      // ثم إعادة السماح بجميع الاتجاهات
                      Future.delayed(Duration(milliseconds: 500), () {
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]);
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        }

        // الوضع العمودي الطبيعي
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.backgroundGradient,
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVideoPlayer(),
                          SizedBox(height: 20),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: _buildLessonInfo(),
                          ),
                          SizedBox(height: 20),
                          // نظام التبويبات
                          _buildTabBar(),
                          SizedBox(height: 20),
                          _buildTabContent(),
                          SizedBox(height: 30),
                          // شريط التحكم في الأسفل
                          _buildBottomControls(),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
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
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextColor(context, secondary: true),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'درس ${widget.lesson.orderIndex}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),

            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    widget.lesson.isCompleted
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: widget.lesson.isCompleted
                        ? Colors.greenAccent
                        : Colors.white,
                  ),
                  onPressed: _markAsCompleted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildVideoPlayer() {
    if (!_hasValidVideo) {
      return Container(
        height: 200,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: AppColors.getTextColor(context).withOpacity(0.54),
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'فيديو غير متاح',
                style: TextStyle(
                  color: AppColors.getTextColor(context, secondary: true),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLocalVideo && _chewieController != null) {
      return AspectRatio(
        aspectRatio: _videoController?.value.aspectRatio ?? 16 / 9,
        child: Chewie(
          controller: _chewieController!,
        ),
      );
    }

    if (_isExternalPlayer) {
      return ExternalVideoPlayer(
        url: widget.lesson.videoUrl,
      );
    }

    if (_youtubeController == null) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl);
        if (videoId != null) {
          return YoutubePlayerWebWindows(
            videoId: videoId,
          );
        }
      }
      return SizedBox.shrink();
    }

    return Focus(
      autofocus: false,
      descendantsAreFocusable: true,
      child: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primaryPurple,
        progressColors: ProgressBarColors(
          playedColor: AppColors.primaryPurple,
          handleColor: AppColors.primaryPurple,
        ),
        onReady: () {
          debugPrint('YouTube Player is ready');
        },
        onEnded: (data) {
          debugPrint('YouTube video ended');
        },
      ),
    );
  }

  Widget _buildLessonInfo() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.lesson.title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.getTextColor(context).withOpacity(0.70),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    widget.lesson.duration,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextColor(context).withOpacity(0.70),
                    ),
                  ),
                  Spacer(),
                  if (widget.lesson.isFree)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 233, 21, 21)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color.fromARGB(255, 224, 77, 19)
                              .withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 16),
              // Content Logic
              // Content Logic - Display ONLY description here to avoid duplication
              Builder(
                builder: (context) {
                  final String description = widget.lesson.description;

                  if (description.isEmpty) return SizedBox.shrink();

                  // Check if description contains HTML
                  final bool isHtml = description.trim().startsWith('<') ||
                      description.contains('<p>') ||
                      description.contains('<br>') ||
                      description.contains('<b>') ||
                      description.contains('<strong>');

                  if (isHtml) {
                    return HtmlWidget(
                      description,
                      textStyle: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 14,
                        height: 1.5,
                        fontFamily: 'Cairo',
                      ),
                      customStylesBuilder: (element) {
                        return {'color': 'white'};
                      },
                    );
                  } else {
                    return Text(
                      description,
                      style: TextStyle(
                        color: AppColors.getTextColor(context, secondary: true),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResources() {
    if (widget.lesson.resources.isEmpty) return SizedBox.shrink();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المرفقات والموارد',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 16),
              ...widget.lesson.resources.map((resource) {
                final fileName = resource['name'] ?? 'ملف غير معروف';
                final url = resource['url'] ?? '';
                final ext = fileName.split('.').last.toLowerCase();

                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      if (ext == 'pdf') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewerScreen(
                              url: url,
                              title: fileName,
                            ),
                          ),
                        );
                      } else if (ext == 'html' || ext == 'htm') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InteractiveQuizScreen(
                              url: url,
                              title: fileName,
                            ),
                          ),
                        );
                      } else {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          debugPrint('Could not launch $url');
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getMutedTextColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ext == 'pdf'
                                ? Icons.picture_as_pdf
                                : (ext == 'html' || ext == 'htm'
                                    ? Icons.play_circle_outline
                                    : Icons.attach_file),
                            color: AppColors.getTextColor(context).withOpacity(0.70),
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                          ),
                          Text(
                            (ext == 'html' || ext == 'htm')
                                ? 'تشغيل'
                                : (ext == 'pdf' ? 'عرض' : 'تنزيل'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.chevron_left,
                            color: AppColors.primaryPurple,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملاحظاتي',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      autofocus: false,
                      style:
                          TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                      decoration: InputDecoration(
                        hintText: 'أضف ملاحظة...',
                        hintStyle: TextStyle(
                          color: const Color.fromARGB(255, 0, 0, 0)
                              .withOpacity(0.7),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color.fromARGB(255, 0, 0, 0)
                                .withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.getMutedTextColor(context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryPurple,
                          AppColors.primaryBlue,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.add, color: AppColors.getTextColor(context)),
                      onPressed: _addNote,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_isLoadingNotes)
                Center(
                  child: CircularProgressIndicator(color: AppColors.getTextColor(context)),
                )
              else if (_notes.isEmpty)
                Center(
                  child: Text(
                    'لا توجد ملاحظات بعد',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextColor(context, secondary: true),
                    ),
                  ),
                )
              else
                ..._notes.map((note) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.getMutedTextColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note['timestamp'] != null)
                          Text(
                            _formatTimestamp(note['timestamp']),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextColor(context, secondary: true),
                            ),
                          ),
                        SizedBox(height: 4),
                        Text(
                          note['content'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildTabBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getMutedTextColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.getMutedTextColor(context),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPurple,
                    AppColors.primaryBlue,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              tabs: [
                Tab(text: 'الشرح'),
                Tab(text: 'اختبار'),
                Tab(text: 'ملاحظات'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 600, // ارتفاع محدد للـ TabBarView
        child: TabBarView(
          controller: _tabController,
          physics: NeverScrollableScrollPhysics(),
          children: [
            // تبويب الشرح (يتضمن التطبيقات التفاعلية)
            SingleChildScrollView(child: _buildContentTab()),
            // تبويب الاختبار (صفحة اختبار معد مسبقاً)
            SingleChildScrollView(child: _buildExamTab()),
            // تبويب الملاحظات
            SingleChildScrollView(child: _buildNotesSection()),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichContentViewer(
          htmlContent: widget.lesson.contentHtml ??
              (widget.lesson.contentMarkdown == null
                  ? '''
<h3>مرحباً بك في هذا الدرس!</h3>
<p>هذا نص تجريبي لاختبار ميزة الشرح أسفل الفيديو.</p>
<p>في هذا الدرس سنتعلم:</p>
<ul>
  <li>المفاهيم الأساسية للموضوع</li>
  <li>كيفية تطبيق ما تعلمناه عملياً</li>
  <li>أمثلة وتمارين محلولة</li>
</ul>
<p>يمكنك استخدام <b>HTML</b> أو <i>Markdown</i> لتنسيق النص وإضافة صور وروابط.</p>
<div style="background-color: rgba(255,255,255,0.1); padding: 10px; border-radius: 8px; margin-top: 10px;">
  <b>ملاحظة مهمة:</b> هذا المحتوى يظهر فقط للاختبار لأنه لا يوجد محتوى فعلي لهذا الدرس في قاعدة البيانات.
</div>
'''
                  : null),
          markdownContent: widget.lesson.contentMarkdown,
        ),

        // عرض الموارد إذا كانت موجودة
        if (widget.lesson.resources.isNotEmpty) ...[
          SizedBox(height: 20),
          _buildResources(),
        ],

        // عرض التطبيقات التفاعلية (البطاقات التعليمية) في الشرح
        _buildInteractiveAppsSection(),
      ],
    );
  }

  Widget _buildInteractiveAppsSection() {
    if (widget.lesson.interactiveElements == null) {
      return SizedBox.shrink();
    }

    // Filter for all interactive types EXCEPT quiz
    final interactiveApps = widget.lesson.interactiveElements!
        .where((e) => e['type'] != 'quiz')
        .map((e) => InteractiveElement.fromJson(e))
        .toList();

    if (interactiveApps.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'تطبيقات تفاعلية',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
        ),
        SizedBox(height: 16),
        ...interactiveApps.map((element) {
          Widget interactiveWidget;
          switch (element.type) {
            // Add other specific types here as needed (e.g. simulation)
            default:
              interactiveWidget = Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      element.title,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (element.description != null) ...[
                      SizedBox(height: 8),
                      Text(
                        element.description!,
                        style: TextStyle(
                          color: AppColors.getTextColor(context, secondary: true),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: interactiveWidget,
          );
        }),
      ],
    );
  }

  Widget _buildExamTab() {
    if (widget.lesson.interactiveElements == null) {
      return _buildNoExamView();
    }

    final quizzes = widget.lesson.interactiveElements!
        .where((e) => e['type'] == 'quiz')
        .map((e) => InteractiveElement.fromJson(e))
        .toList();

    if (quizzes.isEmpty) {
      return _buildNoExamView();
    }

    return Column(
      children: quizzes.map((quiz) {
        return Container(
          margin: EdgeInsets.only(top: 20),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.assignment_outlined,
                color: AppColors.getTextColor(context),
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                quiz.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (quiz.description != null) ...[
                SizedBox(height: 10),
                Text(
                  quiz.description!,
                  style: TextStyle(
                    color: AppColors.getTextColor(context, secondary: true),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LessonExamScreen(
                          quizElement: quiz,
                          lessonTitle: widget.lesson.title,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'بدء الاختبار',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoExamView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60),
          Icon(
            Icons.assignment_turned_in_outlined,
            color: AppColors.getMutedTextColor(context),
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            'لا يوجد اختبار لهذا الدرس',
            style: TextStyle(
              color: AppColors.getTextColor(context, secondary: true),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    // البحث عن الدرس التالي
    Lesson? nextLesson;
    if (_currentLessonIndex < widget.allLessons.length - 1) {
      nextLesson = widget.allLessons[_currentLessonIndex + 1];
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // معاينة الدرس التالي (إذا وجد)
          if (nextLesson != null) ...[
            Container(
              margin: EdgeInsets.only(bottom: 16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.getMutedTextColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.getMutedTextColor(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: AppColors.getTextColor(context).withOpacity(0.70),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'التالي:',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextColor(context).withOpacity(0.54),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          nextLesson.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    nextLesson.duration,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextColor(context).withOpacity(0.54),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // زر إكمال الدرس والانتقال للتالي
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                // تعليم الدرس كمكتمل
                await _markAsCompleted();

                // الانتقال للدرس التالي إذا وجد
                if (nextLesson != null) {
                  _navigateToLesson(_currentLessonIndex + 1);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('أحسنت! لقد أكملت جميع دروس الدورة'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.pop(context); // العودة لقائمة الدروس
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
                shadowColor: AppColors.primaryPurple.withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    nextLesson != null
                        ? 'إكمال والانتقال للتالي'
                        : 'إكمال الدرس وإنهاء الدورة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(nextLesson != null
                      ? Icons.arrow_forward_rounded
                      : Icons.check_circle_outline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
