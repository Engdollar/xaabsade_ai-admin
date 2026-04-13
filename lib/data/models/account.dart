import 'package:cloud_firestore/cloud_firestore.dart';

class Account {
  Account({
    required this.id,
    required this.accountId,
    required this.accountIdLower,
    required this.activeDeviceId,
    required this.allowedDeviceIds,
    required this.businessName,
    required this.ownerName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.updatedAt,
  });

  final String id;
  final String accountId;
  final String accountIdLower;
  final String activeDeviceId;
  final List<String> allowedDeviceIds;
  final String businessName;
  final String ownerName;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final DateTime? updatedAt;

  factory Account.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Account(
      id: doc.id,
      accountId: (data['accountId'] ?? '').toString(),
      accountIdLower: (data['accountIdLower'] ?? '').toString(),
      activeDeviceId: (data['activeDeviceId'] ?? '').toString(),
      allowedDeviceIds: _stringList(data['allowedDeviceIds']),
      businessName: (data['businessName'] ?? '').toString(),
      ownerName: (data['ownerName'] ?? '').toString(),
      createdAt: _toDate(data['createdAt']),
      lastSeenAt: _toDate(data['lastSeenAt']),
      updatedAt: _toDate(data['updatedAt']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value.map((item) => item.toString()).toList();
    }
    return <String>[];
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
}
