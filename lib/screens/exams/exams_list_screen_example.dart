import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/exam.dart';
import 'exam_taking_screen.dart';
import 'exam_result_screen.dart';

class ExamsListScreen extends StatefulWidget {
  const ExamsListScreen({super.key});

  @override
  State<ExamsListScreen> createState() => _ExamsListScreenState();
}

class _ExamsListScreenState extends State<ExamsListScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _upcomingExams = [];
  List<Map<String, dynamic>> _completedExams = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final upcoming = await _db.getUpcomingExams();
      final completed = await _db.getCompletedExams();

      setState(() {
        _upcomingExams = upcoming;
        _completedExams = completed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في تحميل الاختبارات: $e';
        _isLoading = false;
      });
      debugPrint('Error loading exams: $e');
    }
  }

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
                child: _isLoading
                    ? _buildLoadingState()
                    : _errorMessage != null
                        ? _buildErrorState()
                        : _buildExamsList(),
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
              'الاختبارات',
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

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.getTextColor(context),
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              _errorMessage ?? 'حدث خطأ غير متوقع',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.getTextColor(context),
                fontSize: 16,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadExams,
              icon: Icon(Icons.refresh),
              label: Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamsList() {
    return RefreshIndicator(
      onRefresh: _loadExams,
      color: AppColors.getTextColor(context),
      backgroundColor: AppColors.primaryPurple,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upcoming Exams
            Text(
              'الاختبارات القادمة',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),

            SizedBox(height: 16),

            if (_upcomingExams.isEmpty)
              _buildEmptyState('لا توجد اختبارات قادمة')
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
              'الاختبارات المكتملة',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),

            SizedBox(height: 16),

            if (_completedExams.isEmpty)
              _buildEmptyState('لا توجد اختبارات مكتملة')
            else
              ..._completedExams.map((attempt) {
                final exam = attempt['exams'];
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _buildCompletedExamCard(attempt, exam),
                );
              }),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam, {required bool isUpcoming}) {
    final course = exam['courses'];
    final duration = exam['duration'] as int;
    final totalPoints = exam['total_points'] as int;

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
              onTap: () => _handleExamTap(exam['id']),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      exam['title'] ?? 'اختبار',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                    ),

                    SizedBox(height: 8),

                    // Course Name
                    if (course != null)
                      Text(
                        course['title'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextColor(context, secondary: true),
                        ),
                      ),

                    SizedBox(height: 12),

                    // Description
                    if (exam['description'] != null)
                      Text(
                        exam['description'],
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
                          label: _formatDuration(duration),
                        ),
                        SizedBox(width: 12),
                        _buildInfoChip(
                          icon: Icons.assignment,
                          label: '$totalPoints نقطة',
                        ),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Start Button
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ابدأ الاختبار',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.getTextColor(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

  Widget _buildCompletedExamCard(
    Map<String, dynamic> attempt,
    Map<String, dynamic> exam,
  ) {
    final score = attempt['score'] as int?;
    final totalPoints = attempt['total_points'] as int;
    final percentage = attempt['percentage'] as num?;
    final isPassed = attempt['is_passed'] as bool?;

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
              onTap: () => _viewExamResult(attempt['id']),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      exam['title'] ?? 'اختبار',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextColor(context),
                      ),
                    ),

                    SizedBox(height: 8),

                    // Course Name
                    if (exam['courses'] != null)
                      Text(
                        exam['courses']['title'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextColor(context, secondary: true),
                        ),
                      ),

                    SizedBox(height: 16),

                    // Score Info
                    Row(
                      children: [
                        _buildInfoChip(
                          icon: Icons.grade,
                          label: '$score/$totalPoints',
                        ),
                        SizedBox(width: 12),
                        if (percentage != null)
                          _buildScoreChip(
                            percentage.toDouble(),
                            isPassed ?? false,
                          ),
                      ],
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

  Widget _buildScoreChip(double percentage, bool isPassed) {
    final color = isPassed ? Colors.green : Colors.red;

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
          Icon(
            isPassed ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 16,
          ),
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

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes دقيقة';
    } else {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      if (mins == 0) {
        return '$hours ساعة';
      }
      return '$hours ساعة و $mins دقيقة';
    }
  }

  Future<void> _handleExamTap(String examId) async {
    try {
      // Check if user can take the exam
      final canTake = await _db.canTakeExam(examId);

      if (!canTake) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لقد تجاوزت الحد الأقصى لعدد المحاولات'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Start exam attempt
      await _db.startExamAttempt(examId);

      // Get exam details
      final exam = await _db.getExamById(examId);

      if (exam != null && mounted) {
        // Convert exam data to Exam model
        final examModel = _convertToExamModel(exam);

        // Navigate to exam taking screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamTakingScreen(
              exam: examModel,
            ),
          ),
        ).then((_) => _loadExams()); // Reload exams after completing
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _viewExamResult(String attemptId) async {
    try {
      final attemptDetails = await _db.getExamAttemptDetails(attemptId);

      if (attemptDetails != null && mounted) {
        // Convert to Exam model
        final examData = attemptDetails['exams'] as Map<String, dynamic>;
        final examModel = _convertToExamModel(examData);

        // Create completed exam with score
        final completedExam = Exam(
          id: examModel.id,
          title: examModel.title,
          description: examModel.description,
          courseId: examModel.courseId,
          courseName: examModel.courseName,
          questions: examModel.questions,
          duration: examModel.duration,
          totalPoints: attemptDetails['total_points'] as int,
          isCompleted: true,
          score: attemptDetails['score'] as int?,
        );

        // Navigate to exam result screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamResultScreen(
              exam: completedExam,
              userAnswers: null,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ في تحميل النتائج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Helper method to convert database exam to Exam model
  Exam _convertToExamModel(Map<String, dynamic> examData) {
    // Get questions
    final questionsData = examData['questions'] as List? ?? [];
    final questions = questionsData.map((q) {
      final qMap = q as Map<String, dynamic>;
      final options = qMap['options'] as List?;
      final correctAnswer = qMap['correct_answer'];

      return Question(
        id: qMap['id'] ?? '',
        text: qMap['question_text'] ?? '',
        options: options != null ? List<String>.from(options) : [],
        correctAnswer: correctAnswer is int ? correctAnswer : 0,
        explanation: qMap['explanation'],
        points: qMap['points'] ?? 1,
      );
    }).toList();

    // Get course name
    String courseName = '';
    if (examData['courses'] != null) {
      final courseData = examData['courses'] as Map<String, dynamic>;
      courseName = courseData['title'] ?? '';
    }

    return Exam(
      id: examData['id'] ?? '',
      title: examData['title'] ?? '',
      description: examData['description'] ?? '',
      courseId: examData['course_id'] ?? '',
      courseName: courseName,
      questions: questions,
      duration: examData['duration'] ?? 30,
      totalPoints: examData['total_points'] ?? 100,
    );
  }
}
