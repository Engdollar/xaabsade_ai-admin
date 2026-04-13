import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/device.dart';
import '../data/repositories/firestore_repository.dart';

class DeviceProvider extends ChangeNotifier {
  DeviceProvider(this._repository);

  FirestoreRepository _repository;
  StreamSubscription<List<Device>>? _subscription;
  String? _accountId;

  List<Device> _devices = <Device>[];
  bool _isLoading = false;
  String? _errorMessage;

  List<Device> get devices => _devices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get accountId => _accountId;

  void updateRepository(FirestoreRepository repository) {
    _repository = repository;
  }

  void bindAccount(String? accountId) {
    if (_accountId == accountId) {
      return;
    }
    _accountId = accountId;
    _devices = <Device>[];
    _errorMessage = null;
    _subscription?.cancel();

    if (accountId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _repository
        .watchDevicesForAccount(accountId)
        .listen(
          (devices) {
            _devices = devices;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            _errorMessage = 'Failed to load devices.';
            notifyListeners();
          },
        );
  }

  Future<void> updateDevice(String id, Map<String, dynamic> data) {
    return _repository.updateDevice(id, data);
  }

  Future<void> deleteDevice(String id) {
    return _repository.deleteDevice(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
