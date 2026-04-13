import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/account.dart';
import '../models/account_subscription.dart';
import '../models/device.dart';

class FirestoreRepository {
  final CollectionReference<Map<String, dynamic>> _accountsRef =
      FirebaseFirestore.instance.collection('accounts');
  final CollectionReference<Map<String, dynamic>> _devicesRef =
      FirebaseFirestore.instance.collection('devices');
  final CollectionReference<Map<String, dynamic>> _subscriptionsRef =
      FirebaseFirestore.instance.collection('subscriptions');

  Stream<List<Account>> watchAccounts() {
    return _accountsRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Account.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<Device>> watchDevicesForAccount(String accountId) {
    return _devicesRef
        .where('accountId', isEqualTo: accountId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Device.fromFirestore(doc)).toList(),
        );
  }

  Stream<List<AccountSubscription>> watchSubscriptionsForMonth(
    String monthKey,
  ) {
    return _subscriptionsRef
        .where('monthKey', isEqualTo: monthKey)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(AccountSubscription.fromFirestore).toList(),
        );
  }

  Stream<List<AccountSubscription>> watchAllSubscriptions() {
    return _subscriptionsRef.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(AccountSubscription.fromFirestore).toList(),
    );
  }

  Future<List<AccountSubscription>> fetchSubscriptionsForMonth(
    String monthKey,
  ) async {
    final snapshot = await _subscriptionsRef
        .where('monthKey', isEqualTo: monthKey)
        .get();
    return snapshot.docs.map(AccountSubscription.fromFirestore).toList();
  }

  Future<void> updateAccount(String id, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _accountsRef.doc(id).update(payload);
  }

  Future<void> deleteAccount(String id) async {
    await _accountsRef.doc(id).delete();
  }

  Future<void> saveSubscription(AccountSubscription subscription) async {
    final payload = subscription.toFirestore();
    payload['updatedAt'] = FieldValue.serverTimestamp();
    if (subscription.createdAt == null) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }

    await _subscriptionsRef
        .doc(subscription.id)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> deleteSubscriptionsForMonth(String monthKey) async {
    final snapshot = await _subscriptionsRef
        .where('monthKey', isEqualTo: monthKey)
        .get();
    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> deleteSubscriptionForAccountAndMonth({
    required String accountDocId,
    required String monthKey,
  }) async {
    final docId = AccountSubscription.buildDocumentId(
      accountDocId: accountDocId,
      monthKey: monthKey,
    );
    await _subscriptionsRef.doc(docId).delete();
  }

  Future<void> initializeSubscriptionsForMonth({
    required List<Account> accounts,
    required DateTime month,
    required double defaultAmount,
  }) async {
    final monthKey = _monthKey(month);
    final snapshot = await _subscriptionsRef
        .where('monthKey', isEqualTo: monthKey)
        .get();
    final existingAccountIds = snapshot.docs
        .map((doc) => (doc.data()['accountDocId'] ?? '').toString())
        .where((value) => value.isNotEmpty)
        .toSet();

    final batch = FirebaseFirestore.instance.batch();
    for (final account in accounts) {
      if (existingAccountIds.contains(account.id)) {
        continue;
      }

      final docId = AccountSubscription.buildDocumentId(
        accountDocId: account.id,
        monthKey: monthKey,
      );
      batch.set(_subscriptionsRef.doc(docId), <String, dynamic>{
        'accountDocId': account.id,
        'accountId': account.accountId,
        'businessName': account.businessName,
        'ownerName': account.ownerName,
        'monthKey': monthKey,
        'status': SubscriptionStatus.unpaid.value,
        'amount': defaultAmount,
        'notes': '',
        'paidAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> updateDevice(String id, Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _devicesRef.doc(id).update(payload);
  }

  Future<void> deleteDevice(String id) async {
    await _devicesRef.doc(id).delete();
  }

  String _monthKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }
}
