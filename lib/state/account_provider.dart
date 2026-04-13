import 'dart:async';

import 'package:flutter/material.dart';

import '../data/models/account.dart';
import '../data/repositories/firestore_repository.dart';

class AccountProvider extends ChangeNotifier {
  AccountProvider(this._repository) {
    _listen();
  }

  final FirestoreRepository _repository;
  StreamSubscription<List<Account>>? _subscription;

  List<Account> _accounts = <Account>[];
  bool _isLoading = true;
  String? _errorMessage;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _listen() {
    _subscription?.cancel();
    _isLoading = true;
    _subscription = _repository.watchAccounts().listen(
      (accounts) {
        _accounts = accounts;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        _errorMessage = 'Failed to load accounts.';
        notifyListeners();
      },
    );
  }

  Future<void> updateAccount(String id, Map<String, dynamic> data) {
    return _repository.updateAccount(id, data);
  }

  Future<void> deleteAccount(String id) {
    return _repository.deleteAccount(id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
