import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/interactive_element.dart';
import '../../widgets/lesson/quiz_widget.dart';

class LessonExamScreen extends StatelessWidget {
  final InteractiveElement quizElement;
  final String lessonTitle;

  const LessonExamScreen({
    super.key,
    required this.quizElement,
    required this.lessonTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'اختبار: $lessonTitle',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                QuizWidget(
                  questions: quizElement.quizQuestions,
                  title: quizElement.title,
                  onComplete: () {
                    // Optional: Handle completion (e.g., save score)
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
