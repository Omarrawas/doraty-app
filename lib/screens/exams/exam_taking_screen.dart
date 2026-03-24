import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/exam.dart';
import 'exam_result_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/tex_view_widget.dart';

class ExamTakingScreen extends StatefulWidget {
  final Exam exam;
  final VoidCallback? onFinish;
  final VoidCallback? onNext;

  const ExamTakingScreen({
    super.key,
    required this.exam,
    VoidCallback? onFinish,
    this.onNext,
    @Deprecated('Use onFinish') VoidCallback? onCompleted,
  }) : onFinish = onFinish ?? onCompleted;

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> {
  int _currentQuestionIndex = 0;
  final Map<int, int> _answers = {};
  Timer? _timer;
  late int _remainingSeconds;
  bool _isSubmitting = false;
  final DatabaseService _db = DatabaseService.instance;
  String? _attemptId;
  bool _isLoading = true;
  bool _isMuted = true; // Default to muted as per user request

  // Sound Players
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _feedbackPlayer = AudioPlayer();

  // Mock questions for demonstration
  late List<Question> _questions;
  // Map to track original option indices for each question: questionId -> [originalIndex corresponding to newIndex 0, ...]
  final Map<String, List<int>> _shuffledToOriginalIndices = {};

  @override
  void initState() {
    super.initState();
    _initializeQuestions();
    
    _remainingSeconds = widget.exam.duration * 60;
    
    _initSounds();
    _startExamAttempt();
  }

  void _initializeQuestions() {
    // 1. Create a mutable list of questions
    var questionsList = List<Question>.from(widget.exam.questions);

    // 2. Shuffle Questions if enabled
    if (widget.exam.shuffleQuestions) {
      questionsList.shuffle();
    }

    // 3. Shuffle Options if enabled
    if (widget.exam.shuffleOptions) {
      questionsList = questionsList.map((q) {
        // Create indices [0, 1, 2, ...]
        final indices = List<int>.generate(q.options.length, (i) => i);
        // Shuffle indices
        indices.shuffle();

        // Store mapping: newIndex -> originalIndex
        _shuffledToOriginalIndices[q.id] = indices;

        // Create new options list based on shuffled indices
        final newOptions = indices.map((i) => q.options[i]).toList();

        // Find new correct answer index
        // The original correct answer index is q.correctAnswer.
        // We need to find which new index 'k' has indices[k] == q.correctAnswer
        int newCorrectAnswer = 0;
        for (int i = 0; i < indices.length; i++) {
          if (indices[i] == q.correctAnswer) {
            newCorrectAnswer = i;
            break;
          }
        }

        // Return new Question object with shuffled options
        return Question(
          id: q.id,
          text: q.text,
          options: newOptions,
          correctAnswer: newCorrectAnswer,
          explanation: q.explanation,
          points: q.points,
        );
      }).toList();
    }

    _questions = questionsList;
  }

  Future<void> _startExamAttempt() async {
    try {
      final id = await _db.startExamAttempt(widget.exam.id);
      if (mounted) {
        setState(() {
          _attemptId = id;
          _isLoading = false;
        });
        if (_questions.isNotEmpty) {
          _startTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
        Navigator.pop(context);
      }
    }
  }

  void _initSounds() {
    _tickPlayer
        .setSource(AssetSource('sounds/tick.mp3'))
        .catchError((e) => debugPrint('❌ Error setting tick source: $e'));
    _feedbackPlayer
        .setSource(AssetSource('sounds/select.mp3'))
        .catchError((e) => debugPrint('❌ Error setting select source: $e'));
  }


  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer just in case
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            // Play tick sound every second
            _playTick();
          } else {
            _submitExam();
          }
        });
      }
    });
  }

  void _playTick() async {
    if (_isMuted) return; // Don't play if muted
    try {
      // For frequent sounds, seek(0) and resume is faster
      if (_tickPlayer.state == PlayerState.playing) {
        await _tickPlayer.seek(Duration.zero);
      } else {
        await _tickPlayer.play(AssetSource('sounds/tick.mp3'), volume: 0.6);
      }
    } catch (e) {
      debugPrint('❌ Error playing tick sound: $e');
    }
  }

  void _playSound(String fileName) async {
    if (_isMuted) return; // Don't play if muted
    try {
      debugPrint('📣 Attempting to play: $fileName');
      // Use feedback player for short sounds
      await _feedbackPlayer.stop();
      await _feedbackPlayer.play(AssetSource('sounds/$fileName'), volume: 1.0);
    } catch (e) {
      debugPrint('❌ Error playing sound $fileName: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickPlayer.stop();
    _tickPlayer.dispose();
    _feedbackPlayer.stop();
    _feedbackPlayer.dispose();
    super.dispose();
  }

  void _submitExam() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    _timer?.cancel();
    _tickPlayer.stop();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      int score = 0;
      
      // Calculate local score for immediate feedback
      for (var entry in _answers.entries) {
        if (entry.value == _questions[entry.key].correctAnswer) {
          score += _questions[entry.key].points;
        }
      }

      // Sync with backend if we have a valid attempt ID
      if (_attemptId != null) {
        // Submit all answers
        for (var entry in _answers.entries) {
          // Get the question object (which might be shuffled)
          final question = _questions[entry.key];

          // Determine the original option index to send to backend
          int originalOptionIndex = entry.value;

          if (widget.exam.shuffleOptions &&
              _shuffledToOriginalIndices.containsKey(question.id)) {
            final mapping = _shuffledToOriginalIndices[question.id];
            if (mapping != null && entry.value < mapping.length) {
              originalOptionIndex = mapping[entry.value];
            }
          }

          await _db.submitAnswer(
            attemptId: _attemptId!,
            questionId: question.id,
            userAnswer: originalOptionIndex,
          );
        }

        // Complete the attempt
        await _db.submitExamAttempt(_attemptId!);
      }

      _playSound('complete.mp3');

      // Create completed exam for result screen
      final completedExam = Exam(
        id: widget.exam.id,
        title: widget.exam.title,
        description: widget.exam.description,
        courseId: widget.exam.courseId,
        courseName: widget.exam.courseName,
        questions: _questions,
        duration: widget.exam.duration,
        totalPoints: _questions.fold(0, (sum, q) => sum + q.points),
        isCompleted: true,
        score: score,
        maxAttempts: widget.exam.maxAttempts,
        attempts: widget.exam
            .attempts, // Ideally this would be updated but for now it's fine
      );

      if (mounted) {
        // Remove loading dialog
        Navigator.pop(context);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ExamResultScreen(
              exam: completedExam,
              userAnswers: _answers,
              onFinish: widget.onFinish,
              onNext: widget.onNext,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Remove loading dialog
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
        // Still navigate to results? Or keep them here?
        // For now, let's keep them here to retry or exit.
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
        backgroundColor: AppColors.primaryPurple,
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.quiz_outlined, color: AppColors.getTextColor(context), size: 80),
                SizedBox(height: 24),
                Text(
                  'لا توجد أسئلة بهذا الاختبار',
                  style: TextStyle(
                    color: AppColors.getTextColor(context),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'يتم العمل على إضافة محتوى الاختبار، يرجى المحاولة لاحقاً.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.70),
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('العودة للدرس'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await _showExitDialog();
        return shouldExit ?? false;
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with Timer
                _buildHeader(progress),

                // Question Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question Number
                        Text(
                          'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.getTextColor(context, secondary: true),
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        SizedBox(height: 20),

                        // Question Card
                        _buildQuestionCard(question),

                        SizedBox(height: 24),

                        // Options
                        ...List.generate(question.options.length, (index) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _buildOptionCard(question, index),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Navigation Buttons
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    final isLowTime = _remainingSeconds < 300; // Less than 5 minutes

    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Timer
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isLowTime
                          ? Colors.red.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLowTime
                            ? Colors.red.withOpacity(0.5)
                            : Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: isLowTime ? Colors.red : Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            color: isLowTime ? Colors.red : Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Spacer(),

              // Exam Title
              Expanded(
                flex: 2,
                child: Text(
                  widget.exam.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
              ),

              // Mute/Unmute Toggle
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
                      icon: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            _isMuted ? Icons.volume_mute : Icons.volume_up,
                            color: AppColors.getTextColor(context),
                            size: 20,
                          ),
                          if (_isMuted)
                            Transform.rotate(
                              angle: -0.5,
                              child: Container(
                                width: 20,
                                height: 2,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        // If unmuted, play a feedback sound
                        if (!_isMuted) {
                          _playSound('select.mp3');
                        }
                      },
                      tooltip: _isMuted ? 'تشغيل الصوت' : 'كتم الصوت',
                    ),
                  ),
                ),
              ),

              SizedBox(width: 8),

              // Submit Button
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
                      icon: Icon(Icons.check, color: AppColors.getTextColor(context)),
                      onPressed: () => _showSubmitDialog(),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(24),
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
          child: TexViewWidget(
            question.text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextColor(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(Question question, int optionIndex) {
    final isSelected = _answers[_currentQuestionIndex] == optionIndex;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: isSelected
                ? AppColors.primaryGradient
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.5)
                  : Colors.white.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _answers[_currentQuestionIndex] = optionIndex;
                });
                _playSound('select.mp3');
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white
                            : Colors.transparent,
                        border: Border.all(
                          color: AppColors.getTextColor(context),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: AppColors.primaryPurple,
                            )
                          : null,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: TexViewWidget(
                        question.options[optionIndex],
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          // Previous Button
          if (_currentQuestionIndex > 0)
            Expanded(
              child: _buildNavButton(
                label: 'السابق',
                icon: Icons.arrow_back,
                onTap: () {
                  setState(() {
                    _currentQuestionIndex--;
                  });
                },
              ),
            ),

          if (_currentQuestionIndex > 0) SizedBox(width: 12),

          // Next/Submit Button
          Expanded(
            child: _buildNavButton(
              label: _currentQuestionIndex < _questions.length - 1
                  ? 'التالي'
                  : 'إنهاء',
              icon: _currentQuestionIndex < _questions.length - 1
                  ? Icons.arrow_forward
                  : Icons.check,
              onTap: () {
                if (_currentQuestionIndex < _questions.length - 1) {
                  setState(() {
                    _currentQuestionIndex++;
                  });
                } else {
                  _showSubmitDialog();
                }
              },
              isPrimary: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: isPrimary ? AppColors.primaryGradient : null,
            color: isPrimary ? null : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (label == 'السابق') ...[
                      Icon(icon, color: AppColors.getTextColor(context), size: 20),
                      SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (label != 'السابق') ...[
                      SizedBox(width: 8),
                      Icon(icon, color: AppColors.getTextColor(context), size: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showSubmitDialog() async {
    final unanswered = _questions.length - _answers.length;

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryPurple,
        title: Text(
          'إنهاء الاختبار',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        content: Text(
          unanswered > 0
              ? 'لديك $unanswered سؤال لم تجب عليه. هل تريد إنهاء الاختبار؟'
              : 'هل تريد إنهاء الاختبار وإرسال إجاباتك؟',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: TextStyle(color: AppColors.getTextColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('إنهاء', style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );

    if (shouldSubmit == true) {
      _submitExam();
    }
  }

  Future<bool?> _showExitDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryPurple,
        title: Text(
          'الخروج من الاختبار',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        content: Text(
          'هل تريد الخروج من الاختبار؟ سيتم فقدان إجاباتك.',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('إلغاء', style: TextStyle(color: AppColors.getTextColor(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('خروج', style: TextStyle(color: AppColors.getTextColor(context))),
          ),
        ],
      ),
    );
  }
}
