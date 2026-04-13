import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_theme_controller.dart';
import '../../core/data/storage/prefs_store.dart';
import '../../core/data/storage/secure_store.dart';
import '../../core/data/telesom/telesom_api_client.dart';
import '../../core/services/session_feedback.dart';
import '../../ui/blueprint/blueprint_widgets.dart';
import '../autotransfer/manage_auto_transfer_screen.dart';
import '../auth/login_screen.dart';
import '../offline/offline_screen.dart';
import 'state/dashboard_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
    required this.initialSession,
  });

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;
  final StoredSession initialSession;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(
        apiClient: apiClient,
        secureStore: secureStore,
        prefsStore: prefsStore,
        initialSession: initialSession,
      ),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingLogout(controller);
    });

    if (!controller.hasInternet) {
      return OfflineScreen(onRetry: controller.checkInternetNow);
    }

    final session = controller.session;
    final merchantUid = session?.merchantUid ?? session?.username ?? '';
    final merchantName = session?.merchantName ?? '';
    final pictureBytes = _tryDecodeDataImage(session?.merchantPicture);
    final currency = session?.accountCurrencyName ?? session?.currency ?? '';
    final currencySymbol = session?.currencySymbol ?? r'$';

    return Scaffold(
      drawer: _buildDrawer(context, controller),
      body: Stack(
        children: [
          const BlueprintBackground(),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) {
                              return IconButton(
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                                icon: const Icon(Icons.menu),
                                color: BlueprintTokens.ink,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Xaabsade AI',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: BlueprintTokens.ink,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          BlueprintPanel(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: BlueprintTokens.accent,
                                  backgroundImage: pictureBytes == null
                                      ? null
                                      : MemoryImage(pictureBytes),
                                  child: pictureBytes == null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        merchantName.trim().isNotEmpty
                                            ? merchantName
                                            : merchantUid,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: BlueprintTokens.ink,
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        merchantUid,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: BlueprintTokens.muted,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _Pill(
                                            icon: Icons.verified_user,
                                            label: controller.isPolling
                                                ? 'Live'
                                                : 'Ready',
                                          ),
                                          if (currency.trim().isNotEmpty)
                                            _Pill(
                                              icon: Icons.payments,
                                              label: currency,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(
                            icon: Icons.account_balance_wallet,
                            title: 'Account balance',
                          ),
                          const SizedBox(height: 10),
                          _BalanceCard(
                            balance: controller.balance,
                            currency: currency,
                            currencySymbol: currencySymbol,
                            error: controller.error,
                          ),
                          const SizedBox(height: 16),
                          const _SectionHeader(
                            icon: Icons.swap_horiz,
                            title: 'Auto transfer',
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<AutoTransferConfig>(
                            future: controller.prefsStore
                                .readAutoTransferConfig(),
                            builder: (context, configSnap) {
                              final config =
                                  configSnap.data ?? AutoTransferConfig.empty;
                              return FutureBuilder<AutoTransferState>(
                                future: controller.prefsStore
                                    .readAutoTransferState(),
                                builder: (context, stateSnap) {
                                  final state =
                                      stateSnap.data ?? AutoTransferState.empty;
                                  return GestureDetector(
                                    onTap: () async {
                                      final updated = await _openManageTransfer(
                                        controller,
                                      );
                                      if (updated == true && mounted) {
                                        setState(() {});
                                      }
                                    },
                                    child: _AutoTransferCard(
                                      config: config,
                                      state: state,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer(BuildContext context, DashboardProvider controller) {
    final session = controller.session;
    final textTheme = Theme.of(context).textTheme;
    Widget sectionLabel(String label) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
        child: Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: BlueprintTokens.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );
    }

    Widget drawerTile({
      required IconData icon,
      required String title,
      VoidCallback? onTap,
      Widget? trailing,
    }) {
      return ListTile(
        leading: Icon(icon, color: BlueprintTokens.ink),
        title: Text(
          title,
          style: textTheme.bodyLarge?.copyWith(color: BlueprintTokens.ink),
        ),
        trailing: trailing,
        onTap: onTap,
        dense: true,
        horizontalTitleGap: 8,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: BoxDecoration(
                color: BlueprintTokens.panel,
                border: Border(
                  bottom: BorderSide(color: BlueprintTokens.border),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xaabsade AI',
                    style: textTheme.titleLarge?.copyWith(
                      color: BlueprintTokens.ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<DollarSession?>(
                    future: controller.secureStore.readDollarSession(),
                    builder: (context, snap) {
                      final dollar = snap.data;
                      final profile = _parseDollarProfile(dollar?.profileJson);
                      final loginProfile = _parseDollarProfile(
                        dollar?.loginJson,
                      );
                      final mergedProfile = <String, Object?>{
                        ...loginProfile,
                        ...profile,
                      };
                      final name =
                          _pickDollarValue(mergedProfile, const [
                            'full_name',
                            'name',
                            'username',
                          ]) ??
                          ((session?.merchantName?.trim().isNotEmpty ?? false)
                              ? session!.merchantName!
                              : 'Merchant');
                      final subtitle =
                          _pickDollarValue(mergedProfile, const [
                            'email',
                            'mobile',
                            'phone',
                            'username',
                          ]) ??
                          (session?.merchantUid ?? session?.username ?? '');
                      final avatar = _pickDollarValue(mergedProfile, const [
                        'avatar_base64',
                        'avatar',
                        'picture',
                      ]);
                      final avatarImage = _avatarProvider(avatar);

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: BlueprintTokens.accent,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.trim().isEmpty ? 'Merchant' : name,
                                  style: textTheme.titleMedium?.copyWith(
                                    color: BlueprintTokens.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: BlueprintTokens.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: BlueprintTokens.accent.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: BlueprintTokens.accent.withValues(
                                  alpha: 0.6,
                                ),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              'DOLLAR',
                              style: textTheme.labelSmall?.copyWith(
                                color: BlueprintTokens.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            sectionLabel('Quick actions'),
            drawerTile(
              icon: Icons.swap_horiz,
              title: 'Manage auto transfer',
              onTap: () async {
                Navigator.of(context).pop();
                final updated = await _openManageTransfer(controller);
                if (updated == true && mounted) {
                  setState(() {});
                }
              },
            ),
            sectionLabel('Appearance'),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: AppThemeController.mode,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return SwitchListTile(
                  value: isDark,
                  onChanged: (value) {
                    AppThemeController.setMode(
                      controller.prefsStore,
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                  title: Text(isDark ? 'Dark theme' : 'Light theme'),
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
                  contentPadding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                );
              },
            ),
            const Divider(height: 24),

            drawerTile(
              icon: Icons.logout,
              title: 'Log out',
              onTap: () {
                Navigator.of(context).pop();
                _logoutAll(controller);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePendingLogout(DashboardProvider controller) async {
    final request = controller.takePendingLogout();
    if (request == null) return;
    if (!mounted) return;
    switch (request) {
      case LogoutRequestType.primary:
        await _forceLogout(controller);
        break;
      case LogoutRequestType.all:
        await _logoutAll(controller);
        break;
    }
  }

  Future<void> _forceLogout(DashboardProvider controller) async {
    await controller.prefsStore.clearAll();
    await controller.secureStore.clearSession();
    await SessionFeedback.sessionTerminated();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          apiClient: controller.apiClient,
          secureStore: controller.secureStore,
          prefsStore: controller.prefsStore,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _logout(DashboardProvider controller) async {
    final session = controller.session;
    final token = session?.token;

    if (token != null && token.isNotEmpty) {
      try {
        await controller.apiClient.logout(token: token);
      } catch (_) {
        // Ignore logout failures.
      }
    }
    await controller.prefsStore.clearAll();
    await controller.secureStore.clearSession();
    final dollar = await controller.secureStore.readDollarSession();
    final userId = await controller.secureStore.readDollarUserId();
    await controller.secureStore.clearDollarSession();
    await SessionFeedback.sessionTerminated();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          apiClient: controller.apiClient,
          secureStore: controller.secureStore,
          prefsStore: controller.prefsStore,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _logoutAll(DashboardProvider controller) async {
    await controller.prefsStore.clearAll();
    await controller.secureStore.clearSession();
    final dollar = await controller.secureStore.readDollarSession();
    final userId = await controller.secureStore.readDollarUserId();
    await controller.secureStore.clearDollarSession();
    await SessionFeedback.sessionTerminated();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          apiClient: controller.apiClient,
          secureStore: controller.secureStore,
          prefsStore: controller.prefsStore,
        ),
      ),
      (route) => false,
    );
  }

  Future<bool?> _openManageTransfer(DashboardProvider controller) {
    final session = controller.session;
    if (session == null) return Future.value(false);
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManageAutoTransferScreen(
          apiClient: controller.apiClient,
          secureStore: controller.secureStore,
          prefsStore: controller.prefsStore,
          session: session,
        ),
      ),
    );
  }

  Uint8List? _tryDecodeDataImage(String? dataUri) {
    final raw = dataUri?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (!raw.startsWith('data:image/')) return null;
    final comma = raw.indexOf(',');
    if (comma < 0) return null;
    final payload = raw.substring(comma + 1).trim();
    if (payload.isEmpty) return null;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?> _parseDollarProfile(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final map = decoded.cast<String, Object?>();
        final fromData = _extractDollarUser(map);
        return fromData ?? map;
      }
    } catch (_) {}
    return <String, Object?>{};
  }

  static Map<String, Object?>? _extractDollarUser(Map<String, Object?> map) {
    final data = map['data'];
    if (data is Map) {
      final cast = data.cast<String, Object?>();
      final user = cast['user'];
      if (user is Map) return user.cast<String, Object?>();
    }
    final user = map['user'];
    if (user is Map) return user.cast<String, Object?>();
    return null;
  }

  static String? _pickDollarValue(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static ImageProvider? _avatarProvider(String? avatar) {
    if (avatar == null || avatar.trim().isEmpty) return null;
    final dataBytes = _tryStaticDecode(avatar);
    if (dataBytes != null) return MemoryImage(dataBytes);
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return NetworkImage(avatar);
    }
    return null;
  }

  static Uint8List? _tryStaticDecode(String data) {
    if (!data.startsWith('data:image/')) return null;
    final comma = data.indexOf(',');
    if (comma < 0) return null;
    final payload = data.substring(comma + 1).trim();
    if (payload.isEmpty) return null;
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: BlueprintTokens.muted),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: BlueprintTokens.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BlueprintTokens.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: BlueprintTokens.accent.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: BlueprintTokens.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BlueprintTokens.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.currency,
    required this.currencySymbol,
    required this.error,
  });

  final double? balance;
  final String currency;
  final String currencySymbol;
  final String? error;

  String _formatBalance(double value) {
    const decimals = 2;
    final factor = math.pow(10, decimals).toDouble();
    final truncated = (value * factor).truncateToDouble() / factor;
    return truncated.toStringAsFixed(decimals);
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings, size: 18, color: BlueprintTokens.accent),
              const SizedBox(width: 8),
              Text(
                'USD balance',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: BlueprintTokens.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            balance == null
                ? '--'
                : '$currencySymbol ${_formatBalance(balance!)}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: BlueprintTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (error != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFB42318),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFB42318),
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              balance == null
                  ? 'Fetching latest balance...'
                  : 'Updated live • $currency',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BlueprintTokens.muted),
            ),
        ],
      ),
    );
  }
}

class _AutoTransferCard extends StatelessWidget {
  const _AutoTransferCard({required this.config, required this.state});

  final AutoTransferConfig config;
  final AutoTransferState state;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: BlueprintTokens.muted);
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: BlueprintTokens.ink);

    String fmtDate(DateTime? dt) {
      if (dt == null) return '';
      final local = dt.toLocal();
      return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            const SizedBox(height: 2),
            Text(value, style: valueStyle),
          ],
        ),
      );
    }

    return BlueprintPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(
            'Target number',
            config.receiverNumber.isEmpty ? '-' : config.receiverNumber,
          ),
          row(
            'Receiver name',
            config.receiverName.isEmpty ? '-' : config.receiverName,
          ),
          row('Status', config.enabled ? state.status : 'Disabled'),
          row(
            'Last message',
            state.lastMessage.isEmpty ? '-' : state.lastMessage,
          ),
          if (state.lastRun != null) row('Last run', fmtDate(state.lastRun)),
          if (state.balanceAfterTransfer != null)
            row(
              'Balance after transfer',
              state.balanceAfterTransfer!.toString(),
            ),
        ],
      ),
    );
  }
}
