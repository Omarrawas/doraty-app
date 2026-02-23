import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../widgets/dynamic_gradient_background.dart';
import 'payment_receipt_detail_screen.dart';

class PaymentReceiptsScreen extends StatefulWidget {
  const PaymentReceiptsScreen({super.key});

  @override
  State<PaymentReceiptsScreen> createState() => _PaymentReceiptsScreenState();
}

class _PaymentReceiptsScreenState extends State<PaymentReceiptsScreen> {
  final DatabaseService _db = DatabaseService();
  String _selectedStatus = 'all';
  List<Map<String, dynamic>> _receipts = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final receipts = await _db.getAllPaymentReceipts(
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
      final stats = await _db.getPaymentStatistics();
      if (mounted) {
        setState(() {
          _receipts = receipts;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
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
    final isDark = context.watch<ThemeProvider>().isDarkMode;

    return Theme(
      data: isDark ? AppTheme.adminDarkTheme : AppTheme.adminLightTheme,
      child: Scaffold(
        body: DynamicGradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildStatsSection(),
                _buildFilters(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: _buildReceiptsList(),
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
            child: Text(
              'إيصالات الدفع',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.normal,
                color: AppColors.getTextColor(context),
              ),
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
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadData,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard('إجمالي الدخل', '${_stats['total_revenue'] ?? 0} ل.س',
              Colors.greenAccent, Icons.payments),
          _buildStatCard('قيد الانتظار', '${_stats['pending_receipts'] ?? 0}',
              Colors.orangeAccent, Icons.hourglass_empty),
          _buildStatCard('تم قبولها', '${_stats['approved_receipts'] ?? 0}',
              Colors.blueAccent, Icons.check_circle),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getGlassColor(context, opacity: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.getGlassColor(context, opacity: 0.3),
                  width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(height: 8),
                Text(label,
                    style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 11)),
                Text(value,
                    style: TextStyle(
                        color: AppColors.getTextColor(context),
                        fontSize: 15,
                        fontWeight: FontWeight.normal)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      {'id': 'all', 'label': 'الكل'},
      {'id': 'pending', 'label': 'قيد الانتظار'},
      {'id': 'approved', 'label': 'مقبولة'},
      {'id': 'rejected', 'label': 'مرفوضة'},
    ];

    return Container(
      height: 45,
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedStatus == filter['id'];
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(filter['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedStatus = filter['id']!);
                  _loadData();
                }
              },
              backgroundColor: Colors.white.withOpacity(0.2),
              selectedColor: AppColors.primaryPurple,
              labelStyle: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.normal : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side:
                  BorderSide(color: isSelected ? Colors.transparent : Colors.white38),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReceiptsList() {
    if (_receipts.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _receipts.length,
      itemBuilder: (context, index) => _buildReceiptCard(_receipts[index]),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    final status = receipt['status'];
    final user = receipt['users'] as Map<String, dynamic>?;
    final course = receipt['courses'] as Map<String, dynamic>?;

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
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PaymentReceiptDetailScreen(receiptId: receipt['id']),
                    ),
                  );
                  if (result == true) _loadData();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?['full_name'] ?? 'مستخدم مجهول',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.normal,
                                    color: AppColors.getTextColor(context),
                                  ),
                                ),
                                Text(
                                  course?['title'] ?? 'دورة غير معروفة',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.getTextColor(context),
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
                              const Text('المبلغ',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                              Text('${receipt['amount']} ل.س',
                                  style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.normal)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('التاريخ',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                              Text(_formatDate(receipt['created_at']),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
      case 'pending':
        color = Colors.orange;
        label = 'انتظار';
        break;
      case 'approved':
        color = Colors.green;
        label = 'مقبول';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'مرفوض';
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.normal)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('لا توجد إيصالات متاحة',
              style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month}-${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}
