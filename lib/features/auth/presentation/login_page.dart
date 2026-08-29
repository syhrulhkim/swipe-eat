import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/app_spacing.dart';
import '../state/auth_controller.dart';
import 'social_sign_in_buttons.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.authController,
  });

  final AuthController authController;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // A just-registered account arrives here with "check your inbox" pending.
    final notice = widget.authController.notice;
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showMessage(notice);
        widget.authController.clearNotice();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final success = await widget.authController.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      // The router redirect owns where an authenticated user lands, so it is
      // not hardcoded here — onboarding may be owed.
      return;
    }

    _showMessage(widget.authController.errorMessage ?? 'Unable to sign in.');
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Enter your email first, then tap reset.');
      return;
    }

    final sent = await widget.authController.sendPasswordReset(email);
    if (!mounted) {
      return;
    }

    _showMessage(
      sent
          ? widget.authController.notice ?? 'Password reset link sent.'
          : widget.authController.errorMessage ?? 'Unable to send the link.',
    );
    widget.authController.clearNotice();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authController,
      builder: (context, _) {
        final busy = widget.authController.isBusy;

        return FScaffold(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppSpacing.cardMaxWidth),
                  child: FCard(
                    title: const Text('Sign in'),
                    subtitle: const Text(
                      'Your picks, preferences and location live in your '
                      'account, so they follow you to any device.',
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Enter your email.';
                              }
                              if (!text.contains('@')) {
                                return 'Enter a valid email.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => busy ? null : _submit(),
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              hintText: 'Password',
                            ),
                            validator: (value) {
                              if ((value ?? '').isEmpty) {
                                return 'Enter your password.';
                              }
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FButton(
                            onPress: busy ? null : _submit,
                            child: Text(busy ? 'Signing in...' : 'Sign in'),
                          ),
                          SocialSignInButtons(
                            authController: widget.authController,
                            onError: _showMessage,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextButton(
                            onPressed: busy ? null : () => context.go('/register'),
                            child: const Text('Create account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
