import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
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
          SnackBar(content: Text('${_t('error_loading')}: $e')),
        );
      }
    }
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
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: AppColors.getTextColor(context)))
                    : RefreshIndicator(
                        onRefresh: _fetchOrders,
                        color: AppColors.primaryPurple,
                        child: _orders.isEmpty
                            ? SingleChildScrollView(
                                physics: AlwaysScrollableScrollPhysics(),
                                child: ProfessionalEmptyState(
                                  title: _t('no_orders_yet'),
                                  message: _t('no_orders_desc'),
                                  icon: Icons.receipt_long_rounded,
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.all(20),
                                itemCount: _orders.length,
                                itemBuilder: (context, index) {
                                  return _buildOrderCard(_orders[index]);
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
                  color: AppColors.getGlassColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getGlassColor(context, opacity: 0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.getTextColor(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _t('orders'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
                fontFamily: 'Cairo',
              ),
            ),
          ),
          SizedBox(width: 48), // To balance the back button
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final amount = order['total_amount'] ?? 0;
    final orderNumber = order['order_number'] ?? 'N/A';
    final course = order['courses'] as Map<String, dynamic>?;
    final courseTitle = course?['title'] ?? 'اشتراك';
    final paymentMethod = order['payment_method'] ?? 'N/A';
    final transactionId = order['payment_transaction_id'] ?? 'N/A';
    final createdAtStr = order['created_at'];

    // Payment receipts data (if available from join)
    final receipts = order['payment_receipts'] as List?;
    final receipt =
        (receipts != null && receipts.isNotEmpty) ? receipts.first : null;
    final phoneNumber = receipt?['phone_number'] ?? 'N/A';
    final receiptTransactionId = receipt?['transaction_id'] ?? transactionId;

    String dateStr = '';
    if (createdAtStr != null) {
      final createdAt = DateTime.parse(createdAtStr);
      dateStr =
          '${createdAt.year}/${createdAt.month}/${createdAt.day} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
    }

    Color statusColor;
    String statusText;

    switch (status) {
      case 'completed':
      case 'approved':
        statusColor = Colors.green;
        statusText = 'مكتمل';
        break;
      case 'failed':
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'فاشل';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'قيد المعالجة';
    }

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.receipt_long, color: AppColors.getTextColor(context)),
              SizedBox(width: 10),
              Text(
                _t('order_report'),
                style:
                    TextStyle(color: AppColors.getTextColor(context), fontFamily: 'Cairo'),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(_t('order_number'), orderNumber),
                _buildDetailRow(_t('course_title'), courseTitle),
                _buildDetailRow(_t('order_date'), dateStr),
                _buildDetailRow(_t('total_amount'), '$amount ل.س'),
                _buildDetailRow(_t('payment_method'), paymentMethod),
                _buildDetailRow(_t('transaction_id'), receiptTransactionId),
                if (phoneNumber != 'N/A')
                  _buildDetailRow(_t('phone_number'), phoneNumber),
                _buildDetailRow(_t('status'), statusText,
                    valueColor: statusColor),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('cancel'),
                  style: TextStyle(color: AppColors.getTextColor(context).withOpacity(0.70))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
                color: AppColors.getTextColor(context, secondary: true),
                fontSize: 13,
                fontFamily: 'Cairo'),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final amount = order['total_amount'] ?? 0;
    final orderNumber = order['order_number'] ?? 'طلبية';
    final course = order['courses'] as Map<String, dynamic>?;
    final courseTitle = course?['title'] ?? 'اشتراك';
    final createdAtStr = order['created_at'];
    String dateStr = '';
    if (createdAtStr != null) {
      final createdAt = DateTime.parse(createdAtStr);
      dateStr = '${createdAt.year}/${createdAt.month}/${createdAt.day}';
    }

    Color statusColor;
    String statusText;

    switch (status) {
      case 'completed':
      case 'approved':
        statusColor = Colors.green;
        statusText = 'مكتمل';
        break;
      case 'failed':
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'فاشل';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'قيد المعالجة';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getGlassColor(context, opacity: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getGlassColor(context, opacity: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOrderDetails(order),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
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
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          fontFamily: 'Cairo',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '$orderNumber • $dateStr',
                        style: TextStyle(
                          color: AppColors.getTextColor(context, secondary: true),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$amount ل.س',
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.getTextColor(context, secondary: true),
                          size: 18,
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _t('order_report'),
                          style: TextStyle(
                            color: AppColors.getTextColor(context, secondary: true),
                            fontSize: 10,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: statusColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
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
}
