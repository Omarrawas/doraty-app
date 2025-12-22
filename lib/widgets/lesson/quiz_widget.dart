import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/quiz_question.dart';

class QuizWidget extends StatefulWidget {
  final List<QuizQuestion> questions;
  final String title;
  final VoidCallback? onComplete;

  const QuizWidget({
    super.key,
    required this.questions,
    required this.title,
    this.onComplete,
  });

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  bool _showAnswer = false;
  int _correctAnswers = 0;
  bool _quizCompleted = false;

  void _selectAnswer(int index) {
    if (_showAnswer) return;
    setState(() {
      _selectedAnswerIndex = index;
    });
  }

  void _checkAnswer() {
    if (_selectedAnswerIndex == null) return;

    setState(() {
      _showAnswer = true;
      if (_selectedAnswerIndex ==
          widget.questions[_currentQuestionIndex].correctAnswerIndex) {
        _correctAnswers++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = null;
        _showAnswer = false;
      });
    } else {
      setState(() {
        _quizCompleted = true;
      });
      widget.onComplete?.call();
    }
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = null;
      _showAnswer = false;
      _correctAnswers = 0;
      _quizCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const SizedBox.shrink();
    }

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
          child: _quizCompleted ? _buildResults() : _buildQuiz(),
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final question = widget.questions[_currentQuestionIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.quiz_outlined,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'السؤال ${_currentQuestionIndex + 1} من ${widget.questions.length}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          question.question,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(question.options.length, (index) {
          return _buildOption(index, question);
        }),
        if (_showAnswer && question.explanation != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.withOpacity(0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.lightBlueAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.explanation!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (!_showAnswer)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedAnswerIndex != null ? _checkAnswer : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'تحقق من الإجابة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _currentQuestionIndex < widget.questions.length - 1
                    ? 'السؤال التالي'
                    : 'إنهاء الاختبار',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOption(int index, QuizQuestion question) {
    final isSelected = _selectedAnswerIndex == index;
    final isCorrect = index == question.correctAnswerIndex;
    final showCorrect = _showAnswer && isCorrect;
    final showWrong = _showAnswer && isSelected && !isCorrect;

    Color borderColor = Colors.white.withOpacity(0.3);
    Color backgroundColor = Colors.white.withOpacity(0.1);

    if (showCorrect) {
      borderColor = Colors.green;
      backgroundColor = Colors.green.withOpacity(0.2);
    } else if (showWrong) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.2);
    } else if (isSelected) {
      borderColor = AppColors.primaryPurple;
      backgroundColor = AppColors.primaryPurple.withOpacity(0.2);
    }

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: 2,
                ),
                color: isSelected ? borderColor : Colors.transparent,
              ),
              child: showCorrect
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : showWrong
                      ? const Icon(Icons.close, color: Colors.white, size: 16)
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                question.options[index],
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final percentage =
        (_correctAnswers / widget.questions.length * 100).round();
    final isPassed = percentage >= 60;

    return Column(
      children: [
        Icon(
          isPassed ? Icons.celebration : Icons.sentiment_dissatisfied,
          color: isPassed ? Colors.greenAccent : Colors.orangeAccent,
          size: 64,
        ),
        const SizedBox(height: 20),
        Text(
          isPassed ? 'أحسنت!' : 'حاول مرة أخرى',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'لقد أجبت على $_correctAnswers من ${widget.questions.length} بشكل صحيح',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isPassed ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'نسبة النجاح',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _restartQuiz,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'إعادة الاختبار',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
