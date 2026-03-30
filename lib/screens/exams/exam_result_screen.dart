import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/exam.dart';
import 'package:audioplayers/audioplayers.dart';
import 'exam_taking_screen.dart';
import '../../widgets/tex_view_widget.dart';

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
      debugPrint(
          '📣 Playing result sound: ${isPassed ? "success.mp3" : "failure.mp3"}');
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(context),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Result Card
                      _buildResultCard(percentage, isPassed),

                      SizedBox(height: 24),

                      // Statistics
                      _buildStatistics(correctAnswers),

                      SizedBox(height: 24),

                      // Questions Review
                      if (widget.userAnswers != null) ...[
                        Text(
                          'مراجعة الأسئلة',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                        SizedBox(height: 16),
                        ...List.generate(widget.exam.questions.length, (index) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _buildQuestionReview(index),
                          );
                        }),
                      ],

                      SizedBox(height: 24),

                      // Action Buttons
                      _buildActionButtons(context),

                      SizedBox(height: 20),
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
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
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
                  icon: Icon(Icons.close, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'نتيجة الاختبار',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildResultCard(double percentage, bool isPassed) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPassed
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                  border: Border.all(
                    color: isPassed ? Colors.green : Colors.red,
                    width: 3,
                  ),
                ),
                child: Icon(
                  isPassed ? Icons.check_circle : Icons.cancel,
                  size: 60,
                  color: isPassed ? Colors.green : Colors.red,
                ),
              ),

              SizedBox(height: 24),

              // Status
              Text(
                isPassed ? 'نجحت!' : 'لم تنجح',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isPassed ? Colors.green : Colors.red,
                ),
              ),

              SizedBox(height: 12),

              // Percentage - MAIN
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),

              SizedBox(height: 8),

              // Score points - SECONDARY
              Text(
                '(${widget.exam.score} / ${widget.exam.calculatedTotalPoints})',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextColor(context, secondary: true),
                ),
              ),
            ],
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
            icon: Icons.check_circle,
            label: 'إجابات صحيحة',
            value: '$correctAnswers',
            color: Colors.green,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.cancel,
            label: 'إجابات خاطئة',
            value: '${widget.exam.questions.length - correctAnswers}',
            color: Colors.red,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.assignment,
            label: 'مجموع الأسئلة',
            value: '${widget.exam.questions.length}',
            color: const Color.fromARGB(255, 0, 140, 255),
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
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.getTextColor(context, secondary: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionReview(int index) {
    final question = widget.exam.questions[index];
    final userAnswer = widget.userAnswers?[index];
    final isCorrect = userAnswer == question.correctAnswer;
    final wasAnswered = userAnswer != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: wasAnswered
                  ? (isCorrect
                      ? Colors.green.withOpacity(0.5)
                      : Colors.red.withOpacity(0.5))
                  : Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: wasAnswered
                          ? (isCorrect
                              ? Colors.green.withOpacity(0.3)
                              : Colors.red.withOpacity(0.3))
                          : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      wasAnswered ? (isCorrect ? 'صحيح' : 'خطأ') : 'لم تجب',
                      style: TextStyle(
                        color: wasAnswered
                            ? (isCorrect ? const Color.fromARGB(255, 2, 255, 10) : Colors.red)
                            : const Color.fromARGB(255, 250, 244, 244),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Spacer(),
                  Text(
                    'السؤال ${index + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Question Text
              TexViewWidget(
                question.text,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.getTextColor(context),
                ),
              ),

              SizedBox(height: 12),

              // Options
              ...List.generate(question.options.length, (optionIndex) {
                final isUserAnswer = userAnswer == optionIndex;
                final isCorrectAnswer = question.correctAnswer == optionIndex;

                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCorrectAnswer
                          ? const Color.fromARGB(255, 2, 245, 10).withOpacity(0.2)
                          : (isUserAnswer
                              ? const Color.fromARGB(255, 247, 16, 0).withOpacity(0.2)
                              : Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCorrectAnswer
                            ? const Color.fromARGB(255, 1, 247, 10)
                            : (isUserAnswer
                                ? const Color.fromARGB(255, 247, 16, 0)
                                : Colors.white.withOpacity(0.3)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        if (isCorrectAnswer)
                          Icon(
                            Icons.check_circle,
                            color: Color.fromARGB(255, 0, 255, 8),
                            size: 20,
                          )
                        else if (isUserAnswer)
                          Icon(
                            Icons.cancel,
                            color: Color.fromARGB(255, 252, 17, 0),
                            size: 20,
                          ),
                        if (isCorrectAnswer || isUserAnswer)
                          SizedBox(width: 8),
                        Expanded(
                          child: TexViewWidget(
                            question.options[optionIndex],
                            style: TextStyle(
                              fontSize: 14,
                              color: isCorrectAnswer
                                  ? const Color.fromARGB(255, 0, 253, 8)
                                  : (isUserAnswer ? const Color.fromARGB(255, 245, 17, 1) : Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Explanation
              if (question.explanation != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: Colors.yellow,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TexViewWidget(
                          question.explanation!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextColor(context),
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
    return Column(
      children: [
        if (widget.onNext != null) ...[
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              label: 'الانتقال للدرس التالي',
              icon: Icons.arrow_forward_ios,
              isPrimary: true,
              onTap: () {
                Navigator.pop(context); // Close results
                widget.onNext!();
              },
            ),
          ),
          SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'العودة للدرس',
                icon: Icons.play_lesson,
                onTap: () {
                  if (widget.onFinish != null) {
                    widget.onFinish!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                label: 'إعادة الاختبار',
                icon: Icons.refresh,
                onTap: () {
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
                isPrimary: widget.onNext == null, // Make retry primary only if no next lesson option
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
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
                    Icon(icon, color: AppColors.getTextColor(context), size: 20),
                    SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
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

  int _getCorrectAnswersCount() {
    if (widget.userAnswers == null) return 0;

    int count = 0;
    for (var entry in widget.userAnswers!.entries) {
      if (entry.value == widget.exam.questions[entry.key].correctAnswer) {
        count++;
      }
    }
    return count;
  }
}
