import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/exam.dart';
import 'package:audioplayers/audioplayers.dart';
import 'exam_taking_screen.dart';
import '../../widgets/tex_view_widget.dart';
import '../../widgets/dynamic_gradient_background.dart';

class ExamResultScreen extends StatefulWidget {
  final Exam exam;
  final Map<int, int>? userAnswers;
  final VoidCallback? onFinish;
  final VoidCallback? onNext;

  const ExamResultScreen({
    super.key,
    required this.exam,
    this.userAnswers,
    this.onFinish,
    this.onNext,
  });

  @override
  State<ExamResultScreen> createState() => _ExamResultScreenState();
}

class _ExamResultScreenState extends State<ExamResultScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playResultSound();
  }

  void _playResultSound() async {
    final percentage = widget.exam.percentage ?? 0.0;
    final isPassed = percentage >= 60;
    try {
      debugPrint('📣 Playing result sound: ${isPassed ? "success.mp3" : "failure.mp3"}');
      if (isPassed) {
        await _audioPlayer.play(AssetSource('sounds/success.mp3'), volume: 1.0);
      } else {
        await _audioPlayer.play(AssetSource('sounds/failure.mp3'), volume: 1.0);
      }
    } catch (e) {
      debugPrint('❌ Error playing result sound: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.exam.percentage ?? 0.0;
    final isPassed = percentage >= 60;
    final correctAnswers = _getCorrectAnswersCount();

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      _buildResultCard(percentage, isPassed),
                      const SizedBox(height: 32),
                      _buildStatistics(correctAnswers),
                      const SizedBox(height: 32),
                      if (widget.userAnswers != null) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'مراجعة الأسئلة',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.getTextColor(context),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(widget.exam.questions.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildQuestionReview(index),
                          );
                        }),
                      ],
                      const SizedBox(height: 32),
                      _buildActionButtons(context),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipRRect(
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () {
                    if (widget.onFinish != null) {
                      widget.onFinish!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ),
          Text(
            'نتيجة الاختبار',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.getTextColor(context),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(width: 48), // Balancing space for the header title centering
        ],
      ),
    );
  }

  Widget _buildResultCard(double percentage, bool isPassed) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context).withOpacity(0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: (isPassed ? Colors.green : Colors.red).withOpacity(0.15),
            blurRadius: 40,
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPassed ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    border: Border.all(
                      color: isPassed ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isPassed ? Colors.green.withOpacity(0.4) : Colors.red.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPassed ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                    size: 60,
                    color: isPassed ? Colors.greenAccent : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isPassed ? 'مبروك، لقد نجحت!' : 'للأسف، لم يحالفك الحظ',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isPassed ? Colors.greenAccent : Colors.redAccent,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  '(${widget.exam.score} من أصل ${widget.exam.calculatedTotalPoints} نقطة)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.7),
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics(int correctAnswers) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_outline_rounded,
            label: 'إجابات صحيحة',
            value: '$correctAnswers',
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.highlight_off_rounded,
            label: 'إجابات خاطئة',
            value: '${widget.exam.questions.length - correctAnswers}',
            color: Colors.redAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.format_list_numbered_rounded,
            label: 'مجموع الأسئلة',
            value: '${widget.exam.questions.length}',
            color: Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionReview(int index) {
    if (index >= widget.exam.questions.length) return const SizedBox.shrink();
    
    final question = widget.exam.questions[index];
    final userAnswer = widget.userAnswers?[index];
    final isCorrect = userAnswer == question.correctAnswer;
    final wasAnswered = userAnswer != null;

    Color statusColor = wasAnswered
        ? (isCorrect ? Colors.greenAccent : Colors.redAccent)
        : Colors.orangeAccent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      wasAnswered ? (isCorrect ? 'إجابة صحيحة' : 'إجابة خاطئة') : 'لم تجب',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'السؤال ${index + 1}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TexViewWidget(
                question.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 20),
              ...List.generate(question.options.length, (optionIndex) {
                final isUserAnswer = userAnswer == optionIndex;
                final isCorrectAnswer = question.correctAnswer == optionIndex;

                Color optionColor = Colors.white.withOpacity(0.1);
                Color borderColor = Colors.transparent;
                Color textColor = Colors.white;

                if (isCorrectAnswer) {
                  optionColor = Colors.green.withOpacity(0.2);
                  borderColor = Colors.greenAccent.withOpacity(0.5);
                  textColor = Colors.greenAccent;
                } else if (isUserAnswer) {
                  optionColor = Colors.red.withOpacity(0.2);
                  borderColor = Colors.redAccent.withOpacity(0.5);
                  textColor = Colors.redAccent;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: optionColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        if (isCorrectAnswer)
                          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22)
                        else if (isUserAnswer)
                          const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22)
                        else
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white30, width: 2),
                            ),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TexViewWidget(
                            question.options[optionIndex],
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor,
                              fontFamily: 'Cairo',
                              fontWeight: (isCorrectAnswer || isUserAnswer) ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_circle_rounded, color: Colors.amberAccent, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TexViewWidget(
                          question.explanation!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final passesThreshold = widget.exam.questions.isNotEmpty 
        ? (_getCorrectAnswersCount() / widget.exam.questions.length) >= 0.6 
        : false;

    return Column(
      children: [
        if (widget.onNext != null && passesThreshold) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onNext!();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: AppColors.primaryPurple.withOpacity(0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('الدرس التالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (widget.onFinish != null) {
                    widget.onFinish!();
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.library_books_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('العودة للدرس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExamTakingScreen(
                        exam: widget.exam,
                        onFinish: widget.onFinish,
                        onNext: widget.onNext,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.onNext == null ? AppColors.primaryPurple : Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: widget.onNext == null ? 8 : 0,
                  shadowColor: widget.onNext == null ? AppColors.primaryPurple.withOpacity(0.4) : Colors.transparent,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.replay_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('إعادة الاختبار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  int _getCorrectAnswersCount() {
    if (widget.userAnswers == null) return 0;
    int count = 0;
    for (var entry in widget.userAnswers!.entries) {
      if (entry.key < widget.exam.questions.length) {
        if (entry.value == widget.exam.questions[entry.key].correctAnswer) {
          count++;
        }
      }
    }
    return count;
  }
}
