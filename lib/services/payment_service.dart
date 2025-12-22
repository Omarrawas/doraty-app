import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

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
    required String courseId,
    required double amount,
    required PaymentMethod method,
    required String phoneNumber,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 3));
    
    // In a real app, this would call the payment gateway API
    // For Syrian local payments, this might involve:
    // 1. Generating a payment request
    // 2. Waiting for user confirmation via USSD or SMS
    // 3. Verifying the transaction status
    
    return true; // Mock success
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
