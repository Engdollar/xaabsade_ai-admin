import 'package:flutter/material.dart';

class AccountSelectionProvider extends ChangeNotifier {
  String? _accountId;

  String? get accountId => _accountId;

  void select(String accountId) {
    if (_accountId == accountId) {
      return;
    }
    _accountId = accountId;
    notifyListeners();
  }

  void clear() {
    if (_accountId == null) {
      return;
    }
    _accountId = null;
    notifyListeners();
  }
}
