class MerchantInfo {
  const MerchantInfo({
    required this.id,
    required this.name,
    required this.merchantUid,
    required this.currency,
  });

  final String id;
  final String name;
  final String merchantUid;
  final String currency;

  factory MerchantInfo.fromJson(Map<String, Object?> json) {
    return MerchantInfo(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      merchantUid: (json['merchantUid'] ?? '').toString(),
      currency: (json['currency'] ?? '').toString(),
    );
  }

  MerchantInfo copyWith({
    String? id,
    String? name,
    String? merchantUid,
    String? currency,
  }) {
    return MerchantInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      merchantUid: merchantUid ?? this.merchantUid,
      currency: currency ?? this.currency,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'merchantUid': merchantUid,
      'currency': currency,
    };
  }
}

class LoginResponse {
  const LoginResponse({
    required this.token,
    this.refreshToken,
    this.merchant,
    this.replyMessage,
    this.resultCode,
    this.languageId,
    this.sessionId,
    this.userType,
    this.userNature,
    this.username,
  });

  final String token;
  final String? refreshToken;
  final MerchantInfo? merchant;

  // Newer/portal responses
  final String? replyMessage;
  final String? resultCode;
  final String? languageId;
  final String? sessionId;
  final String? userType;
  final String? userNature;
  final String? username;

  factory LoginResponse.fromJson(Map<String, Object?> json) {
    final merchantJson = (json['merchant'] as Map?)?.cast<String, Object?>();
    return LoginResponse(
      token: (json['token'] ?? '').toString(),
      refreshToken: json['refreshToken']?.toString(),
      merchant: merchantJson == null
          ? null
          : MerchantInfo.fromJson(merchantJson),
      replyMessage: json['replyMessage']?.toString(),
      resultCode: json['resultCode']?.toString(),
      languageId: json['languageId']?.toString(),
      sessionId: json['sessionId']?.toString(),
      userType: json['userType']?.toString(),
      userNature: json['userNature']?.toString(),
      username: json['username']?.toString(),
    );
  }
}

class TwoFactorResponse {
  const TwoFactorResponse({
    required this.token,
    this.merchant,
    this.replyMessage,
    this.resultCode,
    this.name,
    this.picture,
    this.languageId,
    this.sessionId,
    this.subscriptionId,
    this.partnerId,
    this.partnerUID,
    this.defaultAccount,
    this.userType,
    this.accountInformation,
    this.raw,
  });

  final String token;
  final MerchantInfo? merchant;

  // Portal /2auth response fields
  final String? replyMessage;
  final String? resultCode;
  final String? name;
  final String? picture;
  final String? languageId;
  final String? sessionId;
  final String? subscriptionId;
  final String? partnerId;
  final String? partnerUID;
  final String? defaultAccount;
  final String? userType;
  final List<AccountInformation>? accountInformation;
  final Map<String, Object?>? raw;

  factory TwoFactorResponse.fromJson(Map<String, Object?> json) {
    final merchantJson = (json['merchant'] as Map?)?.cast<String, Object?>();

    List<AccountInformation>? accounts;
    final rawAccounts = json['accountInformation'];
    if (rawAccounts is List) {
      accounts = rawAccounts
          .whereType<Map>()
          .map((e) => AccountInformation.fromJson(e.cast<String, Object?>()))
          .toList();
    }

    return TwoFactorResponse(
      token: (json['token'] ?? '').toString(),
      merchant: merchantJson == null
          ? null
          : MerchantInfo.fromJson(merchantJson),
      replyMessage: json['replyMessage']?.toString(),
      resultCode: json['resultCode']?.toString(),
      name: json['name']?.toString(),
      picture: json['picture']?.toString(),
      languageId: json['languageId']?.toString(),
      sessionId: json['sessionId']?.toString(),
      subscriptionId: json['subscriptionId']?.toString(),
      partnerId: json['partnerId']?.toString(),
      partnerUID: json['partnerUID']?.toString(),
      defaultAccount: json['defaultAccount']?.toString(),
      userType: json['userType']?.toString(),
      accountInformation: accounts,
      raw: json,
    );
  }

  Map<String, Object?> toJson() {
    if (raw != null) return raw!;
    return {
      'token': token,
      'merchant': merchant?.toJson(),
      'replyMessage': replyMessage,
      'resultCode': resultCode,
      'name': name,
      'picture': picture,
      'languageId': languageId,
      'sessionId': sessionId,
      'subscriptionId': subscriptionId,
      'partnerId': partnerId,
      'partnerUID': partnerUID,
      'defaultAccount': defaultAccount,
      'userType': userType,
      'accountInformation': accountInformation
          ?.map((account) => account.toJson())
          .toList(),
    };
  }

  /// Pick the best accountId for the app currency.
  /// App uses currency strings like DOLLAR / SLSH, while API uses USD / SLSH.
  String? accountIdForAppCurrency(String appCurrency) {
    final accounts = accountInformation;
    if (accounts == null || accounts.isEmpty) return null;

    final want = (appCurrency.toUpperCase() == 'DOLLAR') ? 'USD' : appCurrency;
    final match = accounts.firstWhere(
      (a) => a.currencyName.toUpperCase() == want.toUpperCase(),
      orElse: () => accounts.first,
    );
    return match.accountId;
  }

  AccountInformation? usdAccount() {
    final accounts = accountInformation;
    if (accounts == null || accounts.isEmpty) return null;
    for (final a in accounts) {
      if (a.currencyName.toUpperCase() == 'USD') return a;
    }
    return null;
  }
}

class AccountInformation {
  const AccountInformation({
    required this.accountId,
    required this.accountTitle,
    required this.accountNumber,
    required this.currencyName,
    required this.currencySymbol,
    required this.isDefaultAccount,
  });

  final String accountId;
  final String accountTitle;
  final String accountNumber;
  final String currencyName;
  final String currencySymbol;
  final bool isDefaultAccount;

  factory AccountInformation.fromJson(Map<String, Object?> json) {
    return AccountInformation(
      accountId: (json['accountId'] ?? '').toString(),
      accountTitle: (json['accountTitle'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      currencyName: (json['currencyName'] ?? '').toString(),
      currencySymbol: (json['currencySymbol'] ?? '').toString(),
      isDefaultAccount: (json['isDefaultAccount'] as bool?) ?? false,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'accountId': accountId,
      'accountTitle': accountTitle,
      'accountNumber': accountNumber,
      'currencyName': currencyName,
      'currencySymbol': currencySymbol,
      'isDefaultAccount': isDefaultAccount,
    };
  }
}

class BalanceResponse {
  const BalanceResponse({
    required this.balance,
    required this.availableBalance,
    required this.heldBalance,
    required this.currency,
    required this.currencySymbol,
    required this.lastUpdated,
    required this.accounts,
  });

  final double balance;
  final double availableBalance;
  final double heldBalance;
  final String currency;
  final String currencySymbol;
  final DateTime? lastUpdated;
  final List<BalanceAccountItem> accounts;

  factory BalanceResponse.fromJson(Map<String, Object?> json) {
    DateTime? parsed;
    final lastUpdatedRaw = json['lastUpdated']?.toString();
    if (lastUpdatedRaw != null && lastUpdatedRaw.isNotEmpty) {
      parsed = DateTime.tryParse(lastUpdatedRaw);
    }

    final rawAccounts = json['accounts'];
    final accounts = <BalanceAccountItem>[];
    if (rawAccounts is List) {
      for (final item in rawAccounts) {
        if (item is Map) {
          accounts.add(
            BalanceAccountItem.fromJson(item.cast<String, Object?>()),
          );
        }
      }
    }

    final currencySymbol = (json['currencySymbol'] ?? '').toString();

    return BalanceResponse(
      balance: _toDouble(
        json['balance'] ??
            json['accountBalance'] ??
            json['currentBalance'] ??
            json['availableBalance'],
      ),
      availableBalance: _toDouble(json['availableBalance'] ?? json['balance']),
      heldBalance: _toDouble(json['heldBalance'] ?? 0),
      currency: (json['currency'] ?? json['currencyName'] ?? '').toString(),
      currencySymbol: currencySymbol,
      lastUpdated: parsed,
      accounts: accounts,
    );
  }

  BalanceAccountItem? accountWithSymbol(String symbol) {
    for (final a in accounts) {
      if (a.currencySymbol == symbol) return a;
    }
    return null;
  }
}

class BalanceAccountItem {
  const BalanceAccountItem({
    required this.accountId,
    required this.accountTitle,
    required this.currencySymbol,
    required this.currentBalance,
  });

  final String accountId;
  final String accountTitle;
  final String currencySymbol;
  final double currentBalance;

  factory BalanceAccountItem.fromJson(Map<String, Object?> json) {
    return BalanceAccountItem(
      accountId: (json['accountId'] ?? '').toString(),
      accountTitle: (json['accountTitle'] ?? '').toString(),
      currencySymbol: (json['currencySymbol'] ?? '').toString(),
      currentBalance: _toDouble(json['currentBalance'] ?? json['balance']),
    );
  }
}

class FindAccountResponse {
  const FindAccountResponse({
    required this.found,
    required this.accountName,
    required this.accountNumber,
    required this.type,
    required this.status,
    this.message,
    this.balance,
  });

  final bool found;
  final String accountName;
  final String accountNumber;
  final String type;
  final String status;
  final String? message;
  final double? balance;

  factory FindAccountResponse.fromJson(Map<String, Object?> json) {
    final balanceRaw =
        json['balance'] ??
        json['currentBalance'] ??
        json['availableBalance'] ??
        json['walletBalance'] ??
        json['BALANCE'];

    return FindAccountResponse(
      found: (json['found'] as bool?) ?? false,
      accountName: (json['accountName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      message: json['message']?.toString(),
      balance: balanceRaw == null ? null : _toDouble(balanceRaw),
    );
  }
}

class FindReceiverResponse {
  const FindReceiverResponse({
    required this.resultCode,
    required this.replyMessage,
    required this.receiverInfo,
    required this.sessionId,
  });

  final String resultCode;
  final String replyMessage;
  final ReceiverInfo? receiverInfo;
  final String? sessionId;

  bool get ok => resultCode == '2001' && receiverInfo != null;

  factory FindReceiverResponse.fromJson(Map<String, Object?> json) {
    final raw = json['ReceiverInfo'];
    final info = (raw is Map)
        ? ReceiverInfo.fromJson(raw.cast<String, Object?>())
        : null;

    return FindReceiverResponse(
      resultCode: (json['resultCode'] ?? '').toString(),
      replyMessage: (json['replyMessage'] ?? '').toString(),
      receiverInfo: info,
      sessionId: json['sessionId']?.toString(),
    );
  }
}

class ReceiverInfo {
  const ReceiverInfo({
    required this.accountId,
    required this.identityId,
    required this.subscriberId,
    required this.name,
    required this.isInterNetworkReceiver,
    required this.status,
  });

  final String accountId;
  final String identityId;
  final String subscriberId;
  final String name;
  final String isInterNetworkReceiver;
  final String status;

  factory ReceiverInfo.fromJson(Map<String, Object?> json) {
    return ReceiverInfo(
      accountId: (json['ACCOUNTID'] ?? '').toString(),
      identityId: (json['IDENTITYID'] ?? '').toString(),
      subscriberId: (json['SUBSCRIBERID'] ?? '').toString(),
      name: (json['NAME'] ?? '').toString(),
      isInterNetworkReceiver: (json['ISINTERNETWORKRECEIVER'] ?? '').toString(),
      status: (json['STATUS'] ?? '').toString(),
    );
  }
}

class B2PResponse {
  const B2PResponse({
    required this.transactionId,
    required this.referenceId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.fromAccount,
    required this.toAccount,
    required this.toAccountName,
    required this.timestamp,
    required this.newBalance,
    this.message,
  });

  final String transactionId;
  final String referenceId;
  final String status;
  final double amount;
  final String currency;
  final String fromAccount;
  final String toAccount;
  final String toAccountName;
  final DateTime? timestamp;
  final double? newBalance;
  final String? message;

  factory B2PResponse.fromJson(Map<String, Object?> json) {
    final tsRaw = json['timestamp']?.toString();
    final ts = (tsRaw == null || tsRaw.isEmpty)
        ? null
        : DateTime.tryParse(tsRaw);

    return B2PResponse(
      transactionId: (json['transactionId'] ?? '').toString(),
      referenceId: (json['referenceId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      amount: _toDouble(json['amount']),
      currency: (json['currency'] ?? '').toString(),
      fromAccount: (json['fromAccount'] ?? '').toString(),
      toAccount: (json['toAccount'] ?? '').toString(),
      toAccountName: (json['toAccountName'] ?? '').toString(),
      timestamp: ts,
      newBalance: json['newBalance'] == null
          ? null
          : _toDouble(json['newBalance']),
      message: json['message']?.toString(),
    );
  }
}

double _toDouble(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
