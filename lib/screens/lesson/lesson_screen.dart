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
import '../exams/review_exam_screen.dart';
import '../../core/services/database_service.dart';
import '../notes/add_note_screen.dart';

import '../../widgets/dynamic_gradient_background.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:math' as math; 

import '../../core/services/offline_storage_service.dart';
import '../../widgets/lesson/video_player_controls.dart';

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
  Future<List<Map<String, dynamic>>>? _notesFuture;
  Future<List<Map<String, dynamic>>>? _questionsFuture;
  Future<List<Map<String, dynamic>>>? _examsFuture;
  final ScrollController _mainScrollController = ScrollController();

  // Offline
  bool _isOffline = false;
  final OfflineStorageService _offlineStorage = OfflineStorageService();
  late String _videoUrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _currentHtmlContent = widget.lesson.contentHtml;
    _videoUrl = (widget.lesson.videoUrl as String?) ?? '';
    
    _notesFuture = DatabaseService().getNotes(widget.lesson.id);
    _questionsFuture = DatabaseService().getLessonQuestions(widget.lesson.id);
    _examsFuture = DatabaseService().getExamsForLesson(widget.lesson.id);
    
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
                          'الدرس ${widget.lesson.orderIndex}',
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
                          widget.lesson.title,
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
                            unselectedLabelColor: Colors.white60,
                            labelStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            dividerColor: Colors.transparent,
                            isScrollable: true,
                            tabs: const [
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.description_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('الوصف'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.attach_file, size: 18),
                                    SizedBox(width: 8),
                                    Text('المرفقات'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.science_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('تفاعل'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.quiz_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('اختبارات'),
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.note_alt_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('الملاحظات'),
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
                                    Text('الأسئلة'),
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
          final width = MediaQuery.of(context).size.width;
          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Full-size Iframe
                Container(
                  color: Colors.black,
                  child: Center(
                    child: ConstrainedBox(
                      // Limit max width for larger screens
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: SizedBox(
                        width: width > 1000 ? 1000 : width,
                        height: (width > 1000 ? 1000 : width) * 9 / 16,
                        child: HtmlWidget(
                          '''
                          <div style="width: 100%; height: 100%; background: #000;">
                            <iframe 
                              src="https://www.youtube.com/embed/$videoId?modestbranding=1&rel=0&controls=0&disablekb=1&showinfo=0&iv_load_policy=3&autoplay=1&mute=0" 
                              style="width: 100%; height: 100%; border: 0;" 
                              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                              allowfullscreen>
                            </iframe>
                          </div>
                          ''',
                        ),
                      ),
                    ),
                  ),
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
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInteractiveTab() {
    if (!_hasInteractiveContent()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined,
                size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'لا يوجد تطبيق تفاعلي لهذا الدرس',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
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
                  border: Border.all(
                      color: Colors.white.withOpacity(0.2), width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rocket_launch_outlined,
                        size: 48,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'المحتوى التفاعلي',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'استمتع بتجربة تعليمية تفاعلية غنية تعزز فهمك للموضوع.',
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
                        onPressed: _openInteractiveApp,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('بدء التجربة الآن'),
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
        ),
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
                                  child: Text(
                                    note.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
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

        if (_questionsFuture == null)
          const Center(child: CircularProgressIndicator())
        else
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
                        Text(
                          question.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white),
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
                ...question.replies.map((reply) => _buildReplyItem(reply)),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyItem(LessonQuestionReply reply) {
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
                  },
                ),
              ),
          ],
        ),
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