import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'pdf_viewer_screen.dart';
import 'image_viewer_screen.dart';
import 'interactive_quiz_screen.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';
import '../../models/note.dart';
import '../../models/exam.dart';
import '../../models/lesson_question.dart';
import '../exams/exam_taking_screen.dart';
import '../exams/review_exam_screen.dart';
import '../../core/services/database_service.dart';
import '../notes/add_note_screen.dart';
import '../../core/services/course_download_service.dart';
import '../../models/download.dart' as dl;
import '../../widgets/dynamic_gradient_background.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math; 

import '../../core/services/supabase_service.dart';
import '../../core/services/offline_storage_service.dart';
import '../../widgets/lesson/video_player_controls.dart';
import 'package:provider/provider.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  final List<Lesson> allLessons;
  final String courseTitle;
  final bool isEnrolled;

  const LessonScreen({
    super.key,
    required this.lesson,
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

  // Offline
  bool _isOffline = false;
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  late String _videoUrl;
  Map<String, String>? _downloadedResources;
  final Set<String> _downloadingFiles = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _currentHtmlContent = widget.lesson.contentHtml;
    _videoUrl = (widget.lesson.videoUrl as String?) ?? '';
    
    _notesFuture = DatabaseService().getNotes(widget.lesson.id);
    _examsFuture = DatabaseService().getExamsForLesson(widget.lesson.id);
    
    _initLesson();
  }

  Future<void> _initLesson() async {
    await _checkOfflineLesson();
    await _checkDownloadedResources();
    _initVideoPlayer();
    _refreshFutures();
    _startWatchTimeTracking();
  }

  Future<void> _checkDownloadedResources() async {
    final offlineLesson = await _offlineStorage.getLesson(widget.lesson.id);
    if (mounted) {
      setState(() {
        _downloadedResources = offlineLesson?.downloadedResources;
      });
    }
  }

  Future<void> _downloadResource(Map<String, String> resource) async {
    final url = resource['url'] ?? '';
    final fileName = resource['name'] ?? 'file';
    if (url.isEmpty) return;

    if (mounted) {
      setState(() {
        _downloadingFiles.add(fileName);
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_t('starting_download')} $fileName...')),
    );

    try {
      await CourseDownloadService().downloadResource(
        url: url,
        courseId: widget.lesson.courseId,
        lessonId: widget.lesson.id,
        fileName: fileName,
      );
      await _checkDownloadedResources();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${_t('download_success_encrypted')} $fileName')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_t('download_error')}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingFiles.remove(fileName);
        });
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
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  Future<void> _checkOfflineLesson() async {
    try {
      // 1. Check OfflineStorageService (Old system)
      final offlineLesson = await _offlineStorage.getLesson(widget.lesson.id);
      if (offlineLesson != null && offlineLesson.isDownloaded) {
        if (mounted) {
          setState(() {
            _isOffline = true;
            if (offlineLesson.videoPath != null && File(offlineLesson.videoPath!).existsSync()) {
              _videoUrl = offlineLesson.videoPath!;
            }
          });
        }
        return;
      }

      // 2. Check DownloadManager (New system)
      final downloadManager = dl.DownloadManager();
      if (downloadManager.isDownloaded(widget.lesson.id)) {
        final playableUrl =
            await downloadManager.getPlayableUrl(widget.lesson.id);
        if (playableUrl != null) {
          if (mounted) {
            setState(() {
              _isOffline = true;
              _videoUrl = playableUrl;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking offline lesson: $e');
    }
  }

  void _refreshFutures() {
    if (mounted) {
      setState(() {
        _notesFuture = DatabaseService().getNotes(widget.lesson.id);
        DatabaseService().getLessonQuestions(widget.lesson.id).then((data) {
          if (mounted) {
            setState(() {
              _questionsList =
                  data.map((q) => LessonQuestion.fromJson(q)).toList();
            });
          }
        });
        _examsFuture = DatabaseService().getExamsForLesson(widget.lesson.id);
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
            SnackBar(content: Text('حدث خطأ أثناء حذف الملاحظة: $e')),
          );
        }
      }
    }
  }

  Future<void> _editNote(Note note) async {
    final controller = TextEditingController(text: note.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('edit_note'), textAlign: TextAlign.right),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: _t('your_comment_here'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child:
                Text(_t('save'), style: const TextStyle(color: Colors.white)),
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
            const SnackBar(content: Text('تم تحديث الملاحظة بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في التحديث: $e')),
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
              title: 'الاختبار التفاعلي: ${widget.lesson.title}',
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
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _initVideoPlayer() {
    final url = _videoUrl;
    if (url.isEmpty) return;

    // Handle local/offline file
    if (_isOffline) {
      _isYoutube = false;
      
      // If it's a localhost URL from LocalServerService, or a local file path
      if (_videoUrl.startsWith('http')) {
        _videoPlayerController =
            VideoPlayerController.networkUrl(Uri.parse(_videoUrl));
      } else {
        _videoPlayerController = VideoPlayerController.file(File(_videoUrl));
      }

      _videoPlayerController!.initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: false,
            looping: false,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            errorBuilder: (context, errorMessage) {
              return Center(
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.white)));
            },
          );
        });
      });
      return;
    }

    // Handle Online/YouTube
    if (url.contains('youtu.be') || url.contains('youtube.com')) {
      _isYoutube = true;
      if (kIsWeb) {
        return; // Skip YouTube controller init on Web to avoid InAppWebView crash
      }

      final videoId = YoutubePlayer.convertUrlToId(url);
      if (videoId != null) {
        _youtubePlayerController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
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
    } else {
      _isYoutube = false;
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoPlayerController!.initialize().then((_) {
        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoPlayerController!,
            autoPlay: false,
            looping: false,
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            errorBuilder: (context, errorMessage) {
              return Center(
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.white)));
            },
          );
        });
      });
    }
  }

  // Removed _initWebView and _wrapHtmlContent in favor of separate screen


  @override
  void dispose() {
    _watchTimeTimer?.cancel();
    // _saveProgressBeforeExit(); // Removed async call from dispose
    _tabController.dispose();
    _mainScrollController.dispose();
    _questionController.dispose();

    // Proper video disposal
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _youtubePlayerController?.dispose();
    
    super.dispose();
  }


  void _startWatchTimeTracking() {
    if (((widget.lesson.videoUrl as String?) ?? '').isEmpty) return;

    _watchTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      await DatabaseService().updateLessonProgress(
        lessonId: widget.lesson.id,
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
    if (_isYoutube && _youtubePlayerController != null && !kIsWeb) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubePlayerController!,
          showVideoProgressIndicator: false,
        ),
        builder: (context, player) {
          return _buildScaffold(
            context,
            videoPlayer: _buildVideoWithOverlay(
              player: player,
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
      ),
    );
  }

  Widget _buildVideoWithOverlay({required Widget player}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        VideoPlayerControls(
          isYoutube: _isYoutube,
          youtubeController: _youtubePlayerController,
          videoController: _videoPlayerController,
          lesson: widget.lesson,
          courseTitle: widget.courseTitle,
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
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: videoPlayer,
                  ),
                ),
              ),

              // 1.5 Education Header (The "Professional" Bar) - Minimalist approach
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.primaryPurple.withOpacity(0.2)),
                        ),
                        child: Text(
                          '${_t('lesson_prefix')} ${widget.lesson.orderIndex}',
                          style: const TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.lesson.getLocalizedTitle(
                              Provider.of<LocaleProvider>(context).locale),
                          style: const TextStyle(
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



              // 3. التبويبات المثبتة
              SliverPersistentHeader(
                pinned: true,
                delegate: LessonSliverAppBarDelegate(
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.getSurfaceColor(context)
                              .withOpacity(0.8), // Darker background
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.1))),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.05), // Subtle inner container
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
                            labelStyle: const TextStyle(
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
                                    const Icon(Icons.description_outlined,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Text(_t('description_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file, size: 18),
                                    const SizedBox(width: 8),
                                    Text(_t('attachments_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.science_outlined,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Text(_t('interactive_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.quiz_outlined, size: 18),
                                    const SizedBox(width: 8),
                                    Text(_t('exams_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.note_alt_outlined,
                                        size: 18),
                                    const SizedBox(width: 8),
                                    Text(_t('notes_tab')),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.question_answer_outlined,
                                        size: 18),
                                    const SizedBox(width: 8),
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_t('ai_assistant_coming_soon'),
                    textAlign: TextAlign.right),
                backgroundColor: AppColors.primaryPurple,
              ),
            );
          },
          backgroundColor: AppColors.primaryPurple,
          child: const Icon(Icons.auto_awesome, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTabContent(Widget child) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 24),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    if (((widget.lesson.videoUrl as String?) ?? '').isEmpty) {
      return Container(
        width: double.infinity,
        height: 250,
        color: Colors.black,
        child: Center(
          child: Text(_t('no_video_available'),
              style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    if (_isYoutube) {
      if (kIsWeb) {
        final videoId = YoutubePlayer.convertUrlToId(
            (widget.lesson.videoUrl as String?) ?? '');
        if (videoId != null) {
          return Container(
            width: double.infinity,
            // تأكد من تحديد ارتفاع ثابت هنا لمنع خطأ الـ Layout
            height:
                (MediaQuery.of(context).size.width * 9 / 16).clamp(200, 500),
            color: Colors.black,
            child: HtmlWidget(
              '''
              <iframe 
                width="100%" 
                height="100%" 
                src="https://www.youtube.com/embed/$videoId?autoplay=1&rel=0" 
                frameborder="0" 
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                allowfullscreen>
              </iframe>
              ''',
              factoryBuilder: () => WidgetFactory(),
            ),
          );
        }
      }

      // In YoutubePlayerBuilder, we shouldn't build it again here if used in builder
      // But for the non-youtube path (_isYoutube = false), this is skipped anyway.
      // If we reach here and _isYoutube is true, it means _youtubePlayerController is null
      return Container(
          height: 250,
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()));
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
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
  }

  Widget _buildDescriptionTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HtmlWidget(
          widget.lesson.description,
          textStyle:
              const TextStyle(fontSize: 16, height: 1.8, color: Colors.white),
        ),

        if (widget.lesson.content != null &&
            widget.lesson.content != widget.lesson.description) ...[
          const SizedBox(height: 24),
          HtmlWidget(
            widget.lesson.content!,
            textStyle:
                const TextStyle(fontSize: 16, height: 1.8, color: Colors.white),
          ),
        ],
      ],
    );
  }

  Widget _buildResourcesTab() {
    if (widget.lesson.resources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
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
        ...widget.lesson.resources.map((resource) {
          final fileName = resource['name'] ?? 'ملف غير معروف';
          final url = resource['url'] ?? '';
          final localPath = _downloadedResources?[fileName];
          final isDownloaded = localPath != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildTelegramStyleButton(
                          resource, fileName, url, localPath, isDownloaded),
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

  Widget _buildTelegramStyleButton(Map<String, String> resource,
      String fileName, String url, String? localPath, bool isDownloaded) {
    final isDownloading = _downloadingFiles.contains(fileName);

    if (isDownloading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (!isDownloaded) {
          _downloadResource(resource);
        } else {
          final ext = fileName.split('.').last.toLowerCase();
          if (ext == 'pdf') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(
                  url: null,
                  localPath: localPath,
                  title: fileName,
                  isOffline: true,
                ),
              ),
            );
          } else if (['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerScreen(
                  url: null,
                  localPath: localPath,
                  title: fileName,
                  isOffline: true,
                ),
              ),
            );
          } else {
            // For other types, fallback to browser for now as we don't have internal decryption-viewers
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isDownloaded ? AppColors.primaryGradient : null,
          color: isDownloaded ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: isDownloaded ? null : Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDownloaded
                  ? Icons.remove_red_eye_outlined
                  : Icons.download_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isDownloaded ? 'عرض' : 'تحميل',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
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
          const SizedBox(height: 20),
        ],

        // AI Flashcards Section (Placeholder)
        _buildInteractiveCard(
          title: _t('flashcards_tab'),
          description: _t('ai_assistant_coming_soon'),
          icon: Icons.style_outlined,
          buttonLabel: _t('discussions_coming_soon'),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_t('ai_assistant_coming_soon'),
                    textAlign: TextAlign.right),
                backgroundColor: AppColors.primaryPurple,
              ),
            );
          },
          isAIGenerated: true,
        ),

        if (!_hasInteractiveContent())
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_outlined,
                    size: 64, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'لا يوجد محتوى تفاعلي حالياً',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
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
                      padding: const EdgeInsets.all(16),
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
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome,
                              size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    height: 1.6,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onTap,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(buttonLabel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
    if (_examsFuture == null) return const SizedBox.shrink();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _examsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final examsData = snapshot.data ?? [];
        if (examsData.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...examsData.map((examData) {
              final exam = Exam.fromJson(examData);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
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
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exam.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (exam.description.isNotEmpty)
                                      Text(
                                        exam.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.greenAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),

                          if (exam.attempts.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'سجل المحاولات:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: exam.attempts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: isPassed
                                                ? Colors.green.withOpacity(0.3)
                                                : Colors.red.withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
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
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'محاولة ${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                if (dateStr.isNotEmpty)
                                                  Text(
                                                    dateStr,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white
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
                                          const SizedBox(width: 8),
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

                          const SizedBox(height: 20),
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
                                    padding: const EdgeInsets.symmetric(
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
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              if (exam.attempts.isNotEmpty) ...[
                                const SizedBox(width: 12),
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
                        lessonId: widget.lesson.id,
                        courseId: widget.lesson.courseId,
                      ),
                    ),
                  );
                  if (result == true) {
                    _refreshFutures();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('ملاحظة عادية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.2))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final timestamp = _getCurrentVideoPosition();
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddNoteScreen(
                        lessonId: widget.lesson.id,
                        courseId: widget.lesson.courseId,
                        videoTimestamp: timestamp,
                      ),
                    ),
                  );
                  if (result == true) {
                    _refreshFutures();
                  }
                },
                icon: const Icon(Icons.timer_outlined),
                label: const Text('ملاحظة ذكية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        if (_notesFuture == null)
          const Center(child: CircularProgressIndicator())
        else
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _notesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
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
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.note_outlined,
                                size: 60, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد ملاحظات بعد',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.7)),
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
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notesData.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final note = Note.fromJson(notesData[index]);
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1.5),
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
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (note.videoTimestamp != null) ...[
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () =>
                                                  _seekTo(note.videoTimestamp!),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
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
                                                    const Icon(Icons.play_arrow,
                                                        size: 14,
                                                        color: AppColors
                                                            .primaryPurple),
                                                    Text(
                                                      note.formattedTimestamp,
                                                      style: const TextStyle(
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
                                          color: Colors.white.withOpacity(0.5),
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
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      iconSize: 20,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _deleteNote(note.id),
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red.withOpacity(0.7),
                                      ),
                                      iconSize: 20,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              note.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _sendQuestion,
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      textAlign: TextAlign.right,
                      onSubmitted: (_) => _sendQuestion(),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'اسأل سؤالاً عن هذا الدرس...',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (_questionsList == null)
          const Center(child: CircularProgressIndicator())
        else if (_questionsList!.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('لا توجد أسئلة بعد. كن أول من يسأل!'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _questionsList!.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
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
                                    color: Colors.white.withOpacity(0.7)),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(left: 8),
                              ),
                              IconButton(
                                onPressed: () => _deleteQuestion(question.id),
                                icon: Icon(Icons.delete_outline_rounded,
                                    size: 18,
                                    color: Colors.red.withOpacity(0.7)),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(left: 8),
                              ),
                            ],
                            Text(
                              question.userName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                        Text(
                          _formatDate(question.createdAt),
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    backgroundImage: question.userPhoto != null
                        ? NetworkImage(question.userPhoto!)
                        : null,
                    child: question.userPhoto == null
                        ? const Icon(Icons.person,
                            size: 20, color: Colors.white)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                question.content,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 14, height: 1.5, color: Colors.white),
              ),
              if (question.replies.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                ...question.replies
                    .map((reply) => _buildReplyItem(reply, question)),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showReplyDialog(question),
                  icon: const Icon(Icons.reply_rounded,
                      size: 18, color: Colors.white),
                  label:
                      const Text('رد', style: TextStyle(color: Colors.white)),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(height: 8),
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
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
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
                                size: 16, color: Colors.white.withOpacity(0.7)),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(left: 8),
                          ),
                          IconButton(
                            onPressed: () => _deleteReply(reply.id),
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 16, color: Colors.red.withOpacity(0.7)),
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.only(left: 8),
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
                          fontSize: 10, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white.withOpacity(0.1),
                backgroundImage: reply.userPhoto != null
                    ? NetworkImage(reply.userPhoto!)
                    : null,
                child: reply.userPhoto == null
                    ? const Icon(Icons.person, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            reply.content,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          _buildReactionsRow(
            replyId: reply.id,
            reactionCounts: reply.reactionCounts,
            myReaction: reply.myReaction,
            isSmall: true,
          ),
          const SizedBox(height: 4),
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
                  color: Colors.white.withOpacity(0.6),
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
              .showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
              .showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
                  child: const Text('إلغاء')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('حذف'),
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  const SizedBox(width: 6),
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                ...reactionCounts.entries
                    .where((e) => e.value > 0)
                    .take(3)
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Text(reactions[e.key]!,
                              style: const TextStyle(fontSize: 10)),
                        )),
                const SizedBox(width: 4),
                Text(
                  totalCount.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
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
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                padding: const EdgeInsets.all(10),
                child: Text(e.value, style: const TextStyle(fontSize: 30)),
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
          await DatabaseService().getLessonQuestions(widget.lesson.id);
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
          SnackBar(content: Text('حدث خطأ أثناء التفاعل. $e')),
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
    final replyController = TextEditingController(text: initialText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة رد', textAlign: TextAlign.right),
        content: TextField(
          controller: replyController,
          textAlign: TextAlign.right,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب ردك هنا...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) return;
              final content = replyController.text.trim();
              Navigator.pop(context);

              final messenger = ScaffoldMessenger.of(context);
              try {
                await DatabaseService().addReply(question.id, content);
                _refreshFutures();
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('خطأ: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child: const Text('إرسال', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendQuestion() async {
    if (_questionController.text.trim().isEmpty) return;

    final content = _questionController.text.trim();
    _questionController.clear();

    try {
      await DatabaseService().askLessonQuestion(widget.lesson.id, content);
      _refreshFutures(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال سؤالك بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إرسال السؤال: $e')),
        );
      }
    }
  }

  Widget _buildNavigationButtons() {
    final currentIndex = widget.allLessons.indexWhere((l) => l.id == widget.lesson.id);
    final hasNext = currentIndex != -1 && currentIndex < widget.allLessons.length - 1;
    final hasPrev = currentIndex > 0;
    
    return Container(
      padding: const EdgeInsets.all(20),
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
            if (hasPrev && hasNext) const SizedBox(width: 15),
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

                    // CHECK FOR EXAMS GATING
                    final examsResult =
                        await _db.getExamsForLesson(widget.lesson.id);

                    if (examsResult.isNotEmpty) {
                      final examData = examsResult.first;
                      final attempts = examData['attempts'] as List?;
                      final bool hasPassed = attempts != null &&
                          attempts.any((a) => a['is_passed'] == true);

                      if (hasPassed) {
                        _goToNextLesson(nextLesson);
                      } else {
                        // User hasn't passed the exam yet
                        if (mounted) {
                          _showExamRequirementDialog(examData, nextLesson);
                        }
                      }
                    } else {
                      // No exam for this lesson - show info and move on
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_t('no_exam_at_all'),
                                textAlign: TextAlign.right),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        _goToNextLesson(nextLesson);
                      }
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

  void _showExamRequirementDialog(
      Map<String, dynamic> examData, Lesson nextLesson) {
    final exam = Exam.fromJson(examData);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          _t('must_take_exam'),
          textAlign: TextAlign.right,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'يجب إكمال واجتياز اختبار "${exam.title}" للانتقال للدرس التالي.',
          textAlign: TextAlign.right,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('cancel'),
                style: const TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExamTakingScreen(
                    exam: exam,
                    onCompleted: () {
                      // When exam is finished, go back to this lesson screen
                      // or directly to the next one if they passed?
                      // The current ExamResultScreen returns to lesson.
                      // If they pass, they can click 'Next' again.
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_t('start_exam')),
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
                if (!isPrimary) Icon(icon, color: Colors.white, size: 16),
                if (!isPrimary) const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                if (isPrimary) const SizedBox(width: 8),
                if (isPrimary) Icon(icon, color: Colors.white, size: 16),
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
        title: const Text('تعديل السؤال', textAlign: TextAlign.right),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child: const Text('حفظ التعديل',
                style: TextStyle(color: Colors.white)),
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
              .showSnackBar(SnackBar(content: Text('خطأ في التعديل: $e')));
        }
      }
    }
  }

  Future<void> _editReply(LessonQuestionReply reply) async {
    final controller = TextEditingController(text: reply.content);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الرد', textAlign: TextAlign.right),
        content: TextField(
          controller: controller,
          textAlign: TextAlign.right,
          maxLines: 4,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple),
            child: const Text('حفظ التعديل',
                style: TextStyle(color: Colors.white)),
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
              .showSnackBar(SnackBar(content: Text('خطأ في التعديل: $e')));
        }
      }
    }
  }
}

class LessonSliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  const LessonSliverAppBarDelegate({required this.child});

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