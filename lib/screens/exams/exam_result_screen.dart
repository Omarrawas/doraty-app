import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/exam.dart';

class ExamResultScreen extends StatelessWidget {
  final Exam exam;
  final Map<int, int>? userAnswers;

  const ExamResultScreen({
    super.key,
    required this.exam,
    this.userAnswers,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = exam.percentage ?? 0.0;
    final isPassed = percentage >= 60;
    final correctAnswers = _getCorrectAnswersCount();

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
              // Header
              _buildHeader(context),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Result Card
                      _buildResultCard(percentage, isPassed),

                      const SizedBox(height: 24),

                      // Statistics
                      _buildStatistics(correctAnswers),

                      const SizedBox(height: 24),

                      // Questions Review
                      if (userAnswers != null) ...[
                        const Text(
                          'مراجعة الأسئلة',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(exam.questions.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildQuestionReview(index),
                          );
                        }),
                      ],

                      const SizedBox(height: 24),

                      // Action Buttons
                      _buildActionButtons(context),

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
  }

  Widget _buildHeader(BuildContext context) {
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
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'نتيجة الاختبار',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
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
          padding: const EdgeInsets.all(32),
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
              color: Colors.white.withOpacity(0.3),
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

              const SizedBox(height: 24),

              // Status
              Text(
                isPassed ? 'نجحت!' : 'لم تنجح',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isPassed ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 12),

              // Score
              Text(
                '${exam.score} / ${exam.totalPoints}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              // Percentage
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.9),
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
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.cancel,
            label: 'إجابات خاطئة',
            value: '${exam.questions.length - correctAnswers}',
            color: Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.assignment,
            label: 'مجموع الأسئلة',
            value: '${exam.questions.length}',
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionReview(int index) {
    final question = exam.questions[index];
    final userAnswer = userAnswers?[index];
    final isCorrect = userAnswer == question.correctAnswer;
    final wasAnswered = userAnswer != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
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
                    padding: const EdgeInsets.symmetric(
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
                  const Spacer(),
                  Text(
                    'السؤال ${index + 1}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Question Text
              Text(
                question.text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // Options
              ...List.generate(question.options.length, (optionIndex) {
                final isUserAnswer = userAnswer == optionIndex;
                final isCorrectAnswer = question.correctAnswer == optionIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
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
                          const Icon(
                            Icons.check_circle,
                            color: Color.fromARGB(255, 0, 255, 8),
                            size: 20,
                          )
                        else if (isUserAnswer)
                          const Icon(
                            Icons.cancel,
                            color: Color.fromARGB(255, 252, 17, 0),
                            size: 20,
                          ),
                        if (isCorrectAnswer || isUserAnswer)
                          const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question.options[optionIndex],
                            textAlign: TextAlign.right,
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
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
                      const Icon(
                        Icons.lightbulb,
                        color: Colors.yellow,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          question.explanation!,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
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
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            label: 'العودة للرئيسية',
            icon: Icons.home,
            onTap: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: 'إعادة الاختبار',
            icon: Icons.refresh,
            onTap: () {
              Navigator.pop(context);
            },
            isPrimary: true,
          ),
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
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
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
    if (userAnswers == null) return 0;

    int count = 0;
    for (var entry in userAnswers!.entries) {
      if (entry.value == exam.questions[entry.key].correctAnswer) {
        count++;
      }
    }
    return count;
  }
}
