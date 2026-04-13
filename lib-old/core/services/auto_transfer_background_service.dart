import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../data/storage/prefs_store.dart';
import '../data/storage/secure_store.dart';
import '../data/telesom/telesom_api_client.dart';
import '../data/telesom/telesom_models.dart';
import 'auto_transfer_engine.dart';

class AutoTransferBackgroundService {
  static const String _kKeepAliveKey = 'xaabsade.keepAlive';

  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'xaabsade_auto_transfer',
        channelName: 'Auto transfer',
        channelDescription: 'Keeps auto transfer running in background',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startIfEnabled(
    PrefsStore prefsStore, {
    bool keepAlive = false,
  }) async {
    if (!Platform.isAndroid) return;
    final config = await prefsStore.readAutoTransferConfig();
    if (!config.enabled) {
      if (!keepAlive) {
        await stop();
        return;
      }
    }

    await FlutterForegroundTask.saveData(key: _kKeepAliveKey, value: keepAlive);
    final running = await FlutterForegroundTask.isRunningService;
    if (running) return;

    await FlutterForegroundTask.startService(
      serviceId: 256,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Auto transfer enabled',
      notificationText: 'Monitoring balance every second',
      callback: startCallback,
    );
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    final running = await FlutterForegroundTask.isRunningService;
    if (!running) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AutoTransferTaskHandler());
}

class AutoTransferTaskHandler extends TaskHandler {
  AutoTransferTaskHandler();

  final TelesomApiClient _apiClient = TelesomApiClient();
  final SecureStore _secureStore = SecureStore();
  final PrefsStore _prefsStore = PrefsStore();
  late final AutoTransferEngine _engine = AutoTransferEngine(
    apiClient: _apiClient,
    secureStore: _secureStore,
    prefsStore: _prefsStore,
  );

  double _lastBalance = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    try {
      if (await _prefsStore.readTelesomSessionExpiredFlag()) {
        await _stopForExpiredSession('Session expired. Please login again.');
        return;
      }
      final keepAliveFlag = await FlutterForegroundTask.getData(
        key: AutoTransferBackgroundService._kKeepAliveKey,
      );
      final keepAlive = keepAliveFlag == true || keepAliveFlag == 'true';

      final config = await _prefsStore.readAutoTransferConfig();
      if (!config.enabled) {
        if (!keepAlive) {
          await FlutterForegroundTask.stopService();
          return;
        }
      }

      final session = await _secureStore.readSession();
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

      final res = await _apiClient.getBalance(
        token: token,
        merchantUid: merchantUid,
        currency: currency ?? '',
        accountId: accountId,
        sessionId: sessionId,
        languageId: languageId,
      );

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
      final previous = _lastBalance;
      _lastBalance = current;

      FlutterForegroundTask.updateService(
        notificationText:
            'Last check ${DateTime.now().toLocal().toIso8601String()} | Bal ${_formatAmount(current)}',
      );

      if (config.enabled) {
        await _engine.onBalanceUpdate(
          previousBalance: previous,
          currentBalance: current,
          session: session,
        );
      }
    } on TelesomApiException catch (e) {
      if (_isSessionExpiredError(e)) {
        await _stopForExpiredSession(e.message);
        return;
      }
      FlutterForegroundTask.updateService(
        notificationText: 'Check failed: ${e.message}',
      );
      return;
    } on Exception {
      return;
    }
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

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  Future<void> _stopForExpiredSession(String? message) async {
    await _prefsStore.writeTelesomSessionExpiredFlag(true);
    await _secureStore.clearSession();
    await FlutterForegroundTask.updateService(
      notificationText: message?.isNotEmpty == true
          ? message!
          : 'Session expired. Please login again.',
    );
    await FlutterForegroundTask.stopService();
  }
}

String _formatAmount(double value) {
  const decimals = 2;
  final factor = math.pow(10, decimals).toDouble();
  final truncated = (value * factor).truncateToDouble() / factor;
  return truncated.toStringAsFixed(decimals);
}
