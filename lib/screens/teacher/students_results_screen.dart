import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import 'package:intl/intl.dart' as intl;
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
  List<Map<String, dynamic>> _filteredAttempts = [];
  String? _selectedExamId;
  String _searchQuery = '';
  bool _isLoading = true;
  String _sortBy = 'date'; // 'date', 'score', 'name'
  bool _sortAscending = false;

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
        _filterAttempts();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAttempts() {
    setState(() {
      _filteredAttempts = _attempts.where((attempt) {
        final name = attempt['users']?['full_name']?.toString().toLowerCase() ?? '';
        final email = attempt['users']?['email']?.toString().toLowerCase() ?? '';
        final examTitle = attempt['exams']?['title']?.toString().toLowerCase() ?? '';
        final search = _searchQuery.toLowerCase();
        
        return name.contains(search) || 
               email.contains(search) || 
               examTitle.contains(search);
      }).toList();

      // Apply Sorting
      _filteredAttempts.sort((a, b) {
        int result = 0;
        if (_sortBy == 'date') {
          final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(0);
          final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(0);
          result = dateA.compareTo(dateB);
        } else if (_sortBy == 'score') {
          final scoreA = a['percentage'] as num? ?? 0;
          final scoreB = b['percentage'] as num? ?? 0;
          result = scoreA.compareTo(scoreB);
        } else if (_sortBy == 'name') {
          final nameA = a['users']?['full_name']?.toString().toLowerCase() ?? '';
          final nameB = b['users']?['full_name']?.toString().toLowerCase() ?? '';
          result = nameA.compareTo(nameB);
        }
        return _sortAscending ? result : -result;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _buildHeader(),
              if (_exams.isNotEmpty) ...[
                _buildExamFilter(),
                SizedBox(height: 12),
                _buildSearchAndSort(),
                SizedBox(height: 12),
                _buildSummaryStats(),
                SizedBox(height: 12),
                _buildAnalyticsButton(),
              ],
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : _filteredAttempts.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            child: ListView.builder(
                              padding: EdgeInsets.all(20),
                              itemCount: _filteredAttempts.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: _buildAttemptCard(_filteredAttempts[index]),
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
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.getGlassColor(context, opacity: 0.2), width: 1),
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
            child: Text(
              'نتائج الطلاب',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamFilter() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.1),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.getGlassColor(context, opacity: 0.2), width: 1),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedExamId,
              dropdownColor: AppColors.primaryPurple,
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                labelText: 'اختر الاختبار',
                labelStyle: TextStyle(color: AppColors.getTextColor(context)),
                border: InputBorder.none,
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('جميع الاختبارات',
                      style: TextStyle(color: AppColors.getTextColor(context))),
                ),
                ..._exams.map((exam) {
                  return DropdownMenuItem<String>(
                    value: exam['id'],
                    child: Text(
                      exam['title'] ?? 'اختبار',
                      style: TextStyle(color: AppColors.getTextColor(context)),
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
            padding: EdgeInsets.all(20),
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
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                          Text(
                            examTitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.getTextColor(context, secondary: true),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
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
                SizedBox(height: 12),
                if (attempt['created_at'] != null)
                  Text(
                    'تاريخ المحاولة: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(attempt['created_at']).toLocal())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.getTextColor(context).withOpacity(0.5),
                    ),
                  ),
                SizedBox(height: 16),
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.assignment,
                      '${attempt['score']}/${attempt['total_points']}',
                    ),
                    SizedBox(width: 12),
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
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.2), width: 1),
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

  Widget _buildAnalyticsButton() {
    if (_selectedExamId == null) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
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
          icon: Icon(Icons.analytics_outlined),
          label: Text('عرض التحليلات والإحصائيات'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12),
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
        padding: EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.getMutedTextColor(context),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people, color: AppColors.getTextColor(context), size: 64),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد محاولات',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.getTextColor(context, secondary: true),
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

  Widget _buildSearchAndSort() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.getGlassColor(context, opacity: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.2), width: 1),
                  ),
                  child: TextField(
                    style: TextStyle(color: AppColors.getTextColor(context)),
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterAttempts();
                    },
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: AppColors.getTextColor(context).withOpacity(0.5)),
                      hintText: 'ابحث عن طالب...',
                      hintStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          _buildSortButton(),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.2), width: 1),
          ),
          child: PopupMenuButton<String>(
            icon: Icon(Icons.sort_rounded, color: AppColors.getTextColor(context)),
            color: AppColors.getSurfaceColor(context),
            onSelected: (value) {
              if (_sortBy == value) {
                _sortAscending = !_sortAscending;
              } else {
                _sortBy = value;
                _sortAscending = false;
              }
              _filterAttempts();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18),
                    SizedBox(width: 8),
                    Text('حسب التاريخ'),
                    if (_sortBy == 'date') ...[
                      Spacer(),
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'score',
                child: Row(
                  children: [
                    Icon(Icons.score_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('حسب الدرجة'),
                    if (_sortBy == 'score') ...[
                      Spacer(),
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18),
                    SizedBox(width: 8),
                    Text('حسب الاسم'),
                    if (_sortBy == 'name') ...[
                      Spacer(),
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    if (_attempts.isEmpty) return SizedBox.shrink();

    final totalAttempts = _attempts.length;
    final uniqueStudents = _attempts.map((a) => a['user_id']).toSet().length;
    final passedAttempts = _attempts.where((a) => a['is_passed'] == true).length;
    final passRate = totalAttempts > 0 ? (passedAttempts / totalAttempts) * 100 : 0.0;
    final avgScore = totalAttempts > 0 ? _attempts.fold<double>(0, (prev, a) => prev + (a['percentage'] as num? ?? 0)) / totalAttempts : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSummaryCard('المحاولات', '$totalAttempts', Colors.blue, Icons.history),
            SizedBox(width: 12),
            _buildSummaryCard('الطلاب', '$uniqueStudents', Colors.purple, Icons.people),
            SizedBox(width: 12),
            _buildSummaryCard('نسبة النجاح', '${passRate.toStringAsFixed(1)}%', Colors.green, Icons.check_circle_outline),
            SizedBox(width: 12),
            _buildSummaryCard('متوسط الدرجة', '${avgScore.toStringAsFixed(1)}%', Colors.orange, Icons.analytics),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color, IconData icon) {
    return SizedBox(
      width: 110,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
