import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/database_service.dart';
import '../models/subscription.dart';

enum PaymentMethod {
  shamCash,
  syriatelCash,
  mtnCash,
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  /// Process payment with manual verification (NEW SYSTEM)
  Future<Map<String, dynamic>> processPaymentWithReceipt({
    required SubscriptionPlan plan,
    required PaymentMethod method,
    required String phoneNumber,
    String? transactionId,
    String? receiptImagePath,
  }) async {
    try {
      final dbService = DatabaseService();

      // 1. Create a "Pending" order in Supabase
      final order = await dbService.createOrder(
        planId: plan.id,
        amount: plan.price,
        paymentMethod: _getMethodKey(method),
        transactionId: transactionId,
      );

      final orderId = order['id'] as String;

      // 2. Upload receipt image if provided
      String? receiptUrl;
      if (receiptImagePath != null) {
        receiptUrl = await dbService.uploadReceiptImage(
          receiptImagePath,
          'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      // 3. Create payment receipt record
      final receiptId = await dbService.createPaymentReceipt(
        orderId: orderId,
        paymentMethod: _getMethodKey(method),
        amount: plan.price,
        transactionId: transactionId,
        receiptImageUrl: receiptUrl,
        phoneNumber: phoneNumber,
      );

      debugPrint('Payment receipt created: $receiptId');

      return {
        'success': true,
        'order_id': orderId,
        'receipt_id': receiptId,
        'message': 'تم إرسال طلبك بنجاح. سيتم مراجعته قريباً.',
      };
    } catch (e) {
      debugPrint('Error processing payment: $e');
      return {
        'success': false,
        'message': 'حدث خطأ أثناء معالجة الطلب. يرجى المحاولة مرة أخرى.',
      };
    }
  }

  Color getMethodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.shamCash:
        return AppColors.shamCash;
      case PaymentMethod.syriatelCash:
        return AppColors.syriatelCash;
      case PaymentMethod.mtnCash:
        return AppColors.mtnCash;
    }
  }

  String getMethodName(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.shamCash:
        return 'شام كاش';
      case PaymentMethod.syriatelCash:
        return 'سيريتل كاش';
      case PaymentMethod.mtnCash:
        return 'MTN كاش';
    }
  }

  String _getMethodKey(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.shamCash:
        return 'sham_cash';
      case PaymentMethod.syriatelCash:
        return 'syriatel_cash';
      case PaymentMethod.mtnCash:
        return 'mtn_cash';
    }
  }
}
