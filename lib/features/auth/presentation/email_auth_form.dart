import 'package:flutter/material.dart';

import '../../../core/ui/app_buttons.dart';
import '../../../core/ui/app_spacing.dart';
import '../../../core/ui/design_tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Which of the three things the one form is doing.
enum EmailAuthMode { signIn, createAccount, reset }

/// Email and password — the fallback way in, revealed by "Use email instead".
///
/// The design has no email form at all: phone is the front door. It stays
/// because phone *and* Google are both switched on by a build-time define
/// (D113, D115), so a build without either would otherwise have no way to
/// sign in at all — including every developer build and the reviewer's
/// (D114). One form rather than two pages: sign in, create an account and the
/// reset are the same three fields in different combinations, and swapping
/// between them here keeps the user on the screen they started on.
class EmailAuthForm extends StatefulWidget {
  const EmailAuthForm({
    super.key,
    required this.authController,
    required this.onDismiss,
  });

  final AuthController authController;

  /// Closes the form and puts the provider buttons back.
  final VoidCallback onDismiss;

  @override
  State<EmailAuthForm> createState() => _EmailAuthFormState();
}

class _EmailAuthFormState extends State<EmailAuthForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  EmailAuthMode _mode = EmailAuthMode.signIn;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _setMode(EmailAuthMode mode) {
    setState(() => _mode = mode);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final controller = widget.authController;
    final email = _emailController.text.trim();

    switch (_mode) {
      case EmailAuthMode.signIn:
        final ok = await controller.login(
          email: email,
          password: _passwordController.text,
        );
        if (!mounted || ok) {
          // The router redirect owns where a signed-in user lands — it may be
          // the wizard rather than the deck.
          return;
        }
        _showMessage(controller.errorMessage ?? 'Unable to sign in.');

      case EmailAuthMode.createAccount:
        final ok = await controller.register(
          name: _nameController.text.trim(),
          email: email,
          password: _passwordController.text,
        );
        if (!mounted) {
          return;
        }
        if (!ok) {
          _showMessage(controller.errorMessage ?? 'Unable to create account.');
          return;
        }
        // Email confirmation is on, so signing up issues no session: the
        // account only works once the emailed link is opened. Say so and drop
        // the user on the sign-in form rather than pretending they are in.
        final notice = controller.notice;
        if (notice != null) {
          _showMessage(notice);
          controller.clearNotice();
          _setMode(EmailAuthMode.signIn);
        }

      case EmailAuthMode.reset:
        final sent = await controller.sendPasswordReset(email);
        if (!mounted) {
          return;
        }
        _showMessage(
          sent
              ? controller.notice ?? 'Password reset link sent.'
              : controller.errorMessage ?? 'Unable to send the link.',
        );
        if (sent) {
          controller.clearNotice();
          _setMode(EmailAuthMode.signIn);
        }
    }
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Enter your email.';
    }
    if (!text.contains('@')) {
      return 'Enter a valid email.';
    }
    return null;
  }

  String _primaryLabel(bool busy) {
    switch (_mode) {
      case EmailAuthMode.signIn:
        return busy ? 'Signing in…' : 'Sign in';
      case EmailAuthMode.createAccount:
        return busy ? 'Creating…' : 'Create account';
      case EmailAuthMode.reset:
        return busy ? 'Sending…' : 'Send reset link';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final busy = widget.authController.isBusy;

        return Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mode == EmailAuthMode.createAccount) ...[
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'What should we call you?',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Enter your name.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'you@example.com',
                ),
                validator: _validateEmail,
              ),
              if (_mode != EmailAuthMode.reset) ...[
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: [
                    _mode == EmailAuthMode.signIn
                        ? AutofillHints.password
                        : AutofillHints.newPassword,
                  ],
                  onFieldSubmitted: (_) => busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: _mode == EmailAuthMode.createAccount
                        ? 'At least 8 characters'
                        : 'Your password',
                  ),
                  validator: (value) {
                    final text = value ?? '';
                    if (_mode == EmailAuthMode.createAccount) {
                      return text.length < 8
                          ? 'Password must be at least 8 characters.'
                          : null;
                    }
                    return text.isEmpty ? 'Enter your password.' : null;
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: _primaryLabel(busy),
                expand: true,
                busy: busy,
                onPressed: busy ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  if (_mode != EmailAuthMode.createAccount)
                    AuthTextButton(
                      label: 'Create an account',
                      onPressed: busy
                          ? null
                          : () => _setMode(EmailAuthMode.createAccount),
                    ),
                  if (_mode == EmailAuthMode.signIn)
                    AuthTextButton(
                      label: 'Forgot password?',
                      onPressed:
                          busy ? null : () => _setMode(EmailAuthMode.reset),
                    ),
                  if (_mode != EmailAuthMode.signIn)
                    AuthTextButton(
                      label: 'Sign in instead',
                      onPressed:
                          busy ? null : () => _setMode(EmailAuthMode.signIn),
                    ),
                  AuthTextButton(
                    label: 'More ways in',
                    onPressed: busy ? null : widget.onDismiss,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Email is the fallback while phone sign-in is switched off.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: kTextFontFamily,
                  fontSize: kFontSizeMicro,
                  color: kTextOnPhotoMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
