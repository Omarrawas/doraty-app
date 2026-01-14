import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import 'exam_stats_screen.dart';

class StudentsResultsScreen extends StatefulWidget {
  final String? examId;

  const StudentsResultsScreen({super.key, this.examId});

  @override
  State<StudentsResultsScreen> createState() => _StudentsResultsScreenState();
}

class _StudentsResultsScreenState extends State<StudentsResultsScreen> {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _attempts = [];
  List<Map<String, dynamic>> _exams = [];
  String? _selectedExamId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedExamId = widget.examId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final exams = await _db.getTeacherExams();
      final attempts = await _db.getExamAttemptsForTeacher(
        examId: _selectedExamId,
      );

      setState(() {
        _exams = exams;
        _attempts = attempts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              if (_exams.isNotEmpty) ...[
                _buildExamFilter(),
                const SizedBox(height: 12),
                _buildAnalyticsButton(),
              ],
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : _attempts.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _attempts.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildAttemptCard(_attempts[index]),
                                );
                              },
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
                      color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'نتائج الطلاب',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedExamId,
              dropdownColor: AppColors.primaryPurple,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'اختر الاختبار',
                labelStyle: TextStyle(color: Colors.white),
                border: InputBorder.none,
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('جميع الاختبارات',
                      style: TextStyle(color: Colors.white)),
                ),
                ..._exams.map((exam) {
                  return DropdownMenuItem<String>(
                    value: exam['id'],
                    child: Text(
                      exam['title'] ?? 'اختبار',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() => _selectedExamId = value);
                _loadData();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final percentage = attempt['percentage'] as num? ?? 0;
    final isPassed = attempt['is_passed'] as bool? ?? false;
    final studentName = attempt['users']?['full_name'] ?? 'طالب';
    final examTitle = attempt['exams']?['title'] ?? 'اختبار';

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
            border:
                Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: (isPassed ? Colors.green : Colors.red)
                          .withOpacity(0.3),
                      child: Icon(
                        isPassed ? Icons.check : Icons.close,
                        color: isPassed ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            examTitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: (isPassed ? Colors.green : Colors.red)
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isPassed ? Colors.green : Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.assignment,
                      '${attempt['score']}/${attempt['total_points']}',
                    ),
                    const SizedBox(width: 12),
                    _buildInfoChip(
                      Icons.access_time,
                      '${attempt['time_taken'] ?? 0} دقيقة',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsButton() {
    if (_selectedExamId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            final exam = _exams.firstWhere((e) => e['id'] == _selectedExamId);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExamStatsScreen(
                  examId: _selectedExamId!,
                  examTitle: exam['title'],
                ),
              ),
            );
          },
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('عرض التحليلات والإحصائيات'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد محاولات',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
