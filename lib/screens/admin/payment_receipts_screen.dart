import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../models/payment_receipt.dart';
import 'payment_receipt_detail_screen.dart';

class PaymentReceiptsScreen extends StatefulWidget {
  const PaymentReceiptsScreen({super.key});

  @override
  State<PaymentReceiptsScreen> createState() => _PaymentReceiptsScreenState();
}

class _PaymentReceiptsScreenState extends State<PaymentReceiptsScreen> {
  bool _isLoading = true;
  List<PaymentReceipt> _receipts = [];
  PaymentReceiptStatus? _filterStatus;
  
  final List<String> _statusFilters = [
    'الكل',
    'قيد الانتظار',
    'مقبول',
    'مرفوض',
    'قيد المراجعة',
  ];

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = DatabaseService();
      final receiptsData = await dbService.getAllPaymentReceipts(
        status: _filterStatus != null ? _statusToString(_filterStatus!) : null,
      );

      setState(() {
        _receipts = receiptsData.map((json) => PaymentReceipt.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading receipts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _statusToString(PaymentReceiptStatus status) {
    switch (status) {
      case PaymentReceiptStatus.pending:
        return 'pending';
      case PaymentReceiptStatus.approved:
        return 'approved';
      case PaymentReceiptStatus.rejected:
        return 'rejected';
      case PaymentReceiptStatus.underReview:
        return 'under_review';
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      switch (filter) {
        case 'قيد الانتظار':
          _filterStatus = PaymentReceiptStatus.pending;
          break;
        case 'مقبول':
          _filterStatus = PaymentReceiptStatus.approved;
          break;
        case 'مرفوض':
          _filterStatus = PaymentReceiptStatus.rejected;
          break;
        case 'قيد المراجعة':
          _filterStatus = PaymentReceiptStatus.underReview;
          break;
        default:
          _filterStatus = null;
      }
    });
    _loadReceipts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildFilters(),
              _buildStats(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _receipts.isEmpty
                        ? _buildEmptyState()
                        : _buildReceiptsList(),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'إدارة المدفوعات',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadReceipts,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _statusFilters.length,
        itemBuilder: (context, index) {
          final filter = _statusFilters[index];
          final isSelected = (filter == 'الكل' && _filterStatus == null) ||
              (filter == 'قيد الانتظار' && _filterStatus == PaymentReceiptStatus.pending) ||
              (filter == 'مقبول' && _filterStatus == PaymentReceiptStatus.approved) ||
              (filter == 'مرفوض' && _filterStatus == PaymentReceiptStatus.rejected) ||
              (filter == 'قيد المراجعة' && _filterStatus == PaymentReceiptStatus.underReview);

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _onFilterChanged(filter),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Text(
                          filter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    final pending = _receipts.where((r) => r.status == PaymentReceiptStatus.pending).length;
    final approved = _receipts.where((r) => r.status == PaymentReceiptStatus.approved).length;
    final totalAmount = _receipts
        .where((r) => r.status == PaymentReceiptStatus.approved)
        .fold<double>(0, (sum, r) => sum + r.amount);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'قيد الانتظار',
              pending.toString(),
              Icons.schedule,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'مقبول',
              approved.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'الإيرادات',
              '${totalAmount.toStringAsFixed(0)} ل.س',
              Icons.attach_money,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.white.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد إيصالات',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _receipts.length,
      itemBuilder: (context, index) {
        final receipt = _receipts[index];
        return _buildReceiptCard(receipt);
      },
    );
  }

  Widget _buildReceiptCard(PaymentReceipt receipt) {
    Color statusColor;
    IconData statusIcon;

    switch (receipt.status) {
      case PaymentReceiptStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case PaymentReceiptStatus.approved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PaymentReceiptStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case PaymentReceiptStatus.underReview:
        statusColor = Colors.blue;
        statusIcon = Icons.rate_review;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentReceiptDetailScreen(
                        receiptId: receipt.id,
                      ),
                    ),
                  );
                  
                  if (result == true) {
                    _loadReceipts();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            receipt.statusDisplayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${receipt.amount.toStringAsFixed(0)} ل.س',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (receipt.courseTitle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          receipt.courseTitle!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.payment, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            receipt.paymentMethodDisplayName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (receipt.phoneNumber != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.phone, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              receipt.phoneNumber!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (receipt.transactionId != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.receipt, color: Colors.white, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'رقم العملية: ${receipt.transactionId}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _formatDateTime(receipt.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
