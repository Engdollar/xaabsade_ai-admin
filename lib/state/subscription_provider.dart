import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/account.dart';
import '../data/models/account_subscription.dart';
import '../data/repositories/firestore_repository.dart';
import '../data/services/subscription_export_service.dart';

enum SubscriptionExportScope { all, paid, unpaid }

class BillingMonthGroup {
  const BillingMonthGroup({
    required this.month,
    required this.monthKey,
    required this.total,
    required this.paid,
    required this.unpaid,
  });

  final DateTime month;
  final String monthKey;
  final int total;
  final int paid;
  final int unpaid;

  String get label => DateFormat('MMMM yyyy').format(month);
}

class SubscriptionViewEntry {
  const SubscriptionViewEntry({
    required this.account,
    required this.subscription,
  });

  final Account account;
  final AccountSubscription? subscription;

  bool get isPaid => subscription?.isPaid ?? false;
  double get amount => subscription?.amount ?? 0;
  String get notes => subscription?.notes ?? '';
  DateTime? get paidAt => subscription?.paidAt;
  String get businessName =>
      account.businessName.isEmpty ? 'Unnamed account' : account.businessName;
}

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider(
    this._repository, {
    SubscriptionExportService? exportService,
  }) : _exportService = exportService ?? createSubscriptionExportService() {
    _listen();
    _listenMonths();
  }

  FirestoreRepository _repository;
  final SubscriptionExportService _exportService;
  StreamSubscription<List<AccountSubscription>>? _subscription;
  StreamSubscription<List<AccountSubscription>>? _monthsSubscription;

  DateTime _currentMonth = _normalizeMonth(DateTime.now());
  List<Account> _accounts = <Account>[];
  List<AccountSubscription> _subscriptions = <AccountSubscription>[];
  List<BillingMonthGroup> _billingMonthGroups = <BillingMonthGroup>[];
  Map<String, Map<String, AccountSubscription>> _subscriptionsByMonth =
      <String, Map<String, AccountSubscription>>{};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isInitializing = false;
  bool _isExporting = false;
  String? _errorMessage;

  DateTime get currentMonth => _currentMonth;
  String get currentMonthKey => DateFormat('yyyy-MM').format(_currentMonth);
  String get currentMonthLabel => DateFormat('MMMM yyyy').format(_currentMonth);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isInitializing => _isInitializing;
  bool get isExporting => _isExporting;
  String? get errorMessage => _errorMessage;
  List<BillingMonthGroup> get billingMonthGroups {
    if (_billingMonthGroups.any((group) => group.monthKey == currentMonthKey)) {
      return _billingMonthGroups;
    }

    return <BillingMonthGroup>[
      BillingMonthGroup(
        month: _currentMonth,
        monthKey: currentMonthKey,
        total: entries.length,
        paid: paidCount,
        unpaid: unpaidCount,
      ),
      ..._billingMonthGroups,
    ];
  }

  List<SubscriptionViewEntry> get entries {
    final subscriptionByAccount = <String, AccountSubscription>{
      for (final item in _subscriptions) item.accountDocId: item,
    };

    final items = _accounts
        .map(
          (account) => SubscriptionViewEntry(
            account: account,
            subscription: subscriptionByAccount[account.id],
          ),
        )
        .toList();

    items.sort((left, right) {
      final statusCompare = left.isPaid == right.isPaid
          ? 0
          : (left.isPaid ? 1 : -1);
      if (statusCompare != 0) {
        return statusCompare;
      }
      return left.businessName.toLowerCase().compareTo(
        right.businessName.toLowerCase(),
      );
    });

    return items;
  }

  int get paidCount => entries.where((entry) => entry.isPaid).length;
  int get unpaidCount => entries.length - paidCount;
  double get totalCollected => entries
      .where((entry) => entry.isPaid)
      .fold(0, (sum, entry) => sum + entry.amount);

  void updateRepository(FirestoreRepository repository) {
    if (identical(_repository, repository)) {
      return;
    }
    _repository = repository;
    _listen();
    _listenMonths();
  }

  void updateAccounts(List<Account> accounts) {
    _accounts = List<Account>.unmodifiable(accounts);
    notifyListeners();
  }

  void shiftMonth(int offset) {
    setMonth(DateTime(_currentMonth.year, _currentMonth.month + offset));
  }

  void setMonth(DateTime value) {
    final normalized = _normalizeMonth(value);
    if (_currentMonth.year == normalized.year &&
        _currentMonth.month == normalized.month) {
      return;
    }
    _currentMonth = normalized;
    _listen();
    notifyListeners();
  }

  AccountSubscription? subscriptionForAccount(String accountDocId) {
    for (final item in _subscriptions) {
      if (item.accountDocId == accountDocId) {
        return item;
      }
    }
    return null;
  }

  AccountSubscription? subscriptionForAccountInMonth({
    required String accountDocId,
    required DateTime month,
  }) {
    final monthKey = DateFormat('yyyy-MM').format(_normalizeMonth(month));
    return _subscriptionsByMonth[monthKey]?[accountDocId];
  }

  List<AccountSubscription> billsForAccount(String accountDocId) {
    final items = <AccountSubscription>[];
    for (final monthMap in _subscriptionsByMonth.values) {
      final subscription = monthMap[accountDocId];
      if (subscription != null) {
        items.add(subscription);
      }
    }

    items.sort((left, right) => right.monthKey.compareTo(left.monthKey));
    return items;
  }

  Future<void> saveSubscription({
    required Account account,
    required bool isPaid,
    required double amount,
    required String notes,
  }) async {
    final existing = subscriptionForAccount(account.id);
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = AccountSubscription(
        id: AccountSubscription.buildDocumentId(
          accountDocId: account.id,
          monthKey: currentMonthKey,
        ),
        accountDocId: account.id,
        accountId: account.accountId,
        businessName: account.businessName,
        ownerName: account.ownerName,
        monthKey: currentMonthKey,
        status: isPaid ? SubscriptionStatus.paid : SubscriptionStatus.unpaid,
        amount: amount,
        notes: notes.trim(),
        createdAt: existing?.createdAt,
        updatedAt: DateTime.now(),
        paidAt: isPaid ? (existing?.paidAt ?? DateTime.now()) : null,
      );
      await _repository.saveSubscription(payload);
    } catch (_) {
      _errorMessage = 'Failed to save subscription.';
      rethrow;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> initializeCurrentMonth() async {
    return initializeMonth(
      month: _currentMonth,
      defaultAmount: 0,
      moveToMonth: false,
    );
  }

  Future<void> initializeMonth({
    required DateTime month,
    required double defaultAmount,
    bool moveToMonth = true,
  }) async {
    final normalizedMonth = _normalizeMonth(month);
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.initializeSubscriptionsForMonth(
        accounts: _accounts,
        month: normalizedMonth,
        defaultAmount: defaultAmount,
      );
      if (moveToMonth) {
        setMonth(normalizedMonth);
      }
    } catch (_) {
      _errorMessage = 'Failed to initialize subscriptions for the month.';
      rethrow;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<SubscriptionExportResult> exportCurrentMonth() async {
    return exportMonth(
      month: _currentMonth,
      scope: SubscriptionExportScope.all,
    );
  }

  Future<SubscriptionExportResult> exportMonth({
    required DateTime month,
    required SubscriptionExportScope scope,
  }) async {
    final normalizedMonth = _normalizeMonth(month);
    final monthKey = DateFormat('yyyy-MM').format(normalizedMonth);
    _isExporting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final monthSubscriptions = await _repository.fetchSubscriptionsForMonth(
        monthKey,
      );
      final byAccount = <String, AccountSubscription>{
        for (final item in monthSubscriptions) item.accountDocId: item,
      };

      final rows = <SubscriptionExportRow>[];
      for (final account in _accounts) {
        final subscription = byAccount[account.id];
        final isPaid = subscription?.isPaid ?? false;

        if (scope == SubscriptionExportScope.paid && !isPaid) {
          continue;
        }
        if (scope == SubscriptionExportScope.unpaid && isPaid) {
          continue;
        }

        rows.add(
          SubscriptionExportRow(
            accountId: account.accountId,
            businessName: account.businessName.isEmpty
                ? 'Unnamed account'
                : account.businessName,
            ownerName: account.ownerName,
            statusLabel: isPaid ? 'Paid' : 'Unpaid',
            amount: subscription?.amount ?? 0,
            notes: subscription?.notes ?? '',
            paidAtLabel: subscription?.paidAt == null
                ? ''
                : DateFormat('yyyy-MM-dd HH:mm').format(subscription!.paidAt!),
          ),
        );
      }

      return await _exportService.exportMonthlyReport(
        month: normalizedMonth,
        rows: rows,
      );
    } catch (_) {
      _errorMessage = 'Failed to export monthly subscriptions.';
      rethrow;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<void> deleteMonthBills(DateTime month) async {
    final monthKey = DateFormat('yyyy-MM').format(_normalizeMonth(month));
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteSubscriptionsForMonth(monthKey);
    } catch (_) {
      _errorMessage = 'Failed to delete month bills.';
      rethrow;
    }
  }

  Future<void> deleteAccountBillForCurrentMonth(String accountDocId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteSubscriptionForAccountAndMonth(
        accountDocId: accountDocId,
        monthKey: currentMonthKey,
      );
    } catch (_) {
      _errorMessage = 'Failed to delete account bill.';
      rethrow;
    }
  }

  void _listen() {
    _subscription?.cancel();
    _isLoading = true;
    _subscription = _repository
        .watchSubscriptionsForMonth(currentMonthKey)
        .listen(
          (items) {
            _subscriptions = items;
            _isLoading = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (_) {
            _isLoading = false;
            _errorMessage = 'Failed to load subscriptions.';
            notifyListeners();
          },
        );
  }

  void _listenMonths() {
    _monthsSubscription?.cancel();
    _monthsSubscription = _repository.watchAllSubscriptions().listen((items) {
      final monthMap = <String, _MonthAccumulator>{};
      final monthAccountMap = <String, Map<String, AccountSubscription>>{};
      for (final item in items) {
        if (item.monthKey.isEmpty) {
          continue;
        }

        monthMap.putIfAbsent(item.monthKey, _MonthAccumulator.new).add(item);
        final accountMap = monthAccountMap.putIfAbsent(
          item.monthKey,
          () => <String, AccountSubscription>{},
        );
        accountMap[item.accountDocId] = item;
      }

      final groups =
          monthMap.entries
              .map((entry) {
                final month = _parseMonthKey(entry.key);
                if (month == null) {
                  return null;
                }
                return BillingMonthGroup(
                  month: month,
                  monthKey: entry.key,
                  total: entry.value.total,
                  paid: entry.value.paid,
                  unpaid: entry.value.unpaid,
                );
              })
              .whereType<BillingMonthGroup>()
              .toList()
            ..sort((left, right) => right.month.compareTo(left.month));

      _billingMonthGroups = groups;
      _subscriptionsByMonth = monthAccountMap;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _monthsSubscription?.cancel();
    super.dispose();
  }

  static DateTime _normalizeMonth(DateTime value) {
    return DateTime(value.year, value.month);
  }

  static DateTime? _parseMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return null;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return null;
    }
    return DateTime(year, month);
  }
}

class _MonthAccumulator {
  int total = 0;
  int paid = 0;

  int get unpaid => total - paid;

  void add(AccountSubscription subscription) {
    total += 1;
    if (subscription.isPaid) {
      paid += 1;
    }
  }
}
