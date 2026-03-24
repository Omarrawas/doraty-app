import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/tex_view_widget.dart';
import '../../core/utils/safe_parser.dart';

class ReviewExamScreen extends StatefulWidget {
  final String attemptId;

  ReviewExamScreen({super.key, required this.attemptId});

  @override
  State<ReviewExamScreen> createState() => _ReviewExamScreenState();
}

class _ReviewExamScreenState extends State<ReviewExamScreen> {
  final DatabaseService _db = DatabaseService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _attemptData;

  @override
  void initState() {
    super.initState();
    _loadAttemptDetails();
  }

  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic> _answersMap = {};

  Future<void> _loadAttemptDetails() async {
    try {
      final data = await _db.getExamAttemptDetails(widget.attemptId);
      
      if (data != null) {
         final examId = data['exam_id'];
         final questionsResponse = await _db.supabaseClient
             .from('questions')
             .select()
             .eq('exam_id', examId);
             
         final questionsList = SafeParser.safeMapList(questionsResponse);
         
         // Map answers by question_id for easy lookup
         final answersList = data['answers'] as List;
         final answersMap = {
           for (var answer in answersList) 
             (answer['question_id'] as String): answer as Map<String, dynamic>
         };

         setState(() {
           _attemptData = data;
           _questions = questionsList;
           _answersMap = answersMap;
           _isLoading = false;
         });
      } else {
        setState(() => _isLoading = false);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_attemptData == null) {
      return Scaffold(
        body: Center(child: Text('لم يتم العثور على تفاصيل المحاولة')),
      );
    }

    final score = _attemptData!['score'];
    // Calculate total points from all questions dynamically
    final calculatedTotalPoints = _questions.fold(0, (sum, q) => sum + (q['points'] as int? ?? 0));

    // Fallback if no questions (shouldn't happen)
    final totalPointsToUse = calculatedTotalPoints > 0 ? calculatedTotalPoints : _attemptData!['total_points'];

    return Scaffold(
      appBar: AppBar(
        title: Text('مراجعة الإجابات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildScoreSummary(score, totalPointsToUse),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final question = _questions[index];
                    final answer = _answersMap[question['id']];
                    return _buildAnswerCard(answer, question, index + 1);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSummary(dynamic score, dynamic totalPoints) {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
             Text(
                'النتيجة النهائية',
                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70)),
              ),
              SizedBox(height: 8),
              Text(
                '${((score ?? 0) / (totalPoints > 0 ? totalPoints : 1) * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(score, totalPoints),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(Map<String, dynamic>? answer, Map<String, dynamic> question, int index) {
    final isCorrect = answer != null ? (answer['is_correct'] as bool) : false;
    final userAnswer = answer?['user_answer'];
    final wasAnswered = answer != null;
    
    // In DB, options are stored in question['options'] as List<dynamic>
    final options = List<String>.from(question['options'] ?? []);
    final correctIndex = question['correct_answer'] as int;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: AppColors.getMutedTextColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: wasAnswered 
                      ? (isCorrect ? Colors.green : Colors.red)
                      : Colors.grey,
                  child: Icon(
                    wasAnswered 
                        ? (isCorrect ? Icons.check : Icons.close)
                        : Icons.question_mark,
                    size: 16,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'السؤال $index',
                  style: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.70),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            TexViewWidget(
              question['question_text'] ?? '',
              style: TextStyle(
                color: AppColors.getTextColor(context),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            ...List.generate(options.length, (optIndex) {
              final isUserSelection = userAnswer == optIndex; // Assuming int answers for now
              final isCorrectOption = correctIndex == optIndex;

              Color color = Colors.white.withOpacity(0.05);
              Color borderColor = Colors.transparent;
              IconData? icon;

              if (isUserSelection) {
                if (isCorrect) {
                  color = Colors.green.withOpacity(0.2);
                  borderColor = Colors.green;
                  icon = Icons.check_circle;
                } else {
                  color = Colors.red.withOpacity(0.2);
                  borderColor = Colors.red;
                  icon = Icons.cancel;
                }
              } else if (isCorrectOption) {
                  // Show correct answer (always show it even if user missed it or skipped)
                  if (!isCorrect) { // If user was wrong or skipped
                      color = Colors.green.withOpacity(0.1);
                      borderColor = Colors.green.withOpacity(0.5);
                      icon = Icons.check_circle_outline;
                  }
              }

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TexViewWidget(
                        options[optIndex],
                        style: TextStyle(color: AppColors.getTextColor(context)),
                      ),
                    ),
                    if (icon != null)
                      Icon(icon, color: borderColor, size: 20),
                  ],
                ),
              );
            }),
            if (question['explanation'] != null && question['explanation'].isNotEmpty) ...[
               SizedBox(height: 12),
               Container(
                 padding: EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.blue.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Icon(Icons.info_outline, color: Colors.blue, size: 20),
                     SizedBox(width: 8),
                     Expanded(
                      child: TexViewWidget(
                         'توضيح: ${question['explanation']}',
                         style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70), fontSize: 13),
                       ),
                     ),
                   ],
                 ),
               ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(dynamic score, dynamic total) {
    if (score == null || total == null || total == 0) return Colors.white;
    final percentage = (score / total);
    if (percentage >= 0.8) return Colors.greenAccent;
    if (percentage >= 0.5) return Colors.orangeAccent;
    return Colors.redAccent;
  }
}
