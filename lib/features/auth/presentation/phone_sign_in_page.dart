import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// One tick a second, driving the resend countdown. Injected so a widget test
/// can run the thirty seconds without waiting for them.
typedef ResendTicker = Stream<void> Function();

Stream<void> _secondTicker() =>
    Stream<void>.periodic(const Duration(seconds: 1));

/// Sign in with a phone number: ask for the number, then for the code.
///
/// Malaysia only for now — the app is Kuala Lumpur's, the country code is
/// fixed at +60 and shown as a chip rather than a picker, so the field asks
/// for one thing. A second country is a picker in this one place.
class PhoneSignInPage extends StatefulWidget {
  const PhoneSignInPage({
    super.key,
    required this.authController,
    this.ticker = _secondTicker,
  });

  final AuthController authController;
  final ResendTicker ticker;

  @override
  State<PhoneSignInPage> createState() => _PhoneSignInPageState();
}

class _PhoneSignInPageState extends State<PhoneSignInPage> {
  /// The one country this app serves. See the class doc.
  static const String _dialCode = '+60';

  /// A Malaysian subscriber number is 9 or 10 digits once the trunk `0` is
  /// dropped (`12-345 6789`, `11-2345 6789`).
  static const int _minDigits = 9;
  static const int _maxDigits = 10;

  static const int _codeLength = 6;

  /// How long before a new code can be asked for.
  static const int _resendSeconds = 30;

  final _numberController = TextEditingController();
  final _codeController = TextEditingController();

  StreamSubscription<void>? _tick;
  bool _codeSent = false;
  int _resendIn = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _numberController.addListener(_onNumberChanged);
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    unawaited(_tick?.cancel());
    _numberController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onNumberChanged() => setState(() {});

  void _onCodeChanged() => setState(() {});

  /// The subscriber number: digits only, with the trunk `0` dropped. People
  /// type `012…` because that is how the number is written locally; +60 and a
  /// leading zero together are not a number.
  String get _digits {
    var digits = _numberController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('60')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  bool get _numberIsValid =>
      _digits.length >= _minDigits && _digits.length <= _maxDigits;

  String get _e164 => '$_dialCode$_digits';

  Future<void> _sendCode() async {
    if (!_numberIsValid) {
      return;
    }
    setState(() => _error = null);

    final sent = await widget.authController.signInWithPhone(_e164);
    if (!mounted) {
      return;
    }
    if (!sent) {
      setState(() {
        _error = widget.authController.errorMessage ??
            'That code could not be sent. Try again.';
      });
      return;
    }

    widget.authController.clearNotice();
    setState(() {
      _codeSent = true;
      _error = null;
    });
    _startCountdown();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != _codeLength) {
      return;
    }
    setState(() => _error = null);

    final ok = await widget.authController.verifyPhoneOtp(
      phone: _e164,
      code: code,
    );
    if (!mounted || ok) {
      // The router redirect owns where a verified user lands — the wizard on a
      // new account, the deck on a returning one.
      return;
    }
    setState(() {
      _error = widget.authController.errorMessage ??
          'That code is wrong or has expired. Ask for a new one.';
    });
  }

  void _startCountdown() {
    unawaited(_tick?.cancel());
    setState(() => _resendIn = _resendSeconds);
    _tick = widget.ticker().listen((_) {
      if (!mounted) {
        return;
      }
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) {
        // Cancelled at zero so nothing is still ticking behind the screen —
        // and so a test can settle.
        unawaited(_tick?.cancel());
        _tick = null;
      }
    });
  }

  void _changeNumber() {
    unawaited(_tick?.cancel());
    _tick = null;
    _codeController.clear();
    setState(() {
      _codeSent = false;
      _resendIn = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: Stack(
        children: [
          const ScreenGlow(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSpacing.dashboardMaxWidth,
                ),
                child: AnimatedBuilder(
                  animation: widget.authController,
                  builder: (context, _) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            AppIconButton(
                              icon: Icons.chevron_left_rounded,
                              size: kUtilityButtonSize,
                              background: kGlass,
                              semanticLabel: 'Back',
                              onTap: _back,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // Flexible: at a large text scale the wordmark is
                            // wide enough to push the back button off screen.
                            const Flexible(child: AuthBrand()),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _title(context),
                        const SizedBox(height: AppSpacing.lg),
                        if (_codeSent) ..._codeStep(context) else ..._numberStep(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _back() {
    if (_codeSent) {
      _changeNumber();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Widget _title(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _codeSent ? 'Check your messages' : "What's your number?",
          style: theme.textTheme.headlineMedium!.copyWith(
            fontFamily: kDisplayFontFamily,
            color: kTextOnPhoto,
            fontSize: kFontSizeH1,
            fontWeight: FontWeight.w700,
            height: 1.05,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            _codeSent
                ? 'We sent a six-digit code to $_e164.'
                : "We'll text you a six-digit code. No password to remember.",
            style: theme.textTheme.bodyMedium!.copyWith(
              color: kTextOnPhotoSecondary,
              fontSize: kFontSizeBody,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _numberStep() {
    final busy = widget.authController.isBusy;

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: kAuthButtonHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kSurfacePanel,
              borderRadius: BorderRadius.circular(kRadiusPanel),
              border: Border.all(color: kHairline),
            ),
            child: const Text(
              _dialCode,
              style: TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeBody,
                fontWeight: FontWeight.w600,
                color: kTextOnPhoto,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              key: const ValueKey('phone-number-field'),
              controller: _numberController,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
                LengthLimitingTextInputFormatter(14),
              ],
              onSubmitted: (_) => busy ? null : _sendCode(),
              style: const TextStyle(
                fontFamily: kTextFontFamily,
                fontSize: kFontSizeBody,
                color: kTextOnPhoto,
              ),
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '12 345 6789',
              ),
            ),
          ),
        ],
      ),
      ..._errorLine(),
      const SizedBox(height: AppSpacing.md),
      AppPrimaryButton(
        label: 'Send code',
        expand: true,
        busy: busy,
        // Nothing is sent until the number could be one — the design's rule
        // that a button never works before its stated minimum is met.
        onPressed: _numberIsValid && !busy ? _sendCode : null,
      ),
    ];
  }

  List<Widget> _codeStep(BuildContext context) {
    final busy = widget.authController.isBusy;

    return [
      TextField(
        key: const ValueKey('phone-code-field'),
        controller: _codeController,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(_codeLength),
        ],
        onSubmitted: (_) => busy ? null : _verify(),
        style: const TextStyle(
          fontFamily: kDisplayFontFamily,
          fontSize: kFontSizeH2,
          fontWeight: FontWeight.w700,
          color: kTextOnPhoto,
          letterSpacing: 6,
        ),
        decoration: const InputDecoration(
          labelText: 'Six-digit code',
          hintText: '••••••',
        ),
      ),
      ..._errorLine(),
      const SizedBox(height: AppSpacing.md),
      AppPrimaryButton(
        label: 'Verify',
        expand: true,
        busy: busy,
        onPressed: _codeController.text.trim().length == _codeLength && !busy
            ? _verify
            : null,
      ),
      const SizedBox(height: AppSpacing.xs),
      Center(
        child: _resendIn > 0
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Resend in $_resendIn s',
                  style: const TextStyle(
                    fontFamily: kTextFontFamily,
                    fontSize: kFontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: kTextOnPhotoMuted,
                    height: 1.2,
                  ),
                ),
              )
            : AuthTextButton(
                label: 'Send a new code',
                onPressed: busy ? null : _sendCode,
              ),
      ),
      Center(
        child: AuthTextButton(
          label: 'Change number',
          onPressed: busy ? null : _changeNumber,
        ),
      ),
    ];
  }

  /// The failure sits under the field it belongs to, in the design's voice —
  /// not in a snack bar that covers the button the user just pressed.
  List<Widget> _errorLine() {
    final error = _error;
    if (error == null) {
      return const [];
    }

    return [
      const SizedBox(height: AppSpacing.xs),
      Text(
        error,
        style: const TextStyle(
          fontFamily: kTextFontFamily,
          fontSize: kFontSizeSmall,
          color: kTintSpice,
          height: 1.35,
        ),
      ),
    ];
  }
}
