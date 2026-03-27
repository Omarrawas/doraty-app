import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/constants/app_strings.dart';
import '../../core/localization/locale_provider.dart';

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final DatabaseService _db = DatabaseService();
  DateTimeRange? _dateRange;
  String? _selectedCourseId;
  List<Map<String, dynamic>> _courses = [];

  String _t(String key) {
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
    return AppStrings.get(key, locale);
  }

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    try {
      final courses = await _db.getCourses();
      if (mounted) {
        setState(() {
          _courses = courses;
        });
      }
    } catch (e) {
      debugPrint('Error loading filters: $e');
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryPurple,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final reportData = await _db.getFinancialReport(
      startDate: _dateRange?.start,
      endDate: _dateRange?.end,
      courseId: _selectedCourseId,
      // teacherId: _selectedTeacherId, // Add teacher filter UI if needed
    );

    final pdf = pw.Document();
    
    // Load font for Arabic support
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final ttfBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(
            base: ttf,
            bold: ttfBold,
          ),
          textDirection: pw.TextDirection.rtl,
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        build: (context) => [
          _buildHeader(reportData, ttfBold),
          pw.SizedBox(height: 20),
          _buildSummary(reportData, ttfBold),
          pw.SizedBox(height: 20),
          _buildTable(reportData, ttfBold),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(Map<String, dynamic> data, pw.Font fontBold) {
    return pw.Header(
      level: 0,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(_t('financial_report'),
                  style: pw.TextStyle(fontSize: 24, font: fontBold, color: PdfColors.purple)),
              pw.Text(_t('platform_name'),
                  style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('${_t('period')}: ${data['period']}',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('${_t('print_date')}: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummary(Map<String, dynamic> data, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem(_t('total_revenue'),
              '${(data['totalEarnings'] as double).toStringAsFixed(2)} \$', fontBold),
          _buildSummaryItem(_t('enrollments_count'), '${data['totalEnrollments']}', fontBold),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value, pw.Font fontBold) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 18, font: fontBold, color: PdfColors.purple)),
      ],
    );
  }

  pw.Widget _buildTable(Map<String, dynamic> data, pw.Font fontBold) {
    final items = data['items'] as List<Map<String, dynamic>>;

    return pw.Table.fromTextArray(
      headers: [_t('date'), _t('student'), _t('course'), _t('amount')],
      data: items.map((item) {
        return [
          intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(item['date'])),
          item['student'],
          item['course'],
          '${item['amount']} \$',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
      cellAlignment: pw.Alignment.centerRight,
      cellStyle: const pw.TextStyle(fontSize: 10),
    );
  }
  
  void _openPdfPreview() {
    context.push(
      '/admin/reports/financial/preview',
      extra: _generatePdf,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('admin_financial_reports')),
        backgroundColor: AppColors.primaryPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.date_range),
                      title: Text(_dateRange == null
                          ? _t('select_period')
                          : '${intl.DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${intl.DateFormat('yyyy/MM/dd').format(_dateRange!.end)}'),
                      trailing: Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _pickDateRange,
                    ),
                    Divider(),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: _t('filter_by_course_optional'),
                        prefixIcon: Icon(Icons.book),
                        border: InputBorder.none,
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(_t('all'))),
                        ..._courses.map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(
                                (c['title'] as String).length > 30
                                    ? '${(c['title'] as String).substring(0, 30)}...'
                                    : c['title'] as String,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )),
                      ],
                      value: _selectedCourseId,
                      onChanged: (val) => setState(() => _selectedCourseId = val),
                    ),
                  ],
                ),
              ),
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _openPdfPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.picture_as_pdf, color: AppColors.getTextColor(context)),
                label: Text(
                  _t('generate_report'),
                  style: TextStyle(color: AppColors.getTextColor(context), fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
