import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../widgets/glass_card.dart';

class CourseStatisticsScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseStatisticsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseStatisticsScreen> createState() => _CourseStatisticsScreenState();
}

class _CourseStatisticsScreenState extends State<CourseStatisticsScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _enrollments = [];
  Map<String, int> _statusDistribution = {};
  List<FlSpot> _enrollmentTrend = [];
  double _totalRevenue = 0;
  int _activeEnrollments = 0;
  
  // Removed unused _currencyFormat


  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final enrollments = await _db.getAllEnrollments(courseId: widget.courseId);
      
      if (mounted) {
        _processData(enrollments);
        setState(() {
          _enrollments = enrollments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorUtils.getFriendlyErrorMessage(e);
        });
      }
    }
  }

  void _processData(List<Map<String, dynamic>> enrollments) {
    _statusDistribution = {};
    _totalRevenue = 0;
    _activeEnrollments = 0;

    final now = DateTime.now();
    final Map<int, int> dayCounts = {};
    for (int i = 0; i < 7; i++) {
      dayCounts[i] = 0;
    }

    for (var enrollment in enrollments) {
      final status = enrollment['status'] ?? 'unknown';
      _statusDistribution[status] = (_statusDistribution[status] ?? 0) + 1;
      if (status == 'active') _activeEnrollments++;

      if (status != 'cancelled') {
        _totalRevenue += (enrollment['courses']['price'] as num? ?? 0).toDouble();
      }

      final enrolledAtStr = enrollment['enrolled_at'];
      if (enrolledAtStr != null) {
        final enrolledAt = DateTime.parse(enrolledAtStr);
        final difference = now.difference(enrolledAt).inDays;
        if (difference >= 0 && difference < 7) {
          dayCounts[6 - difference] = (dayCounts[6 - difference] ?? 0) + 1;
        }
      }
    }

    _enrollmentTrend = dayCounts.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();
    
    // Sort enrollments for "Recent" list
    _enrollments.sort((a, b) {
      final enrolledA = a['enrolled_at'];
      final enrolledB = b['enrolled_at'];
      if (enrolledA == null || enrolledB == null) return 0;
      final dateA = DateTime.parse(enrolledA);
      final dateB = DateTime.parse(enrolledB);
      return dateB.compareTo(dateA);
    });
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    
    // Load fonts for Arabic support
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final ttfBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(32),
        ),
        build: (context) => [
          _buildPdfHeader(ttfBold),
          pw.SizedBox(height: 20),
          _buildPdfSummary(ttfBold),
          pw.SizedBox(height: 30),
          _buildPdfTrendTable(ttfBold),
          pw.SizedBox(height: 30),
          _buildPdfRecentEnrollments(ttfBold),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader(pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('تقرير إحصائيات الدورة', style: pw.TextStyle(fontSize: 24, font: fontBold, color: PdfColors.purple)),
            pw.Text('أكاديمية دوراتي', style: pw.TextStyle(fontSize: 16, font: fontBold, color: PdfColors.grey700)),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.purple100),
        pw.SizedBox(height: 10),
        pw.Text('اسم الدورة: ${widget.courseTitle}', style: pw.TextStyle(fontSize: 14, font: fontBold)),
        pw.Text('تاريخ التقرير: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildPdfSummary(pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildPdfSummaryItem('إجمالي الطلاب', _enrollments.length.toString(), fontBold),
          _buildPdfSummaryItem('الطلاب النشطين', _activeEnrollments.toString(), fontBold),
          _buildPdfSummaryItem('الإيرادات', '${_totalRevenue.toStringAsFixed(0)} ل.س', fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, font: fontBold, color: PdfColors.purple900)),
      ],
    );
  }

  pw.Widget _buildPdfTrendTable(pw.Font fontBold) {
    const days = ['منذ 6 أيام', 'منذ 5 أيام', 'منذ 4 أيام', 'منذ 3 أيام', 'منذ يومين', 'أمس', 'اليوم'];
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('توجه الاشتراكات (آخر 7 أيام)', style: pw.TextStyle(fontSize: 14, font: fontBold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['الفترة', 'عدد الاشتراكات'],
          data: _enrollmentTrend.asMap().entries.map((e) {
            return [days[e.key], e.value.y.toInt().toString()];
          }).toList(),
          headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
          cellAlignment: pw.Alignment.center,
        ),
      ],
    );
  }

  pw.Widget _buildPdfRecentEnrollments(pw.Font fontBold) {
    final recent = _enrollments.take(10).toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('آخر 10 مشتركين', style: pw.TextStyle(fontSize: 14, font: fontBold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['الطالب', 'التاريخ', 'الحالة'],
          data: recent.map((e) {
            final user = e['users'] ?? {};
            final date = DateTime.parse(e['enrolled_at'] ?? DateTime.now().toIso8601String());
            return [
              user['full_name'] ?? 'طالب جديد',
              intl.DateFormat('yyyy/MM/dd').format(date),
              _getStatusLabel(e['status'] ?? 'unknown'),
            ];
          }).toList(),
          headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
          cellAlignment: pw.Alignment.center,
        ),
      ],
    );
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
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                      : _errorMessage != null
                          ? _buildErrorState()
                          : RefreshIndicator(
                              onRefresh: _loadStats,
                              color: AppColors.primaryPurple,
                              child: _buildStatsContent(),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildGlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحليلات الدورة',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextColor(context),
                  ),
                ),
                Text(
                  widget.courseTitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.getTextColor(context).withOpacity(0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildGlassIconButton(
            icon: Icons.picture_as_pdf_rounded,
            onPressed: () {
              context.push(
                '/admin/pdf-preview',
                extra: {
                  'generator': _generatePdf,
                  'title': 'تقرير إحصائيات الدورة',
                  'filename': 'stats_${widget.courseId}',
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onPressed}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getGlassColor(context, opacity: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.2), width: 1),
          ),
          child: IconButton(
            icon: Icon(icon, color: AppColors.getTextColor(context), size: 20),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildMetricsGrid(),
        const SizedBox(height: 24),
        _buildTrendChart(),
        const SizedBox(height: 24),
        _buildDistributionChart(),
        const SizedBox(height: 24),
        _buildRecentEnrollments(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          title: 'إجمالي الطلاب',
          value: _enrollments.length.toString(),
          subtitle: 'مشترك',
          icon: Icons.people_alt_rounded,
          color: Colors.blue,
        ),
        _buildMetricCard(
          title: 'الإيرادات',
          value: _totalRevenue >= 1000000 
              ? '${(_totalRevenue / 1000000).toStringAsFixed(1)}M' 
              : _totalRevenue >= 1000 
                  ? '${(_totalRevenue / 1000).toStringAsFixed(0)}K'
                  : _totalRevenue.toStringAsFixed(0),
          subtitle: 'ليرة سورية',
          icon: Icons.payments_rounded,
          color: Colors.green,
        ),
        _buildMetricCard(
          title: 'الطلاب النشطين',
          value: _activeEnrollments.toString(),
          subtitle: 'نشط حالياً',
          icon: Icons.person_search_rounded,
          color: Colors.orange,
        ),
        _buildMetricCard(
          title: 'معدل الإكمال',
          value: '42%', // Mock data for now
          subtitle: 'متوسط الدروس',
          icon: Icons.insights_rounded,
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.getTextColor(context).withOpacity(0.5),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart() {
    double maxY = 1;
    if (_enrollmentTrend.isNotEmpty) {
      final maxVal = _enrollmentTrend.map((e) => e.y).reduce((a, b) => a > b ? a : b);
      if (maxVal > 0) maxY = (maxVal * 1.2).ceilToDouble();
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'توجه الاشتراكات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'آخر 7 أيام',
                  style: TextStyle(fontSize: 10, color: Colors.blue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.getTextColor(context).withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const days = ['6d', '5d', '4d', '3d', '2d', '1d', 'اليوم'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
                              style: TextStyle(
                                color: AppColors.getTextColor(context).withOpacity(0.4),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: _enrollmentTrend,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.withOpacity(0.2),
                          Colors.purple.withOpacity(0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionChart() {
    final List<PieChartSectionData> sections = [];
    final statusColors = {
      'active': Colors.green,
      'cancelled': Colors.red,
      'expired': Colors.orange,
    };

    _statusDistribution.forEach((status, count) {
      if (count > 0) {
        sections.add(PieChartSectionData(
          color: statusColors[status] ?? Colors.grey,
          value: count.toDouble(),
          title: '', 
          radius: 12,
          showTitle: false,
        ));
      }
    });

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حالات الاشتراكات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sections: sections.isEmpty
                        ? [PieChartSectionData(color: Colors.grey.withOpacity(0.1), value: 1, radius: 10, showTitle: false)]
                        : sections,
                    sectionsSpace: 5,
                    centerSpaceRadius: 40,
                    startDegreeOffset: -90,
                  ),
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  children: _statusDistribution.entries.map((e) {
                    final color = statusColors[e.key] ?? Colors.grey;
                    final percentage = _enrollments.isEmpty 
                        ? '0' 
                        : ((e.value / _enrollments.length) * 100).toStringAsFixed(0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getStatusLabel(e.key),
                              style: TextStyle(
                                color: AppColors.getTextColor(context).withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Text(
                            '$percentage%',
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEnrollments() {
    final recent = _enrollments.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'آخر المشتركين',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'لا يوجد مشتركين حالياً',
                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5)),
              ),
            ),
          )
        else
          ...recent.map((enrollment) {
            final user = enrollment['users'] ?? {};
            final enrolledAtStr = enrollment['enrolled_at'];
            final enrolledAt = enrolledAtStr != null ? DateTime.parse(enrolledAtStr) : DateTime.now();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryPurple.withOpacity(0.1),
                      backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                      child: user['avatar_url'] == null ? Icon(Icons.person, color: AppColors.primaryPurple) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user['full_name'] ?? 'طالب جديد',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                          Text(
                            intl.DateFormat('yyyy/MM/dd HH:mm').format(enrolledAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.getTextColor(context).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (enrollment['status'] == 'active' ? Colors.green : Colors.orange).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getStatusLabel(enrollment['status'] ?? 'unknown'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: enrollment['status'] == 'active' ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active': return 'نشط';
      case 'cancelled': return 'ملغي';
      case 'expired': return 'منتهي';
      default: return 'غير معروف';
    }
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
          const SizedBox(height: 16),
          Text(
            'حدث خطأ أثناء تحميل البيانات',
            style: TextStyle(color: AppColors.getTextColor(context), fontSize: 16),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5), fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadStats,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
