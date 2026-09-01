// lib/models/withdrawal_model.dart
import 'package:flutter/material.dart';

enum WithdrawalStatus {
  pending,
  processing,
  completed,
  failed,
  rejected,
}

extension WithdrawalStatusExtension on WithdrawalStatus {
  String get displayName {
    switch (this) {
      case WithdrawalStatus.pending:
        return 'Pending';
      case WithdrawalStatus.processing:
        return 'Processing';
      case WithdrawalStatus.completed:
        return 'Completed';
      case WithdrawalStatus.failed:
        return 'Failed';
      case WithdrawalStatus.rejected:
        return 'Rejected';
    }
  }

  Color get color {
    switch (this) {
      case WithdrawalStatus.pending:
      case WithdrawalStatus.processing:
        return Colors.orange;
      case WithdrawalStatus.completed:
        return Colors.green;
      case WithdrawalStatus.failed:
        return Colors.red;
      case WithdrawalStatus.rejected:
        return Colors.red;
    }
  }
}

class WithdrawalRequest {
  final int id;
  final int userId;
  final double amount;
  final String phone;
  final WithdrawalStatus status;
  final String? adminNotes;
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final DateTime? completedAt;

  WithdrawalRequest({
    required this.id,
    required this.userId,
    required this.amount,
    required this.phone,
    required this.status,
    this.adminNotes,
    this.rejectionReason,
    required this.requestedAt,
    this.processedAt,
    this.completedAt,
  });

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = WithdrawalStatus.values.firstWhere(
          (e) => e.name == statusStr,
      orElse: () => WithdrawalStatus.pending,
    );

    return WithdrawalRequest(
      id: json['id'] as int,
      userId: json['userId'] as int,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      phone: json['phone'] as String? ?? '',
      status: status,
      adminNotes: json['adminNotes'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      requestedAt: DateTime.tryParse(json['requestedAt'] as String? ?? '') ?? DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'amount': amount,
    'phone': phone,
    'status': status.name,
    'adminNotes': adminNotes,
    'rejectionReason': rejectionReason,
    'requestedAt': requestedAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  WithdrawalRequest copyWith({
    int? id,
    int? userId,
    double? amount,
    String? phone,
    WithdrawalStatus? status,
    String? adminNotes,
    String? rejectionReason,
    DateTime? requestedAt,
    DateTime? processedAt,
    DateTime? completedAt,
  }) {
    return WithdrawalRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      adminNotes: adminNotes ?? this.adminNotes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}