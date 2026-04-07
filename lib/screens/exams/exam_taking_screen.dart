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
import '../../widgets/dynamic_gradient_background.dart';

class ExamTakingScreen extends StatefulWidget {
  final Exam exam;
  final VoidCallback? onFinish;
  final VoidCallback? onNext;

  const ExamTakingScreen({
    super.key,
    required this.exam,
    this.onFinish,
    this.onNext,
    @Deprecated('Use onFinish') VoidCallback? onCompleted,
  });

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
  bool _isMuted = true;

  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _feedbackPlayer = AudioPlayer();

  late List<Question> _questions;
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
    var questionsList = List<Question>.from(widget.exam.questions);
    if (widget.exam.shuffleQuestions) {
      questionsList.shuffle();
    }

    if (widget.exam.shuffleOptions) {
      questionsList = questionsList.map((q) {
        final indices = List<int>.generate(q.options.length, (i) => i);
        indices.shuffle();
        _shuffledToOriginalIndices[q.id] = indices;
        final newOptions = indices.map((i) => q.options[i]).toList();
        int newCorrectAnswer = 0;
        for (int i = 0; i < indices.length; i++) {
          if (indices[i] == q.correctAnswer) {
            newCorrectAnswer = i;
            break;
          }
        }
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
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e)), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context);
      }
    }
  }

  void _initSounds() {
    _tickPlayer.release();
    _feedbackPlayer.release();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
            if (_remainingSeconds == 60) _playSound('warning.mp3');
          } else {
            _submitExam();
          }
        });
      }
    });
  }

  void _playSound(String fileName) async {
    if (_isMuted) return;
    try {
      await _feedbackPlayer.play(AssetSource('sounds/$fileName'), volume: 1.0);
    } catch (e) {
      debugPrint('❌ Error playing sound: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickPlayer.dispose();
    _feedbackPlayer.dispose();
    super.dispose();
  }

  void _submitExam() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    _timer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
    );

    try {
      int score = 0;
      for (var entry in _answers.entries) {
        if (entry.value == _questions[entry.key].correctAnswer) {
          score += _questions[entry.key].points;
        }
      }

      if (_attemptId != null) {
        for (var entry in _answers.entries) {
          final question = _questions[entry.key];
          int originalOptionIndex = entry.value;
          if (widget.exam.shuffleOptions && _shuffledToOriginalIndices.containsKey(question.id)) {
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
        await _db.submitExamAttempt(_attemptId!);
      }

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
        attempts: widget.exam.attempts,
      );

      if (mounted) {
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e)), behavior: SnackBarBehavior.floating),
        );
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
        backgroundColor: Colors.black,
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: DynamicGradientBackground(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_outlined, color: Colors.white, size: 80),
              const SizedBox(height: 24),
              const Text('لا توجد أسئلة بهذا الاختبار', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const SizedBox(height: 16),
              const Text('يتم العمل على إضافة محتوى الاختبار، يرجى المحاولة لاحقاً.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Cairo')),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('العودة للدرس', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return WillPopScope(
      onWillPop: () async => await _showExitDialog() ?? false,
      child: Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(progress),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextColor(context).withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildQuestionCard(question),
                        const SizedBox(height: 32),
                        ...List.generate(question.options.length, (index) {
                          return _buildOptionCard(question, index);
                        }),
                      ],
                    ),
                  ),
                ),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double progress) {
    final isLowTime = _remainingSeconds < 60;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isLowTime ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isLowTime ? Colors.red.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, color: isLowTime ? Colors.redAccent : Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(color: isLowTime ? Colors.redAccent : Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _buildSimpleIconButton(
                icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                onTap: () => setState(() => _isMuted = !_isMuted),
                color: _isMuted ? Colors.white30 : AppColors.primaryPurple,
              ),
              const SizedBox(width: 12),
              _buildSimpleIconButton(
                icon: Icons.done_all_rounded,
                onTap: _showSubmitDialog,
                color: Colors.greenAccent,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleIconButton({required IconData icon, required VoidCallback onTap, required Color color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: 20),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context).withOpacity(0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, spreadRadius: -10),
        ],
      ),
      child: TexViewWidget(
        question.text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.getTextColor(context),
          fontFamily: 'Cairo',
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildOptionCard(Question question, int index) {
    final isSelected = _answers[_currentQuestionIndex] == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryPurple.withOpacity(0.8) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1), width: 1.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _answers[_currentQuestionIndex] = index);
                    _playSound('select.mp3');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? Colors.white : Colors.white24, width: 2),
                            color: isSelected ? Colors.white : Colors.transparent,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: AppColors.primaryPurple) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TexViewWidget(
                            question.options[index],
                            style: TextStyle(
                              fontSize: 16,
                              color: isSelected ? Colors.white : AppColors.getTextColor(context),
                              fontFamily: 'Cairo',
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isLast = _currentQuestionIndex == _questions.length - 1;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0) ...[
            Expanded(
              child: _buildNavBtn(
                label: 'السابق',
                onTap: () => setState(() => _currentQuestionIndex--),
                isOutline: true,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: _buildNavBtn(
              label: isLast ? 'إنهاء الاختبار' : 'السؤال التالي',
              onTap: isLast ? _showSubmitDialog : () => setState(() => _currentQuestionIndex++),
              isOutline: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBtn({required String label, required VoidCallback onTap, bool isOutline = false}) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutline ? Colors.transparent : AppColors.primaryPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: isOutline ? const BorderSide(color: Colors.white24) : BorderSide.none,
        ),
        elevation: isOutline ? 0 : 8,
        shadowColor: AppColors.primaryPurple.withOpacity(0.3),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
    );
  }

  Future<void> _showSubmitDialog() async {
    final unanswered = _questions.length - _answers.length;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.getSurfaceColor(context).withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Colors.white10)),
          title: const Text('إنهاء الاختبار؟', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text(
            unanswered > 0 ? 'لديك $unanswered سؤالاً لم تجب عليها، هل أنت متأكد من التسليم؟' : 'هل أنت متأكد من رغبتك في تسليم الاختبار الآن؟',
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo'))),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
              child: const Text('تسليم الآن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    if (result == true) _submitExam();
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.getSurfaceColor(context).withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('خروج من الاختبار؟', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: const Text('سيتم فقدان تقدمك الحالي إذا خرجت الآن.', style: TextStyle(fontFamily: 'Cairo')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إكمال', style: TextStyle(fontFamily: 'Cairo'))),
            TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('خروج', style: TextStyle(fontFamily: 'Cairo'))),
          ],
        ),
      ),
    );
  }
}
