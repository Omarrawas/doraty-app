class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMonths;
  final List<String> features;
  final bool isPopular;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMonths,
    required this.features,
    this.isPopular = false,
  });

  String get formattedPrice {
    return '${price.toStringAsFixed(0)} ل.س';
  }

  String get formattedDuration {
    if (durationMonths == 1) return 'شهر واحد';
    if (durationMonths == 12) return 'سنة واحدة';
    return '$durationMonths أشهر';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'durationMonths': durationMonths,
      'features': features,
      'isPopular': isPopular,
    };
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      durationMonths: json['durationMonths'],
      features: List<String>.from(json['features']),
      isPopular: json['isPopular'] ?? false,
    );
  }
}

class UserSubscription {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  UserSubscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  bool get isExpired => DateTime.now().isAfter(endDate);

  int get daysRemaining {
    if (isExpired) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planId': planId,
      'planName': planName,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'],
      userId: json['userId'],
      planId: json['planId'],
      planName: json['planName'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'],
    );
  }
}

enum PaymentMethod {
  syriatel,
  mtn,
  bankTransfer,
  creditCard,
}

class Payment {
  final String id;
  final String userId;
  final double amount;
  final PaymentMethod method;
  final String? transactionId;
  final DateTime createdAt;
  final PaymentStatus status;

  Payment({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    this.transactionId,
    required this.createdAt,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'method': method.toString(),
      'transactionId': transactionId,
      'createdAt': createdAt.toIso8601String(),
      'status': status.toString(),
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      userId: json['userId'],
      amount: (json['amount'] ?? 0).toDouble(),
      method: PaymentMethod.values.firstWhere(
        (e) => e.toString() == json['method'],
      ),
      transactionId: json['transactionId'],
      createdAt: DateTime.parse(json['createdAt']),
      status: PaymentStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
    );
  }
}

enum PaymentStatus {
  pending,
  completed,
  failed,
  cancelled,
}
