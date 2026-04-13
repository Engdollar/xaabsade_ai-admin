import 'package:flutter/material.dart';

import '../../core/data/storage/prefs_store.dart';
import '../../core/data/storage/secure_store.dart';
import '../../core/data/telesom/telesom_api_client.dart';
import '../../core/services/session_feedback.dart';
import '../auth/login_screen.dart';
import '../../ui/blueprint/blueprint_widgets.dart';

class ManageAutoTransferScreen extends StatefulWidget {
  const ManageAutoTransferScreen({
    super.key,
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
    required this.session,
  });

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;
  final StoredSession session;

  @override
  State<ManageAutoTransferScreen> createState() =>
      _ManageAutoTransferScreenState();
}

class _ManageAutoTransferScreenState extends State<ManageAutoTransferScreen> {
  final _receiverCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _enabled = false;
  bool _interNetwork = false;
  bool _busy = false;
  bool _pinVisible = false;

  String _receiverName = '';
  String _receiverAccountId = '';
  String _receiverStatus = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _receiverCtrl.dispose();
    _pinCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.prefsStore.readAutoTransferConfig();
    final pin = await widget.secureStore.readMerchantPin();
    setState(() {
      _enabled = config.enabled;
      _receiverCtrl.text = config.receiverNumber;
      _receiverName = config.receiverName;
      _receiverAccountId = config.receiverAccountId;
      _descCtrl.text = config.description;
      _interNetwork = config.interNetwork;
      _pinCtrl.text = pin ?? '';
    });
  }

  Future<void> _lookupReceiver() async {
    final number = _receiverCtrl.text.trim();
    if (number.isEmpty) return;

    final token = widget.session.token ?? widget.session.loginToken;
    final sessionId = widget.session.sessionId;
    if (token == null || token.isEmpty) return;
    if (sessionId == null || sessionId.trim().isEmpty) return;

    setState(() {
      _busy = true;
      _receiverName = '';
      _receiverAccountId = '';
      _receiverStatus = '';
    });

    try {
      final res = await widget.apiClient.findReceiver(
        token: token,
        mobileNo: number,
        sessionId: sessionId,
        type: 'internetwork',
        userNature: 'MERCHANT',
      );

      final info = res.receiverInfo;
      final sessionExpiredMessage = _firstSessionExpiredMessage([
        res.replyMessage,
        info?.status,
      ]);
      if (sessionExpiredMessage != null) {
        if (mounted) {
          setState(() {
            _receiverStatus = sessionExpiredMessage;
          });
        }
        await _redirectToLogin();
        return;
      }

      setState(() {
        if (info != null) {
          _receiverName = info.name;
          _receiverAccountId = info.accountId;
          _receiverStatus = info.status;
        } else {
          _receiverStatus = res.replyMessage.isEmpty
              ? 'Receiver not found'
              : res.replyMessage;
        }
      });
    } on TelesomApiException catch (e) {
      if (_isSessionExpiredError(e)) {
        _receiverStatus = 'Your Session has expired. Please login again.';
        if (mounted) setState(() {});
        await _redirectToLogin();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
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

  String? _firstSessionExpiredMessage(Iterable<String?> messages) {
    for (final raw in messages) {
      if (_isSessionExpiredMessage(raw)) {
        final trimmed = raw?.trim();
        if (trimmed != null && trimmed.isNotEmpty) {
          return trimmed;
        }
        return 'Your Session has expired. Please login again.';
      }
    }
    return null;
  }

  bool _isSessionExpiredMessage(String? message) {
    if (message == null) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('session has expired') ||
        normalized.contains('session expired');
  }

  Future<void> _redirectToLogin() async {
    await widget.prefsStore.clearAll();
    await widget.secureStore.clearSession();
    await SessionFeedback.sessionTerminated();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          apiClient: widget.apiClient,
          secureStore: widget.secureStore,
          prefsStore: widget.prefsStore,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _save() async {
    final number = _receiverCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (_enabled && (number.isEmpty || pin.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receiver number and PIN are required')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.secureStore.writeMerchantPin(pin);
      final current = await widget.prefsStore.readAutoTransferConfig();
      final updated = current.copyWith(
        enabled: _enabled,
        receiverNumber: number,
        receiverName: _receiverName,
        receiverAccountId: _receiverAccountId,
        description: _descCtrl.text.trim(),
        interNetwork: _interNetwork,
      );
      await widget.prefsStore.writeAutoTransferConfig(updated);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    try {
      final current = await widget.prefsStore.readAutoTransferConfig();
      await widget.prefsStore.writeAutoTransferConfig(
        current.copyWith(enabled: false),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration fieldDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF5F8FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BlueprintTokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BlueprintTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: BlueprintTokens.accent,
            width: 1.4,
          ),
        ),
      );
    }

    String fmtDate(DateTime? dt) {
      if (dt == null) return 'Not yet';
      final local = dt.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      body: Stack(
        children: [
          const BlueprintBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: BlueprintTokens.ink,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Auto Transfer',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: BlueprintTokens.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      BlueprintTag(
                        label: _enabled ? 'ENABLED' : 'DISABLED',
                        icon: _enabled ? Icons.toggle_on : Icons.toggle_off,
                        color: _enabled
                            ? BlueprintTokens.accent
                            : BlueprintTokens.muted,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      BlueprintPanel(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.sync_alt,
                                  color: BlueprintTokens.accent,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Transfer controls',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: BlueprintTokens.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const Spacer(),
                                Switch(
                                  value: _enabled,
                                  onChanged: _busy
                                      ? null
                                      : (v) => setState(() => _enabled = v),
                                  activeThumbColor: BlueprintTokens.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _receiverCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: fieldDecoration(
                                'Receiver mobile number',
                                Icons.call,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _lookupReceiver,
                                icon: const Icon(Icons.search),
                                label: const Text('Lookup receiver'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: BlueprintTokens.accent,
                                  side: const BorderSide(
                                    color: BlueprintTokens.accent,
                                  ),
                                ),
                              ),
                            ),
                            if (_receiverName.isNotEmpty ||
                                _receiverAccountId.isNotEmpty ||
                                _receiverStatus.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              BlueprintPanel(
                                padding: const EdgeInsets.all(12),
                                tone: const Color(0xFFF2F6FF),
                                showAccent: false,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _detailRow(
                                      'Name',
                                      _receiverName.isEmpty
                                          ? '-'
                                          : _receiverName,
                                    ),
                                    _detailRow(
                                      'Account ID',
                                      _receiverAccountId.isEmpty
                                          ? '-'
                                          : _receiverAccountId,
                                    ),
                                    _detailRow(
                                      'Status',
                                      _receiverStatus.isEmpty
                                          ? '-'
                                          : _receiverStatus,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinCtrl,
                              obscureText: !_pinVisible,
                              decoration:
                                  fieldDecoration(
                                    'Merchant PIN',
                                    Icons.lock,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(
                                              () => _pinVisible = !_pinVisible,
                                            ),
                                      icon: Icon(
                                        _pinVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _descCtrl,
                              decoration: fieldDecoration(
                                'Description (optional)',
                                Icons.notes,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Inter-network transfer\nEnable only if the receiver is on another network.',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: BlueprintTokens.muted,
                                        ),
                                  ),
                                ),
                                Switch(
                                  value: _interNetwork,
                                  onChanged: _busy
                                      ? null
                                      : (v) =>
                                            setState(() => _interNetwork = v),
                                  activeThumbColor: BlueprintTokens.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _busy ? null : _save,
                                    icon: _busy
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.lock_open),
                                    label: const Text('Update auto transfer'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: BlueprintTokens.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _disable,
                                  icon: const Icon(Icons.power_settings_new),
                                  label: const Text('Disable'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: BlueprintTokens.muted,
                                    side: BorderSide(
                                      color: BlueprintTokens.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      BlueprintPanel(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics,
                                  color: BlueprintTokens.accent,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Analytics',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: BlueprintTokens.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<AutoTransferState>(
                              future: widget.prefsStore.readAutoTransferState(),
                              builder: (context, stateSnap) {
                                final state =
                                    stateSnap.data ?? AutoTransferState.empty;
                                return FutureBuilder<AutoTransferConfig>(
                                  future: widget.prefsStore
                                      .readAutoTransferConfig(),
                                  builder: (context, configSnap) {
                                    final config =
                                        configSnap.data ??
                                        AutoTransferConfig.empty;
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F6FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: BlueprintTokens.border,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _analyticsRow(
                                            'Status',
                                            _enabled
                                                ? state.status
                                                : 'Disabled',
                                          ),
                                          _analyticsRow(
                                            'Last run',
                                            fmtDate(state.lastRun),
                                          ),
                                          _analyticsRow(
                                            'Last message',
                                            state.lastMessage.isEmpty
                                                ? 'No messages yet'
                                                : state.lastMessage,
                                          ),
                                          _analyticsRow(
                                            'Keep balance',
                                            config.keepBalance.toStringAsFixed(
                                              2,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          LinearProgressIndicator(
                                            minHeight: 6,
                                            value: _enabled ? 1 : 0,
                                            backgroundColor:
                                                BlueprintTokens.border,
                                            color: BlueprintTokens.accent,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      BlueprintPanel(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  color: BlueprintTokens.accent,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Recent activity',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: BlueprintTokens.ink,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<String>>(
                              future: widget.prefsStore.readRecentActivity(),
                              builder: (context, snap) {
                                final items = snap.data ?? const [];
                                if (items.isEmpty) {
                                  return Text(
                                    '-',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: BlueprintTokens.muted,
                                        ),
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: items
                                      .take(5)
                                      .map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            e,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: BlueprintTokens.muted,
                                                ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: BlueprintTokens.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BlueprintTokens.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: BlueprintTokens.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: BlueprintTokens.ink),
          ),
        ],
      ),
    );
  }
}
