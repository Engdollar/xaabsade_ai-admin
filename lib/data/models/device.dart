import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  Device({
    required this.id,
    required this.accountId,
    required this.allowed,
    required this.appName,
    required this.buildNumber,
    required this.createdAt,
    required this.deviceId,
    required this.deviceName,
    required this.lastSeenAt,
    required this.packageName,
    required this.platform,
    required this.updatedAt,
    required this.version,
  });

  final String id;
  final String accountId;
  final bool allowed;
  final String appName;
  final String buildNumber;
  final DateTime? createdAt;
  final String deviceId;
  final String deviceName;
  final DateTime? lastSeenAt;
  final String packageName;
  final String platform;
  final DateTime? updatedAt;
  final String version;

  factory Device.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Device(
      id: doc.id,
      accountId: (data['accountId'] ?? '').toString(),
      allowed: data['allowed'] == true,
      appName: (data['appName'] ?? '').toString(),
      buildNumber: (data['buildNumber'] ?? '').toString(),
      createdAt: _toDate(data['createdAt']),
      deviceId: (data['deviceId'] ?? '').toString(),
      deviceName: (data['deviceName'] ?? '').toString(),
      lastSeenAt: _toDate(data['lastSeenAt']),
      packageName: (data['packageName'] ?? '').toString(),
      platform: (data['platform'] ?? '').toString(),
      updatedAt: _toDate(data['updatedAt']),
      version: (data['version'] ?? '').toString(),
    );
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
