import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';
import '../../models/interactive_element.dart';
import '../../core/services/database_service.dart';
import '../../widgets/lesson/rich_content_viewer.dart';
import '../../widgets/lesson/flashcard_widget.dart';
import '../lesson/pdf_viewer_screen.dart';
import '../lesson/interactive_quiz_screen.dart';
import '../../models/download.dart'; // Add import
import 'lesson_exam_screen.dart';

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/error_utils.dart';

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
      final downloadManager = DownloadManager();
      if (downloadManager.isDownloaded(widget.lesson.id)) {
        // Load Local Video
        final url = await downloadManager.getPlayableUrl(widget.lesson.id);
        if (url != null) {
          debugPrint('Playing local video from: $url');
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
            systemOverlaysOnEnterFullScreen: [],
            systemOverlaysAfterFullScreen: SystemUiOverlay.values,
          );

          _videoController!.addListener(() {
            _updateProgress(); // You might need to adapt this method for VideoPlayerController
          });

          if (mounted) {
            setState(() {
              _isLocalVideo = true;
              _hasValidVideo = true;
            });
          }
          return;
        }
      }

      // Fallback to YouTube
      final videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl);
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
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
            controlsVisibleAtStart: true,
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
        if (mounted) setState(() => _hasValidVideo = false);
      }
    } catch (e) {
      debugPrint('Error initializing player: $e');
      if (mounted) setState(() => _hasValidVideo = false);
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
      if (_youtubeController == null || !_youtubeController!.value.isPlaying) {
        return;
      }

      final position = _youtubeController!.value.position.inSeconds;
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
          const SnackBar(content: Text('تم تعليم الدرس كمكتمل')),
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
      final position = _youtubeController?.value.position.inSeconds ?? 0;
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
          const SnackBar(content: Text('تمت إضافة الملاحظة')),
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

  Future<void> _showQualitySelectionDialog() async {
    final isYoutube = widget.lesson.videoUrl.contains('youtube.com') ||
        widget.lesson.videoUrl.contains('youtu.be');

    if (!isYoutube) {
      // Direct download for non-YouTube videos
      _startDownload();
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري تحميل خيارات الجودة...'),
          ],
        ),
      ),
    );

    try {
      final yt = YoutubeExplode();
      final videoId = VideoId(widget.lesson.videoUrl);
      
      // Add timeout to prevent infinite loading
      final manifest =
          await yt.videos.streamsClient.getManifest(videoId).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('انتهت مهلة الاتصال. يرجى المحاولة لاحقاً');
        },
      );
      yt.close();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      final muxedStreams = manifest.muxed.toList()
        ..sort((a, b) =>
            b.bitrate.compareTo(a.bitrate)); // Sort by bitrate descending

      if (muxedStreams.isEmpty) {
        throw Exception('لا توجد خيارات جودة متاحة لهذا الفيديو');
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر جودة الفيديو'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: muxedStreams.length,
              itemBuilder: (context, index) {
                final stream = muxedStreams[index];
                final sizeMB =
                    (stream.size.totalBytes / 1024 / 1024).toStringAsFixed(1);
                return ListTile(
                  title: Text(
                      '${stream.videoQualityLabel} (${stream.videoResolution})'),
                  subtitle: Text(
                      'الحجم: $sizeMB MB • ${stream.container.name.toUpperCase()}'),
                  onTap: () {
                    Navigator.pop(context);
                    _startDownloadWithQuality(stream);
                  },
                  trailing: stream.videoQualityLabel.contains('1080') ||
                          stream.videoQualityLabel.contains('720')
                      ? const Icon(Icons.hd, color: Colors.blue)
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
      );
    }
  }

  void _startDownload() {
    final downloadManager = DownloadManager();
    downloadManager.startDownload(DownloadedLesson(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lessonId: widget.lesson.id,
      courseId: widget.lesson.courseId,
      title: widget.lesson.title,
      videoUrl: widget.lesson.videoUrl,
      localPath: '',
      fileSize: 0,
      downloadedAt: DateTime.now(),
    ));
  }

  void _startDownloadWithQuality(MuxedStreamInfo stream) {
    final downloadManager = DownloadManager();
    downloadManager.startDownload(DownloadedLesson(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lessonId: widget.lesson.id,
      courseId: widget.lesson.courseId,
      title: widget.lesson.title,
      videoUrl: stream.url.toString(), // Use selected stream URL
      localPath: '',
      fileSize: stream.size.totalBytes,
      downloadedAt: DateTime.now(),
    ));
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
                        const Icon(Icons.fullscreen_exit, color: Colors.white),
                    onPressed: () {
                      // إجبار الجهاز على العودة للوضع العمودي
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                      // ثم إعادة السماح بجميع الاتجاهات
                      Future.delayed(const Duration(milliseconds: 500), () {
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
            decoration: const BoxDecoration(
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
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildLessonInfo(),
                          ),
                          const SizedBox(height: 20),
                          // نظام التبويبات
                          _buildTabBar(),
                          const SizedBox(height: 20),
                          _buildTabContent(),
                          const SizedBox(height: 30),
                          // شريط التحكم في الأسفل
                          _buildBottomControls(),
                          const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseTitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'درس ${widget.lesson.orderIndex}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // زر التحميل
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: _buildDownloadButton(),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
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

  Widget _buildDownloadButton() {
    return AnimatedBuilder(
      animation: DownloadManager(),
      builder: (context, child) {
        final downloadManager = DownloadManager();
        final isDownloaded = downloadManager.isDownloaded(widget.lesson.id);

        // Find if there is an active download/progress
        final activeDownload = downloadManager.activeDownloads.firstWhere(
            (d) => d.lessonId == widget.lesson.id,
            orElse: () => DownloadedLesson(
                id: '',
                lessonId: '',
                courseId: '',
                title: '',
                videoUrl:
                    '', // Changed from videoPath to videoUrl to match constructor
                localPath: '',
                fileSize: 0,
                downloadedAt: DateTime.now(),
                status: DownloadStatus.notDownloaded));

        if (activeDownload.status == DownloadStatus.downloading) {
          return SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: activeDownload.progress,
                  color: Colors.white,
                  strokeWidth: 3,
                ),
                const Icon(Icons.stop, color: Colors.white, size: 20),
              ],
            ),
          );
        }

        return IconButton(
          icon: Icon(
            isDownloaded ? Icons.download_done : Icons.download_rounded,
            color: isDownloaded ? Colors.greenAccent : Colors.white,
          ),
          onPressed: () {
            if (isDownloaded) {
              // Confirm delete
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('حذف التحميل'),
                  content: const Text('هل تريد حذف هذا الفيديو من الجهاز؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final download =
                            downloadManager.getDownload(widget.lesson.id);
                        if (download != null) {
                          await downloadManager.deleteDownload(download.id);
                        }
                      },
                      child: const Text('حذف',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            } else if (activeDownload.status == DownloadStatus.downloading) {
              // Cancel?
              downloadManager.cancelDownload(activeDownload.id);
            } else {
              // Show quality selection dialog
              _showQualitySelectionDialog();
            }
          },
        );
      },
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
              const Icon(
                Icons.video_library_outlined,
                color: Colors.white54,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'فيديو غير متاح',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
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

    if (_youtubeController == null) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final videoId = YoutubePlayer.convertUrlToId(widget.lesson.videoUrl);
        if (videoId != null) {
          return Container(
            width: double.infinity,
            height:
                (MediaQuery.of(context).size.width * 9 / 16).clamp(200, 500),
            color: Colors.black,
            child: HtmlWidget(
              '''
              <iframe 
                width="100%" 
                height="100%" 
                src="https://www.youtube-nocookie.com/embed/$videoId?autoplay=0&rel=0&modestbranding=1" 
                frameborder="0" 
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share; fullscreen" 
                allowfullscreen>
              </iframe>
              ''',
            ),
          );
        }
      }
      return const SizedBox.shrink();
    }

    return Focus(
      autofocus: false,
      descendantsAreFocusable: true,
      child: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primaryPurple,
        progressColors: const ProgressBarColors(
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
          padding: const EdgeInsets.all(20),
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
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.lesson.title,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white70,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.lesson.duration,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  if (widget.lesson.isFree)
                    Container(
                      padding: const EdgeInsets.symmetric(
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
              const SizedBox(height: 16),
              // Content Logic
              // Content Logic - Display ONLY description here to avoid duplication
              Builder(
                builder: (context) {
                  final String description = widget.lesson.description;

                  if (description.isEmpty) return const SizedBox.shrink();

                  // Check if description contains HTML
                  final bool isHtml = description.trim().startsWith('<') ||
                      description.contains('<p>') ||
                      description.contains('<br>') ||
                      description.contains('<b>') ||
                      description.contains('<strong>');

                  if (isHtml) {
                    return HtmlWidget(
                      description,
                      textStyle: const TextStyle(
                        color: Colors.white,
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
                        color: Colors.white.withOpacity(0.9),
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
    if (widget.lesson.resources.isEmpty) return const SizedBox.shrink();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
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
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المرفقات والموارد',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...widget.lesson.resources.map((resource) {
                final fileName = resource['name'] ?? 'ملف غير معروف';
                final url = resource['url'] ?? '';
                final ext = fileName.split('.').last.toLowerCase();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
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
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              fileName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            (ext == 'html' || ext == 'htm')
                                ? 'تشغيل'
                                : (ext == 'pdf' ? 'عرض' : 'تنزيل'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPurple,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
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
          padding: const EdgeInsets.all(20),
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
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ملاحظاتي',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      autofocus: false,
                      style:
                          const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
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
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryPurple,
                          AppColors.primaryBlue,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: _addNote,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isLoadingNotes)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else if (_notes.isEmpty)
                Center(
                  child: Text(
                    'لا توجد ملاحظات بعد',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                )
              else
                ..._notes.map((note) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
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
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          note['content'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryPurple,
                    AppColors.primaryBlue,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.6),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 600, // ارتفاع محدد للـ TabBarView
        child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
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
          const SizedBox(height: 20),
          _buildResources(),
        ],

        // عرض التطبيقات التفاعلية (البطاقات التعليمية) في الشرح
        _buildInteractiveAppsSection(),
      ],
    );
  }

  Widget _buildInteractiveAppsSection() {
    if (widget.lesson.interactiveElements == null) {
      return const SizedBox.shrink();
    }

    // Filter for all interactive types EXCEPT quiz
    final interactiveApps = widget.lesson.interactiveElements!
        .where((e) => e['type'] != 'quiz')
        .map((e) => InteractiveElement.fromJson(e))
        .toList();

    if (interactiveApps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'تطبيقات تفاعلية',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...interactiveApps.map((element) {
          Widget widget;
          switch (element.type) {
            case InteractiveElementType.flashcard:
              widget = FlashcardWidget(
                flashcards: element.flashcards,
                title: element.title,
              );
              break;
            // Add other types here as needed (e.g. simulation)
            default:
              widget = Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      element.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (element.description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        element.description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: widget,
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
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                quiz.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (quiz.description != null) ...[
                const SizedBox(height: 10),
                Text(
                  quiz.description!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    'بدء الاختبار',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
          const SizedBox(height: 60),
          Icon(
            Icons.assignment_turned_in_outlined,
            color: Colors.white.withOpacity(0.3),
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد اختبار لهذا الدرس',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // معاينة الدرس التالي (إذا وجد)
          if (nextLesson != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'التالي:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextLesson.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    nextLesson.duration,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
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
                      const SnackBar(
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
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
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
