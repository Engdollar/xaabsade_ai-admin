import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoTransferConfig {
  const AutoTransferConfig({
    required this.enabled,
    required this.receiverNumber,
    required this.receiverName,
    required this.receiverAccountId,
    required this.description,
    required this.interNetwork,
    required this.keepBalance,
  });

  final bool enabled;
  final String receiverNumber;
  final String receiverName;
  final String receiverAccountId;
  final String description;
  final bool interNetwork;
  final double keepBalance;

  static const empty = AutoTransferConfig(
    enabled: false,
    receiverNumber: '',
    receiverName: '',
    receiverAccountId: '',
    description: '',
    interNetwork: false,
    keepBalance: 0.10,
  );

  AutoTransferConfig copyWith({
    bool? enabled,
    String? receiverNumber,
    String? receiverName,
    String? receiverAccountId,
    String? description,
    bool? interNetwork,
    double? keepBalance,
  }) {
    return AutoTransferConfig(
      enabled: enabled ?? this.enabled,
      receiverNumber: receiverNumber ?? this.receiverNumber,
      receiverName: receiverName ?? this.receiverName,
      receiverAccountId: receiverAccountId ?? this.receiverAccountId,
      description: description ?? this.description,
      interNetwork: interNetwork ?? this.interNetwork,
      keepBalance: keepBalance ?? this.keepBalance,
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'receiverNumber': receiverNumber,
    'receiverName': receiverName,
    'receiverAccountId': receiverAccountId,
    'description': description,
    'interNetwork': interNetwork,
    'keepBalance': keepBalance,
  };

  factory AutoTransferConfig.fromJson(Map<String, Object?> json) {
    return AutoTransferConfig(
      enabled: (json['enabled'] as bool?) ?? false,
      receiverNumber: (json['receiverNumber'] ?? '').toString(),
      receiverName: (json['receiverName'] ?? '').toString(),
      receiverAccountId: (json['receiverAccountId'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      interNetwork: (json['interNetwork'] as bool?) ?? false,
      keepBalance: (json['keepBalance'] is num)
          ? (json['keepBalance'] as num).toDouble()
          : double.tryParse((json['keepBalance'] ?? '0.10').toString()) ?? 0.10,
    );
  }
}

class AutoTransferState {
  const AutoTransferState({
    required this.status,
    required this.lastMessage,
    required this.lastRun,
    required this.balanceAfterTransfer,
  });

  final String status;
  final String lastMessage;
  final DateTime? lastRun;
  final double? balanceAfterTransfer;

  static const empty = AutoTransferState(
    status: 'Standing by',
    lastMessage: '',
    lastRun: null,
    balanceAfterTransfer: null,
  );

  Map<String, Object?> toJson() => {
    'status': status,
    'lastMessage': lastMessage,
    'lastRun': lastRun?.toIso8601String(),
    'balanceAfterTransfer': balanceAfterTransfer,
  };

  factory AutoTransferState.fromJson(Map<String, Object?> json) {
    final raw = json['lastRun']?.toString();
    return AutoTransferState(
      status: (json['status'] ?? 'Standing by').toString(),
      lastMessage: (json['lastMessage'] ?? '').toString(),
      lastRun: raw == null || raw.isEmpty ? null : DateTime.tryParse(raw),
      balanceAfterTransfer: json['balanceAfterTransfer'] == null
          ? null
          : (json['balanceAfterTransfer'] is num)
          ? (json['balanceAfterTransfer'] as num).toDouble()
          : double.tryParse(json['balanceAfterTransfer'].toString()),
    );
  }
}

class PrefsStore {
  static const _kAutoTransferConfig = 'autotransfer.config.v1';
  static const _kAutoTransferState = 'autotransfer.state.v1';
  static const _kRecentActivity = 'autotransfer.activity.v1';
  static const _kThemeMode = 'ui.theme.mode.v1';
  static const _kTelesomSessionExpired = 'telesom.session.expired.v1';

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<AutoTransferConfig> readAutoTransferConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAutoTransferConfig);
    if (raw == null || raw.isEmpty) return AutoTransferConfig.empty;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AutoTransferConfig.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {}
    return AutoTransferConfig.empty;
  }

  Future<void> writeAutoTransferConfig(AutoTransferConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAutoTransferConfig, jsonEncode(config.toJson()));
  }

  Future<AutoTransferState> readAutoTransferState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kAutoTransferState);
    if (raw == null || raw.isEmpty) return AutoTransferState.empty;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AutoTransferState.fromJson(decoded.cast<String, Object?>());
      }
    } catch (_) {}
    return AutoTransferState.empty;
  }

  Future<void> writeAutoTransferState(AutoTransferState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAutoTransferState, jsonEncode(state.toJson()));
  }

  Future<List<String>> readRecentActivity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kRecentActivity) ?? const [];
  }

  Future<void> addRecentActivity(String message) async {
    final prefs = await SharedPreferences.getInstance();
    final items = (prefs.getStringList(_kRecentActivity) ?? <String>[])
        .toList();
    items.insert(0, message);
    if (items.length > 20) {
      items.removeRange(20, items.length);
    }
    await prefs.setStringList(_kRecentActivity, items);
  }

  Future<ThemeMode> readThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeMode);
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
    }
    return ThemeMode.light;
  }

  Future<void> writeThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
  }

  Future<bool> readTelesomSessionExpiredFlag() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kTelesomSessionExpired) ?? false;
  }

  Future<void> writeTelesomSessionExpiredFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTelesomSessionExpired, value);
  }

  Future<void> clearTelesomSessionExpiredFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTelesomSessionExpired);
  }
}
