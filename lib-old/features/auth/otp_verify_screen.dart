import 'package:flutter/material.dart';
import '../../core/data/storage/prefs_store.dart';
import '../../core/data/storage/secure_store.dart';
import '../../core/data/telesom/telesom_api_client.dart';
import '../../core/data/telesom/telesom_models.dart';
import '../../ui/blueprint/blueprint_widgets.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
    required this.tempToken,
    required this.refreshToken,
    required this.merchant,
    required this.username,
    required this.password,
    required this.currency,
    required this.type,
    required this.sessionId,
    required this.languageId,
  });

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;

  final String tempToken;
  final String refreshToken;
  final MerchantInfo merchant;
  final String username;
  final String password;
  final String currency;
  final String type;
  final String sessionId;
  final String languageId;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  bool _busy = false;

  late String _tempToken;
  late String _refreshToken;
  late MerchantInfo _merchant;
  late String _currency;
  late String _sessionId;
  late String _languageId;
  String? _status;

  @override
  void initState() {
    super.initState();
    _tempToken = widget.tempToken;
    _refreshToken = widget.refreshToken;
    _merchant = widget.merchant;
    _currency = widget.currency;
    _sessionId = widget.sessionId;
    _languageId = widget.languageId;
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final res = await widget.apiClient.verify2fa(
        tempToken: _tempToken,
        code: _otpCtrl.text.trim(),
        sessionId: _sessionId,
        languageId: _languageId,
      );

      final merchant = res.merchant ?? _merchant;
      final token = res.token.isEmpty ? _tempToken : res.token;
      final currency = merchant.currency.isEmpty
          ? _currency
          : merchant.currency;

      final merchantUid = (res.subscriptionId?.isNotEmpty ?? false)
          ? res.subscriptionId!
          : merchant.merchantUid;
      final merchantName = (res.name?.isNotEmpty ?? false)
          ? res.name!
          : merchant.name;
      final merchantPicture =
          (res.picture != null && res.picture!.trim().isNotEmpty)
          ? res.picture!.trim()
          : null;
      final usd = res.usdAccount();
      final selectedAccountId = usd?.accountId;
      final selectedAccountCurrencyName = usd?.currencyName;
      final selectedCurrencySymbol = usd?.currencySymbol;

      await widget.secureStore.writeSession(
        loginToken: _tempToken,
        token: token,
        refreshToken: _refreshToken,
        merchantUid: merchantUid,
        merchantName: merchantName,
        merchantPicture: merchantPicture,
        currency: currency,
        accountId: selectedAccountId,
        accountCurrencyName: selectedAccountCurrencyName,
        currencySymbol: selectedCurrencySymbol,
        sessionId: res.sessionId ?? _sessionId,
        languageId: res.languageId ?? _languageId,
        type: widget.type,
        username: widget.username,
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            apiClient: widget.apiClient,
            secureStore: widget.secureStore,
            prefsStore: widget.prefsStore,
            initialSession: StoredSession(
              loginToken: _tempToken,
              token: token,
              refreshToken: _refreshToken,
              merchantUid: merchantUid,
              merchantName: merchantName,
              merchantPicture: merchantPicture,
              currency: currency,
              accountId: selectedAccountId,
              accountCurrencyName: selectedAccountCurrencyName,
              currencySymbol: selectedCurrencySymbol,
              sessionId: res.sessionId ?? _sessionId,
              languageId: res.languageId ?? _languageId,
              type: widget.type,
              username: widget.username,
            ),
          ),
        ),
        (route) => false,
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _status = e.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resendOtp() async {
    if (widget.username.trim().isEmpty || widget.password.isEmpty) return;
    setState(() {
      _busy = true;
      _status = 'Sending OTP…';
    });

    try {
      final res = await widget.apiClient.login(
        username: widget.username.trim(),
        password: widget.password,
        currency: _currency,
        type: widget.type,
      );
      _tempToken = res.token;
      _refreshToken = res.refreshToken ?? _refreshToken;
      _merchant = res.merchant ?? _merchant;
      _currency = _merchant.currency.isEmpty ? _currency : _merchant.currency;
      _sessionId = res.sessionId ?? _sessionId;
      _languageId = res.languageId ?? _languageId;
      if (!mounted) return;
      setState(() => _status = 'OTP sent. Check your SMS.');
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goToLogin() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlueprintBackground(),
          Positioned(
            top: 8,
            left: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: _busy ? null : _goToLogin,
                icon: const Icon(Icons.arrow_back),
                color: BlueprintTokens.ink,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final content = isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: _buildOtpPanel(context))],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_buildOtpPanel(context)],
                      );

                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: content,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return BlueprintPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BlueprintTag(
                label: 'STEP 2',
                icon: Icons.verified_user,
                color: BlueprintTokens.accent,
              ),
              const SizedBox(width: 10),
              Text(
                'Two-factor check',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: BlueprintTokens.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Authenticate session',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: BlueprintTokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We just sent a verification code to your phone. Use the latest SMS to finish the login handshake.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: BlueprintTokens.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: BlueprintTokens.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: BlueprintTokens.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.sms_outlined, color: BlueprintTokens.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tip: If you resend, the previous code is invalid.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BlueprintTokens.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(
              _status!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BlueprintTokens.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpPanel(BuildContext context) {
    InputDecoration fieldDecoration(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: BlueprintTokens.panel,
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

    return BlueprintPanel(
      padding: const EdgeInsets.all(22),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter OTP',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: BlueprintTokens.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Code length is usually 4-6 digits.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: BlueprintTokens.muted),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                decoration: fieldDecoration('Code', Icons.shield_outlined),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                onFieldSubmitted: (_) => _busy ? null : _verify(),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Required';
                  if (value.length < 4) return 'Invalid code';
                  return null;
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : _verify,
                style: FilledButton.styleFrom(
                  backgroundColor: BlueprintTokens.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                icon: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_user),
                label: const Text('Authenticate'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _resendOtp,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BlueprintTokens.accent,
                  side: BorderSide(color: BlueprintTokens.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                icon: const Icon(Icons.autorenew),
                label: const Text('Resend code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
