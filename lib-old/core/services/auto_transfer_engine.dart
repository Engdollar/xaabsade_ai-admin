import 'dart:math' as math;

import '../data/storage/prefs_store.dart';
import '../data/storage/secure_store.dart';
import '../data/telesom/telesom_api_client.dart';

class AutoTransferEngine {
  AutoTransferEngine({
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
  });

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;
  bool _transferInProgress = false;
  // Ping findAccount at most once per interval while waiting for funds.
  static const Duration _keepAliveInterval = Duration(seconds: 10);
  DateTime? _lastKeepAlivePing;
  static const Duration _idleKeepAliveDelay = Duration(minutes: 5);
  static const Duration _idleKeepAliveCooldown = Duration(minutes: 5);
  static const double _idleKeepAliveAmount = 1.0;
  double? _lastObservedBalance;
  DateTime? _lastBalanceChangeAt;
  DateTime? _lastIdleKeepAliveAt;

  bool get transferInProgress => _transferInProgress;

  Future<void> onBalanceUpdate({
    required double previousBalance,
    required double currentBalance,
    required StoredSession session,
  }) async {
    if (_transferInProgress) return;

    _trackBalanceChange(currentBalance);

    final config = await prefsStore.readAutoTransferConfig();
    if (!config.enabled) return;
    if (config.receiverNumber.isEmpty) return;
    if (config.receiverName.isEmpty) return;

    final pin = await secureStore.readMerchantPin();
    if (pin == null || pin.isEmpty) return;

    final sessionId = session.sessionId;
    if (sessionId == null || sessionId.trim().isEmpty) return;

    // Portal headers use Authorization: Bearer <login_token>.
    final token = session.loginToken ?? session.token;
    if (token == null || token.isEmpty) return;

    final keepBalance = config.keepBalance <= 0 ? 0.1 : config.keepBalance;
    final idleKeepAliveAttempted = await _maybeIdleKeepAliveTransfer(
      session: session,
      token: token,
      sessionId: sessionId,
      pin: pin,
      currentBalance: currentBalance,
      keepBalance: keepBalance,
      config: config,
    );
    if (idleKeepAliveAttempted) return;
    if (currentBalance <= keepBalance) {
      await _maybePingFindAccount(
        session: session,
        token: token,
        currentBalance: currentBalance,
        keepBalance: keepBalance,
        config: config,
      );
      return;
    }

    final transferAmount = currentBalance - keepBalance;
    if (transferAmount <= 0) return;

    final amountStr = _formatAmount(transferAmount);
    final keepBalanceStr = _formatAmount(keepBalance);
    final inter = config.interNetwork ? '1' : '0';

    _transferInProgress = true;
    try {
      await prefsStore.writeAutoTransferState(
        AutoTransferState(
          status: 'Transferring...',
          lastMessage: 'Sending $amountStr (keeping $keepBalanceStr)',
          lastRun: DateTime.now(),
          balanceAfterTransfer: keepBalance,
        ),
      );

      final raw = await apiClient.b2pMerchant(
        token: token,
        userNature: 'MERCHANT',
        sessionId: sessionId,
        receiverMobile: config.receiverNumber,
        receiverName: config.receiverName,
        pin: pin,
        amount: amountStr,
        description: 'sarif xaabsade ',
        isInterNetwork: inter,
      );

      final status = (raw['status'] ?? raw['resultCode'] ?? 'OK')
          .toString()
          .trim();
      final reply = (raw['replyMessage'] ?? raw['message'] ?? '')
          .toString()
          .trim();
      if (_isSessionExpiredMessage(status) || _isSessionExpiredMessage(reply)) {
        final message = reply.isNotEmpty
            ? reply
            : (status.isNotEmpty
                  ? status
                  : 'Your Session has expired. Please login again.');
        await _handleSessionExpiredDuringTransfer(message);
        return;
      }
      final message = reply.isEmpty
          ? '$status: $amountStr → ${config.receiverName}'
          : '$status: $reply';
      await prefsStore.writeAutoTransferState(
        AutoTransferState(
          status: status.isEmpty ? 'OK' : status,
          lastMessage: message,
          lastRun: DateTime.now(),
          balanceAfterTransfer: keepBalance,
        ),
      );
      await prefsStore.addRecentActivity(
        '${DateTime.now().toIso8601String()}  $message',
      );
    } on TelesomApiException catch (e) {
      final message = e.message;
      if (_isSessionExpiredMessage(message)) {
        await _handleSessionExpiredDuringTransfer(message);
      } else {
        await _recordTransferFailure(e);
      }
    } on Exception catch (e) {
      await _recordTransferFailure(e);
    } finally {
      _transferInProgress = false;
    }
  }

  void _trackBalanceChange(double currentBalance) {
    if (_lastObservedBalance == null) {
      _lastObservedBalance = currentBalance;
      _lastBalanceChangeAt = DateTime.now();
      return;
    }
    if (_lastObservedBalance != currentBalance) {
      _lastObservedBalance = currentBalance;
      _lastBalanceChangeAt = DateTime.now();
    }
  }

  Future<bool> _maybeIdleKeepAliveTransfer({
    required StoredSession session,
    required String token,
    required String sessionId,
    required String pin,
    required double currentBalance,
    required double keepBalance,
    required AutoTransferConfig config,
  }) async {
    final lastChange = _lastBalanceChangeAt;
    if (lastChange == null) return false;

    final now = DateTime.now();
    if (now.difference(lastChange) < _idleKeepAliveDelay) return false;
    if (_lastIdleKeepAliveAt != null &&
        now.difference(_lastIdleKeepAliveAt!) < _idleKeepAliveCooldown) {
      return false;
    }

    final availableForKeepAlive = currentBalance - keepBalance;
    if (availableForKeepAlive < _idleKeepAliveAmount) {
      return false;
    }

    _lastIdleKeepAliveAt = now;
    _transferInProgress = true;
    try {
      await prefsStore.writeAutoTransferState(
        AutoTransferState(
          status: 'KEEP_ALIVE',
          lastMessage:
              'Sending ${_formatAmount(_idleKeepAliveAmount)} to keep session alive',
          lastRun: now,
          balanceAfterTransfer: currentBalance - _idleKeepAliveAmount,
        ),
      );

      final inter = config.interNetwork ? '1' : '0';
      final raw = await apiClient.b2pMerchant(
        token: token,
        userNature: 'MERCHANT',
        sessionId: sessionId,
        receiverMobile: config.receiverNumber,
        receiverName: config.receiverName,
        pin: pin,
        amount: _formatAmount(_idleKeepAliveAmount),
        description: 'keep alive',
        isInterNetwork: inter,
      );

      final status = (raw['status'] ?? raw['resultCode'] ?? 'OK')
          .toString()
          .trim();
      final reply = (raw['replyMessage'] ?? raw['message'] ?? '')
          .toString()
          .trim();
      if (_isSessionExpiredMessage(status) || _isSessionExpiredMessage(reply)) {
        final message = reply.isNotEmpty
            ? reply
            : (status.isNotEmpty
                  ? status
                  : 'Your Session has expired. Please login again.');
        await _handleSessionExpiredDuringTransfer(message);
        return true;
      }

      final message = reply.isEmpty
          ? '$status: keep alive ${_formatAmount(_idleKeepAliveAmount)}'
          : '$status: $reply';
      await prefsStore.writeAutoTransferState(
        AutoTransferState(
          status: status.isEmpty ? 'OK' : status,
          lastMessage: message,
          lastRun: now,
          balanceAfterTransfer: currentBalance - _idleKeepAliveAmount,
        ),
      );
      await prefsStore.addRecentActivity('${now.toIso8601String()}  $message');
      return true;
    } on TelesomApiException catch (e) {
      final message = e.message;
      if (_isSessionExpiredMessage(message)) {
        await _handleSessionExpiredDuringTransfer(message);
      } else {
        await _recordTransferFailure(e);
      }
      return true;
    } on Exception catch (e) {
      await _recordTransferFailure(e);
      return true;
    } finally {
      _transferInProgress = false;
    }
  }

  /// Keeps the session alive by poking `findAccount` until balance grows
  /// beyond the configured keep threshold.
  Future<void> _maybePingFindAccount({
    required StoredSession session,
    required String token,
    required double currentBalance,
    required double keepBalance,
    required AutoTransferConfig config,
  }) async {
    final now = DateTime.now();
    if (_lastKeepAlivePing != null &&
        now.difference(_lastKeepAlivePing!) < _keepAliveInterval) {
      return;
    }

    final sessionId = session.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) return;

    final mobile = config.receiverNumber.trim();
    if (mobile.isEmpty) return;

    final type = 'internetwork';

    _lastKeepAlivePing = now;

    try {
      await apiClient.findAccount(
        token: token,
        sessionId: sessionId,
        type: type,
        mobileNo: mobile,
        userNature: 'MERCHANT',
      );

      await prefsStore.writeAutoTransferState(
        AutoTransferState(
          status: 'Waiting',
          lastMessage:
              'Waiting for funds (${_formatAmount(currentBalance)} / ${_formatAmount(keepBalance)})',
          lastRun: now,
          balanceAfterTransfer: currentBalance,
        ),
      );
    } on TelesomApiException catch (e) {
      if (_isSessionExpiredMessage(e.message)) {
        await _handleSessionExpiredDuringTransfer(e.message);
        return;
      }
      await prefsStore.writeAutoTransferState(
        AutoTransferState(
          status: 'Waiting',
          lastMessage: 'Find account ping failed: ${e.message}',
          lastRun: now,
          balanceAfterTransfer: currentBalance,
        ),
      );
    } on Exception catch (e) {
      await prefsStore.writeAutoTransferState(
        AutoTransferState(
          status: 'Waiting',
          lastMessage: 'Find account ping error: $e',
          lastRun: now,
          balanceAfterTransfer: currentBalance,
        ),
      );
    }
  }

  Future<void> _handleSessionExpiredDuringTransfer(String message) async {
    final normalized = message.isEmpty
        ? 'Your Session has expired. Please login again.'
        : message;
    await prefsStore.writeAutoTransferState(
      AutoTransferState(
        status: 'SESSION_EXPIRED',
        lastMessage: normalized,
        lastRun: DateTime.now(),
        balanceAfterTransfer: null,
      ),
    );
    await prefsStore.addRecentActivity(
      '${DateTime.now().toIso8601String()}  SESSION_EXPIRED  $normalized',
    );
    await prefsStore.writeTelesomSessionExpiredFlag(true);
    await secureStore.clearSession();
  }

  Future<void> _recordTransferFailure(Object error) async {
    final message = error.toString();
    await prefsStore.writeAutoTransferState(
      AutoTransferState(
        status: 'FAILED',
        lastMessage: message,
        lastRun: DateTime.now(),
        balanceAfterTransfer: null,
      ),
    );
    await prefsStore.addRecentActivity(
      '${DateTime.now().toIso8601String()}  FAILED  $message',
    );
  }
}

String _formatAmount(double value) {
  const decimals = 2;
  final factor = math.pow(10, decimals).toDouble();
  final truncated = (value * factor).truncateToDouble() / factor;
  return truncated.toStringAsFixed(decimals);
}

bool _isSessionExpiredMessage(String? message) {
  if (message == null) return false;
  final normalized = message.toLowerCase();
  return normalized.contains('session has expired') ||
      normalized.contains('session expired');
}
