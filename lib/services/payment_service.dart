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

  Future<bool> processPayment({
    required SubscriptionPlan plan,
    required PaymentMethod method,
    required String phoneNumber,
    String? transactionId,
  }) async {
    try {
      final dbService = DatabaseService();

      // 1. Create a "Pending" order in Supabase
      final order = await dbService.createOrder(
        planId: plan.id,
        amount: plan.price,
        paymentMethod: getMethodName(method),
        transactionId: transactionId,
      );

      final orderId = order['id'];

      // 2. Simulate network delay / verification step
      await Future.delayed(const Duration(seconds: 3));

      // 3. Update order to "Completed"
      await dbService.updateOrderStatus(orderId, 'completed');

      // 4. Activate subscription
      final userId = order['user_id'];
      await dbService.activateSubscription(
        userId: userId,
        planId: plan.id,
        durationMonths: plan.durationMonths,
      );

      return true;
    } catch (e) {
      debugPrint('Error processing payment: $e');
      return false;
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
}
