import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../widgets/dynamic_gradient_background.dart';

class ExamStatsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  ExamStatsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ExamStatsScreen> createState() => _ExamStatsScreenState();
}

class _ExamStatsScreenState extends State<ExamStatsScreen> {
  final DatabaseService _db = DatabaseService.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _db.getExamStats(widget.examId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                      : _stats == null || (_stats!['attempts'] as List).isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد بيانات كافية للتحليل',
                                style: TextStyle(
                                  color: AppColors.getTextColor(context)
                                      .withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryCards(),
                                  SizedBox(height: 24),
                                  Text(
                                    'أداء الأسئلة',
                                    style: TextStyle(
                                      color: AppColors.getTextColor(context),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  _buildQuestionsList(),
                                  SizedBox(height: 32),
                                ],
                              ),
                            ),
                ),
              ],
            ),
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
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.3),
                      width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحليلات الاختبار',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  widget.examTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final attemptCount = _stats!['attemptCount'] as int;
    final averageScore = _stats!['averageScore'] as double;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'عدد المحاولات',
            attemptCount.toString(),
            Icons.people,
            Colors.blueAccent,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'متوسط الدرجات',
            averageScore.toStringAsFixed(1),
            Icons.score,
            Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.getGlassColor(context, opacity: 0.2)),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.getTextColor(context).withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsList() {
    final questions = _stats!['questionStats'] as List;
    
    return ListView.separated(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: questions.length,
      separatorBuilder: (_, __) => SizedBox(height: 16),
      itemBuilder: (context, index) {
        final q = questions[index];
        final total = q['totalCount'] as int;
        final correct = q['correctCount'] as int;
        final wrong = q['wrongCount'] as int;
        final correctPercentage = total > 0 ? (correct / total) : 0.0;
        
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getGlassColor(context, opacity: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'س ${index + 1}',
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          q['questionText'],
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.getMutedTextColor(context),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: correctPercentage,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.greenAccent, Colors.tealAccent],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'إجابات صحيحة: $correct (${(correctPercentage * 100).toStringAsFixed(0)}%)',
                            style: TextStyle(
                                color: Colors.greenAccent.withOpacity(0.9),
                                fontSize: 12),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'خاطئة: $wrong',
                            style: TextStyle(
                                color: Colors.redAccent.withOpacity(0.9),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
