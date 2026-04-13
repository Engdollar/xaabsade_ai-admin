import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StoredSession {
  const StoredSession({
    required this.loginToken,
    required this.token,
    required this.refreshToken,
    required this.merchantUid,
    required this.merchantName,
    required this.merchantPicture,
    required this.currency,
    required this.accountId,
    required this.accountCurrencyName,
    required this.currencySymbol,
    required this.sessionId,
    required this.languageId,
    required this.type,
    required this.username,
  });

  final String? loginToken;
  final String? token;
  final String? refreshToken;
  final String? merchantUid;
  final String? merchantName;
  final String? merchantPicture;
  final String? currency;
  final String? accountId;
  final String? accountCurrencyName;
  final String? currencySymbol;
  final String? sessionId;
  final String? languageId;
  final String? type;
  final String? username;
}

class SecureStore {
  static const _kLoginToken = 'telesom.loginToken';
  static const _kToken = 'telesom.token';
  static const _kRefreshToken = 'telesom.refreshToken';
  static const _kMerchantUid = 'telesom.merchantUid';
  static const _kMerchantName = 'telesom.merchantName';
  static const _kMerchantPicture = 'telesom.merchantPicture';
  static const _kCurrency = 'telesom.currency';
  static const _kAccountId = 'telesom.accountId';
  static const _kAccountCurrencyName = 'telesom.accountCurrencyName';
  static const _kCurrencySymbol = 'telesom.currencySymbol';
  static const _kSessionId = 'telesom.sessionId';
  static const _kLanguageId = 'telesom.languageId';
  static const _kType = 'telesom.type';
  static const _kUsername = 'telesom.username';

  static const _kMerchantPin = 'telesom.merchantPin';

  static const _kDollarToken = 'dollar.token';
  static const _kDollarLoginJson = 'dollar.loginJson';
  static const _kDollarProfileJson = 'dollar.profileJson';
  static const _kDollarEmail = 'dollar.email';
  static const _kDollarPassword = 'dollar.password';
  static const _kDollarUserId = 'dollar.userId';

  FlutterSecureStorage? _storage;

  FlutterSecureStorage get _s => _storage ??= const FlutterSecureStorage();

  Future<StoredSession?> readSession() async {
    final loginToken = await _s.read(key: _kLoginToken);
    final token = await _s.read(key: _kToken);
    final refreshToken = await _s.read(key: _kRefreshToken);
    final merchantUid = await _s.read(key: _kMerchantUid);
    final merchantName = await _s.read(key: _kMerchantName);
    final merchantPicture = await _s.read(key: _kMerchantPicture);
    final currency = await _s.read(key: _kCurrency);
    final accountId = await _s.read(key: _kAccountId);
    final accountCurrencyName = await _s.read(key: _kAccountCurrencyName);
    final currencySymbol = await _s.read(key: _kCurrencySymbol);
    final sessionId = await _s.read(key: _kSessionId);
    final languageId = await _s.read(key: _kLanguageId);
    final type = await _s.read(key: _kType);
    final username = await _s.read(key: _kUsername);

    if (token == null || token.isEmpty) return null;

    return StoredSession(
      loginToken: loginToken,
      token: token,
      refreshToken: refreshToken,
      merchantUid: merchantUid,
      merchantName: merchantName,
      merchantPicture: merchantPicture,
      currency: currency,
      accountId: accountId,
      accountCurrencyName: accountCurrencyName,
      currencySymbol: currencySymbol,
      sessionId: sessionId,
      languageId: languageId,
      type: type,
      username: username,
    );
  }

  Future<void> writePendingAuth({
    required String loginToken,
    required String sessionId,
    required String languageId,
    required String username,
  }) async {
    await _s.write(key: _kLoginToken, value: loginToken);
    await _s.write(key: _kSessionId, value: sessionId);
    await _s.write(key: _kLanguageId, value: languageId);
    await _s.write(key: _kUsername, value: username);
  }

  Future<void> writeSession({
    String? loginToken,
    required String token,
    required String refreshToken,
    required String merchantUid,
    required String merchantName,
    String? merchantPicture,
    required String currency,
    String? accountId,
    String? accountCurrencyName,
    String? currencySymbol,
    String? sessionId,
    String? languageId,
    required String type,
    required String username,
  }) async {
    if (loginToken != null) {
      await _s.write(key: _kLoginToken, value: loginToken);
    }
    await _s.write(key: _kToken, value: token);
    await _s.write(key: _kRefreshToken, value: refreshToken);
    await _s.write(key: _kMerchantUid, value: merchantUid);
    await _s.write(key: _kMerchantName, value: merchantName);
    await _s.write(key: _kMerchantPicture, value: merchantPicture);
    await _s.write(key: _kCurrency, value: currency);
    await _s.write(key: _kAccountId, value: accountId);
    await _s.write(key: _kAccountCurrencyName, value: accountCurrencyName);
    await _s.write(key: _kCurrencySymbol, value: currencySymbol);
    await _s.write(key: _kSessionId, value: sessionId);
    await _s.write(key: _kLanguageId, value: languageId);
    await _s.write(key: _kType, value: type);
    await _s.write(key: _kUsername, value: username);
  }

  Future<void> clearSession() async {
    await _s.delete(key: _kLoginToken);
    await _s.delete(key: _kToken);
    await _s.delete(key: _kRefreshToken);
    await _s.delete(key: _kMerchantUid);
    await _s.delete(key: _kMerchantName);
    await _s.delete(key: _kMerchantPicture);
    await _s.delete(key: _kCurrency);
    await _s.delete(key: _kAccountId);
    await _s.delete(key: _kAccountCurrencyName);
    await _s.delete(key: _kCurrencySymbol);
    await _s.delete(key: _kSessionId);
    await _s.delete(key: _kLanguageId);
    await _s.delete(key: _kType);
    await _s.delete(key: _kUsername);
    await _s.delete(key: _kMerchantPin);
  }

  Future<String?> readMerchantPin() => _s.read(key: _kMerchantPin);

  Future<void> writeMerchantPin(String pin) =>
      _s.write(key: _kMerchantPin, value: pin);

  Future<DollarSession?> readDollarSession() async {
    final token = await _s.read(key: _kDollarToken);
    if (token == null || token.isEmpty) return null;
    final loginRaw = await _s.read(key: _kDollarLoginJson);
    final profileRaw = await _s.read(key: _kDollarProfileJson);
    return DollarSession(
      token: token,
      loginJson: loginRaw,
      profileJson: profileRaw,
    );
  }

  Future<void> writeDollarSession({
    required String token,
    String? loginJson,
    String? profileJson,
  }) async {
    await _s.write(key: _kDollarToken, value: token);
    if (loginJson != null) {
      await _s.write(key: _kDollarLoginJson, value: loginJson);
    }
    if (profileJson != null) {
      await _s.write(key: _kDollarProfileJson, value: profileJson);
    }
  }

  Future<void> writeDollarProfile(String profileJson) async {
    await _s.write(key: _kDollarProfileJson, value: profileJson);
  }

  Future<void> writeDollarAuth({
    required String email,
    required String password,
    String? userId,
  }) async {
    await _s.write(key: _kDollarEmail, value: email);
    await _s.write(key: _kDollarPassword, value: password);
    if (userId != null && userId.isNotEmpty) {
      await _s.write(key: _kDollarUserId, value: userId);
    }
  }

  Future<DollarAuth?> readDollarAuth() async {
    final email = await _s.read(key: _kDollarEmail);
    final password = await _s.read(key: _kDollarPassword);
    final userId = await _s.read(key: _kDollarUserId);
    if (email == null ||
        email.isEmpty ||
        password == null ||
        password.isEmpty) {
      return null;
    }
    return DollarAuth(email: email, password: password, userId: userId);
  }

  Future<String?> readDollarUserId() async {
    final cached = await _s.read(key: _kDollarUserId);
    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    String? extractFromJson(String? raw) {
      if (raw == null || raw.trim().isEmpty) return null;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = decoded.cast<String, Object?>();
          return _extractDollarUserId(map);
        }
      } catch (_) {}
      return null;
    }

    final loginJson = await _s.read(key: _kDollarLoginJson);
    final profileJson = await _s.read(key: _kDollarProfileJson);
    final derived = extractFromJson(loginJson) ?? extractFromJson(profileJson);
    if (derived != null && derived.isNotEmpty) {
      await _s.write(key: _kDollarUserId, value: derived);
      return derived;
    }
    return null;
  }

  Future<void> clearDollarSession() async {
    await _s.delete(key: _kDollarToken);
    await _s.delete(key: _kDollarLoginJson);
    await _s.delete(key: _kDollarProfileJson);
    await _s.delete(key: _kDollarEmail);
    await _s.delete(key: _kDollarPassword);
    await _s.delete(key: _kDollarUserId);
  }

  String? _extractDollarUserId(Map<String, Object?> source) {
    Map<String, Object?>? user;
    final data = source['data'];
    if (data is Map) {
      final nested = data['user'];
      if (nested is Map) user = nested.cast<String, Object?>();
    }
    if (user == null) {
      final direct = source['user'];
      if (direct is Map) user = direct.cast<String, Object?>();
    }
    final id = user?['id']?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }
}

class DollarSession {
  const DollarSession({required this.token, this.loginJson, this.profileJson});

  final String token;
  final String? loginJson;
  final String? profileJson;
}

class DollarAuth {
  const DollarAuth({required this.email, required this.password, this.userId});

  final String email;
  final String password;
  final String? userId;
}
