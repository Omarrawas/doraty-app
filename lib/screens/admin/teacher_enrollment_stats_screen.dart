import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/string_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../../core/utils/error_utils.dart';
import 'package:go_router/go_router.dart';

class TeacherEnrollmentStatsScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;
  final String? avatarUrl;

  const TeacherEnrollmentStatsScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    this.avatarUrl,
  });

  @override
  State<TeacherEnrollmentStatsScreen> createState() => _TeacherEnrollmentStatsScreenState();
}

class _TeacherEnrollmentStatsScreenState extends State<TeacherEnrollmentStatsScreen> {
  final DatabaseService _db = DatabaseService();
  final intl.NumberFormat _currencyFormat =
      intl.NumberFormat.currency(symbol: 'ل.س ', decimalDigits: 0);

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final stats = await _db.getTeacherDetailedStats(widget.teacherId);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                else if (_stats.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 64,
                            color: AppColors.getTextColor(context).withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'لا توجد بيانات متاحة حالياً',
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadStats,
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadStats,
                      color: AppColors.primaryPurple,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        children: [
                          _buildStatsGrid(),
                          const SizedBox(height: 24),
                          _buildSectionTitle('أداء الكورسات'),
                          const SizedBox(height: 12),
                          ...(_stats['courses_breakdown'] as List? ?? [])
                              .map((course) => _buildCourseStatCard(course)),
                          const SizedBox(height: 24),
                          _buildSectionTitle('أحدث الاشتراكات (آخر 10)'),
                          const SizedBox(height: 12),
                          ...(_stats['recent_enrollments'] as List? ?? [])
                              .map((enrollment) => _buildRecentEnrollmentCard(enrollment)),
                          const SizedBox(height: 30),
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
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => context.pop(),
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
                  'إحصائيات المدرس',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context, secondary: true),
                  ),
                ),
                Text(
                  StringUtils.cleanTeacherName(widget.teacherName),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: IconButton(
                  icon: Icon(Icons.print, color: AppColors.getTextColor(context)),
                  onPressed: _showMonthSelectionDialog,
                  tooltip: 'طباعة التقرير الشهري',
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          CircleAvatar(
            radius: 24,
            backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
            child: widget.avatarUrl == null ? Icon(Icons.person, color: AppColors.getTextColor(context)) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildSummaryCard(
          'إجمالي الدخل',
          _currencyFormat.format(_stats['total_revenue'] ?? 0),
          Icons.payments,
          Colors.greenAccent,
        ),
        _buildSummaryCard(
          'إجمالي الطلاب',
          '${_stats['student_count'] ?? 0}',
          Icons.people,
          Colors.blueAccent,
        ),
        _buildSummaryCard(
          'عدد الكورسات',
          '${_stats['course_count'] ?? 0}',
          Icons.book,
          Colors.orangeAccent,
        ),
        _buildSummaryCard(
          'متوسط دخل الكورس',
          _currencyFormat.format((_stats['total_revenue'] ?? 0) /
              ((_stats['course_count'] ?? 1) == 0 ? 1 : (_stats['course_count'] ?? 1))),
          Icons.analytics,
          Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2), width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(height: 8),
              Text(label, style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 11)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.normal, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.normal),
    );
  }

  Widget _buildCourseStatCard(Map<String, dynamic> course) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getMutedTextColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: course['image_url'] != null
                        ? DecorationImage(image: NetworkImage(course['image_url']), fit: BoxFit.cover)
                        : null,
                    color: Colors.black26,
                  ),
                  child: course['image_url'] == null ? Icon(Icons.book, color: AppColors.getTextColor(context).withOpacity(0.24)) : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course['title'],
                          style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.normal)),
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.blueAccent, size: 12),
                          SizedBox(width: 4),
                          Text('${course['student_count']} طالب',
                              style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60), fontSize: 12)),
                          SizedBox(width: 12),
                          Icon(Icons.payments, color: Colors.greenAccent, size: 12),
                          SizedBox(width: 4),
                          Text(_currencyFormat.format(course['revenue']),
                              style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentEnrollmentCard(Map<String, dynamic> enrollment) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        tileColor: Colors.white.withOpacity(0.03),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
          child: Text((enrollment['user_full_name']?[0] ?? 'U').toUpperCase(),
              style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14)),
        ),
        title: Text(enrollment['user_full_name'] ?? 'مستخدم',
            style: TextStyle(color: AppColors.getTextColor(context), fontSize: 14, fontWeight: FontWeight.normal)),
        subtitle: Text(enrollment['course_title'] ?? '',
            style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 11)),
        trailing: Text(
          intl.DateFormat('MM/dd')
              .format(DateTime.parse(enrollment['enrolled_at'])),
          style: TextStyle(color: AppColors.getMutedTextColor(context), fontSize: 11),
        ),
      ),
    );
  }

  void _showMonthSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => _MonthSelectionDialog(
        onGenerateReport: (selectedMonths) {
          if (selectedMonths.isNotEmpty) {
            _generateAndPrintReport(selectedMonths);
          }
        },
      ),
    );
  }

  Future<void> _generateAndPrintReport(List<DateTime> selectedMonths) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: AppColors.getTextColor(context)),
      ),
    );

    try {
      final startDate = selectedMonths.reduce((a, b) => a.isBefore(b) ? a : b);
      final endDate = DateTime(
        selectedMonths.reduce((a, b) => a.isAfter(b) ? a : b).year,
        selectedMonths.reduce((a, b) => a.isAfter(b) ? a : b).month + 1,
        0,
      );

      final stats = await _db.getTeacherMonthlyStatistics(
        widget.teacherId,
        startDate: startDate,
        endDate: endDate,
      );

      if (mounted) Navigator.pop(context); // Close loading

      final pdf = await _createPDF(stats, selectedMonths);

      await Printing.layoutPdf(
        onLayout: (format) => pdf.save(),
        name:
            'Report_${widget.teacherName}_${intl.DateFormat('yyyyMMdd').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<pw.Document> _createPDF(
      Map<String, dynamic> stats, List<DateTime> selectedMonths) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final ttfBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(30),
        ),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('التقرير الإحصائي الشهري التفصيلي',
                        style: pw.TextStyle(
                            fontSize: 24,
                            font: ttfBold,
                            color: PdfColors.blue900)),
                    pw.Text('المدرس: ${widget.teacherName}',
                        style: pw.TextStyle(fontSize: 16, font: ttf)),
                    if (stats['start_date'] != null &&
                        stats['end_date'] != null)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 4),
                        child: pw.Text(
                            'الفترة: ${_formatMonthYear(stats['start_date'].toString().substring(0, 7))} - ${_formatMonthYear(stats['end_date'].toString().substring(0, 7))}',
                            style: pw.TextStyle(
                                fontSize: 10,
                                font: ttf,
                                color: PdfColors.grey700)),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                        'تاريخ الإنشاء: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Summary Cards
          pw.Row(
            children: [
              _buildPDFStatCard(
                  'إجمالي الدخل',
                  _currencyFormat.format(_safeDouble(stats['total_revenue'])),
                  PdfColors.green800,
                  ttfBold),
              pw.SizedBox(width: 8),
              _buildPDFStatCard(
                  'إجمالي الطلاب',
                  (stats['total_users'] ?? 0).toString(),
                  PdfColors.blue800,
                  ttfBold),
              pw.SizedBox(width: 8),
              _buildPDFStatCard(
                  'الاشتراكات الجديدة',
                  (stats['total_enrollments'] ?? 0).toString(),
                  PdfColors.orange800,
                  ttfBold),
            ],
          ),

          pw.SizedBox(height: 25),

          // Monthly Table
          pw.Text('الخلاصة الشهرية',
              style: pw.TextStyle(fontSize: 16, font: ttfBold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('الشهر', ttfBold, isHeader: true),
                  _buildTableCell('الاشتراكات', ttfBold, isHeader: true),
                  _buildTableCell('طلاب جدد', ttfBold, isHeader: true),
                  _buildTableCell('الإيرادات', ttfBold, isHeader: true),
                  _buildTableCell('الاختبارات', ttfBold, isHeader: true),
                ],
              ),
              ...(stats['monthly_breakdown'] as List? ?? [])
                  .map((m) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(
                            _formatMonthYear(m['month'] ?? ''), ttf),
                        _buildTableCell(
                            (m['enrollments'] ?? 0).toString(), ttf),
                        _buildTableCell((m['students'] ?? 0).toString(), ttf),
                        _buildTableCell(
                            _currencyFormat.format(_safeDouble(m['revenue'])),
                            ttf),
                        _buildTableCell((m['attempts'] ?? 0).toString(), ttf),
                      ],
                    );
                  })
                  .toList()
                  .cast<pw.TableRow>(),
            ],
          ),

          pw.SizedBox(height: 25),

          // Detailed Table
          pw.Text('تفاصيل المشتركين والمبالغ',
              style: pw.TextStyle(fontSize: 16, font: ttfBold)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _buildTableCell('اسم الطالب', ttfBold, isHeader: true),
                  _buildTableCell('الكورس', ttfBold, isHeader: true),
                  _buildTableCell('المبلغ', ttfBold, isHeader: true),
                  _buildTableCell('التاريخ', ttfBold, isHeader: true),
                ],
              ),
              ...(stats['enrollments'] as List? ?? [])
                  .map((e) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(e['user_full_name'] ?? '-', ttf),
                        _buildTableCell(e['course_title'] ?? '-', ttf),
                        _buildTableCell(
                            _currencyFormat
                                .format(_safeDouble(e['course_price'])),
                            ttf),
                        _buildTableCell(_formatFullDate(e['enrolled_at']), ttf),
                      ],
                    );
                  })
                  .toList()
                  .cast<pw.TableRow>(),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFStatCard(
      String label, String value, PdfColor color, pw.Font fontBold) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
            pw.Text(value,
                style: pw.TextStyle(
                    color: PdfColors.white, fontSize: 16, font: fontBold)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 12 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatMonthYear(String monthKey) {
    if (monthKey.isEmpty) return '-';
    try {
      final parts = monthKey.split('-');
      if (parts.length < 2) return monthKey;
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return intl.DateFormat('MMMM yyyy', 'ar').format(date);
    } catch (e) {
      return monthKey;
    }
  }

  String _formatFullDate(dynamic dateValue) {
    if (dateValue == null) return '-';
    try {
      DateTime? date;
      if (dateValue is DateTime) {
        date = dateValue;
      } else if (dateValue is String) {
        String s = dateValue.trim();
        if (s.length >= 10 && s[10] == ' ') {
          s = s.replaceRange(10, 11, 'T');
        }
        date = DateTime.tryParse(s);
      }
      if (date != null) {
        return intl.DateFormat('yyyy/MM/dd HH:mm', 'ar').format(date);
      }
    } catch (_) {}
    return dateValue.toString();
  }
}

class _MonthSelectionDialog extends StatefulWidget {
  final Function(List<DateTime>) onGenerateReport;

  const _MonthSelectionDialog({required this.onGenerateReport});

  @override
  State<_MonthSelectionDialog> createState() => _MonthSelectionDialogState();
}

class _MonthSelectionDialogState extends State<_MonthSelectionDialog> {
  final Map<DateTime, bool> _selectedMonths = {};

  @override
  void initState() {
    super.initState();
    _initializeMonths();
  }

  void _initializeMonths() {
    final now = DateTime.now();
    for (int i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      _selectedMonths[month] = false;
    }
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      _selectedMonths.updateAll((key, _) => value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedMonths.values.where((v) => v).length;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: AppColors.getGlassColor(context, opacity: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white24),
        ),
        title: Text('اختر الأشهر للتقرير',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => _toggleSelectAll(true),
                    icon: Icon(Icons.select_all, size: 18),
                    label: Text('تحديد الكل'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.blueAccent),
                  ),
                  TextButton.icon(
                    onPressed: () => _toggleSelectAll(false),
                    icon: Icon(Icons.deselect, size: 18),
                    label: Text('إلغاء الكل'),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  ),
                ],
              ),
              Divider(color: AppColors.getTextColor(context).withOpacity(0.12)),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _selectedMonths.keys.toList().reversed.map((month) {
                    final monthName =
                        intl.DateFormat('MMMM yyyy', 'ar').format(month);
                    return CheckboxListTile(
                      value: _selectedMonths[month],
                      onChanged: (val) =>
                          setState(() => _selectedMonths[month] = val!),
                      title: Text(monthName,
                          style: TextStyle(color: AppColors.getTextColor(context))),
                      activeColor: AppColors.primaryPurple,
                      checkColor: Colors.white,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.60))),
          ),
          ElevatedButton(
            onPressed: selectedCount > 0
                ? () {
                    final selected = _selectedMonths.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList();
                    Navigator.pop(context);
                    widget.onGenerateReport(selected);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('إنشاء التقرير ($selectedCount)'),
          ),
        ],
      ),
    );
  }
}
