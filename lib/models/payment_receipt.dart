class PaymentReceipt {
  final String id;
  final String orderId;
  final String userId;
  final String? courseId;
  final String? courseTitle;
  final String? courseImageUrl;
  final String paymentMethod;
  final String? transactionId;
  final String? receiptImageUrl;
  final String? phoneNumber;
  final double amount;
  final PaymentReceiptStatus status;
  final String? adminNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentReceipt({
    required this.id,
    required this.orderId,
    required this.userId,
    this.courseId,
    this.courseTitle,
    this.courseImageUrl,
    required this.paymentMethod,
    this.transactionId,
    this.receiptImageUrl,
    this.phoneNumber,
    required this.amount,
    required this.status,
    this.adminNotes,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) {
    final courses = json['courses'] as Map<String, dynamic>?;
    return PaymentReceipt(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String?,
      courseTitle: courses?['title'] as String?,
      courseImageUrl: courses?['image_url'] as String?,
      paymentMethod: json['payment_method'] as String,
      transactionId: json['transaction_id'] as String?,
      receiptImageUrl: json['receipt_image_url'] as String?,
      phoneNumber: json['phone_number'] as String?,
      amount: (json['amount'] as num).toDouble(),
      status: _parseStatus(json['status'] as String),
      adminNotes: json['admin_notes'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'user_id': userId,
      'payment_method': paymentMethod,
      'transaction_id': transactionId,
      'receipt_image_url': receiptImageUrl,
      'phone_number': phoneNumber,
      'amount': amount,
      'status': _statusToString(status),
      'admin_notes': adminNotes,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static PaymentReceiptStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return PaymentReceiptStatus.pending;
      case 'approved':
        return PaymentReceiptStatus.approved;
      case 'rejected':
        return PaymentReceiptStatus.rejected;
      case 'under_review':
        return PaymentReceiptStatus.underReview;
      default:
        return PaymentReceiptStatus.pending;
    }
  }

  static String _statusToString(PaymentReceiptStatus status) {
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

  String get statusDisplayName {
    switch (status) {
      case PaymentReceiptStatus.pending:
        return 'قيد الانتظار';
      case PaymentReceiptStatus.approved:
        return 'تم القبول';
      case PaymentReceiptStatus.rejected:
        return 'مرفوض';
      case PaymentReceiptStatus.underReview:
        return 'قيد المراجعة';
    }
  }

  String get paymentMethodDisplayName {
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

enum PaymentReceiptStatus {
  pending,
  approved,
  rejected,
  underReview,
}
