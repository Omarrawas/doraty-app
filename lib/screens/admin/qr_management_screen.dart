import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import 'package:intl/intl.dart' as intl;
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../core/utils/error_utils.dart';

class QrManagementScreen extends StatefulWidget {
  const QrManagementScreen({super.key});

  @override
  State<QrManagementScreen> createState() => _QrManagementScreenState();
}

class _QrManagementScreenState extends State<QrManagementScreen> {
  final DatabaseService _db = DatabaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allCodes = [];
  List<Map<String, dynamic>> _filteredCodes = [];
  Map<String, List<Map<String, dynamic>>> _groupedCodes = {};
  String _filterStatus = 'all'; // all, active, used, expired
  
  // Search and Pagination
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 0;
  final int _pageSize = 50;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllCodes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCodes({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _hasMore = true;
        _allCodes = [];
      });
    }

    try {
      final codes = await _db.getAllQrCodes(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (refresh) {
            _allCodes = codes;
          } else {
            _allCodes.addAll(codes);
          }
          _isLoading = false;
          _isLoadingMore = false;
          if (codes.length < _pageSize) {
            _hasMore = false;
          }
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _loadMoreCodes() async {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadAllCodes(refresh: false);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
    // For small datasets we could just filter locally, but for large ones we fetch.
    // Given the previous user's request for pagination, we should fetch.
    _loadAllCodes(); 
  }

  void _applyFilter() {
    final now = DateTime.now();
    setState(() {
      _filteredCodes = _allCodes.where((code) {
        final isRedeemed = code['is_redeemed'] == true;
        final expiresAt = code['expires_at'] != null
            ? DateTime.parse(code['expires_at'])
            : null;
        final isExpired = expiresAt != null && expiresAt.isBefore(now);

        switch (_filterStatus) {
          case 'active':
            return !isRedeemed && !isExpired;
          case 'used':
            return isRedeemed;
          case 'expired':
            return isExpired && !isRedeemed;
          default:
            return true;
        }
      }).toList();

      // Group by batch name
      _groupedCodes = {};
      for (var code in _filteredCodes) {
        final batchName = code['batch_name'] ?? 'بدون مجموعة';
        if (!_groupedCodes.containsKey(batchName)) {
          _groupedCodes[batchName] = [];
        }
        _groupedCodes[batchName]!.add(code);
      }
    });
  }

  void _showCreateQrDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateQrBulkDialog(),
    ).then((added) {
      if (added == true) {
        _loadAllCodes();
      }
    });
  }

  Future<void> _toggleCodeActivation(Map<String, dynamic> code) async {
    final codeId = code['id'];
    final currentStatus = code['is_active'] ?? true;
    
    try {
      await _db.supabaseClient.from('qr_codes').update({
        'is_active': !currentStatus,
      }).eq('id', codeId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentStatus ? 'تم إلغاء تفعيل الكود' : 'تم تفعيل الكود'),
        ),
      );
      _loadAllCodes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _deleteCode(String codeId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        title: Text(
          'تأكيد الحذف',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا الكود؟',
          style: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.supabaseClient.from('qr_codes').delete().eq('id', codeId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف الكود')),
        );
        _loadAllCodes();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _deleteBatch(String batchId, String batchName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        title: Text(
          'تأكيد حذف المجموعة',
          style: TextStyle(color: AppColors.getTextColor(context)),
        ),
        content: Text(
          'هل أنت متأكد من حذف مجموعة "$batchName" بجميع أكوادها؟',
          style: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('حذف المجموعة'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteQrBatch(batchId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف المجموعة')),
        );
        _loadAllCodes();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _printBatch(String batchId) async {
    try {
      final codes = await _db.getQrCodesByBatch(batchId);
      
      // Load fonts for Arabic support
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      final ttf = pw.Font.ttf(fontData);
      final fontBoldData = await rootBundle.load("assets/fonts/Cairo-Bold.ttf");
      final ttfBold = pw.Font.ttf(fontBoldData);

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: ttf,
          bold: ttfBold,
        ),
      );
      
      // A4: 595x842 points. 4 columns x 5 rows = 20 cards
      const codesPerPage = 20;
      
      for (int page = 0; page < (codes.length / codesPerPage).ceil(); page++) {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.copyWith(
              marginLeft: 0,
              marginRight: 0,
              marginTop: 0,
              marginBottom: 0,
            ),
            build: (context) {
              final pageStart = page * codesPerPage;
              final pageEnd = (pageStart + codesPerPage).clamp(0, codes.length);
              final pageCodes = codes.sublist(pageStart, pageEnd);
              
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Center(
                child: pw.Wrap(
                  children: pageCodes.map((code) => _buildQrCodeCell(code)).toList(),
                ),
              ),
            );
            },
          ),
        );
      }
      
      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
      );
    }
  }

  pw.Widget _buildQrCodeCell(Map<String, dynamic> code) {
    final expiresAt = code['expires_at'] != null
        ? intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(code['expires_at']))
        : '';
        
    return pw.Container(
      width: 141.7, // 5cm
      height: 165,  // Approx 5.8cm
      decoration: pw.BoxDecoration(
        border: pw.Border.all(style: pw.BorderStyle.dashed, width: 0.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.SizedBox(height: 5),
          pw.BarcodeWidget(
            data: code['code'],
            barcode: pw.Barcode.qrCode(),
            width: 130, 
            height: 130,
          ),
          pw.Spacer(),
          pw.Text(
            code['batch_name'] ?? '',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
          ),
          pw.Text(
            'صالح حتى: $expiresAt',
            style: const pw.TextStyle(fontSize: 7),
            textAlign: pw.TextAlign.center,
          ),
          if (code['price'] != null && code['price'] > 0)
            pw.Text(
              '${code['price']} S.P',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              textAlign: pw.TextAlign.center,
            ),
          pw.SizedBox(height: 5),
        ],
      ),
    );
  }

  void _showQrPreview(Map<String, dynamic> code) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'رمز QR',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 8),
              Text(
                code['batch_name'] ?? 'كود QR',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextColor(context, secondary: true),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: code['code'],
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code['code'],
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(Icons.close),
                label: Text('إغلاق'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: AppColors.getTextColor(context)),
            decoration: InputDecoration(
              hintText: 'البحث بالكود أو اسم المجموعة...',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.getTextColor(context).withOpacity(0.70)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, color: AppColors.getTextColor(context).withOpacity(0.70)),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              filled: true,
              fillColor: AppColors.getGlassColor(context, opacity: 0.1),
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              hintStyle: TextStyle(color: AppColors.getMutedTextColor(context)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          _buildFilterChip('الكل', 'all', Icons.qr_code_rounded),
          SizedBox(width: 10),
          _buildFilterChip('متاح', 'active', Icons.check_circle_rounded),
          SizedBox(width: 10),
          _buildFilterChip('مستخدم', 'used', Icons.done_all_rounded),
          SizedBox(width: 10),
          _buildFilterChip('منتهي', 'expired', Icons.timer_off_rounded),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = value;
          _applyFilter();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryPurple : AppColors.getGlassColor(context, opacity: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.white24 : AppColors.getGlassColor(context, opacity: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.getTextColor(context, secondary: true)),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.getTextColor(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(Map<String, dynamic> code) {
    final status = _getStatusText(code);
    switch (status) {
      case 'متاح':
        return AppColors.success;
      case 'مستخدم':
        return AppColors.primaryBlue;
      case 'منتهي':
        return AppColors.error;
      case 'معطّل':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(Map<String, dynamic> code) {
    final isRedeemed = code['is_redeemed'] == true;
    final expiresAt = code['expires_at'] != null
        ? DateTime.parse(code['expires_at'])
        : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final isActive = code['is_active'] ?? true;

    if (!isActive) return 'معطّل';
    if (isRedeemed) return 'مستخدم';
    if (isExpired) return 'منتهي';
    return 'متاح';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildFilterChips(),
                
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                      : _groupedCodes.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadAllCodes,
                              color: AppColors.primaryPurple,
                              child: ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: _groupedCodes.length,
                                itemBuilder: (context, index) {
                                  final batchName = _groupedCodes.keys.elementAt(index);
                                  final batchCodes = _groupedCodes[batchName]!;
                                  final batchId = batchCodes.first['batch_id'];

                                  return _buildBatchCard(batchName, batchCodes, batchId);
                                },
                              ),
                            ),
                ),
                
                if (_hasMore && _filteredCodes.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.all(20.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            )
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoadingMore ? null : _loadMoreCodes,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isLoadingMore
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'تحميل المزيد',
                                        style: TextStyle(
                                          color: AppColors.getTextColor(context),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateQrDialog,
          backgroundColor: AppColors.primaryPurple,
          elevation: 8,
          icon: Icon(Icons.add_rounded, color: AppColors.getTextColor(context)),
          label: Text('إنشاء مجموعة', style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.3),
        border: Border(bottom: BorderSide(color: AppColors.getBorderColor(context))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.getTextColor(context)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'إدارة أكواد QR',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.getTextColor(context)),
            onPressed: _loadAllCodes,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 100,
            color: AppColors.getMutedTextColor(context),
          ),
          SizedBox(height: 24),
          Text(
            'لا توجد أكواد QR حالياً',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.getTextColor(context),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'قم بإنشاء مجموعة جديدة للبدء',
            style: TextStyle(color: AppColors.getTextColor(context, secondary: true)),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchCard(String name, List<Map<String, dynamic>> codes, String? batchId) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorderColor(context)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryPurple.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.auto_awesome_motion_rounded, color: AppColors.primaryPurple, size: 24),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.getTextColor(context),
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'عدد الأكواد: ${codes.length}',
          style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 13),
        ),
        trailing: batchId != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.print_rounded, color: AppColors.professionalBlue),
                    onPressed: () => _printBatch(batchId),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_sweep_rounded, color: AppColors.error),
                    onPressed: () => _deleteBatch(batchId, name),
                  ),
                ],
              )
            : null,
        children: codes.map((code) => _buildCodeListTile(code)).toList(),
      ),
    );
  }

  Widget _buildCodeListTile(Map<String, dynamic> code) {
    final status = _getStatusText(code);
    final statusColor = _getStatusColor(code);
    final expiresAt = code['expires_at'] != null
        ? intl.DateFormat('yyyy/MM/dd HH:mm').format(DateTime.parse(code['expires_at']).toLocal())
        : 'غير محدد';
    final isActive = code['is_active'] ?? true;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        title: Text(
          code['code'],
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppColors.getTextColor(context),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 12, color: AppColors.getMutedTextColor(context)),
                SizedBox(width: 4),
                Text(
                  expiresAt,
                  style: TextStyle(fontSize: 11, color: AppColors.getMutedTextColor(context)),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: AppColors.getTextColor(context, secondary: true)),
          onSelected: (value) {
            if (value == 'preview') {
              _showQrPreview(code);
            } else if (value == 'toggle') {
              _toggleCodeActivation(code);
            } else if (value == 'delete') {
              _deleteCode(code['id']);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'preview',
              child: ListTile(
                leading: Icon(Icons.qr_code_2_rounded),
                title: Text('عرض الرمز'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                leading: Icon(isActive ? Icons.block_rounded : Icons.check_circle_rounded),
                title: Text(isActive ? 'تعطيل' : 'تفعيل'),
                dense: true,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: Text('حذف', style: TextStyle(color: AppColors.error)),
                dense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog for creating bulk QR codes (unchanged from previous version)
class CreateQrBulkDialog extends StatefulWidget {
  const CreateQrBulkDialog({super.key});

  @override
  State<CreateQrBulkDialog> createState() => _CreateQrBulkDialogState();
}

class _CreateQrBulkDialogState extends State<CreateQrBulkDialog> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();
  final _batchNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '10');
  final _discountController = TextEditingController(text: '0');
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _filteredCourses = [];
  final List<String> _selectedCourseIds = [];
  DateTime _expiryDate = DateTime.now().add(Duration(days: 30));
  bool _isLoading = true;
  bool _isSaving = false;

  double _totalPrice = 0;

  @override
  void initState() {
    super.initState();
    _loadCourses();
    _searchController.addListener(_filterCourses);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _batchNameController.dispose();
    _quantityController.dispose();
    _discountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterCourses() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCourses = _courses;
      } else {
        _filteredCourses = _courses.where((course) {
          final title = (course['title'] ?? '').toLowerCase();
          return title.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadCourses() async {
    try {
      final courses = await _db.getCourses();
      setState(() {
        _courses = courses;
        _filteredCourses = courses;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _calculatePrice() {
    double total = 0;
    for (var courseId in _selectedCourseIds) {
      final course = _courses.firstWhere(
        (c) => c['id'] == courseId,
        orElse: () => {},
      );
      if (course.isNotEmpty) {
        total += (course['price'] as num? ?? 0).toDouble();
      }
    }
    
    // Price calculation
    
    final discount = double.tryParse(_discountController.text) ?? 0;
    if (discount > 0) {
      total = total * (1 - (discount / 100));
    }
    
    setState(() => _totalPrice = total);
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _createBulkQrCodes() async {
    if (!_formKey.currentState!.validate() || _selectedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى ملء جميع الحقول واختيار مادة واحدة على الأقل')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _db.generateBulkQrCodes(
        courseIds: _selectedCourseIds,
        batchName: _batchNameController.text,
        quantity: int.parse(_quantityController.text),
        expiryDate: _expiryDate,
        totalPrice: _totalPrice,
        discountPercent: int.tryParse(_discountController.text) ?? 0,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء ${_quantityController.text} كود بنجاح'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                          child: Text(
                            'إنشاء مجموعة أكواد QR',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextColor(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildGlassInput(
                                  controller: _batchNameController,
                                  label: 'اسم المجموعة',
                                  icon: Icons.label_rounded,
                                  hint: 'مثال: دفعة يناير 2026',
                                  validator: (v) => v?.isEmpty == true ? 'مطلوب' : null,
                                ),
                                SizedBox(height: 16),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildGlassInput(
                                        controller: _quantityController,
                                        label: 'العدد',
                                        icon: Icons.numbers_rounded,
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v?.isEmpty == true) return 'مطلوب';
                                          final num = int.tryParse(v!);
                                          if (num == null || num < 1 || num > 200) return 'بين 1 و 200';
                                          return null;
                                        },
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildGlassInput(
                                        controller: _discountController,
                                        label: 'الخصم %',
                                        icon: Icons.percent_rounded,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => _calculatePrice(),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                                
                                // Date Picker
                                InkWell(
                                  onTap: _selectDate,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.getGlassColor(context, opacity: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.getGlassColor(context, opacity: 0.1)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 20, color: AppColors.primaryPurple),
                                        SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('تاريخ الانتهاء', style: TextStyle(fontSize: 11, color: AppColors.getMutedTextColor(context))),
                                            Text(intl.DateFormat('yyyy/MM/dd').format(_expiryDate), style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: 20),
                                
                                // Price Summary
                                if (_totalPrice > 0)
                                  Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppColors.success.withOpacity(0.2), AppColors.success.withOpacity(0.05)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.success.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('سعر الكود الواحد:', style: TextStyle(fontWeight: FontWeight.w600)),
                                        Text('$_totalPrice S.P', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success)),
                                      ],
                                    ),
                                  ),
                                
                                SizedBox(height: 20),
                                
                                Text('اختيار المواد', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.getTextColor(context))),
                                SizedBox(height: 12),
                                
                                // Course Search
                                _buildGlassInput(
                                  controller: _searchController,
                                  label: 'بحث عن مادة',
                                  icon: Icons.search_rounded,
                                  isDense: true,
                                ),
                                
                                SizedBox(height: 12),
                                
                                // Courses List
                                Container(
                                  constraints: BoxConstraints(maxHeight: 250),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _filteredCourses.length,
                                    itemBuilder: (context, index) {
                                      final course = _filteredCourses[index];
                                      final courseId = course['id'];
                                      final isSelected = _selectedCourseIds.contains(courseId);
                                      
                                      return CheckboxListTile(
                                        value: isSelected,
                                        onChanged: (checked) {
                                          setState(() {
                                            if (checked == true) {
                                              _selectedCourseIds.add(courseId);
                                            } else {
                                              _selectedCourseIds.remove(courseId);
                                            }
                                            _calculatePrice();
                                          });
                                        },
                                        title: Text(course['title'] ?? '', style: TextStyle(fontSize: 14)),
                                        subtitle: Text('${course['price'] ?? 0} S.P', style: TextStyle(color: AppColors.primaryPurple, fontSize: 11)),
                                        activeColor: AppColors.primaryPurple,
                                        contentPadding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Actions
                        Padding(
                          padding: EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('إلغاء', style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.6))),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _isSaving ? null : _createBulkQrCodes,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: _isSaving
                                        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text('إنشاء الأكواد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ],
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

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool isDense = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: AppColors.getTextColor(context)),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryPurple),
        filled: true,
        fillColor: AppColors.getGlassColor(context, opacity: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.getGlassColor(context, opacity: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.getGlassColor(context, opacity: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.primaryPurple, width: 1.5),
        ),
        isDense: isDense,
        labelStyle: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.6)),
        hintStyle: TextStyle(color: AppColors.getMutedTextColor(context)),
      ),
    );
  }
}