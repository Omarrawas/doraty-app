import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';

class ExamStatsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const ExamStatsScreen({
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
    return Scaffold(
      appBar: AppBar(
        title: Text('تحليلات: ${widget.examTitle}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _stats == null || (_stats!['attempts'] as List).isEmpty
                  ? const Center(child: Text('لا توجد بيانات كافية للتحليل', style: TextStyle(color: Colors.white)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCards(),
                          const SizedBox(height: 24),
                          const Text(
                            'أداء الأسئلة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildQuestionsList(),
                        ],
                      ),
                    ),
        ),
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
        const SizedBox(width: 16),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList() {
    final questions = _stats!['questionStats'] as List;
    
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final q = questions[index];
        final total = q['totalCount'] as int;
        final correct = q['correctCount'] as int;
        final wrong = q['wrongCount'] as int;
        final correctPercentage = total > 0 ? (correct / total) : 0.0;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'س ${index + 1}: ${q['questionText']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: (correctPercentage * 100).toInt(),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - correctPercentage) * 100).toInt(),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'صح: $correct (${(correctPercentage * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(color: Colors.green, fontSize: 12),
                  ),
                  Text(
                    'خطأ: $wrong',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
