import 'package:flutter/material.dart';

import '../../core/data/storage/prefs_store.dart';
import '../../core/data/storage/secure_store.dart';
import '../../core/data/telesom/telesom_models.dart';
import '../../core/data/telesom/telesom_api_client.dart';
import '../../ui/blueprint/blueprint_widgets.dart';
import 'otp_verify_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.apiClient,
    required this.secureStore,
    required this.prefsStore,
    this.logoAsset = 'assets/images/xaabsade_logo.png',
  });

  final TelesomApiClient apiClient;
  final SecureStore secureStore;
  final PrefsStore prefsStore;
  final String logoAsset;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  static const String _currency = '840';
  static const String _type = 'MERCHANT';
  static const Set<String> _acceptedLoginCodes = {
    '2001',
    '200',
    '201',
    '0',
    '00',
    'ok',
    'success',
  };
  bool _busy = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final login = await widget.apiClient.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        currency: _currency,
        type: _type,
      );

      final validationError = _loginValidationError(login);
      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationError)));
        return;
      }

      final tempToken = login.token;
      final refreshToken = login.refreshToken ?? '';
      final merchant = login.merchant!;
      final currency = merchant.currency.isEmpty
          ? _currency
          : merchant.currency;
      final sessionId = login.sessionId ?? '';
      final languageId = login.languageId ?? '';

      await widget.secureStore.writePendingAuth(
        loginToken: tempToken,
        sessionId: sessionId,
        languageId: languageId,
        username: _usernameCtrl.text.trim(),
      );

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OtpVerifyScreen(
            apiClient: widget.apiClient,
            secureStore: widget.secureStore,
            prefsStore: widget.prefsStore,
            tempToken: tempToken,
            refreshToken: refreshToken,
            merchant: merchant,
            username: _usernameCtrl.text.trim(),
            password: _passwordCtrl.text,
            currency: currency,
            type: _type,
            sessionId: sessionId,
            languageId: languageId,
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _loginValidationError(LoginResponse login) {
    final token = login.token.trim();
    final sessionId = login.sessionId?.trim() ?? '';
    final resultCode = login.resultCode?.trim();
    final reply = login.replyMessage?.trim();
    final replyIsOtpPrompt = _replySuggestsOtpPrompt(reply);

    final bool invalidToken = token.isEmpty;
    final bool missingSession = sessionId.isEmpty;
    final bool codeRejected =
        !replyIsOtpPrompt && !_isLoginResultCodeOk(resultCode);
    final bool replyRejected =
        !replyIsOtpPrompt && _replySuggestsFailure(reply);

    if (!(invalidToken || missingSession || codeRejected || replyRejected)) {
      return null;
    }

    if (replyRejected && reply != null && reply.isNotEmpty) {
      return reply;
    }
    if (codeRejected && reply != null && reply.isNotEmpty) {
      return reply;
    }
    return 'Invalid username or password. Please try again.';
  }

  bool _isLoginResultCodeOk(String? code) {
    if (code == null || code.trim().isEmpty) return true;
    return _acceptedLoginCodes.contains(code.trim().toLowerCase());
  }

  bool _replySuggestsFailure(String? reply) {
    if (reply == null || reply.isEmpty) return false;
    final normalized = reply.toLowerCase();
    return normalized.contains('invalid') ||
        normalized.contains('incorrect') ||
        normalized.contains('wrong') ||
        normalized.contains('denied') ||
        normalized.contains('blocked') ||
        normalized.contains('failed') ||
        normalized.contains('not allowed');
  }

  bool _replySuggestsOtpPrompt(String? reply) {
    if (reply == null || reply.isEmpty) return false;
    final normalized = reply.toLowerCase();
    return normalized.contains('enter key') ||
        normalized.contains('enter the key') ||
        normalized.contains('sms') ||
        normalized.contains('otp') ||
        normalized.contains('one time') ||
        normalized.contains('verification code') ||
        normalized.contains('2fa') ||
        normalized.contains('two factor');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const BlueprintBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final content = isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: _buildFormPanel(context))],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [_buildFormPanel(context)],
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
              Image.asset(widget.logoAsset, width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xaabsade AI',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: BlueprintTokens.ink,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      'Xaliyaha caqliga leh ee maareynta lacagaha',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BlueprintTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              BlueprintTag(
                label: 'SECURE',
                icon: Icons.lock_outline,
                color: BlueprintTokens.accent,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Xaabsade AI',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: BlueprintTokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Sign in to monitor balance flows, verify live status, and manage auto transfers in one click.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: BlueprintTokens.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              BlueprintTag(label: 'LIVE BALANCE', icon: Icons.speed),
              BlueprintTag(label: 'AUTO TRANSFER', icon: Icons.swap_horiz),
              BlueprintTag(label: '2FA READY', icon: Icons.verified_user),
            ],
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
                Icon(Icons.shield_outlined, color: BlueprintTokens.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Multi-layer authentication is required for every session.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BlueprintTokens.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel(BuildContext context) {
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: BlueprintTokens.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use your merchant credentials to continue.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: BlueprintTokens.muted),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _usernameCtrl,
              decoration: fieldDecoration('Username', Icons.person_outline),
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              decoration: fieldDecoration('Password', Icons.lock_outline)
                  .copyWith(
                    suffixIcon: IconButton(
                      onPressed: () =>
                          setState(() => _passwordVisible = !_passwordVisible),
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _busy ? null : _submit(),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
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
                  : const Icon(Icons.login),
              label: const Text('Sign in'),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}
