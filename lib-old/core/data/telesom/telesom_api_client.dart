import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'telesom_models.dart';

class TelesomApiException implements Exception {
  const TelesomApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => 'TelesomApiException($statusCode): $message';
}

class TelesomApiClient {
  TelesomApiClient({http.Client? httpClient, Uri? baseUri})
    : _http = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://mymerchant.telesom.com');

  final http.Client _http;
  final Uri _baseUri;

  /// Some deployments expect a session cookie (like the web portal).
  /// `package:http` does not manage cookies automatically, so we keep a simple
  /// in-memory cookie header and attach it to subsequent requests.
  final Map<String, String> _cookies = <String, String>{};

  static const Duration _requestTimeout = Duration(minutes: 3);

  Future<LoginResponse> login({
    required String username,
    required String password,
    required String currency,
    required String type,
  }) async {
    await _warmUpSession();
    final body = {
      'userNature': 'MERCHANT',
      'type': 'MERCHANT',
      'username': username,
      'currency': currency,
      'password': password,
    };
    final res = await _postJson('/api/account/login', body: body);
    final json = _decodeJson(res);
    if (res.statusCode != 200) {
      throw TelesomApiException(
        (json['message'] ?? 'Login failed').toString(),
        statusCode: res.statusCode,
        details: json,
      );
    }
    final parsed = LoginResponse.fromJson(json);
    final fallbackMerchant = MerchantInfo(
      id: '',
      name: parsed.username ?? username,
      merchantUid: parsed.username ?? username,
      currency: currency,
    );
    final merchant = (parsed.merchant == null)
        ? fallbackMerchant
        : (parsed.merchant!.currency.isEmpty
              ? parsed.merchant!.copyWith(currency: currency)
              : parsed.merchant!);
    return LoginResponse(
      token: parsed.token,
      refreshToken: parsed.refreshToken,
      merchant: merchant,
      replyMessage: parsed.replyMessage,
      resultCode: parsed.resultCode,
      languageId: parsed.languageId,
      sessionId: parsed.sessionId,
      userType: parsed.userType,
      userNature: parsed.userNature,
      username: parsed.username ?? username,
    );
  }

  Future<TwoFactorResponse> verify2fa({
    required String tempToken,
    required String code,
    required String sessionId,
    required String languageId,
  }) async {
    await _warmUpSession();
    final codeValue = code.trim();
    final numericCode = int.tryParse(codeValue);
    final bodyBase = <String, Object?>{
      'userNature': 'MERCHANT',
      'type': 'MERCHANT',
      'sessionId': sessionId,
    };
    final attempts = <Map<String, Object?>>[
      {...bodyBase, 'code': codeValue},
      if (numericCode != null) {...bodyBase, 'code': numericCode},
    ];
    Map<String, Object?>? lastJson;
    int? lastStatus;
    for (final attemptBody in attempts) {
      final res = await _postJson(
        '/api/account/2auth',
        bearerToken: tempToken,
        body: attemptBody,
      );
      final json = _decodeJson(res);
      if (res.statusCode == 200) {
        final parsed = TwoFactorResponse.fromJson(json);
        if (parsed.token.isEmpty) {
          return TwoFactorResponse(token: tempToken, merchant: parsed.merchant);
        }
        return parsed;
      }
      lastJson = json;
      lastStatus = res.statusCode;
      if (res.statusCode >= 500) break;
    }
    final message =
        _errorMessageFromJson(lastJson) ??
        (lastStatus == 422
            ? '2FA verification failed (invalid/expired code or request format)'
            : '2FA verification failed');
    throw TelesomApiException(
      message,
      statusCode: lastStatus,
      details: lastJson,
    );
  }

  Future<BalanceResponse> getBalance({
    required String token,
    required String merchantUid,
    required String currency,
    String? accountId,
    String? sessionId,
    String? languageId,
  }) async {
    final sid = sessionId?.trim() ?? '';
    if (sid.isEmpty) {
      throw const TelesomApiException(
        'Session ID is required for balance lookup',
      );
    }
    final body = <String, Object?>{'userNature': 'MERCHANT', 'sessionId': sid};

    final res = await _postJson(
      '/api/account/balance',
      bearerToken: token,
      body: body,
    );

    final json = _decodeJson(res);
    if (res.statusCode != 200) {
      throw TelesomApiException(
        (_errorMessageFromJson(json) ?? 'Get balance failed').toString(),
        statusCode: res.statusCode,
        details: json,
      );
    }

    final message = _errorMessageFromJson(json)?.toLowerCase() ?? '';
    if (message.contains('session') &&
        (message.contains('expired') || message.contains('invalid'))) {
      throw TelesomApiException(
        message.isEmpty ? 'Session expired' : message,
        statusCode: 401,
        details: json,
      );
    }

    return BalanceResponse.fromJson(json);
  }

  Future<FindAccountResponse> findAccount({
    required String token,
    required String sessionId,
    required String type,
    required String mobileNo,
    String userNature = 'MERCHANT',
  }) async {
    final sid = sessionId.trim();
    if (sid.isEmpty) {
      throw const TelesomApiException(
        'Session ID is required for account lookup',
      );
    }

    final mobile = mobileNo.trim();
    if (mobile.isEmpty) {
      throw const TelesomApiException(
        'Mobile number is required for account lookup',
      );
    }

    final result = await _performAccountFind(
      token: token,
      sessionId: sid,
      type: type,
      mobileNo: mobile,
      userNature: userNature,
    );

    final statusCode = result.statusCode;
    final json = result.json;

    if (statusCode == 200) {
      return FindAccountResponse.fromJson(json);
    }

    if (statusCode == 404) {
      return FindAccountResponse.fromJson({...json, 'found': false});
    }

    throw TelesomApiException(
      (json['message'] ?? 'Account lookup failed').toString(),
      statusCode: statusCode,
      details: json,
    );
  }

  /// Receiver lookup using the portal-style contract you provided.
  ///
  /// Body example:
  /// { userNature: 'MERCHANT', sessionId: 'WEB;..', type: 'internetwork', mobileNo: '06..' }
  /// Response contains a `ReceiverInfo` object.
  Future<FindReceiverResponse> findReceiver({
    required String token,
    required String mobileNo,
    required String sessionId,
    required String type,
    String userNature = 'MERCHANT',
  }) async {
    final sid = sessionId.trim();
    if (sid.isEmpty) {
      throw const TelesomApiException(
        'Session ID is required for receiver lookup',
      );
    }

    final mobile = mobileNo.trim();
    if (mobile.isEmpty) {
      throw const TelesomApiException(
        'Mobile number is required for receiver lookup',
      );
    }

    final result = await _performAccountFind(
      token: token,
      sessionId: sid,
      type: type,
      mobileNo: mobile,
      userNature: userNature,
    );

    final status = result.statusCode;
    final json = result.json;
    if (status != 200) {
      throw TelesomApiException(
        (_errorMessageFromJson(json) ?? 'Receiver lookup failed').toString(),
        statusCode: status,
        details: json,
      );
    }

    // Prefer the new contract.
    if (json.containsKey('ReceiverInfo')) {
      return FindReceiverResponse.fromJson(json);
    }

    // Fallback: some deployments might still return legacy account lookup.
    final legacy = FindAccountResponse.fromJson(json);
    if (legacy.found) {
      return FindReceiverResponse(
        resultCode: '2001',
        replyMessage: '',
        receiverInfo: ReceiverInfo(
          accountId: legacy.accountNumber,
          identityId: '',
          subscriberId: '',
          name: legacy.accountName,
          isInterNetworkReceiver: '0',
          status: legacy.status,
        ),
        sessionId: sessionId,
      );
    }

    return FindReceiverResponse(
      resultCode: (json['resultCode'] ?? '').toString(),
      replyMessage:
          (json['replyMessage'] ?? legacy.message ?? 'Receiver not found')
              .toString(),
      receiverInfo: null,
      sessionId: json['sessionId']?.toString() ?? sessionId,
    );
  }

  Future<_AccountFindResult> _performAccountFind({
    required String token,
    required String sessionId,
    required String type,
    required String mobileNo,
    required String userNature,
  }) async {
    final body = <String, Object?>{
      'userNature': userNature,
      'sessionId': sessionId,
      'type': type,
      'mobileNo': mobileNo,
    };

    final res = await _postJson(
      '/api/account/find',
      bearerToken: token,
      body: body,
    );

    final json = _decodeJson(res);
    return _AccountFindResult(statusCode: res.statusCode, json: json);
  }

  /// Programmatic helper for the portal-style B2P transfer.
  Future<B2PResponse> b2p({
    required String token,
    required String sessionId,
    required String receiverMobile,
    required String receiverName,
    required String pin,
    required String amount,
    required String description,
    required String isInterNetwork,
    String userNature = 'MERCHANT',
  }) async {
    final json = await _performPortalB2P(
      token: token,
      sessionId: sessionId,
      receiverMobile: receiverMobile,
      receiverName: receiverName,
      pin: pin,
      amount: amount,
      description: description,
      isInterNetwork: isInterNetwork,
      userNature: userNature,
    );

    return B2PResponse.fromJson(json);
  }

  Future<void> logout({required String token}) async {
    final res = await _postJson(
      '/api/account/logout',
      bearerToken: token,
      body: const <String, Object?>{},
    );

    if (res.statusCode == 200) return;

    final json = _decodeJson(res);
    throw TelesomApiException(
      (json['message'] ?? 'Logout failed').toString(),
      statusCode: res.statusCode,
      details: json,
    );
  }

  Map<String, String> _jsonHeaders({String? bearerToken}) {
    final headers = <String, String>{
      // Match portal headers closely.
      'Content-Type': 'application/json;charset=UTF-8',
      'Accept': 'application/json; charset=utf-8',
      'Accept-Language': 'en-US,en;q=0.9,so;q=0.8',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
      'Origin': _defaultOrigin(),
      'sec-ch-ua':
          '"Not:A-Brand";v="99", "Google Chrome";v="145", "Chromium";v="145"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-Mode': 'cors',
      'Sec-Fetch-Dest': 'empty',
      'host': _baseUri.host,
    };
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    final cookieHeader = _cookieHeaderValue();
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }
    return headers;
  }

  /// Merchant portal transfer contract.
  ///
  /// POST /api/money/b2p
  /// Headers: Content-Type/Accept application/json + Authorization: Bearer LOGIN_TOKEN
  /// Body example:
  /// {"userNature":"MERCHANT","sessionId":"WEB;...","receiverMobile":"06..","receiverName":"...","pin":"9955","amount":"100","description":"sarif xaabsade ","isInterNetwork":"0"}
  Future<Map<String, Object?>> b2pMerchant({
    required String token,
    required String sessionId,
    required String receiverMobile,
    required String receiverName,
    required String pin,
    required String amount,
    required String description,
    required String isInterNetwork,
    String userNature = 'MERCHANT',
  }) async {
    return _performPortalB2P(
      token: token,
      sessionId: sessionId,
      receiverMobile: receiverMobile,
      receiverName: receiverName,
      pin: pin,
      amount: amount,
      description: description,
      isInterNetwork: isInterNetwork,
      userNature: userNature,
    );
  }

  Future<Map<String, Object?>> _performPortalB2P({
    required String token,
    required String sessionId,
    required String receiverMobile,
    required String receiverName,
    required String pin,
    required String amount,
    required String description,
    required String isInterNetwork,
    required String userNature,
  }) async {
    final body = <String, Object?>{
      'userNature': userNature,
      'sessionId': sessionId,
      'receiverMobile': receiverMobile,
      'receiverName': receiverName,
      'pin': pin,
      'amount': amount,
      'description': description,
      'isInterNetwork': isInterNetwork,
    };

    final res = await _postJson(
      '/api/money/b2p',
      bearerToken: token,
      body: body,
    );

    final json = _decodeJson(res);
    if (res.statusCode != 200) {
      throw TelesomApiException(
        (_errorMessageFromJson(json) ?? 'Transfer failed').toString(),
        statusCode: res.statusCode,
        details: json,
      );
    }

    return json;
  }

  Future<http.Response> _postJson(
    String path, {
    String? bearerToken,
    required Map<String, Object?> body,
  }) async {
    final headers = _jsonHeaders(bearerToken: bearerToken);
    final payload = jsonEncode(body);

    Object? lastError;

    for (final base in _candidateBaseUris()) {
      final uri = base.resolve(path);
      try {
        final res = await _http
            .post(uri, headers: headers, body: payload)
            .timeout(_requestTimeout);
        _updateCookies(res);
        return res;
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on Exception catch (e) {
        lastError = e;
      }
    }

    throw TelesomApiException(
      _networkErrorMessage(lastError),
      details: lastError,
    );
  }

  Future<void> _warmUpSession() async {
    // If we already have the main session cookie, skip.
    if (_cookies.containsKey('cookiesession1')) return;

    Object? lastError;
    for (final base in _candidateBaseUris()) {
      final uri = base.resolve('/');
      try {
        final res = await _http
            .get(uri, headers: _browserHeaders())
            .timeout(_requestTimeout);
        _updateCookies(res);
        if (_cookies.containsKey('cookiesession1')) return;
      } on TimeoutException catch (e) {
        lastError = e;
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on Exception catch (e) {
        lastError = e;
      }
    }

    // Don't fail login just because warm-up failed; the POST may still work.
    if (lastError != null) {
      return;
    }
  }

  Map<String, String> _browserHeaders() {
    final headers = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,so;q=0.8',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 (KHTML, like Gecko) Chrome Mobile Safari/537.36',
    };
    final cookieHeader = _cookieHeaderValue();
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      headers['Cookie'] = cookieHeader;
    }
    return headers;
  }

  String _defaultOrigin() {
    // Match the portal request shape (typically Origin is the main site).
    final scheme = _baseUri.scheme.isEmpty ? 'https' : _baseUri.scheme;
    final host = _baseUri.host;
    return '$scheme://$host';
  }

  void _updateCookies(http.Response res) {
    final setCookie = res.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return;

    for (final raw in _splitSetCookieHeader(setCookie)) {
      final nameValue = raw.split(';').first.trim();
      if (!nameValue.contains('=')) continue;
      final idx = nameValue.indexOf('=');
      final name = nameValue.substring(0, idx).trim();
      final value = nameValue.substring(idx + 1).trim();
      if (name.isEmpty) continue;
      _cookies[name] = value;
    }
  }

  List<String> _splitSetCookieHeader(String header) {
    // Split on commas that are not within an Expires attribute.
    final parts = <String>[];
    final sb = StringBuffer();
    var inExpires = false;

    for (var i = 0; i < header.length; i++) {
      final ch = header[i];
      if (ch == ',') {
        if (!inExpires) {
          parts.add(sb.toString().trim());
          sb.clear();
          continue;
        }
      }

      sb.write(ch);

      // Track whether we're inside Expires=... until next ';'
      final lower = sb.toString().toLowerCase();
      if (!inExpires && lower.endsWith('expires=')) {
        inExpires = true;
      }
      if (inExpires && ch == ';') {
        inExpires = false;
      }
    }

    final last = sb.toString().trim();
    if (last.isNotEmpty) parts.add(last);
    return parts.where((e) => e.isNotEmpty).toList();
  }

  String? _cookieHeaderValue() {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  String? _errorMessageFromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final candidates = [
      json['message'],
      json['error'],
      json['detail'],
      json['title'],
    ];
    for (final c in candidates) {
      final s = c?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }

    final errors = json['errors'];
    if (errors != null) {
      final s = errors.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  List<Uri> _candidateBaseUris() {
    final primary = _baseUri;
    final candidates = <Uri>[primary];

    // If a port was specified (like :8099) and it fails, try the default port.
    if (primary.hasPort && primary.port != 0) {
      final withoutPort = Uri(
        scheme: primary.scheme,
        userInfo: primary.userInfo,
        host: primary.host,
        path: primary.path,
        query: primary.query,
        fragment: primary.fragment,
      );
      if (!candidates.contains(withoutPort)) {
        candidates.add(withoutPort);
      }
      return candidates;
    }

    // If no port specified, also try :8099 (some deployments use it).
    final with8099 = Uri(
      scheme: primary.scheme,
      userInfo: primary.userInfo,
      host: primary.host,
      port: 8099,
      path: primary.path,
      query: primary.query,
      fragment: primary.fragment,
    );
    if (!candidates.contains(with8099)) {
      candidates.add(with8099);
    }
    return candidates;
  }

  String _networkErrorMessage(Object? error) {
    final host = _baseUri.host;
    if (error is TimeoutException) {
      return 'Connection timed out. Check your internet and whether $host is reachable.';
    }
    if (error is SocketException) {
      return 'Network error: ${error.message}. Check your internet and DNS for $host.';
    }
    if (error is http.ClientException) {
      return 'Network error: ${error.message}. Check your internet for $host.';
    }
    return 'Network error. Check your internet and whether $host is reachable.';
  }

  Map<String, Object?> _decodeJson(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, Object?>) return decoded;
      if (decoded is Map) return decoded.cast<String, Object?>();
      return {'message': decoded.toString()};
    } catch (_) {
      return {'message': res.body};
    }
  }
}

class _AccountFindResult {
  const _AccountFindResult({required this.statusCode, required this.json});

  final int statusCode;
  final Map<String, Object?> json;
}
