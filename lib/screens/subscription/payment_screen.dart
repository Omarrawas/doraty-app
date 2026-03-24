import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/theme/app_colors.dart';
import '../../core/services/database_service.dart';
import '../../core/utils/error_utils.dart';
import '../../models/payment_account.dart';
import '../../services/payment_service.dart' as service;
import '../../models/course.dart';
import '../payment/qr_scanner_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Course? course;
  final double amount;
  final String title;

  PaymentScreen({
    super.key,
    this.course,
    required this.amount,
    required this.title,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  service.PaymentMethod? _selectedMethod;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();
  
  bool _isProcessing = false;
  bool _isLoadingAccounts = true;
  List<PaymentAccount> _paymentAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentAccounts();
  }

  Future<void> _loadPaymentAccounts() async {
    try {
      final dbService = DatabaseService();
      final accounts = await dbService.getPaymentAccounts();
      
      setState(() {
        _paymentAccounts = accounts;
        _isLoadingAccounts = false;
      });
    } catch (e) {
      debugPrint('Error loading payment accounts: $e');
      setState(() {
        _isLoadingAccounts = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _transactionIdController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء اختيار طريقة الدفع'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty &&
        (_selectedMethod == service.PaymentMethod.syriatelCash ||
            _selectedMethod == service.PaymentMethod.mtnCash)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء إدخال رقم الهاتف'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // رقم العملية إلزامي
    if (_transactionIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء إدخال رقم العملية'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final paymentService = service.PaymentService();
      final result = await paymentService.processPaymentWithReceipt(
        amount: widget.amount,
        method: _selectedMethod!,
        phoneNumber: _phoneController.text.trim(),
        transactionId: _transactionIdController.text.trim(),
        receiptImagePath: null, // لا توجد صورة
        courseId: widget.course?.id,
      );

      if (mounted) {
        if (result['success'] == true) {
          _showPendingDialog(result['order_id'], result['receipt_id']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'حدث خطأ'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  PaymentAccount? _getSelectedAccount() {
    if (_selectedMethod == null) return null;
    
    final methodKey = _getMethodKey(_selectedMethod!);
    return _paymentAccounts.firstWhere(
      (account) => account.paymentMethod == methodKey,
      orElse: () => PaymentAccount(
        id: '',
        paymentMethod: methodKey,
        accountName: 'غير متوفر',
        accountNumber: 'N/A',
        isActive: false,
        displayOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  String _getMethodKey(service.PaymentMethod method) {
    switch (method) {
      case service.PaymentMethod.shamCash:
        return 'sham_cash';
      case service.PaymentMethod.syriatelCash:
        return 'syriatel_cash';
      case service.PaymentMethod.mtnCash:
        return 'mtn_cash';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoadingAccounts
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.getTextColor(context)),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPlanSummary(),
                            SizedBox(height: 24),
                            _buildScanQrCard(),
                            SizedBox(height: 24),
                            Text(
                              'اختر طريقة الدفع',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildPaymentMethod(
                              method: service.PaymentMethod.syriatelCash,
                              title: 'سيريتل كاش',
                              icon: Icons.phone_android,
                              color: Color(0xFF00A651),
                            ),
                            SizedBox(height: 12),
                            _buildPaymentMethod(
                              method: service.PaymentMethod.mtnCash,
                              title: 'MTN كاش',
                              icon: Icons.phone_android,
                              color: Color(0xFFFFCC00),
                            ),
                            SizedBox(height: 12),
                            _buildPaymentMethod(
                              method: service.PaymentMethod.shamCash,
                              title: 'شام كاش',
                              icon: Icons.account_balance_wallet,
                              color: Color(0xFF2196F3),
                            ),
                            if (_selectedMethod != null) ...[ 
                              SizedBox(height: 24),
                              _buildPaymentDetails(),
                            ],
                            SizedBox(height: 30),
                            _buildPayButton(),
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
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.getMutedTextColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getMutedTextColor(context),
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
              'الدفع',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextColor(context),
              ),
            ),
          ),
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPlanSummary() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ملخص الطلب',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  Text(
                    '${widget.amount} ل.س',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Divider(color: AppColors.getTextColor(context), height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المجموع',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  Text(
                    '${widget.amount} ل.س',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethod({
    required service.PaymentMethod method,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedMethod == method;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected ? null : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.5)
                  : Colors.white.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _selectedMethod = method;
                });
              },
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: AppColors.getTextColor(context),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: AppColors.getTextColor(context),
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentDetails() {
    final account = _getSelectedAccount();
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.getMutedTextColor(context),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تفاصيل الدفع',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextColor(context),
                ),
              ),
              SizedBox(height: 16),
              
              // Account Information
              if (account != null) ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'معلومات التحويل:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextColor(context),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildInfoRow('اسم الحساب:', account.accountName),
                      _buildInfoRow('رقم الحساب:', account.accountNumber),
                      if (account.instructions != null) ...[
                        SizedBox(height: 12),
                        Text(
                          account.instructions!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.getTextColor(context, secondary: true),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Phone Number (للطرق التي تحتاجه)
              if (_selectedMethod == service.PaymentMethod.syriatelCash ||
                  _selectedMethod == service.PaymentMethod.mtnCash) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppColors.getTextColor(context)),
                  decoration: InputDecoration(
                    labelText: 'رقم الهاتف الذي حولت منه',
                    labelStyle: TextStyle(color: AppColors.getTextColor(context)),
                    hintText: '09XX XXX XXX',
                    hintStyle: TextStyle(
                      color: AppColors.getTextColor(context, secondary: true),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.getMutedTextColor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.getMutedTextColor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.getTextColor(context),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
              ],

              // Transaction ID - إلزامي
              TextField(
                controller: _transactionIdController,
                keyboardType: TextInputType.text,
                textAlign: TextAlign.right,
                style: TextStyle(color: AppColors.getTextColor(context)),
                decoration: InputDecoration(
                  labelText: 'رقم العملية *',
                  labelStyle: TextStyle(color: AppColors.getTextColor(context)),
                  hintText: 'أدخل رقم عملية التحويل',
                  hintStyle: TextStyle(
                    color: AppColors.getTextColor(context, secondary: true),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  prefixIcon: Icon(Icons.receipt, color: AppColors.getTextColor(context)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.getMutedTextColor(context),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.getMutedTextColor(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.getTextColor(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'بعد إتمام التحويل، أدخل رقم العملية الذي حصلت عليه من التطبيق',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.getTextColor(context, secondary: true),
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
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.getTextColor(context, secondary: true),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.getTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isProcessing ? null : _processPayment,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: _isProcessing
                      ? Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: AppColors.getTextColor(context),
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Text(
                          'إرسال الطلب للمراجعة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.getTextColor(context),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanQrCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.purple.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.getTextColor(context), size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'هل لديك كود تفعيل؟',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextColor(context),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'امسح رمز QR لتفعيل الدورة مباشرة',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.getTextColor(context).withOpacity(0.70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => QrScannerScreen(),
                      ),
                    );

                    if (result == true && mounted) {
                      // Success, maybe close payment screen or referesh
                      Navigator.pop(context, true);
                    }
                  },
                  icon: Icon(Icons.camera_alt),
                  label: Text('اشحن بالكود (QR)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPendingDialog(String orderId, String receiptId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.getMutedTextColor(context),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.schedule,
                      color: Colors.orange,
                      size: 50,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'طلبك قيد المراجعة',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'تم إرسال طلبك بنجاح\nسيتم مراجعته والرد عليك قريباً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.getTextColor(context),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'رقم الطلب: ${orderId.substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.getTextColor(context, secondary: true),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'العودة للرئيسية',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.getTextColor(context),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}
