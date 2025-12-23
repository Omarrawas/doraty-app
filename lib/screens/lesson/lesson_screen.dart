import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'interactive_quiz_screen.dart';

import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';
import '../../models/note.dart';
import '../../models/exam.dart';
import '../../models/lesson_question.dart';
import '../exams/exam_taking_screen.dart';
import '../../core/services/database_service.dart';
import '../notes/add_note_screen.dart';
import '../../core/data/demo_data.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'dart:ui';

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
  
  // TTS
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  final TextEditingController _questionController = TextEditingController();

  // Video
  bool _isYoutube = false;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  YoutubePlayerController? _youtubePlayerController;

  // WebView
  String? _currentHtmlContent;

  // Exams
  List<Map<String, dynamic>> _lessonExams = [];
  bool _isLoadingExams = true;

  // Progress tracking
  int _videoWatchTime = 0;
  Timer? _watchTimeTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // _currentHtmlContent will be used for the interactive quiz
    _currentHtmlContent = widget.lesson.contentHtml;
    
    _initTts();
    _initVideoPlayer();
    _fetchLessonExams();
    _startWatchTimeTracking();
  }

  Future<void> _fetchLessonExams() async {
    try {
      final exams = await DatabaseService().getExamsForLesson(widget.lesson.id);
      if (mounted) {
        setState(() {
          _lessonExams = exams;
          _isLoadingExams = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching lesson exams: $e');
      if (mounted) {
        setState(() {
          _isLoadingExams = false;
        });
      }
    }
  }

  void _loadDemoQuiz() {
    const quizContent = BiologyDemoData.biologyQuiz;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InteractiveQuizScreen(
          content: quizContent,
          title: 'اختبار تجريبي: الأحياء',
        ),
      ),
    );
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ar-SA");
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setStartHandler(() {
      setState(() => _isSpeaking = true);
    });

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });

    _flutterTts.setCancelHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  void _initVideoPlayer() {
    final url = widget.lesson.videoUrl;
    if (url.isEmpty) return;

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
              return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
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
    _saveProgressBeforeExit();
    _tabController.dispose();
    _flutterTts.stop();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _youtubePlayerController?.dispose();
    super.dispose();
  }

  Future<void> _speakDescription() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      return;
    }

    // Determine text to speak
    String textToSpeak = widget.lesson.content ?? widget.lesson.description;

    if (textToSpeak.trim().isNotEmpty) {
      // Strip tags if any
      textToSpeak = textToSpeak.replaceAll(RegExp(r'<[^>]*>'), '');
      await _flutterTts.speak(textToSpeak);
    }
  }

  void _startWatchTimeTracking() {
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
      return _videoPlayerController?.value.position.inSeconds;
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
    // Mark as completed if watched > 80% of video
    return duration > 0 && (position / duration) > 0.8;
  }

  Future<void> _sendQuestion() async {
    final content = _questionController.text.trim();
    if (content.isEmpty) return;

    try {
      await DatabaseService().askLessonQuestion(
        lessonId: widget.lesson.id,
        content: content,
      );
      _questionController.clear();
      setState(() {}); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال سؤالك بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.lesson.title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.science_outlined, color: Colors.white),
              tooltip: 'تجربة اختبار تفاعلي',
              onPressed: _loadDemoQuiz,
            ),
          ],
        ),
        body: Column(
          children: [
            // Video Player Area
             _buildVideoPlayer(),

            // Content Tabs
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                 Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                  child: Text(
                                    widget.lesson.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                 Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              ],
                            ),
                          ),
                        ];
                      },
                      body: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTabContent(_buildDescriptionTab()),
                          _buildTabContent(_buildNotesTab()),
                          _buildTabContent(_buildQuestionsTab()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Navigation Buttons
             _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(Widget child) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildVideoPlayer() {
    if (widget.lesson.videoUrl.isEmpty) {
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
      if (_youtubePlayerController == null) {
        return Container(height: 250, color: Colors.black, child: const Center(child: CircularProgressIndicator()));
      }
      return YoutubePlayer(
        controller: _youtubePlayerController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppColors.primaryPurple,
        progressColors: const ProgressBarColors(
          playedColor: AppColors.primaryPurple,
          handleColor: AppColors.primaryPurple,
        ),
      );
    } else {
      if (_chewieController != null && _videoPlayerController!.value.isInitialized) {
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
        // AI Reader Control
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 107, 76, 250).withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _speakDescription,
                icon: Icon(
                  _isSpeaking ? Icons.stop_circle_outlined : Icons.play_circle_fill,
                  color: AppColors.primaryPurple,
                  size: 32,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       _isSpeaking ? 'جاري القراءة...' : 'استمع للشرح',
                       style: const TextStyle(
                         fontWeight: FontWeight.bold,
                         color: AppColors.primaryPurple,
                         fontSize: 16,
                       ),
                     ),
                     const Text(
                       'استخدم القارئ الذكي للاستماع للدرس أثناء التنقل',
                       style: TextStyle(
                         color: AppColors.textSecondary,
                         fontSize: 12,
                       ),
                     ),
                   ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),

        // Content
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 250, 250, 250),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((_currentHtmlContent != null && _currentHtmlContent!.trim().isNotEmpty) || (widget.lesson.contentMarkdown != null && widget.lesson.contentMarkdown!.trim().isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final contentToLoad = _currentHtmlContent ?? widget.lesson.contentMarkdown ?? '';
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => InteractiveQuizScreen(
                              content: contentToLoad,
                              title: 'الاختبار التفاعلي: ${widget.lesson.title}',
                              isHtml: _currentHtmlContent != null,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_lesson_outlined),
                      label: const Text('فتح المحتوى التفاعلي'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              HtmlWidget(
                widget.lesson.content ?? widget.lesson.description,
                textStyle: const TextStyle(fontSize: 16, height: 1.8, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        
        // Exam Logic Link
        _buildExamSection(context),

        const SizedBox(height: 20),

        // PDF Download Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'تنزيل',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              const Row(
                children: [
                  Text(
                    'ملخص الدرس.pdf',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.picture_as_pdf, color: AppColors.error, size: 28),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExamSection(BuildContext context) {
    if (_isLoadingExams) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lessonExams.isEmpty) {
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
        ..._lessonExams.map((examData) {
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
                  color: const Color(0xFFFF5722).withOpacity(0.3), width: 2),
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
                                fontSize: 14, color: AppColors.textSecondary),
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
                setState(() {}); // Refresh notes
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
          future: DatabaseService().getNotes(widget.lesson.id),
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
          future: DatabaseService().getLessonQuestions(widget.lesson.id),
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
          if (question.answer != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryPurple.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رد المدرس',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          question.answer!,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.reply_all_rounded, color: AppColors.primaryPurple, size: 20),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
}