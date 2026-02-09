import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';

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
              pw.Text('التقرير المالي',
                  style: pw.TextStyle(fontSize: 24, font: fontBold, color: PdfColors.purple)),
              pw.Text('منصة دوراتي التعليمية',
                  style: const pw.TextStyle(fontSize: 14)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('الفترة: ${data['period']}',
                  style: const pw.TextStyle(fontSize: 12)),
              pw.Text('تاريخ الطباعة: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.now())}',
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
          _buildSummaryItem('إجمالي الإيرادات',
              '${(data['totalEarnings'] as double).toStringAsFixed(2)} \$', fontBold),
          _buildSummaryItem('عدد الاشتراكات', '${data['totalEnrollments']}', fontBold),
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
      headers: ['التاريخ', 'الطالب', 'الدورة', 'المبلغ'],
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('معاينة التقرير')),
          body: PdfPreview(
            build: (format) => _generatePdf(format),
            canDebug: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير المالية'),
        backgroundColor: AppColors.primaryPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.date_range),
                      title: Text(_dateRange == null
                          ? 'اختر الفترة الزمنية'
                          : '${intl.DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${intl.DateFormat('yyyy/MM/dd').format(_dateRange!.end)}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _pickDateRange,
                    ),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'تصفية حسب الدورة (اختياري)',
                        prefixIcon: Icon(Icons.book),
                        border: InputBorder.none,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('الكل')),
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
            const Spacer(),
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
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text(
                  'استخراج التقرير',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
