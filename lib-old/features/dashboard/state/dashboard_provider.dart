import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/data/storage/prefs_store.dart';
import '../../../core/data/storage/secure_store.dart';
import '../../../core/data/telesom/telesom_api_client.dart';
import '../../../core/data/telesom/telesom_models.dart';
import '../../../core/services/auto_transfer_background_service.dart';
import '../../../core/services/auto_transfer_engine.dart';

enum LogoutRequestType { primary, all }

class DashboardProvider extends ChangeNotifier with WidgetsBindingObserver {
  DashboardProvider({
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
    required StoredSession initialSession,
  }) {
    _session = initialSession;
    _engine = AutoTransferEngine(
      apiClient: apiClient,
      secureStore: secureStore,
      prefsStore: prefsStore,
    );
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;

  late final AutoTransferEngine _engine;

  StoredSession? _session;
  StoredSession? get session => _session;

  double? _balance;
  double? get balance => _balance;

  bool _polling = false;
  bool get isPolling => _polling;

  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;

  String? _error;
  String? get error => _error;

  LogoutRequestType? _pendingLogout;
  LogoutRequestType? takePendingLogout() {
    final value = _pendingLogout;
    _pendingLogout = null;
    return value;
  }

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _pollLoopRunning = false;

  Future<void> _init() async {
    await prefsStore.clearTelesomSessionExpiredFlag();
    _startConnectivityWatch();
    _startPolling();
    unawaited(AutoTransferBackgroundService.stop());
    Future.microtask(_ensureBackgroundPermissions);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> checkInternetNow() => _checkInternetNow();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopPolling();
      unawaited(
        AutoTransferBackgroundService.startIfEnabled(
          prefsStore,
          keepAlive: true,
        ),
      );
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  Future<void> _handleResume() async {
    if (await _consumeSessionExpiredFlag()) {
      _queueLogout(LogoutRequestType.primary);
      return;
    }
    _stopPolling();
    _startPolling();
    await _checkInternetNow();
    unawaited(_pollOnce());
    await AutoTransferBackgroundService.stop();
  }

  void _startPolling() {
    if (_pollLoopRunning) return;
    _pollLoopRunning = true;
    _pollLoop();
  }

  void _stopPolling() {
    _pollLoopRunning = false;
  }

  Future<void> _pollLoop() async {
    while (_pollLoopRunning) {
      final started = DateTime.now();
      await _pollOnce();
      final elapsed = DateTime.now().difference(started);
      final remaining = const Duration(seconds: 1) - elapsed;
      if (remaining > Duration.zero) {
        await Future.delayed(remaining);
      }
    }
  }

  Future<void> _pollOnce() async {
    if (_polling) return;
    if (!_hasInternet) return;
    if (await _consumeSessionExpiredFlag()) {
      _queueLogout(LogoutRequestType.primary);
      return;
    }
    final session = _session;
    if (session == null) return;

    final token = session.token;
    final merchantUid = session.merchantUid;
    final currency = session.currency;
    final accountId = session.accountId;
    final sessionId = session.sessionId;
    final languageId = session.languageId;

    if (token == null || token.isEmpty) return;
    if (merchantUid == null || merchantUid.isEmpty) return;
    if ((accountId == null || accountId.isEmpty) &&
        (currency == null || currency.isEmpty)) {
      return;
    }

    _setPolling(true);
    _setError(null);
    try {
      final res = await apiClient.getBalance(
        token: token,
        merchantUid: merchantUid,
        currency: currency ?? '',
        accountId: accountId,
        sessionId: sessionId,
        languageId: languageId,
      );

      final prev = _balance;
      BalanceAccountItem? picked;
      if (accountId != null && accountId.isNotEmpty) {
        for (final a in res.accounts) {
          if (a.accountId == accountId) {
            picked = a;
            break;
          }
        }
      }
      if (picked == null) {
        final symbol = (session.currencySymbol?.trim().isNotEmpty ?? false)
            ? session.currencySymbol!.trim()
            : res.currencySymbol.trim();
        if (symbol.isNotEmpty) {
          picked = res.accountWithSymbol(symbol);
        }
      }
      if (picked == null && res.accounts.isNotEmpty) {
        picked = res.accounts.first;
      }

      final current = picked?.currentBalance ?? res.balance;
      _setBalance(current);

      await _engine.onBalanceUpdate(
        previousBalance: prev ?? 0,
        currentBalance: current,
        session: session,
      );
    } on TelesomApiException catch (e) {
      if (_isSessionExpiredError(e)) {
        _queueLogout(LogoutRequestType.primary);
        return;
      }
      _setError(e.toString());
    } on Exception catch (e) {
      _setError(e.toString());
      if (e.toString().toLowerCase().contains('socketexception') ||
          e.toString().toLowerCase().contains('network')) {
        _setHasInternet(false);
      }
    } finally {
      _setPolling(false);
    }
  }

  Future<bool> _consumeSessionExpiredFlag() async {
    final expired = await prefsStore.readTelesomSessionExpiredFlag();
    if (!expired) return false;
    await prefsStore.clearTelesomSessionExpiredFlag();
    return true;
  }

  bool _isSessionExpiredError(TelesomApiException error) {
    final code = error.statusCode ?? 0;
    if (code == 401 || code == 403 || code == 419 || code == 440) return true;
    final message = error.message.toLowerCase();
    if (message.contains('session') &&
        (message.contains('expired') || message.contains('invalid'))) {
      return true;
    }
    if (message.contains('unauthorized') || message.contains('token')) {
      return true;
    }
    return false;
  }

  void _startConnectivityWatch() {
    _connectivitySub?.cancel();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      _checkInternetNow();
    });
    _checkInternetNow();
  }

  Future<void> _checkInternetNow() async {
    final connected = await _hasNetworkInterface();
    if (!connected) {
      _setHasInternet(false);
      return;
    }

    final reachable = await _canResolveHost('mymerchant.telesom.com');
    _setHasInternet(reachable);
  }

  Future<bool> _hasNetworkInterface() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<bool> _canResolveHost(String host) async {
    try {
      final res = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureBackgroundPermissions() async {
    if (!Platform.isAndroid) return;
    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
  }

  void _setBalance(double value) {
    _balance = value;
    notifyListeners();
  }

  void _setPolling(bool value) {
    if (_polling == value) return;
    _polling = value;
    notifyListeners();
  }

  void _setError(String? value) {
    if (_error == value) return;
    _error = value;
    notifyListeners();
  }

  void _setHasInternet(bool value) {
    if (_hasInternet == value) return;
    _hasInternet = value;
    notifyListeners();
  }

  void _queueLogout(LogoutRequestType type) {
    _pendingLogout = type;
    notifyListeners();
  }
}
