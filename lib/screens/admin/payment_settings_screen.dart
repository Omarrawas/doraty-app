import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../models/payment_account.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../widgets/dynamic_gradient_background.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final DatabaseService _db = DatabaseService();
  List<PaymentAccount> _accounts = [];
  bool _isLoading = true;
  bool _isQrEnabled = true; // Default to true or fetch from settings

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoading = true);
    try {
      final accounts = await _db.getPaymentAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الحسابات: $e',
                style: const TextStyle(fontFamily: 'Cairo')),
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
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : RefreshIndicator(
                          onRefresh: _loadAccounts,
                          child: _accounts.isEmpty
                              ? _buildEmptyState()
                              : _buildAccountsList(),
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
              'إعدادات الدفع',
              style: TextStyle(
                fontSize: 22,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
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
                  onPressed: _loadAccounts,
                ),
              ),
            ),
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
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text(
            'لا توجد حسابات دفع',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Cairo',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _accounts.length + 1, // +1 for QR Code
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildQrCodeToggle();
        }
        return _buildAccountCard(_accounts[index - 1]);
      },
    );
  }

  Widget _buildQrCodeToggle() {
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
                  width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.qr_code_2,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الدفع عبر رمز QR',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              color: AppColors.getTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isQrEnabled ? 'مفعل' : 'غبر مفعل',
                            style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Cairo',
                              color: _isQrEnabled
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isQrEnabled,
                      activeColor: AppColors.primaryPurple,
                      onChanged: (value) {
                         setState(() => _isQrEnabled = value);

                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(
                             content: Text(
                               value ? 'تم تفعيل الدفع عبر QR' : 'تم إيقاف الدفع عبر QR',
                               style: const TextStyle(fontFamily: 'Cairo'),
                             ),
                             backgroundColor: value ? Colors.green : Colors.red,
                           ),
                         );
                      },
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

  Widget _buildAccountCard(PaymentAccount account) {
    Color cardColor = Colors.white;
    IconData icon = Icons.credit_card;

    if (account.paymentMethod == 'syriatel_cash') {
      cardColor = Colors.redAccent;
      icon = Icons.phone_android;
    } else if (account.paymentMethod == 'mtn_cash') {
      cardColor = Colors.amber;
      icon = Icons.phone_android;
    } else if (account.paymentMethod == 'sham_cash') {
      cardColor = Colors.blueAccent;
      icon = Icons.account_balance;
    }

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: cardColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.methodDisplayName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Cairo',
                                color: AppColors.getTextColor(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              account.isActive ? 'مفعل' : 'غير مفعل',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Cairo',
                                color: account.isActive
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _showEditDialog(account),
                        icon: const Icon(Icons.edit, color: Colors.white),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white12),
                  _buildDetailRow('اسم الحساب', account.accountName),
                  const SizedBox(height: 8),
                  _buildDetailRow('الرقم', account.accountNumber),
                  if (account.instructions != null &&
                      account.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('تعليمات', account.instructions!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Cairo',
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showEditDialog(PaymentAccount account) {
    final nameController = TextEditingController(text: account.accountName);
    final numberController = TextEditingController(text: account.accountNumber);
    final instructionsController =
        TextEditingController(text: account.instructions);
    bool isActive = account.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E1E2C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(
                'تعديل ${account.methodDisplayName}',
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Cairo'),
                      decoration: const InputDecoration(
                        labelText: 'اسم الحساب',
                        labelStyle: TextStyle(
                            color: Colors.white, fontFamily: 'Cairo'),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: numberController,
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Cairo'),
                      decoration: const InputDecoration(
                        labelText: 'رقم الحساب / الهاتف',
                        labelStyle: TextStyle(
                            color: Colors.white, fontFamily: 'Cairo'),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: instructionsController,
                      style: const TextStyle(
                          color: Colors.white, fontFamily: 'Cairo'),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'تعليمات إضافية',
                        labelStyle: TextStyle(
                            color: Colors.white, fontFamily: 'Cairo'),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text(
                          'الحالة:',
                          style: TextStyle(
                              color: Colors.white, fontFamily: 'Cairo'),
                        ),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (val) => setState(() => isActive = val),
                          activeColor: AppColors.primaryPurple,
                        ),
                        Text(
                          isActive ? 'مفعل' : 'غير مفعل',
                          style: TextStyle(
                            color:
                                isActive ? Colors.greenAccent : Colors.redAccent,
                            fontFamily: 'Cairo',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context); // Close dialog
                    
                    try {
                      setState(() => _isLoading = true);

                      final updatedAccount = PaymentAccount(
                        id: account.id,
                        paymentMethod: account.paymentMethod,
                        accountName: nameController.text,
                        accountNumber: numberController.text,
                        instructions: instructionsController.text,
                        isActive: isActive,
                        // Preserve other fields
                        displayOrder: account.displayOrder,
                        createdAt: account.createdAt,
                        updatedAt: DateTime.now(),
                        accountDetails: account.accountDetails,
                      );

                      await _db.updatePaymentAccount(updatedAccount);
                      await _loadAccounts(); // Reload list

                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('تم التحديث بنجاح',
                                style: TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                         setState(() => _isLoading = false);
                         messenger.showSnackBar(
                          SnackBar(
                            content: Text('خطأ في التحديث: $e',
                                style: const TextStyle(fontFamily: 'Cairo')),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ',
                      style:
                          TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
