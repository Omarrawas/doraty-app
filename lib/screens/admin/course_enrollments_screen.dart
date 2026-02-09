import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/string_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CourseEnrollmentsScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseEnrollmentsScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseEnrollmentsScreen> createState() => _CourseEnrollmentsScreenState();
}

class _CourseEnrollmentsScreenState extends State<CourseEnrollmentsScreen> {
  final DatabaseService _db = DatabaseService();
  final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: 'ل.س ', decimalDigits: 0);

  List<Map<String, dynamic>> _enrollments = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final enrollments = await _db.getAllEnrollments(
        courseId: widget.courseId,
        searchQuery: _searchQuery,
      );

      if (!mounted) return;
      setState(() {
        _enrollments = enrollments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red),
      );
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
                _buildHeader(),
                _buildSearchSection(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.primaryPurple,
                          child: _enrollments.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(20),
                                  itemCount: _enrollments.length,
                                  itemBuilder: (context, index) {
                                    return _buildEnrollmentCard(_enrollments[index]);
                                  },
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
      padding: const EdgeInsets.all(20),
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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اشتراكات الدورة',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.getTextColor(context).withOpacity(0.6),
                  ),
                ),
                Text(
                  widget.courseTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.normal,
                    color: AppColors.getTextColor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
                  icon: const Icon(Icons.print, color: Colors.white),
                  onPressed:
                      _enrollments.isEmpty ? null : _generateAndPrintReport,
                  tooltip: 'طباعة التقرير',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadData,
                  tooltip: 'تحديث البيانات',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.2),
                  width: 1.5),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _loadData();
              },
              style: TextStyle(color: AppColors.getTextColor(context)),
              decoration: InputDecoration(
                hintText: 'بحث باسم الطالب...',
                hintStyle: TextStyle(
                    color: AppColors.getTextColor(context).withOpacity(0.4)),
                prefixIcon: Icon(Icons.search,
                    color: AppColors.getTextColor(context).withOpacity(0.6)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnrollmentCard(Map<String, dynamic> enrollment) {
    final userData = enrollment['users'] as Map<String, dynamic>?;
    final courseData = enrollment['courses'] as Map<String, dynamic>?;
    final DateTime? enrolledAt = enrollment['enrolled_at'] != null
        ? DateTime.parse(enrollment['enrolled_at'])
        : null;
    final String status = enrollment['status'] ?? 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.3),
                  width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: AppColors.primaryPurple,
                        backgroundImage: userData?['avatar_url'] != null
                            ? NetworkImage(userData!['avatar_url'])
                            : null,
                        child: userData?['avatar_url'] == null
                            ? Text(
                                (userData?['full_name']?[0] ?? 'U').toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              StringUtils.cleanTeacherName(
                                  userData?['full_name'] ?? 'مستخدم'),
                              style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontWeight: FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              userData?['email'] ?? '',
                              style: TextStyle(
                                color: AppColors.getTextColor(context)
                                    .withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تاريخ الاشتراك',
                            style: TextStyle(
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            enrolledAt != null
                                ? DateFormat('yyyy/MM/dd').format(enrolledAt)
                                : '-',
                            style: TextStyle(
                              color: AppColors.getTextColor(context),
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'المبلغ المدفوع',
                            style: TextStyle(
                              color: AppColors.getTextColor(context)
                                  .withOpacity(0.5),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _currencyFormat.format(courseData?['price'] ?? 0),
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (status == 'active') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _confirmChangeStatus(enrollment['id'], 'cancelled'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('إلغاء الاشتراك',
                            style: TextStyle(fontWeight: FontWeight.normal)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = Colors.green;
        label = 'نشط';
        break;
      case 'expired':
        color = Colors.orange;
        label = 'منتهي';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'ملغي';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.normal),
      ),
    );
  }

  void _confirmChangeStatus(String enrollmentId, String newStatus) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: AppColors.getGlassColor(context, opacity: 0.9),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white24)),
          title: const Text('تأكيد الإجراء',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
          content: const Text(
            'هل أنت متأكد من تغيير حالة الاشتراك لهذا الطالب؟ سيؤدي هذا لإلغاء وصوله للمحتوى.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.redAccent, Colors.red]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  try {
                    await _db.updateEnrollmentStatus(enrollmentId, newStatus);
                    _loadData();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث حالة الاشتراك بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
                          backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('تأكيد الإلغاء',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndPrintReport() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      final pdf = await _createPDF();

      if (!mounted) return;
      Navigator.pop(context); // Hide loading

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'تقرير_${widget.courseTitle}',
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Hide loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<pw.Document> _createPDF() async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicBold = await PdfGoogleFonts.cairoBold();

    // Calculate stats
    double totalRevenue = 0;
    int activeCount = 0;
    for (var e in _enrollments) {
      totalRevenue += (e['courses']['price'] as num? ?? 0).toDouble();
      if (e['status'] == 'active') activeCount++;
    }

    pdf.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicBold,
        ),
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('تقرير اشتراكات الدورة',
                  style: pw.TextStyle(fontSize: 20, font: arabicBold)),
              pw.Text(DateFormat('yyyy/MM/dd').format(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
        build: (pw.Context context) => [
          pw.SizedBox(height: 10),
          pw.Text('الدورة: ${widget.courseTitle}',
              style: pw.TextStyle(fontSize: 18, font: arabicBold)),
          pw.SizedBox(height: 20),

          // Summary Cards
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPDFStatCard(
                  'إجمالي الاشتراكات', '${_enrollments.length}', arabicBold),
              _buildPDFStatCard(
                  'الاشتراكات النشطة', '$activeCount', arabicBold),
              _buildPDFStatCard('إجمالي المبالغ',
                  _currencyFormat.format(totalRevenue), arabicBold),
            ],
          ),

          pw.SizedBox(height: 30),
          pw.Text('قائمة المشتركين:',
              style: pw.TextStyle(fontSize: 16, font: arabicBold)),
          pw.SizedBox(height: 10),

          // Students Table
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(3), // Name
              1: const pw.FlexColumnWidth(3), // Email
              2: const pw.FlexColumnWidth(2), // Date
              3: const pw.FlexColumnWidth(2), // Amount
              4: const pw.FlexColumnWidth(1), // Status
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildPDFTableCell('اسم الطالب', arabicBold, isHeader: true),
                  _buildPDFTableCell('البريد الإلكتروني', arabicBold,
                      isHeader: true),
                  _buildPDFTableCell('تاريخ الاشتراك', arabicBold,
                      isHeader: true),
                  _buildPDFTableCell('المبلغ', arabicBold, isHeader: true),
                  _buildPDFTableCell('الحالة', arabicBold, isHeader: true),
                ],
              ),
              ..._enrollments.map((e) {
                final dateStr = e['enrolled_at'] != null
                    ? DateFormat('yyyy/MM/dd')
                        .format(DateTime.parse(e['enrolled_at']))
                    : '-';
                String statusLabel = 'نشط';
                if (e['status'] == 'cancelled') statusLabel = 'ملغي';
                if (e['status'] == 'expired') statusLabel = 'منتهي';

                return pw.TableRow(
                  children: [
                    _buildPDFTableCell(
                        e['users']['full_name'] ?? '', arabicFont),
                    _buildPDFTableCell(e['users']['email'] ?? '', arabicFont),
                    _buildPDFTableCell(dateStr, arabicFont),
                    _buildPDFTableCell(
                        _currencyFormat.format(e['courses']['price'] ?? 0),
                        arabicFont),
                    _buildPDFTableCell(statusLabel, arabicFont),
                  ],
                );
              }),
            ],
          ),
        ],
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 20),
          child: pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 5),
              pw.Text('تم إنشاء هذا التقرير تلقائياً من منصة دراتي',
                  style:
                      const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
            ],
          ),
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildPDFStatCard(String label, String value, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      width: 150,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E1BEE7')),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        color: PdfColor.fromHex('#F3E5F5'),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 5),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 14, font: font, color: PdfColors.purple800)),
        ],
      ),
    );
  }

  pw.Widget _buildPDFTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
          color: isHeader ? PdfColors.black : PdfColors.grey800,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'لا يوجد طلاب مشتركين بعد',
            style: TextStyle(
              color: AppColors.getTextColor(context).withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
