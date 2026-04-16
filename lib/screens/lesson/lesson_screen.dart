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
import '../../core/utils/error_utils.dart';
import 'dart:ui';
import 'package:pointer_interceptor/pointer_interceptor.dart';
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

class _LessonScreenState extends State<LessonScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
            child: Text(_t('save'),
                style: TextStyle(color: AppColors.getTextColor(context))),
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

    // 1. Handle Online/YouTube Link
    if (url.contains('youtu.be') || url.contains('youtube.com')) {
      _isYoutube = true;

      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _youtubePlayerController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            forceHD: true,
            enableCaption: false,
            isLive: false,
            disableDragSeek: false,
            hideControls: true, // Hide default controls
            hideThumbnail: true,
          ),
        )..addListener(() {
            if (mounted) setState(() {});
          });
      }
      return;
    }

    // 2. Handle Direct Network Stream
    else {
      _isYoutube = false;
      final sanitizedUrl = _sanitizeUrl(url);

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(sanitizedUrl),
        httpHeaders: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
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
            showControls: false, // Use our custom controls
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            deviceOrientationsOnEnterFullScreen: isVertical
                ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
                : [
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight
                  ],
            deviceOrientationsAfterFullScreen: [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
            placeholder: Container(
              color: Colors.black,
              child: const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primaryPurple)),
            ),
          );
        });
      }).catchError((error) {
        debugPrint('Error initializing network stream: $error');
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
        queryParameters:
            uri.queryParameters.isNotEmpty ? uri.queryParameters : null,
      );
      return encodedUri.toString();
    } catch (e) {
      // Fallback: simple character replacement for most common issues
      return url.replaceAll(' ', '%20');
    }
  }

  String _encodePath(String path) {
    if (path.isEmpty) return path;
    return path
        .split('/')
        .map((segment) => Uri.encodeComponent(segment))
        .join('/');
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

    return OrientationBuilder(
      builder: (context, orientation) {
        final bool isLandscape = orientation == Orientation.landscape;
        
        final Widget playerWidget = _buildVideoPlayer();
        final Widget videoWithOverlay = _buildVideoWithOverlay(
          player: playerWidget,
          onToggleFullScreen: () => _handleToggleFullScreen(),
        );

        if (isLandscape) {
          // In landscape, we show the video player in full screen mode automatically
          return Scaffold(
            backgroundColor: Colors.black,
            body: videoWithOverlay,
          );
        }

        return _buildScaffold(
          context,
          videoPlayer: videoWithOverlay,
        );
      },
    );
  }

  void _handleToggleFullScreen() {
    // YouTube on mobile: push our own fullscreen page so controls remain visible.
    if (_isYoutube && !kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
      if (_youtubePlayerController == null) return;
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => _YoutubeFullscreenPage(
            controller: _youtubePlayerController!,
            lesson: lesson,
            courseTitle: courseTitle,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ).then((_) {
        if (mounted) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      });
      return;
    }

    // Non-YouTube (direct video via Chewie)
    final bool isCurrentlyFullScreen = _chewieController?.isFullScreen ?? false;
    if (isCurrentlyFullScreen) {
      _chewieController?.exitFullScreen();
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      double aspectRatio = 16 / 9;
      if (_videoPlayerController != null &&
          _videoPlayerController!.value.isInitialized) {
        aspectRatio = _videoPlayerController!.value.aspectRatio;
      }
      if (aspectRatio < 1.0) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      _chewieController?.enterFullScreen();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Widget _buildVideoWithOverlay(
      {required Widget player, VoidCallback? onToggleFullScreen}) {
    final bool showCustomControls = !(_isYoutube && (kIsWeb || defaultTargetPlatform == TargetPlatform.windows));

    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        if (showCustomControls)
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
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.getBackgroundColor(context),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.getBackgroundColor(context),
                elevation: 0,
                automaticallyImplyLeading: false,
                leading: kIsWeb
                    ? PointerInterceptor(
                        child: _buildBackButton(context),
                      )
                    : _buildBackButton(context),
                // Removed actions containing equations button as requested
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [
                    StretchMode.zoomBackground,
                    StretchMode.blurBackground,
                  ],
                  background: videoPlayer,
                  titlePadding: const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: innerBoxIsScrolled ? 1.0 : 0.0,
                    child: Text(
                      lesson.getLocalizedTitle(Provider.of<LocaleProvider>(context).locale),
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primaryPurple.withOpacity(0.3)),
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
                          const SizedBox(width: 12),
                          if (lesson.isFree)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: const Text('مجاني', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lesson.getLocalizedTitle(Provider.of<LocaleProvider>(context).locale),
                        style: TextStyle(color: AppColors.getTextColor(context), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
              ),
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(
                  pinned: true,
                  delegate: LessonSliverAppBarDelegate(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.getBackgroundColor(context),
                        border: Border(
                          bottom: BorderSide(
                              color: AppColors.getBorderColor(context), width: 1),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        indicatorColor: AppColors.primaryPurple,
                        indicatorWeight: 3,
                        labelColor: AppColors.primaryPurple,
                        unselectedLabelColor:
                            AppColors.getTextColor(context, secondary: true),
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            fontFamily: 'Cairo'),
                        tabs: [
                          Tab(text: _t('description_tab')),
                          Tab(text: _t('attachments_tab')),
                          Tab(text: _t('interactive_tab')),
                          Tab(text: _t('exams_tab')),
                          Tab(text: _t('notes_tab')),
                          Tab(text: _t('questions_tab')),
                        ],
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
              _buildTabContent(_buildQuestionsTab()),
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
        color: AppColors.getSurfaceColor(context),
        child: Center(
          child: Text(_t('no_video_available'),
              style: TextStyle(color: AppColors.getTextColor(context))),
        ),
      );
    }

    if (_isYoutube) {
      // Web / Windows: use IFrame-based player.
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

      // Mobile: wrap with minimal YoutubePlayerBuilder so YoutubePlayer has
      // a valid ancestor. Fullscreen is handled via _YoutubeFullscreenPage.
      if (_youtubePlayerController != null) {
        return YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: _youtubePlayerController!,
            showVideoProgressIndicator: false,
          ),
          builder: (_, player) => player,
        );
      }

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
        child: Center(
            child: CircularProgressIndicator(
                color: AppColors.getTextColor(context))),
      );
    }
  }

  Widget _buildDescriptionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TexViewWidget(
          lesson.description,
          style: TextStyle(
              fontSize: 16,
              height: 1.8,
              color: AppColors.getTextColor(context)),
        ),
        if (lesson.content != null &&
            lesson.content != lesson.description &&
            lesson.content!.isNotEmpty) ...[
          SizedBox(height: 24),
          TexViewWidget(
            lesson.content!,
            style: TextStyle(
                fontSize: 16,
                height: 1.8,
                color: AppColors.getTextColor(context)),
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
                    color: AppColors.getElevatedSurfaceColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.getBorderColor(context),
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
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
                  style: TextStyle(
                      color: AppColors.getTextColor(context, secondary: true)),
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
              color: AppColors.getElevatedSurfaceColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.getBorderColor(context), width: 1.5),
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
                                strokeWidth: 2,
                                color: AppColors.getTextColor(context)))
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
                        color: AppColors.getElevatedSurfaceColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.getBorderColor(context),
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
                                          color: AppColors.getTextColor(context,
                                              secondary: true),
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
                                color: AppColors.getTextColor(context)
                                    .withOpacity(0.70),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: exam.attempts.length,
                              separatorBuilder: (_, __) => SizedBox(height: 8),
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
                                        color:
                                            AppColors.getSurfaceColor(context),
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
                                                    color:
                                                        AppColors.getTextColor(
                                                            context),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (dateStr.isNotEmpty)
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                              .getTextColor(
                                                                  context)
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
                                    padding: EdgeInsets.symmetric(vertical: 12),
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
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
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
        SizedBox(
          width: double.infinity,
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
                          color: AppColors.getElevatedSurfaceColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.getBorderColor(context),
                              width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note_outlined,
                                size: 60,
                                color: AppColors.getMutedTextColor(context)),
                            SizedBox(height: 16),
                            Text(
                              'لا توجد ملاحظات بعد',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.getTextColor(context,
                                      secondary: true)),
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
                          color: AppColors.getElevatedSurfaceColor(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.getBorderColor(context),
                              width: 1.5),
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
                                              color: AppColors.getTextColor(
                                                  context),
                                            ),
                                          ),
                                          if (note.videoTimestamp != null) ...[
                                            SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () =>
                                                  _seekTo(note.videoTimestamp!),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
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
                                          color: AppColors.getTextColor(context,
                                              secondary: true),
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
                                        color: AppColors.getTextColor(context,
                                            secondary: true),
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
                                color: AppColors.getTextColor(context,
                                    secondary: true),
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
                color: AppColors.getElevatedSurfaceColor(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.getBorderColor(context), width: 1.5),
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
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            color: AppColors.getElevatedSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.getBorderColor(context), width: 1.5),
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
                                    color: AppColors.getTextColor(context,
                                        secondary: true)),
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
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.getTextColor(context)),
              ),
              if (question.replies.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                      color: AppColors.getTextColor(context).withOpacity(0.24),
                      height: 1),
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
                  label: Text('رد',
                      style: TextStyle(color: AppColors.getTextColor(context))),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                size: 16,
                                color: AppColors.getTextColor(context,
                                    secondary: true)),
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
                    ? Icon(Icons.person,
                        size: 14, color: AppColors.getTextColor(context))
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
          ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.getTextColor(context).withOpacity(0.70)),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
      final freshData = await DatabaseService().getLessonQuestions(lesson.id);
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
            child: Text('إرسال',
                style: TextStyle(color: AppColors.getTextColor(context))),
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
              onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
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
          ScaffoldMessenger.of(context).showSnackBar(
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
              onPressed: () => Navigator.pop(context), child: Text('إلغاء')),
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
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))));
        }
      }
    }
  }

  Widget _buildNavigationButtons() {
    int currentIndex = widget.allLessons.indexWhere((l) => l.id == lesson.id);
    if (currentIndex == -1) return SizedBox.shrink();

    bool hasPrev = currentIndex > 0;
    bool hasNext = currentIndex < widget.allLessons.length - 1;

    if (!hasPrev && !hasNext) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.getBackgroundColor(context),
        border: Border(
            top: BorderSide(color: AppColors.getBorderColor(context), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (hasPrev)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _goToLesson(widget.allLessons[currentIndex - 1]),
                  icon: Icon(Icons.chevron_right, size: 18),
                  label: Text('الدرس السابق'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.getTextColor(context, secondary: true),
                    side: BorderSide(color: AppColors.getBorderColor(context)),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (hasPrev && hasNext) SizedBox(width: 16),
            if (hasNext)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _goToLesson(widget.allLessons[currentIndex + 1]),
                  icon: Icon(Icons.chevron_left, size: 18),
                  label: Text('الدرس التالي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _goToLesson(Lesson newLesson) {
    _saveProgressBeforeExit();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LessonScreen(
          lesson: newLesson,
          allLessons: widget.allLessons,
          courseTitle: courseTitle,
          isEnrolled: isEnrolled,
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
          tooltip: 'رجوع',
        ),
      ),
    );
  }
}

class LessonSliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  LessonSliverAppBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(LessonSliverAppBarDelegate oldDelegate) {
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom fullscreen page for YouTube on mobile.
// Shown by _handleToggleFullScreen() so our VideoPlayerControls overlay is
// always visible (play/pause, progress bar, fullscreen-exit button).
// ─────────────────────────────────────────────────────────────────────────────
class _YoutubeFullscreenPage extends StatelessWidget {
  final YoutubePlayerController controller;
  final Lesson lesson;
  final String courseTitle;

  const _YoutubeFullscreenPage({
    required this.controller,
    required this.lesson,
    this.courseTitle = '',
  });

  @override
  Widget build(BuildContext context) {
    // Wrap in YoutubePlayerBuilder so internal YoutubePlayer lookups work.
    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: controller,
        showVideoProgressIndicator: false,
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Centre the 16:9 video inside the landscape screen.
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: player,
                ),
              ),
              // Our custom controls overlay.
              VideoPlayerControls(
                isYoutube: true,
                youtubeController: controller,
                lesson: lesson,
                courseTitle: courseTitle,
                // Pressing the fullscreen toggle or the back arrow closes the page.
                onToggleFullScreen: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
