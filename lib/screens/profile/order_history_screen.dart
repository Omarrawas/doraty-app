import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/localization/locale_provider.dart';
import '../../core/constants/app_strings.dart';
import '../../widgets/dynamic_gradient_background.dart';
import '../../widgets/empty_state.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final DatabaseService _databaseService = DatabaseService();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  String _t(String key) => AppStrings.get(
      key, Provider.of<LocaleProvider>(context, listen: false).locale);

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final orders = await _databaseService.getUserOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_t('error_loading')}: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale;
    final isRtl = locale == 'ar';

    return Scaffold(
      body: DynamicGradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isRtl),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                    : RefreshIndicator(
                        onRefresh: _fetchOrders,
                        color: AppColors.primaryPurple,
                        child: _orders.isEmpty
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ProfessionalEmptyState(
                                  title: _t('no_orders_yet'),
                                  message: _t('no_orders_desc'),
                                  icon: Icons.receipt_long_rounded,
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                itemCount: _orders.length,
                                itemBuilder: (context, index) {
                                  return _buildPremiumOrderCard(_orders[index]);
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

  Widget _buildHeader(bool isRtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
              color: AppColors.getTextColor(context),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              _t('orders'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.getTextColor(context),
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPremiumOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final amount = order['total_amount'] ?? 0;
    final curso = order['courses'] as Map<String, dynamic>?;
    final courseTitle = curso?['title'] ?? 'اشتراك دورة';
    final createdAtStr = order['created_at'];

    String dateStr = '';
    if (createdAtStr != null) {
      final createdAt = DateTime.parse(createdAtStr);
      dateStr = DateFormat('yyyy/MM/dd').format(createdAt);
    }

    final statusInfo = _getStatusInfo(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.getSurfaceColor(context).withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showOrderDetails(order),
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                                  courseTitle,
                                  style: TextStyle(
                                    color: AppColors.getTextColor(context),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    fontFamily: 'Cairo',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: AppColors.getMutedTextColor(context),
                                    fontSize: 12,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(statusInfo),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payment_rounded, size: 16, color: AppColors.primaryPurple.withOpacity(0.6)),
                              const SizedBox(width: 8),
                              Text(
                                order['payment_method'] ?? 'N/A',
                                style: TextStyle(
                                  color: AppColors.getMutedTextColor(context),
                                  fontSize: 13,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${NumberFormat('#,###').format(amount)} ل.س',
                            style: TextStyle(
                              color: AppColors.primaryPurple,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              fontFamily: 'Cairo',
                            ),
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

  Widget _buildStatusBadge(_StatusData info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: info.color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 12, color: info.color),
          const SizedBox(width: 6),
          Text(
            info.text,
            style: TextStyle(
              color: info.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  _StatusData _getStatusInfo(String status) {
    switch (status) {
      case 'completed':
      case 'approved':
        return _StatusData(Colors.greenAccent, 'مكتمل', Icons.check_circle_rounded);
      case 'failed':
      case 'rejected':
        return _StatusData(Colors.redAccent, 'فاشل', Icons.cancel_rounded);
      default:
        return _StatusData(Colors.orangeAccent, 'قيد المعالجة', Icons.pending_rounded);
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final amount = order['total_amount'] ?? 0;
    final orderNumber = order['order_number'] ?? 'N/A';
    final course = order['courses'] as Map<String, dynamic>?;
    final courseTitle = course?['title'] ?? 'اشتراك دورة';
    final paymentMethod = order['payment_method'] ?? 'N/A';
    final createdAtStr = order['created_at'];

    final receipts = order['payment_receipts'] as List?;
    final receipt = (receipts != null && receipts.isNotEmpty) ? receipts.first : null;
    final phoneNumber = receipt?['phone_number'] ?? 'N/A';
    final transactionId = receipt?['transaction_id'] ?? order['payment_transaction_id'] ?? 'N/A';

    String dateTimeStr = '';
    if (createdAtStr != null) {
      final createdAt = DateTime.parse(createdAtStr);
      dateTimeStr = DateFormat('yyyy/MM/dd HH:mm').format(createdAt);
    }

    final statusInfo = _getStatusInfo(status);

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: AppColors.getSurfaceColor(context).withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          title: Row(
            children: [
              Icon(Icons.description_outlined, color: AppColors.primaryPurple),
              const SizedBox(width: 12),
              Text(
                'تفاصيل الطلب',
                style: TextStyle(
                  color: AppColors.getTextColor(context),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOrderInfoTile('رقم الطلب', orderNumber),
                _buildOrderInfoTile('المادة/الدورة', courseTitle, isLong: true),
                _buildOrderInfoTile('التاريخ', dateTimeStr),
                _buildOrderInfoTile('طريقة الدفع', paymentMethod),
                _buildOrderInfoTile('رقم العملية', transactionId),
                if (phoneNumber != 'N/A') _buildOrderInfoTile('رقم الهاتف', phoneNumber),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white12),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الحالة', style: TextStyle(color: Colors.white60, fontSize: 13, fontFamily: 'Cairo')),
                    _buildStatusBadge(statusInfo),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ الإجمالي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Cairo')),
                    Text(
                      '${NumberFormat('#,###').format(amount)} ل.س',
                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'Cairo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إغلاق',
                style: TextStyle(color: AppColors.getMutedTextColor(context), fontFamily: 'Cairo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoTile(String label, String value, {bool isLong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: isLong ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.getMutedTextColor(context), fontSize: 12, fontFamily: 'Cairo'),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: AppColors.getTextColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusData {
  final Color color;
  final String text;
  final IconData icon;
  _StatusData(this.color, this.text, this.icon);
}
