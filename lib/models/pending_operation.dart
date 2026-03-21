import '../core/utils/safe_parser.dart';

enum OperationType {
  create,
  update,
  delete,
  toggle, // For things like like/bookmark
}

class PendingOperation {
  final String id;
  final String table;
  final OperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  PendingOperation({
    required this.id,
    required this.table,
    required this.type,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory PendingOperation.fromJson(Map<String, dynamic> json) {
    return PendingOperation(
      id: SafeParser.toStringSafe(json['id']),
      table: SafeParser.toStringSafe(json['table']),
      type: OperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => OperationType.update,
      ),
      data: SafeParser.safeMap(json['data']),
      createdAt: SafeParser.toDateTime(json['created_at']) ?? DateTime.now(),
      retryCount: SafeParser.toInt(json['retry_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table': table,
      'type': type.toString(),
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  PendingOperation copyWith({int? retryCount}) {
    return PendingOperation(
      id: id,
      table: table,
      type: type,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
