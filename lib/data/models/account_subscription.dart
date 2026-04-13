import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus { paid, unpaid }

extension SubscriptionStatusX on SubscriptionStatus {
  String get value {
    switch (this) {
      case SubscriptionStatus.paid:
        return 'paid';
      case SubscriptionStatus.unpaid:
        return 'unpaid';
    }
  }

  String get label {
    switch (this) {
      case SubscriptionStatus.paid:
        return 'Paid';
      case SubscriptionStatus.unpaid:
        return 'Not paid';
    }
  }

  static SubscriptionStatus fromValue(dynamic value) {
    final normalized = (value ?? '').toString().toLowerCase().trim();
    if (normalized == 'paid') {
      return SubscriptionStatus.paid;
    }
    return SubscriptionStatus.unpaid;
  }
}

class AccountSubscription {
  AccountSubscription({
    required this.id,
    required this.accountDocId,
    required this.accountId,
    required this.businessName,
    required this.ownerName,
    required this.monthKey,
    required this.status,
    required this.amount,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.paidAt,
  });

  final String id;
  final String accountDocId;
  final String accountId;
  final String businessName;
  final String ownerName;
  final String monthKey;
  final SubscriptionStatus status;
  final double amount;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? paidAt;

  bool get isPaid => status == SubscriptionStatus.paid;

  factory AccountSubscription.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AccountSubscription(
      id: doc.id,
      accountDocId: (data['accountDocId'] ?? '').toString(),
      accountId: (data['accountId'] ?? '').toString(),
      businessName: (data['businessName'] ?? '').toString(),
      ownerName: (data['ownerName'] ?? '').toString(),
      monthKey: (data['monthKey'] ?? '').toString(),
      status: SubscriptionStatusX.fromValue(data['status']),
      amount: _toDouble(data['amount']),
      notes: (data['notes'] ?? '').toString(),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      paidAt: _toDate(data['paidAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'accountDocId': accountDocId,
      'accountId': accountId,
      'businessName': businessName,
      'ownerName': ownerName,
      'monthKey': monthKey,
      'status': status.value,
      'amount': amount,
      'notes': notes,
      'paidAt': paidAt,
    };
  }

  AccountSubscription copyWith({
    String? id,
    String? accountDocId,
    String? accountId,
    String? businessName,
    String? ownerName,
    String? monthKey,
    SubscriptionStatus? status,
    double? amount,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    bool clearPaidAt = false,
  }) {
    return AccountSubscription(
      id: id ?? this.id,
      accountDocId: accountDocId ?? this.accountDocId,
      accountId: accountId ?? this.accountId,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      monthKey: monthKey ?? this.monthKey,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: clearPaidAt ? null : (paidAt ?? this.paidAt),
    );
  }

  static String buildDocumentId({
    required String accountDocId,
    required String monthKey,
  }) {
    return '${accountDocId}_$monthKey';
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}
