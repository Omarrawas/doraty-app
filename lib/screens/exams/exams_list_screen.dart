import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../models/exam.dart';
import 'exam_taking_screen.dart';
import 'exam_result_screen.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';
import 'package:provider/provider.dart';

class ExamsListScreen extends StatefulWidget {
  const ExamsListScreen({super.key});

  @override
  State<ExamsListScreen> createState() => _ExamsListScreenState();
}

class _ExamsListScreenState extends State<ExamsListScreen> {
  String _t(String key) {
    if (!mounted) return key;
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

  List<Exam> get _upcomingExams => [
    Exam(
      id: '1',
      title: _t('exam_math_title'),
      description: _t('exam_math_desc'),
      courseId: '1',
      courseName: _t('exam_math_course'),
      questions: [],
      duration: 60,
      totalPoints: 100,
    ),
    Exam(
      id: '2',
      title: _t('exam_physics_title'),
      description: _t('exam_physics_desc'),
      courseId: '2',
      courseName: _t('exam_physics_course'),
      questions: [],
      duration: 45,
      totalPoints: 50,
    ),
  ];

  List<Exam> get _completedExams => [
    Exam(
      id: '3',
      title: _t('exam_chemistry_title'),
      description: _t('exam_chemistry_desc'),
      courseId: '3',
      courseName: _t('exam_chemistry_course'),
      questions: [],
      duration: 30,
      totalPoints: 50,
      isCompleted: true,
      score: 42,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              SizedBox(height: 20),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upcoming Exams
                      Text(
                        _t('upcoming_exams'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),

                      SizedBox(height: 16),

                      if (_upcomingExams.isEmpty)
                        _buildEmptyState(_t('no_upcoming_exams'))
                      else
                        ..._upcomingExams.map((exam) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _buildExamCard(exam, isUpcoming: true),
                          );
                        }),

                      SizedBox(height: 30),

                      // Completed Exams
                      Text(
                        _t('completed_exams'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),

                      SizedBox(height: 16),

                      if (_completedExams.isEmpty)
                        _buildEmptyState(_t('no_completed_exams'))
                      else
                        ..._completedExams.map((exam) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: _buildExamCard(exam, isUpcoming: false),
                          );
                        }),

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

  Widget _buildHeader() {
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
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _t('exams'),
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

  Widget _buildExamCard(Exam exam, {required bool isUpcoming}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (isUpcoming) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExamTakingScreen(exam: exam),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExamResultScreen(exam: exam),
                    ),
                  );
                }
              },
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      exam.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                    ),

                    SizedBox(height: 8),

                    // Course Name
                    Text(
                      exam.courseName,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextColor(context, secondary: true),
                      ),
                    ),

                    SizedBox(height: 12),

                    // Description
                    Text(
                      exam.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextColor(context, secondary: true),
                      ),
                    ),

                    SizedBox(height: 16),

                    // Info Row
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.access_time,
                          label: exam.formattedDuration,
                        ),
                        SizedBox(width: 12),
                        _buildInfoChip(
                          icon: Icons.assignment,
                          label: '${exam.totalPoints} ${_t('points')}',
                        ),
                        if (!isUpcoming && exam.score != null) ...[
                          SizedBox(width: 12),
                          _buildScoreChip(exam),
                        ],
                      ],
                    ),

                    if (isUpcoming) ...[
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _t('start_exam'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.getTextColor(context), size: 16),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.getTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(Exam exam) {
    final percentage = exam.percentage ?? 0.0;
    final color = percentage >= 80
        ? Colors.green
        : percentage >= 60
            ? Colors.orange
            : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grade, color: color, size: 16),
          SizedBox(width: 6),
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.getTextColor(context, secondary: true),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
