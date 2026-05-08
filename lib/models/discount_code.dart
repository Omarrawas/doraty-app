import '../core/utils/safe_parser.dart';

class DiscountCode {
  final String id;
  final String code;
  final int discountPercent;
  final double discountAmount;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final int? usageLimit;
  final int usageCount;
  final String? courseId;
  final String? bundleId;
  final bool isActive;

  DiscountCode({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.discountAmount,
    this.validFrom,
    this.validUntil,
    this.usageLimit,
    required this.usageCount,
    this.courseId,
    this.bundleId,
    required this.isActive,
  });

  factory DiscountCode.fromJson(Map<String, dynamic> json) {
    return DiscountCode(
      id: SafeParser.toStringSafe(json['id']),
      code: SafeParser.toStringSafe(json['code']),
      discountPercent: SafeParser.toInt(json['discount_percent']),
      discountAmount: SafeParser.toDouble(json['discount_amount']),
      validFrom: SafeParser.toDateTime(json['valid_from']),
      validUntil: SafeParser.toDateTime(json['valid_until']),
      usageLimit: json['usage_limit'] != null ? SafeParser.toInt(json['usage_limit']) : null,
      usageCount: SafeParser.toInt(json['usage_count']),
      courseId: SafeParser.toStringSafe(json['course_id']),
      bundleId: SafeParser.toStringSafe(json['bundle_id']),
      isActive: SafeParser.toBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_percent': discountPercent,
      'discount_amount': discountAmount,
      'valid_from': validFrom?.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'usage_limit': usageLimit,
      'usage_count': usageCount,
      'course_id': courseId,
      'bundle_id': bundleId,
      'is_active': isActive,
    };
  }

  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    if (usageLimit != null && usageCount >= usageLimit!) return false;
    return true;
  }

  double calculateDiscount(double originalAmount) {
    double discount = 0;
    if (discountPercent > 0) {
      discount = originalAmount * (discountPercent / 100);
    } else if (discountAmount > 0) {
      discount = discountAmount;
    }
    return discount > originalAmount ? originalAmount : discount;
  }
}
