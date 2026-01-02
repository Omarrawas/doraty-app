class PaymentAccount {
  final String id;
  final String paymentMethod; // syriatel_cash, mtn_cash, sham_cash
  final String accountName;
  final String accountNumber;
  final Map<String, dynamic>? accountDetails;
  final String? instructions;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentAccount({
    required this.id,
    required this.paymentMethod,
    required this.accountName,
    required this.accountNumber,
    this.accountDetails,
    this.instructions,
    required this.isActive,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentAccount.fromJson(Map<String, dynamic> json) {
    return PaymentAccount(
      id: json['id'] as String,
      paymentMethod: json['payment_method'] as String,
      accountName: json['account_name'] as String,
      accountNumber: json['account_number'] as String,
      accountDetails: json['account_details'] as Map<String, dynamic>?,
      instructions: json['instructions'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_method': paymentMethod,
      'account_name': accountName,
      'account_number': accountNumber,
      'account_details': accountDetails,
      'instructions': instructions,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get methodDisplayName {
    switch (paymentMethod) {
      case 'syriatel_cash':
        return 'سيريتل كاش';
      case 'mtn_cash':
        return 'MTN كاش';
      case 'sham_cash':
        return 'شام كاش';
      default:
        return paymentMethod;
    }
  }
}
