import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'pdf_viewer_screen.dart';
import 'interactive_quiz_screen.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';
import '../../models/note.dart';
import '../../models/exam.dart';
import '../../models/lesson_question.dart';
import '../exams/exam_taking_screen.dart';
import '../../core/services/database_service.dart';
import '../notes/add_note_screen.dart';

import '../../widgets/dynamic_gradient_background.dart';
import 'dart:ui';
import 'dart:io'; 

import '../../core/services/offline_storage_service.dart';

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  final List<Lesson> allLessons;
  final String courseTitle;

  const LessonScreen({
    super.key,
    required this.lesson,
    this.allLessons = const [],
    this.courseTitle = '',
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final TextEditingController _questionController = TextEditingController();

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
  late Future<List<Map<String, dynamic>>> _notesFuture;
  late Future<List<Map<String, dynamic>>> _questionsFuture;
  late Future<List<Map<String, dynamic>>> _examsFuture;
  final ScrollController _mainScrollController = ScrollController();

  // Offline
  bool _isOffline = false;
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  late String _videoUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentHtmlContent = widget.lesson.contentHtml;
    _videoUrl = (widget.lesson.videoUrl as String?) ?? '';
    
    _initLesson();
  }

  Future<void> _initLesson() async {
    await _checkOfflineLesson();
    _initVideoPlayer();
    _refreshFutures();
    _startWatchTimeTracking();
  }

  Future<void> _checkOfflineLesson() async {
    try {
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
      }
    } catch (e) {
      debugPrint('Error checking offline lesson: $e');
    }
  }

  void _refreshFutures() {
    if (mounted) {
      setState(() {
        _notesFuture = DatabaseService().getNotes(widget.lesson.id);
        _questionsFuture =
            DatabaseService().getLessonQuestions(widget.lesson.id);
        _examsFuture = DatabaseService().getExamsForLesson(widget.lesson.id);
      });
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
            content: const Text(
              'لا يوجد محتوى تفاعلي مخصص لهذا الدرس',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo'),
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

    // Handle offline file
    if (_isOffline && !url.startsWith('http')) {
      _isYoutube = false;
      _videoPlayerController = VideoPlayerController.file(File(url));
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

  int? _getCurrentVideoPosition() {
    if (_isYoutube) {
      return _youtubePlayerController?.value.position.inSeconds;
    } else {
      return _videoPlayerController!.value.position.inSeconds;
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
    final position = _getCurrentVideoPosition() ?? 0;
    final duration = _getVideoDuration() ?? 1;
    if (duration <= 0) return false;
    // Mark as completed if watched > 80% of video
    return (position / (duration > 0 ? duration : 1)) > 0.8;
  }

  void _seekRelative(int seconds) {
    if (_isYoutube) {
      final currentPos =
          _youtubePlayerController?.value.position.inSeconds ?? 0;
      final duration = _getVideoDuration() ?? 0;
      _youtubePlayerController?.seekTo(
          Duration(seconds: (currentPos + seconds).clamp(0, duration)));
    } else {
      final currentPos = _videoPlayerController?.value.position.inSeconds ?? 0;
      final duration = _getVideoDuration() ?? 0;
      _videoPlayerController?.seekTo(
          Duration(seconds: (currentPos + seconds).clamp(0, duration)));
    }
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return "--:--";
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "$minutes:${remainingSeconds.toString().padLeft(2, '0')}";
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
              player: Positioned.fill(child: player),
              additionalOverlays: [
                // Custom Controls Overlay (Privacy Shield)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (_youtubePlayerController!.value.isPlaying) {
                        _youtubePlayerController!.pause();
                      } else {
                        _youtubePlayerController!.play();
                      }
                      setState(() {});
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _youtubePlayerController!.value.isPlaying
                              ? 0.0
                              : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Colors.black26,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _youtubePlayerController!.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Progress Bar at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<YoutubePlayerValue>(
                    valueListenable: _youtubePlayerController!,
                    builder: (context, value, child) {
                      final duration = value.metaData.duration.inSeconds;
                      return LinearProgressIndicator(
                        value: duration > 0
                            ? value.position.inSeconds / duration
                            : 0,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primaryPurple),
                        minHeight: 4,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget playerWidget = _buildVideoPlayer();
    return _buildScaffold(context,
        videoPlayer: _buildVideoWithOverlay(
            player: Positioned.fill(child: playerWidget)));
  }

  Widget _buildVideoWithOverlay(
      {required Widget player, List<Widget> additionalOverlays = const []}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        ...additionalOverlays,
        // Educational Header Overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 50, vertical: 12), // Added padding to avoid icons
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.lesson.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  '⏱ ${_formatDuration(_getVideoDuration())}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
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
                      .clamp(250.0, MediaQuery.of(context).size.height * 0.5),
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
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.science_outlined,
                          color: Colors.white),
                      tooltip: 'تطبيق تفاعلي',
                      onPressed: _openInteractiveApp,
                    ),
                  ],
                ),
              ),

              // 1.5 Education Header (The "Professional" Bar) - Visible when scrolled
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryPurple.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.book_outlined,
                            color: AppColors.primaryPurple, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الدرس ${widget.lesson.orderIndex}: ${widget.lesson.title}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(_getVideoDuration()),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  _isLessonCompleted()
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 12,
                                  color: _isLessonCompleted()
                                      ? Colors.green
                                      : AppColors.textLight,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isLessonCompleted()
                                      ? 'تم الإكمال'
                                      : 'قيد التقدم',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _isLessonCompleted()
                                        ? Colors.green
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Educational Action Buttons
              SliverToBoxAdapter(child: _buildEducationalActionButtons()),

              // 3. التبويبات المثبتة
              SliverPersistentHeader(
                pinned: true,
                delegate: LessonSliverAppBarDelegate(
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(text: 'الوصف'),
                          Tab(text: 'الملاحظات'),
                          Tab(text: 'الأسئلة'),
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
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 10),
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
        child: const Center(
          child: Text('لا يوجد فيديو لهذا الدرس', style: TextStyle(color: Colors.white)),
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
            height: double.infinity,
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-size Iframe
                HtmlWidget(
                  '''
                  <div style="width: 100%; height: 100%; position: relative; background: #000; overflow: hidden;">
                    <iframe 
                      src="https://www.youtube.com/embed/$videoId?modestbranding=1&rel=0&controls=0&disablekb=1&showinfo=0&iv_load_policy=3&autoplay=1&mute=0" 
                      style="position: absolute; top: -50px; left: 0; width: 100%; height: calc(100% + 100px); border: 0;" 
                      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                      allowfullscreen>
                    </iframe>
                    <!-- Advanced Privacy Masks -->
                    <div style="position: absolute; top: 0; left: 0; width: 100%; height: 80px; background: transparent; z-index: 100; cursor: default;"></div>
                    <div style="position: absolute; bottom: 0; right: 0; width: 150px; height: 80px; background: transparent; z-index: 100; cursor: default;"></div>
                    <div style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; z-index: 200; pointer-events: none;"></div>
                  </div>
                  ''',
                ),
                // 2. Custom Control Overlay (Optional - to block all clicks)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // Note: We can't easily control the iframe via standard web-view bridging without API
                      // But the iframe params controls=0 will handle basic non-interaction.
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // 3. Title Shield (UI Label)
                Positioned(
                  top: 10,
                  right: 16,
                  child: Text(
                    widget.lesson.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                ),
              ],
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
        const SizedBox(height: 10),

        // Section: The Core Idea
        _buildContentSection(
          title: 'الفكرة الأساسية',
          icon: Icons.lightbulb_outline,
          color: Colors.amber.shade700,
          child: HtmlWidget(
            widget.lesson.description,
            textStyle: const TextStyle(
                fontSize: 16, height: 1.8, color: AppColors.textPrimary),
          ),
        ),

        const SizedBox(height: 16),

        // Section: Interactive Content (If exists)
        if (_hasInteractiveContent())
          _buildContentSection(
            title: 'المحتوى التفاعلي',
            icon: Icons.play_lesson_outlined,
            color: AppColors.primaryPurple,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openInteractiveApp,
                icon: const Icon(Icons.stars),
                label: const Text('بدء التجربة التفاعلية'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

        // Section: Detailed Content (If exists and different from description)
        if (widget.lesson.content != null &&
            widget.lesson.content != widget.lesson.description)
          _buildContentSection(
            title: 'شرح مفصل',
            icon: Icons.subject,
            color: Colors.blue.shade700,
            child: HtmlWidget(
              widget.lesson.content!,
              textStyle: const TextStyle(
                  fontSize: 16, height: 1.8, color: AppColors.textPrimary),
            ),
          ),

        const SizedBox(height: 16),
        
        // Dynamic Resources Section
        if (widget.lesson.resources.isNotEmpty) ...[
          const Text(
            'المرفقات والموارد',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...widget.lesson.resources.map((resource) {
            final fileName = resource['name'] ?? 'ملف غير معروف';
            final url = resource['url'] ?? '';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
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
                      } else {
                        // Logic to open/download URL
                        debugPrint('Downloading resource: $url');
                        launchUrl(Uri.parse(url),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        fileName.toLowerCase().endsWith('.pdf')
                            ? 'عرض'
                            : 'تنزيل',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 20),
        _buildExamSection(context),
      ],
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
            const Text(
              'الاختبارات المرتبطة بالدرس',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...examsData.map((examData) {
              final exam = Exam.fromJson(examData);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFF5722).withOpacity(0.1),
                      const Color(0xFFFF9800).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFFF5722).withOpacity(0.3),
                      width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.quiz,
                              color: Color(0xFFFF5722), size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exam.title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                exam.description,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          ExamTakingScreen(exam: exam)));
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'ابدأ الاختبار',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_back,
                                      color: Colors.white, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
            label: const Text('إضافة ملاحظة جديدة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        
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
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.note_outlined, size: 60, color: AppColors.textLight),
                    SizedBox(height: 16),
                    Text(
                      'لا توجد ملاحظات بعد',
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                  ],
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
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              note.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(note.updatedAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
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
        const Text(
          'أسئلة الطلاب',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        
        // Question Input
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _sendQuestion,
                icon: const Icon(Icons.send_rounded, color: AppColors.primaryPurple),
              ),
              Expanded(
                child: TextField(
                  controller: _questionController,
                  textAlign: TextAlign.right,
                  onSubmitted: (_) => _sendQuestion(),
                  decoration: const InputDecoration(
                    hintText: 'اسأل سؤالاً عن هذا الدرس...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        FutureBuilder<List<Map<String, dynamic>>>(
          future: _questionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }

            final questionsData = snapshot.data ?? [];
            if (questionsData.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('لا توجد أسئلة بعد. كن أول من يسأل!'),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: questionsData.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final question = LessonQuestion.fromJson(questionsData[index]);
                return _buildQuestionItem(question);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuestionItem(LessonQuestion question) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
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
                    Text(
                      question.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _formatDate(question.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                backgroundImage: question.userPhoto != null ? NetworkImage(question.userPhoto!) : null,
                child: question.userPhoto == null 
                    ? const Icon(Icons.person, size: 20, color: AppColors.primaryPurple)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.content,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          if (question.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...question.replies.map((reply) => Container(
                  margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                    color: reply.isInstructorReply
                        ? AppColors.primaryPurple.withOpacity(0.05)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: reply.isInstructorReply
                          ? AppColors.primaryPurple.withOpacity(0.1)
                          : Colors.grey[200]!,
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
                                Text(
                                  reply.userName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: reply.isInstructorReply
                                        ? AppColors.primaryPurple
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  _formatDate(reply.createdAt),
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: reply.userPhoto != null
                                ? NetworkImage(reply.userPhoto!)
                                : null,
                            child: reply.userPhoto == null
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reply.content,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 12),
          // Reply Button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showReplyDialog(question),
              icon: const Icon(Icons.reply, size: 16),
              label: const Text('رد', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                padding: EdgeInsets.zero,
                minimumSize: const Size(50, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReplyDialog(LessonQuestion question) {
    final replyController = TextEditingController();
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
    
    // Calculate progress (just for display)
    final totalLessons = widget.allLessons.length;
    final displayIndex = currentIndex == -1 ? 1 : currentIndex + 1;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: hasPrev ? 1.0 : 0.5,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: hasPrev ? AppColors.primaryGradient : null,
                      color: hasPrev ? null : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: hasPrev 
                          ? () async {
                              // Save progress before navigating
                              await _saveProgressBeforeExit();
                              
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LessonScreen(
                                      lesson: widget.allLessons[currentIndex - 1],
                                      allLessons: widget.allLessons,
                                      courseTitle: widget.courseTitle,
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'الدرس السابق',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerRight,
                      widthFactor: totalLessons > 0 ? displayIndex / totalLessons : 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$displayIndex من $totalLessons دروس',
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: hasNext ? 1.0 : 0.5,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: hasNext ? AppColors.primaryGradient : null,
                      color: hasNext ? null : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: hasNext
                          ? () async {
                              // Save progress before navigating
                              await _saveProgressBeforeExit();
                              
                              if (mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LessonScreen(
                                      lesson: widget.allLessons[currentIndex + 1],
                                      allLessons: widget.allLessons,
                                      courseTitle: widget.courseTitle,
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'الدرس التالي',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          ],
                        ),
                      ),
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

  Widget _buildEducationalActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildActionItem(
            icon: Icons.replay_30,
            label: 'إعادة 30ث',
            onTap: () => _seekRelative(-30),
          ),
          _buildActionItem(
            icon: Icons.quiz_outlined,
            label: 'اختبار سريع',
            onTap: () {
              // Scroll to exams or open interactive if available
              if (_hasInteractiveContent()) {
                _openInteractiveApp();
              } else {
                _tabController
                    .animateTo(0); // Switch to content where exams usually are
              }
            },
          ),
          _buildActionItem(
            icon: Icons.file_download_outlined,
            label: 'تحميل ملخص',
            onTap: () {
              // Highlight resources
              _tabController.animateTo(0);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('تفقد المرفقات في الأسفل'),
                    duration: Duration(seconds: 1)),
              );
            },
          ),
          _buildActionItem(
            icon: Icons.question_answer_outlined,
            label: 'اسأل المعلم',
            onTap: () {
              _tabController.animateTo(2); // Switch to Questions tab
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.primaryPurple, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
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