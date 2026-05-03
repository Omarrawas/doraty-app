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
import '../../widgets/dynamic_gradient_background.dart';

class FinancialReportsScreen extends StatefulWidget {
  final String? instructorId;
  const FinancialReportsScreen({super.key, this.instructorId});

  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen> {
  final DatabaseService _db = DatabaseService();
  DateTimeRange? _dateRange;
  String? _selectedCourseId;
  String? _selectedTeacherId;
  double _teacherPercentage = 70.0;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _teachers = [];
  bool _isLoadingFilters = true;

  String _t(String key) {
    try {
      final locale = Provider.of<LocaleProvider>(context, listen: false).locale;
      return AppStrings.get(key, locale);
    } catch (e) {
      return key;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedTeacherId = widget.instructorId;
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    setState(() => _isLoadingFilters = true);
    try {
      final results = await Future.wait([
        _db.getCourses(),
        _db.getAllTeachers(),
      ]);
      if (mounted) {
        setState(() {
          _courses = List<Map<String, dynamic>>.from(results[0] as Iterable);
          _teachers = List<Map<String, dynamic>>.from(results[1] as Iterable);
          _isLoadingFilters = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading filters: $e');
      if (mounted) setState(() => _isLoadingFilters = false);
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
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primaryPurple,
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              surface: AppColors.getSurfaceColor(context),
            ),
            dialogBackgroundColor: AppColors.getSurfaceColor(context),
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
      teacherId: _selectedTeacherId,
    );

    final pdf = pw.Document();
    
    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
    final ttfBold = pw.Font.ttf(fontBoldData);

    final double total = (reportData['totalEarnings'] as num).toDouble();
    final double teacherShare = total * (_teacherPercentage / 100);
    final double platformShare = total - teacherShare;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
          textDirection: pw.TextDirection.rtl,
          margin: const pw.EdgeInsets.all(32),
        ),
        build: (context) => [
          _buildPdfHeader(reportData, ttfBold),
          pw.SizedBox(height: 20),
          _buildPdfCalculations(total, teacherShare, platformShare, ttfBold),
          pw.SizedBox(height: 20),
          _buildPdfTable(reportData, ttfBold),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfHeader(Map<String, dynamic> data, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_t('financial_report'), style: pw.TextStyle(fontSize: 28, font: fontBold, color: PdfColors.purple900)),
            pw.Text('DORATY APP', style: pw.TextStyle(fontSize: 16, font: fontBold, color: PdfColors.grey700)),
          ],
        ),
        pw.Divider(thickness: 2, color: PdfColors.purple100),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${_t('period')}: ${data['period']}', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('${_t('print_date')}: ${intl.DateFormat('yyyy/MM/dd').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfCalculations(double total, double teacherShare, double platformShare, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.purple50,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.purple200, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfSummaryItem('إجمالي الإيرادات', '${total.toStringAsFixed(2)} \$', fontBold, PdfColors.purple900),
              _buildPdfSummaryItem('نسبة المدرس', '${_teacherPercentage.toStringAsFixed(0)}%', fontBold, PdfColors.blueGrey700),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfSummaryItem('حصة المدرس', '${teacherShare.toStringAsFixed(2)} \$', fontBold, PdfColors.green800),
              _buildPdfSummaryItem('حصة المنصة', '${platformShare.toStringAsFixed(2)} \$', fontBold, PdfColors.blue800),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value, pw.Font fontBold, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 18, font: fontBold, color: color)),
      ],
    );
  }

  pw.Widget _buildPdfTable(Map<String, dynamic> data, pw.Font fontBold) {
    final items = data['items'] as List<Map<String, dynamic>>;

    return pw.Table.fromTextArray(
      headers: ['التاريخ', 'اسم الطالب', 'الدورة / الكورس', 'المبلغ'],
      data: items.map((item) {
        return [
          intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(item['date'])),
          item['student'],
          item['course'],
          '${item['amount']} \$',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white, fontSize: 12),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.purple700),
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5))),
      cellAlignment: pw.Alignment.centerRight,
      cellPadding: const pw.EdgeInsets.all(8),
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
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoadingFilters 
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildFiltersCard(),
                          const SizedBox(height: 20),
                          _buildShareCalculationCard(),
                          const SizedBox(height: 30),
                          _buildActionButtons(),
                        ],
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
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Text(
            widget.instructorId != null ? 'تقاريري المالية' : _t('admin_financial_reports'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
              color: AppColors.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.3)),
      ),
      child: Column(
        children: [
          _buildFilterItem(
            icon: Icons.calendar_today,
            title: _dateRange == null ? 'اختر الفترة' : 'تاريخ التقرير',
            subtitle: _dateRange == null 
                ? 'تاريخ البداية والنهاية' 
                : '${intl.DateFormat('yyyy/MM/dd').format(_dateRange!.start)} - ${intl.DateFormat('yyyy/MM/dd').format(_dateRange!.end)}',
            onTap: _pickDateRange,
          ),
          _buildDivider(),
          if (widget.instructorId == null) ...[
            _buildFilterItem(
              icon: Icons.person_outline,
              title: 'تصفية حسب المدرس',
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTeacherId,
                  isExpanded: true,
                  hint: Text('كل المدرسين', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5), fontSize: 13)),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('جميع المدرسين')),
                    ..._teachers.map((t) => DropdownMenuItem(
                      value: t['id'] as String,
                      child: Text(t['full_name'] ?? 'مدرس', overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedTeacherId = val;
                    if (val != null) _selectedCourseId = null; // Clear course if teacher selected
                  }),
                ),
              ),
            ),
            _buildDivider(),
          ],
          _buildFilterItem(
            icon: Icons.book_outlined,
            title: 'تصفية حسب الدورة',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCourseId,
                isExpanded: true,
                hint: Text('كل الدورات', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.5), fontSize: 13)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('جميع الدورات')),
                  ..._courses.map((c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text(c['title'] ?? 'دورة', overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (val) => setState(() {
                  _selectedCourseId = val;
                  if (val != null) _selectedTeacherId = null; // Clear teacher if course selected
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCalculationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryPurple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('نسبة المدرس (%)', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              SizedBox(
                width: 70,
                child: TextField(
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    final percent = double.tryParse(val);
                    if (percent != null && percent >= 0 && percent <= 100) {
                      setState(() => _teacherPercentage = percent);
                    }
                  },
                  controller: TextEditingController(text: _teacherPercentage.toStringAsFixed(0)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Slider(
            value: _teacherPercentage,
            min: 0,
            max: 100,
            divisions: 20,
            activeColor: AppColors.primaryPurple,
            label: '${_teacherPercentage.toInt()}%',
            onChanged: (val) => setState(() => _teacherPercentage = val),
          ),
          const SizedBox(height: 10),
          _buildShareRow('حصة المدرس:', '${_teacherPercentage.toInt()}%'),
          _buildShareRow('حصة المنصة:', '${(100 - _teacherPercentage).toInt()}%'),
        ],
      ),
    );
  }

  Widget _buildShareRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: AppColors.getTextColor(context).withOpacity(0.7))),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryPurple)),
        ],
      ),
    );
  }

  Widget _buildFilterItem({required IconData icon, required String title, String? subtitle, Widget? child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primaryPurple, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  if (subtitle != null)
                    Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.getTextColor(context).withOpacity(0.6))),
                  if (child != null) ...[
                    const SizedBox(height: 4),
                    child,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: AppColors.getGlassColor(context, opacity: 0.1));

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _openPdfPreview,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('معاينة التقرير والطباعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'سيتم احتساب الحصص تلقائياً في ملف PDF المطبوع',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.getTextColor(context).withOpacity(0.5)),
        ),
      ],
    );
  }
}
