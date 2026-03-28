import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'pdf_viewer_screen.dart';
import 'image_viewer_screen.dart';
import 'interactive_quiz_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/tex_view_widget.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';
import '../../models/note.dart';
import '../../models/exam.dart';
import '../../models/lesson_question.dart';
import '../exams/exam_taking_screen.dart';
import '../exams/review_exam_screen.dart';
import '../../core/services/database_service.dart';
import '../notes/add_note_screen.dart';
import '../../widgets/dynamic_gradient_background.dart';

import '../../core/utils/error_utils.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../../core/services/supabase_service.dart';
import '../../widgets/lesson/video_player_controls.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/lesson/youtube_player_web_windows.dart';

class LessonScreen extends StatefulWidget {
  final Lesson? lesson;
  final String? lessonId;
  final String? courseId;
  final List<Lesson> allLessons;
  final String courseTitle;
  final bool isEnrolled;

  const LessonScreen({
    super.key,
    this.lesson,
    this.lessonId,
    this.courseId,
    this.allLessons = const [],
    this.courseTitle = '',
    this.isEnrolled = false,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);
  
  final TextEditingController _questionController = TextEditingController();
  final DatabaseService _db = DatabaseService.instance;

  // Video
  bool _isYoutube = false;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubePlayerController;

  // WebView
  String? _currentHtmlContent;

  // Progress tracking
  int _videoWatchTime = 0;
  Timer? _watchTimeTimer;

  // Refactor: Futures for DB calls
  Future<List<Map<String, dynamic>>>? _notesFuture;
  Future<List<Map<String, dynamic>>>? _examsFuture;
  List<LessonQuestion>? _questionsList;
  final ScrollController _mainScrollController = ScrollController();

  late String _videoUrl;
  bool _isLoading = false;
  Lesson? _currentLesson;
  String? _effectiveCourseTitle;
  bool _effectiveIsEnrolled = false;

  Lesson get lesson => _currentLesson!;
  String get courseTitle => _effectiveCourseTitle ?? '';
  bool get isEnrolled => _effectiveIsEnrolled;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    
    _currentLesson = widget.lesson;
    _effectiveCourseTitle = widget.courseTitle;
    _effectiveIsEnrolled = widget.isEnrolled;

    if (_currentLesson != null) {
      _finishInit();
    } else if (widget.lessonId != null) {
      _fetchAndInitLesson();
    }
  }

  void _finishInit() {
    if (_currentLesson == null) return;
    _currentHtmlContent = _currentLesson!.contentHtml;
    _videoUrl = _currentLesson!.videoUrl;
    
    _notesFuture = DatabaseService().getNotes(_currentLesson!.id);
    _examsFuture = DatabaseService().getExamsForLesson(_currentLesson!.id);
    
    _initLesson();
  }

  Future<void> _fetchAndInitLesson() async {
    setState(() => _isLoading = true);
    try {
      // Logic to fetch lesson by ID or Slug
      final lessonJson = await _db.getLessonById(widget.lessonId!);
      if (lessonJson != null) {
        _currentLesson = Lesson.fromJson(lessonJson);
        
        // If course info is missing, fetch it too
        if (_effectiveCourseTitle == null || _effectiveCourseTitle!.isEmpty) {
          final courseId = _currentLesson!.courseId;
          final courseJson = await _db.getCourseById(courseId);
          if (courseJson != null) {
            _effectiveCourseTitle = courseJson['title'] ?? '';
            // Check enrollment
            _effectiveIsEnrolled = await _db.isEnrolled(courseId);
          }
        }

        _finishInit();
      }
    } catch (e) {
      debugPrint('Error fetching lesson: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initLesson() async {
    _initVideoPlayer();
    _refreshFutures();
    _startWatchTimeTracking();
  }



  Future<void> _handleOpenResource(Map<String, String> resource) async {
    final url = resource['url'] ?? '';
    final fileName = resource['name'] ?? 'file';
    if (url.isEmpty) return;

    final ext = fileName.split('.').last.toLowerCase();
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
    } else if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(
            url: url,
            title: fileName,
          ),
        ),
      );
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  int _getCurrentVideoPosition() {
    if (_isYoutube) {
      return _youtubePlayerController?.value.position.inSeconds ?? 0;
    } else {
      return _videoPlayerController?.value.position.inSeconds ?? 0;
    }
  }

  void _seekTo(int seconds) {
    if (_isYoutube && _youtubePlayerController != null) {
      _youtubePlayerController!.seekTo(Duration(seconds: seconds));
    } else if (_videoPlayerController != null) {
      _videoPlayerController!.seekTo(Duration(seconds: seconds));
    }
    _mainScrollController.animateTo(0,
        duration: Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  void _refreshFutures() {
    final curLesson = _currentLesson;
    if (mounted && curLesson != null) {
      setState(() {
        _notesFuture = DatabaseService().getNotes(curLesson.id);
        DatabaseService().getLessonQuestions(curLesson.id).then((data) {
          if (mounted) {
            setState(() {
              _questionsList =
                  data.map((q) => LessonQuestion.fromJson(q)).toList();
            });
          }
        });
        _examsFuture = DatabaseService().getExamsForLesson(curLesson.id);
      });
    }
  }

  Future<void> _deleteNote(String noteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('delete_note')),
        content: Text(_t('delete_note_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseService().deleteNote(noteId);
        _refreshFutures();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('note_deleted_success'))),
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
  }

  Future<void> _editNote(Note note) async {
    String editedContent = note.content;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('edit_note'), textAlign: TextAlign.right),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: TextField(
          controller: TextEditingController(text: note.content),
          maxLines: null,
          minLines: 5,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'اكتب ملاحظتك هنا...',
          ),
          onChanged: (text) {
            editedContent = text;
          },
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, editedContent),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child:
                Text(_t('save'), style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await DatabaseService().updateNote(note.id, result.trim());
        _refreshFutures();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم تحديث الملاحظة بنجاح')),
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
  }

  bool _hasInteractiveContent() {
    // Check only if there is internal HTML content
    return _currentHtmlContent != null &&
        _currentHtmlContent!.trim().isNotEmpty;
  }

  void _openInteractiveApp() {
    // Schedule navigation to avoid gesture conflicts during device updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_currentHtmlContent != null &&
          _currentHtmlContent!.trim().isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => InteractiveQuizScreen(
              content: _currentHtmlContent,
              title: 'الاختبار التفاعلي: ${lesson.title}',
              isHtml: true,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t('no_interactive_content'),
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _initVideoPlayer() {
    final url = _videoUrl;
    if (url.isEmpty) return;

    // 1. Handle Online/YouTube Link FIRST
    if (url.contains('youtu.be') || url.contains('youtube.com')) {
      _isYoutube = true;
      
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        return; 
      }

      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _youtubePlayerController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            forceHD: true,
            enableCaption: false,
            isLive: false,
            disableDragSeek: false,
            hideControls: true, 
            hideThumbnail: true,
          ),
        );
      }
      return; // Handled as YouTube
    }

    // 2. Handle Direct Network Stream (MX Player Style: HLS, DASH, MP4)
    else {
      _isYoutube = false;
      
      // Sanitize URL: handle spaces and Arabic characters
      final sanitizedUrl = _sanitizeUrl(url);

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(sanitizedUrl),
        // Add headers to avoid some servers blocking the request (e.g. GitHub raw, Supabase)
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Referer': 'https://supabase.co',
        },
      );

      _videoPlayerController!.initialize().then((_) {
        if (!mounted) return;
        setState(() {
          final isVertical = _videoPlayerController!.value.aspectRatio < 1.0;
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: false,
            looping: false,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            deviceOrientationsOnEnterFullScreen: isVertical
                ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
                : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
            deviceOrientationsAfterFullScreen: [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
            placeholder: Container(
              color: Colors.black,
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
            ),
            errorBuilder: (context, errorMessage) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 40),
                      SizedBox(height: 10),
                      Text(
                        'فشل تحميل البث المباشر. تأكد من صحة الرابط أو جودة الإنترنت.',
                        style: TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        });
      }).catchError((error) {
        debugPrint('Error initializing network stream: $error');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('خطأ في الاتصال بالبث: $error')),
           );
        }
      });
    }
  }

  /// Sanitize URL to handle special characters and spaces
  String _sanitizeUrl(String url) {
    if (url.isEmpty) return url;
    try {
      // If it's already an encoded URI, just return it
      if (url.contains('%')) return url;
      
      final uri = Uri.parse(url);
      final encodedUri = uri.replace(
        path: _encodePath(uri.path),
        queryParameters: uri.queryParameters.isNotEmpty ? uri.queryParameters : null,
      );
      return encodedUri.toString();
    } catch (e) {
      // Fallback: simple character replacement for most common issues
      return url.replaceAll(' ', '%20');
    }
  }

  String _encodePath(String path) {
    if (path.isEmpty) return path;
    return path.split('/').map((segment) => Uri.encodeComponent(segment)).join('/');
  }

  // Removed _initWebView and _wrapHtmlContent in favor of separate screen


  @override
  void dispose() {
    _watchTimeTimer?.cancel();
    // _saveProgressBeforeExit(); // Removed async call from dispose
    _tabController.dispose();
    _mainScrollController.dispose();

    // Proper video disposal
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _youtubePlayerController?.dispose();
    
    super.dispose();
  }


  void _startWatchTimeTracking() {
    if ((lesson.videoUrl.isEmpty)) return;

    _watchTimeTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      bool isPlaying = false;
      
      if (_isYoutube) {
        isPlaying = _youtubePlayerController?.value.isPlaying ?? false;
      } else {
        isPlaying = _videoPlayerController?.value.isPlaying ?? false;
      }
      
      if (isPlaying) {
        _videoWatchTime++;
      }
    });
  }

  Future<void> _saveProgressBeforeExit() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return; // Skip saving progress for guests
      
      await DatabaseService().updateLessonProgress(
        lessonId: lesson.id,
        watchTime: _videoWatchTime,
        lastPosition: _getCurrentVideoPosition(),
        isCompleted: _isLessonCompleted(),
      );
    } catch (e) {
      debugPrint('Error saving lesson progress: $e');
    }
  }



  int? _getVideoDuration() {
    if (_isYoutube) {
      return _youtubePlayerController?.metadata.duration.inSeconds;
    } else {
      return _videoPlayerController?.value.duration.inSeconds;
    }
  }

  bool _isLessonCompleted() {
    final position = _getCurrentVideoPosition();
    final duration = _getVideoDuration() ?? 1;
    if (duration <= 0) return false;
    // Mark as completed if watched > 80% of video
    return (position / (duration > 0 ? duration : 1)) > 0.8;
  }




  @override
  Widget build(BuildContext context) {
    if (_isLoading || _currentLesson == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryPurple),
        ),
      );
    }

    if (_isYoutube &&
        _youtubePlayerController != null &&
        !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.windows) {
      return YoutubePlayerBuilder(
        onEnterFullScreen: () {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        },
        onExitFullScreen: () {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        },
        player: YoutubePlayer(
          controller: _youtubePlayerController!,
          showVideoProgressIndicator: false, // يُدار من VideoPlayerControls
        ),
        builder: (context, player) {
          return _buildScaffold(
            context,
            videoPlayer: _buildVideoWithOverlay(
              player: player,
              onToggleFullScreen: () => _handleToggleFullScreen(),
            ),
          );
        },
      );
    }

    Widget playerWidget = _buildVideoPlayer();
    return _buildScaffold(
      context,
      videoPlayer: _buildVideoWithOverlay(
        player: playerWidget,
        onToggleFullScreen: () => _handleToggleFullScreen(),
      ),
    );
  }

  void _handleToggleFullScreen() {
    final bool isCurrentlyFullScreen = _isYoutube 
        ? (_youtubePlayerController?.value.isFullScreen ?? false)
        : (_chewieController?.isFullScreen ?? false);

    double aspectRatio = 16 / 9;
    if (_isYoutube) {
      // YouTube metadata might not be ready, default to 16/9 or try to get it
      aspectRatio = 16 / 9; 
    } else if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) {
      aspectRatio = _videoPlayerController!.value.aspectRatio;
    }

    if (isCurrentlyFullScreen) {
      // Exit Full Screen
      if (_isYoutube) {
        _youtubePlayerController?.toggleFullScreenMode();
      } else {
        _chewieController?.exitFullScreen();
      }
      // Reset orientation
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      // Enter Full Screen
      // If video is vertical (aspect ratio < 1), lock to portrait
      if (aspectRatio < 1.0) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      } else {
        // If video is landscape, lock to landscape
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }

      if (_isYoutube) {
        _youtubePlayerController?.toggleFullScreenMode();
      } else {
        _chewieController?.enterFullScreen();
      }
    }
  }

  Widget _buildVideoWithOverlay(
      {required Widget player, VoidCallback? onToggleFullScreen}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        VideoPlayerControls(
          isYoutube: _isYoutube,
          youtubeController: _youtubePlayerController,
          videoController: _videoPlayerController,
          lesson: lesson,
          courseTitle: courseTitle,
          onToggleFullScreen: onToggleFullScreen,
        ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context, {required Widget videoPlayer}) {
    return DynamicGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          controller: _mainScrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverAppBar(
                  expandedHeight: (MediaQuery.of(context).size.width * 9 / 16)
                      .clamp(
                          250.0,
                          math.max(
                              250.0, MediaQuery.of(context).size.height * 0.5)),
                  floating: false,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.primaryPurple,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: videoPlayer,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primaryPurple.withOpacity(0.2)),
                        ),
                        child: Text(
                          '${_t('lesson_prefix')} ${lesson.orderIndex}',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lesson.getLocalizedTitle(
                              Provider.of<LocaleProvider>(context).locale),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPersistentHeader(
                pinned: true,
                delegate: LessonSliverAppBarDelegate(
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context)
                              .withOpacity(0.8),
                          border: Border(
                              bottom: BorderSide(
                                  color: AppColors.getMutedTextColor(context))),
                        ),
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.getTextColor(context)
                                .withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: Colors.white,
                            unselectedLabelColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white60
                                    : Colors.black54,
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            dividerColor: Colors.transparent,
                            isScrollable: true,
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(_t('description_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.attach_file, size: 18),
                                    SizedBox(width: 8),
                                    Text(_t('attachments_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.science_outlined,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(_t('interactive_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.quiz_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text(_t('exams_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.note_alt_outlined,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(_t('notes_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.question_answer_outlined,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(_t('questions_tab')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTabContent(_buildDescriptionTab()),
              _buildTabContent(_buildResourcesTab()),
              _buildTabContent(_buildInteractiveTab()),
              _buildTabContent(_buildExamSection(context)),
              _buildTabContent(_buildNotesTab()),
              _buildTabContent(_buildQuestionsTab())
            ],
          ),
        ),
        bottomNavigationBar: _buildNavigationButtons(),
      ),
    );
  }

  Widget _buildTabContent(Widget child) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            SliverPadding(
              padding: EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    if (lesson.videoUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 250,
        color: Colors.black,
        child: Center(
          child: Text(_t('no_video_available'),
              style: TextStyle(color: AppColors.getTextColor(context))),
        ),
      );
    }

    if (_isYoutube) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final videoId = YoutubePlayer.convertUrlToId(lesson.videoUrl);
        if (videoId != null) {
          return YoutubePlayerWebWindows(
            videoId: videoId,
            height:
                (MediaQuery.of(context).size.width * 9 / 16).clamp(200, 500),
          );
        }
      }

      // In YoutubePlayerBuilder, we shouldn't build it again here if used in builder
      // But for the non-youtube path (_isYoutube = false), this is skipped anyway.
      // If we reach here and _isYoutube is true, it means _youtubePlayerController is null
      return Container(
          height: 250,
          color: Colors.black,
          child: Center(child: CircularProgressIndicator()));
    } else {
      if (_chewieController != null &&
          _videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized) {
        return AspectRatio(
          aspectRatio: _videoPlayerController!.value.aspectRatio,
          child: Chewie(controller: _chewieController!),
        );
      }
      return Container(
        height: 250,
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: AppColors.getTextColor(context))),
      );
    }
  }

  Widget _buildDescriptionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TexViewWidget(
          lesson.description,
          style:
              TextStyle(fontSize: 16, height: 1.8, color: AppColors.getTextColor(context)),
        ),

        if (lesson.content != null &&
            lesson.content != lesson.description &&
            lesson.content!.isNotEmpty) ...[
          SizedBox(height: 24),
          TexViewWidget(
            lesson.content!,
            style:
                TextStyle(fontSize: 16, height: 1.8, color: AppColors.getTextColor(context)),
          ),
        ],
      ],
    );
  }

  Widget _buildResourcesTab() {
    if (lesson.resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'لا توجد مرفقات لهذا الدرس',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lesson.resources.map((resource) {
          final fileName = resource['name'] ?? 'ملف غير معروف';
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getMutedTextColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.getMutedTextColor(context),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getResourceIcon(fileName),
                        color: AppColors.primaryPurple,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _handleOpenResource(resource),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple.withOpacity(0.3),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.remove_red_eye_outlined,
                                color: AppColors.getTextColor(context),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'عرض',
                                style: TextStyle(
                                  color: AppColors.getTextColor(context),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInteractiveTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasInteractiveContent()) ...[
          _buildInteractiveCard(
            title: 'المحتوى التفاعلي',
            description:
                'استمتع بتجربة تعليمية تفاعلية غنية تعزز فهمك للموضوع.',
            icon: Icons.rocket_launch_outlined,
            buttonLabel: 'بدء التجربة الآن',
            onTap: _openInteractiveApp,
          ),
          SizedBox(height: 20),
        ],



        if (!_hasInteractiveContent())
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_outlined,
                    size: 64, color: AppColors.getMutedTextColor(context)),
                SizedBox(height: 16),
                Text(
                  'لا يوجد محتوى تفاعلي حالياً',
                  style: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInteractiveCard({
    required String title,
    required String description,
    required IconData icon,
    required String buttonLabel,
    required VoidCallback? onTap,
    bool isLoading = false,
    bool isAIGenerated = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.getMutedTextColor(context),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 48,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    if (isAIGenerated)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_awesome,
                              size: 12, color: AppColors.getTextColor(context)),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 20),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTextColor(context, secondary: true),
                    height: 1.6,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.getTextColor(context)))
                        : Icon(Icons.play_arrow_rounded),
                    label: Text(buttonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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



  IconData _getResourceIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.attach_file;
    }
  }

  Widget _buildExamSection(BuildContext context) {
    if (_examsFuture == null) return SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _examsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final examsData = snapshot.data ?? [];
        if (examsData.isEmpty) {
          return SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...examsData.map((examData) {
              final exam = Exam.fromJson(examData);
              return Container(
                margin: EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getMutedTextColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.getMutedTextColor(context),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  (examData['type'] ?? 'exam') == 'quiz'
                                      ? Icons.quiz
                                      : Icons.assignment,
                                  color: AppColors.primaryPurple,
                                  size: 24,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exam.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.getTextColor(context),
                                      ),
                                    ),
                                    if (exam.description.isNotEmpty)
                                      Text(
                                        exam.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.getTextColor(context, secondary: true),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16),
                          // Attempts Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                exam.maxAttempts != null
                                    ? 'المحاولات: ${exam.attemptCount} / ${exam.maxAttempts}'
                                    : 'المحاولات: ${exam.attemptCount}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: exam.canTakeAgain
                                      ? Colors.white.withOpacity(0.7)
                                      : Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (exam.attempts.isNotEmpty)
                                Text(
                                  'أفضل نتيجة: ${((exam.bestAttempt?['score'] ?? 0) / (exam.calculatedTotalPoints > 0 ? exam.calculatedTotalPoints : 1) * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),

                          if (exam.attempts.isNotEmpty) ...[
                            SizedBox(height: 16),
                            Text(
                              'سجل المحاولات:',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.getTextColor(context).withOpacity(0.70),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: exam.attempts.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final attempt = exam.attempts[index];
                                final percentage = ((attempt['score'] ?? 0) /
                                    (exam.calculatedTotalPoints > 0
                                        ? exam.calculatedTotalPoints
                                        : 1) *
                                    100);
                                final isPassed = percentage >= 60;
                                final dateStr = attempt['submitted_at'] != null
                                    ? DateTime.parse(
                                            attempt['submitted_at'].toString())
                                        .toString()
                                        .substring(0, 16)
                                        .replaceAll('T', ' ')
                                    : '';

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      if (attempt['id'] != null) {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ReviewExamScreen(
                                              attemptId: attempt['id'],
                                            ),
                                          ),
                                        );
                                        _refreshFutures();
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppColors.getMutedTextColor(context),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: isPassed
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isPassed
                                                  ? Colors.green
                                                      .withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isPassed
                                                  ? Icons.check
                                                  : Icons.close,
                                              size: 16,
                                              color: isPassed
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'محاولة ${index + 1}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: AppColors.getTextColor(context),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (dateStr.isNotEmpty)
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.getTextColor(context)
                                                          .withOpacity(0.5),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${percentage.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: isPassed
                                                      ? Colors.greenAccent
                                                      : Colors.redAccent,
                                                ),
                                              ),
                                              Text(
                                                isPassed ? 'ناجح' : 'راسب',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isPassed
                                                      ? Colors.green
                                                      : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 12,
                                            color:
                                                Colors.white.withOpacity(0.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: exam.canTakeAgain
                                      ? () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  ExamTakingScreen(exam: exam),
                                            ),
                                          );
                                          _refreshFutures();
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryPurple,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledBackgroundColor:
                                        Colors.grey.withOpacity(0.2),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    exam.canTakeAgain
                                        ? 'ابدأ الاختبار'
                                        : 'انتهت المحاولات',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              if (exam.attempts.isNotEmpty) ...[
                                SizedBox(width: 12),
                                // "Review Results" button removed as requested
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        // Add Note Button
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddNoteScreen(
                        lessonId: lesson.id,
                        courseId: lesson.courseId,
                      ),
                    ),
                  );
                  if (result == true) {
                    _refreshFutures();
                  }
                },
                icon: Icon(Icons.add),
                label: Text('ملاحظة عادية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.2))),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final timestamp = _getCurrentVideoPosition();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddNoteScreen(
                        lessonId: lesson.id,
                        courseId: lesson.courseId,
                        videoTimestamp: timestamp,
                      ),
                    ),
                  );
                  if (result == true) {
                    _refreshFutures();
                  }
                },
                icon: Icon(Icons.timer_outlined),
                label: Text('ملاحظة ذكية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        
        if (_notesFuture == null)
          Center(child: CircularProgressIndicator())
        else
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _notesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
                return Center(
                    child: Text(
                        ErrorUtils.getFriendlyErrorMessage(snapshot.error!)));
            }
            
            final notesData = snapshot.data ?? [];
            if (notesData.isEmpty) {
                return SizedBox(
                width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.getMutedTextColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.getMutedTextColor(context), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note_outlined,
                                size: 60, color: AppColors.getMutedTextColor(context)),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد ملاحظات بعد',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.getTextColor(context, secondary: true)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ),
              );
            }
            
            return ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: notesData.length,
              separatorBuilder: (context, index) => SizedBox(height: 12),
              itemBuilder: (context, index) {
                final note = Note.fromJson(notesData[index]);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.getMutedTextColor(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.getMutedTextColor(context), width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            note.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.getTextColor(context),
                                            ),
                                          ),
                                          if (note.videoTimestamp != null) ...[
                                            SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () =>
                                                  _seekTo(note.videoTimestamp!),
                                              child: Container(
                                                padding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryPurple
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: AppColors
                                                          .primaryPurple
                                                          .withOpacity(0.5)),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.play_arrow,
                                                        size: 14,
                                                        color: AppColors
                                                            .primaryPurple),
                                                    Text(
                                                      note.formattedTimestamp,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: AppColors
                                                            .primaryPurple,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        _formatDate(note.updatedAt),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.getTextColor(context, secondary: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _editNote(note),
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        color: AppColors.getTextColor(context, secondary: true),
                                      ),
                                      iconSize: 20,
                                      constraints: BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _deleteNote(note.id),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red.withOpacity(0.7),
                                      ),
                                      iconSize: 20,
                                      constraints: BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            TexViewWidget(
                              note.content,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.getTextColor(context, secondary: true),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildQuestionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        // Question Input
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.getMutedTextColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.getMutedTextColor(context), width: 1.5),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _questionController,
                    maxLines: null,
                    minLines: 3,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'اسأل سؤالاً عن هذا الدرس...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                    style: TextStyle(color: AppColors.getTextColor(context)),
                  ),
                  SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _sendQuestion,
                      icon: Icon(Icons.send_rounded, size: 18),
                      label: Text('إرسال السؤال'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 24),

        if (_questionsList == null)
          Center(child: CircularProgressIndicator())
        else if (_questionsList!.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'لا توجد أسئلة بعد. كن أول من يسأل!',
                style: TextStyle(color: AppColors.getTextColor(context)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _questionsList!.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildQuestionItem(_questionsList![index]);
            },
          ),
      ],
    );
  }

  Widget _buildQuestionItem(LessonQuestion question) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (question.userId ==
                                SupabaseService.instance.currentUserId) ...[
                              IconButton(
                                onPressed: () => _editQuestion(question),
                                icon: Icon(Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.getTextColor(context, secondary: true)),
                                constraints: BoxConstraints(),
                                padding: EdgeInsets.only(left: 8),
                              ),
                              IconButton(
                                onPressed: () => _deleteQuestion(question.id),
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.red.withOpacity(0.7)),
                                constraints: BoxConstraints(),
                                padding: EdgeInsets.only(left: 8),
                              ),
                            ],
                            Text(
                              question.userName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.getTextColor(context)),
                            ),
                          ],
                        ),
                        Text(
                          _formatDate(question.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: question.userPhoto != null
                        ? NetworkImage(question.userPhoto!)
                        : null,
                    child: question.userPhoto == null
                        ? Icon(Icons.person,
                            size: 20, color: AppColors.getTextColor(context))
                        : null,
                  ),
                ],
              ),
              SizedBox(height: 12),
              TexViewWidget(
                question.content,
                style: TextStyle(
                    fontSize: 14, height: 1.5, color: AppColors.getTextColor(context)),
              ),
              if (question.replies.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.getTextColor(context).withOpacity(0.24), height: 1),
                ),
                ...question.replies
                    .map((reply) => _buildReplyItem(reply, question)),
              ],
              SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showReplyDialog(question),
                  icon: Icon(Icons.reply_rounded,
                      size: 18, color: AppColors.getTextColor(context)),
                  label:
                      Text('رد', style: TextStyle(color: AppColors.getTextColor(context))),
                  style: TextButton.styleFrom(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              SizedBox(height: 8),
              _buildReactionsRow(
                questionId: question.id,
                reactionCounts: question.reactionCounts,
                myReaction: question.myReaction,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyItem(LessonQuestionReply reply, LessonQuestion question) {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: reply.isInstructorReply
            ? AppColors.primaryPurple.withOpacity(0.1)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: reply.isInstructorReply
              ? AppColors.primaryPurple.withOpacity(0.2)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (reply.userId ==
                            SupabaseService.instance.currentUserId) ...[
                          IconButton(
                            onPressed: () => _editReply(reply),
                            icon: Icon(Icons.edit_outlined,
                                size: 16, color: AppColors.getTextColor(context, secondary: true)),
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.only(left: 8),
                          ),
                          IconButton(
                            onPressed: () => _deleteReply(reply.id),
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 16, color: Colors.red.withOpacity(0.7)),
                            constraints: BoxConstraints(),
                            padding: EdgeInsets.only(left: 8),
                          ),
                        ],
                        Text(
                          reply.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: reply.isInstructorReply
                                ? AppColors.primaryPurple
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDate(reply.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.getTextColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: reply.userPhoto != null
                    ? NetworkImage(reply.userPhoto!)
                    : null,
                child: reply.userPhoto == null
                    ? Icon(Icons.person, size: 14, color: AppColors.getTextColor(context))
                    : null,
              ),
            ],
          ),
          SizedBox(height: 4),
          TexViewWidget(
            reply.content,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.getTextColor(context),
            ),
          ),
          _buildReactionsRow(
            replyId: reply.id,
            reactionCounts: reply.reactionCounts,
            myReaction: reply.myReaction,
            isSmall: true,
          ),
          SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _showReplyDialog(question,
                  initialText: '@${reply.userName} '),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'رد',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.getTextColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQuestion(String questionId) async {
    final confirmed = await _showConfirmDialog(
        'حذف السؤال', 'هل أنت متأكد من حذف هذا السؤال وكل الردود عليه؟');
    if (confirmed) {
      try {
        await DatabaseService().deleteLessonQuestion(questionId);
        _refreshFutures();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
              SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))));
        }
      }
    }
  }

  Future<void> _deleteReply(String replyId) async {
    final confirmed =
        await _showConfirmDialog('حذف الرد', 'هل أنت متأكد من حذف هذا الرد؟');
    if (confirmed) {
      try {
        await DatabaseService().deleteReply(replyId);
        _refreshFutures();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
              SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))));
        }
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title, textAlign: TextAlign.right),
            content: Text(content, textAlign: TextAlign.right),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('إلغاء')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildReactionsRow({
    String? questionId,
    String? replyId,
    required Map<String, int> reactionCounts,
    String? myReaction,
    bool isSmall = false,
  }) {
    final reactions = {
      'like': '👍',
      'love': '❤️',
      'haha': '😂',
    };

    final hasReacted = myReaction != null;
    final String label = hasReacted ? reactions[myReaction]! : '👍';
    final Color activeColor =
        hasReacted ? AppColors.primaryPurple : Colors.white70;

    // Calculate total reactions count
    int totalCount = 0;
    for (var v in reactionCounts.values) {
      totalCount += v;
    }

    return Row(
      children: [
        GestureDetector(
          onLongPress: () =>
              _showReactionPicker(questionId: questionId, replyId: replyId),
          child: InkWell(
            onTap: () => _toggleReaction(
                questionId: questionId,
                replyId: replyId,
                type: myReaction ?? 'like'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: hasReacted
                    ? AppColors.primaryPurple.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasReacted ? AppColors.primaryPurple : Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  Text(label, style: TextStyle(fontSize: isSmall ? 14 : 16)),
                  SizedBox(width: 6),
                  Text(
                    hasReacted ? 'تم' : 'إعجاب',
                    style: TextStyle(
                      color: activeColor,
                      fontSize: isSmall ? 11 : 13,
                      fontWeight:
                          hasReacted ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (totalCount > 0) ...[
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.getTextColor(context).withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                ...reactionCounts.entries
                    .where((e) => e.value > 0)
                    .take(3)
                    .map((e) => Padding(
                          padding: EdgeInsets.symmetric(horizontal: 1),
                          child: Text(reactions[e.key]!,
                              style: TextStyle(fontSize: 10)),
                        )),
                SizedBox(width: 4),
                Text(
                  totalCount.toString(),
                  style: TextStyle(fontSize: 10, color: AppColors.getTextColor(context).withOpacity(0.70)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showReactionPicker({String? questionId, String? replyId}) {
    final reactions = {
      'like': '👍',
      'love': '❤️',
      'haha': '😂',
    };

    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: reactions.entries.map((e) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
                _toggleReaction(
                    questionId: questionId, replyId: replyId, type: e.key);
              },
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Text(e.value, style: TextStyle(fontSize: 30)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _toggleReaction(
      {String? questionId, String? replyId, required String type}) async {
    if (_questionsList == null) return;

    // Optimistic Update
    setState(() {
      _questionsList = _questionsList!.map((q) {
        if (questionId != null && q.id == questionId) {
          return _updateItemReaction(q, type) as LessonQuestion;
        } else if (replyId != null) {
          return q.copyWith(
            replies: q.replies.map((r) {
              if (r.id == replyId) {
                return _updateItemReaction(r, type) as LessonQuestionReply;
              }
              return r;
            }).toList(),
          );
        }
        return q;
      }).toList();
    });

    try {
      await DatabaseService().toggleReaction(
        questionId: questionId,
        replyId: replyId,
        reactionType: type,
      );
      // Optional: sync with real server data again to ensure consistency
      // but without the jarring refresh since we already updated the list
      final freshData =
          await DatabaseService().getLessonQuestions(lesson.id);
      if (mounted) {
        setState(() {
          _questionsList =
              freshData.map((q) => LessonQuestion.fromJson(q)).toList();
        });
      }
    } catch (e) {
      // Revert or show error
      _refreshFutures();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  dynamic _updateItemReaction(dynamic item, String type) {
    final Map<String, int> newCounts = Map.from(item.reactionCounts);
    String? newMyReaction = item.myReaction;

    if (item.myReaction == type) {
      // Remove reaction
      newCounts[type] = (newCounts[type] ?? 1) - 1;
      if (newCounts[type]! <= 0) newCounts.remove(type);
      newMyReaction = null;
    } else {
      // If had different reaction, remove it first
      if (item.myReaction != null) {
        final oldType = item.myReaction!;
        newCounts[oldType] = (newCounts[oldType] ?? 1) - 1;
        if (newCounts[oldType]! <= 0) newCounts.remove(oldType);
      }
      // Add new reaction
      newCounts[type] = (newCounts[type] ?? 0) + 1;
      newMyReaction = type;
    }

    return item.copyWith(
      reactionCounts: newCounts,
      myReaction: newMyReaction,
    );
  }

  void _showReplyDialog(LessonQuestion question, {String? initialText}) {
    String replyContent = initialText ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة رد', textAlign: TextAlign.right),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
        child: TextField(
          controller: TextEditingController(text: initialText),
          maxLines: null,
          minLines: 5,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'اكتب ردك هنا...',
          ),
          onChanged: (text) {
            replyContent = text;
          },
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyContent.trim().isEmpty) return;
              final content = replyContent.trim();
              Navigator.pop(context);

              final messenger = ScaffoldMessenger.of(context);
              try {
                await DatabaseService().addReply(question.id, content);
                _refreshFutures();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child: Text('إرسال', style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );
  }

  Future<void> _sendQuestion() async {
    final content = _questionController.text.trim();
    _questionController.clear();

    try {
      await DatabaseService().askLessonQuestion(lesson.id, content);
      _refreshFutures(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرسال سؤالك بنجاح')),
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

  Widget _buildNavigationButtons() {
    final currentIndex = widget.allLessons.indexWhere((l) => l.id == lesson.id);
    final hasNext = currentIndex != -1 && currentIndex < widget.allLessons.length - 1;
    final hasPrev = currentIndex > 0;
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (hasPrev)
              Expanded(
                child: _buildNavButton(
                  label: 'السابق',
                  icon: Icons.arrow_back_ios_new,
                  isPrimary: false,
                  onTap: () async {
                    await _saveProgressBeforeExit();
                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LessonScreen(
                            lesson: widget.allLessons[currentIndex - 1],
                            allLessons: widget.allLessons,
                            courseTitle: widget.courseTitle,
                            isEnrolled: widget.isEnrolled,
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            if (hasPrev && hasNext) SizedBox(width: 15),
            if (hasNext)
              Expanded(
                child: _buildNavButton(
                  label: 'الدرس التالي',
                  icon: Icons.arrow_forward_ios,
                  isPrimary: true,
                  onTap: () async {
                    final nextLesson = widget.allLessons[currentIndex + 1];

                    // Check if user has access to next lesson
                    if (!widget.isEnrolled && !nextLesson.isFree) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_t('must_subscribe'),
                                textAlign: TextAlign.right),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                      return;
                    }

                    await _saveProgressBeforeExit();
                    if (!mounted) return;

                    // CHECK FOR EXAMS
                    final examsResult =
                        await _db.getExamsForLesson(lesson.id);

                    if (!mounted) return;

                    if (examsResult.isNotEmpty) {
                      final examData = examsResult.first;
                      _showExamRecommendationDialog(examData, nextLesson);
                    } else {
                      // No exam for this lesson - show dialog as requested
                      _showNoExamDialog(nextLesson);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _goToNextLesson(Lesson nextLesson) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LessonScreen(
          lesson: nextLesson,
          allLessons: widget.allLessons,
          courseTitle: widget.courseTitle,
          isEnrolled: widget.isEnrolled,
        ),
      ),
    );
  }

  void _showNoExamDialog(Lesson nextLesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('تنبيه', textAlign: TextAlign.right, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.info_outline, color: Colors.blueAccent),
          ],
        ),
        content: Text(
          'لا يوجد اختبار مرتبط بهذا الدرس حالياً. يمكنك الانتقال للدرس التالي مباشرة.',
          textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _goToNextLesson(nextLesson);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('الانتقال للدرس التالي'),
          ),
        ],
      ),
    );
  }

  void _showExamRecommendationDialog(
      Map<String, dynamic> examData, Lesson nextLesson) {
    final exam = Exam.fromJson(examData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('يوجد اختبار', textAlign: TextAlign.right, style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.assignment_outlined, color: Colors.orangeAccent),
          ],
        ),
        content: Text(
          'هذا الدرس يحتوي على اختبار بعنوان "${exam.title}". هل تود خوض الاختبار الآن أم الانتقال للدرس التالي؟',
          textAlign: TextAlign.right,
          style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExamTakingScreen(
                          exam: exam,
                          onNext: () {
                            _goToNextLesson(nextLesson);
                          },
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('بدء الاختبار الآن'),
                ),
              ),
              SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _goToNextLesson(nextLesson);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                  ),
                  child: Text('تخطي والانتقال للدرس التالي'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: isPrimary ? AppColors.primaryGradient : null,
        color: isPrimary ? null : Colors.white10,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isPrimary ? AppColors.buttonShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isPrimary) Icon(icon, color: AppColors.getTextColor(context), size: 16),
                if (!isPrimary) SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                      color: AppColors.getTextColor(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                if (isPrimary) SizedBox(width: 8),
                if (isPrimary) Icon(icon, color: AppColors.getTextColor(context), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editQuestion(LessonQuestion question) async {
    final controller = TextEditingController(text: question.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل السؤال', textAlign: TextAlign.right),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          maxLines: 4,
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child: Text('حفظ التعديل',
                style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await DatabaseService()
            .updateLessonQuestion(question.id, result.trim());
        _refreshFutures();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
              SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))));
        }
      }
    }
  }

  Future<void> _editReply(LessonQuestionReply reply) async {
    final controller = TextEditingController(text: reply.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل الرد', textAlign: TextAlign.right),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          maxLines: 4,
          decoration: InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child: Text('حفظ التعديل',
                style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        await DatabaseService().updateReply(reply.id, result.trim());
        _refreshFutures();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
              SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))));
        }
      }
    }
  }
}

class LessonSliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  LessonSliverAppBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 80;

  @override
  double get maxExtent => 80;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: 80,
      child: child,
    );
  }

  @override
  bool shouldRebuild(SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
