import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Email and Google sign-in.
///
/// Sign-up is offered alongside sign-in because reps are onboarded by being
/// given the app, not by an admin pre-creating credentials. A new account
/// lands as `pending` and can read nothing until an admin assigns it, so
/// self-signup is safe.
class SignInScreen extends StatefulWidget {
  final AuthService authService;

  const SignInScreen({super.key, required this.authService});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  bool _isRegistering = false;
  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  /// Runs [action] with the busy state and error handling every path needs.
  Future<void> _run(Future<void> Function() action, {String? successNotice}) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
      _notice = null;
    });

    try {
      await action();
      if (!mounted) return;
      setState(() => _notice = successNotice);
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isRegistering) {
      await _run(
        () => widget.authService.signUpWithEmail(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
        ),
        successNotice: 'Account created. Check your email to confirm it.',
      );
    } else {
      await _run(
        () => widget.authService.signInWithEmail(
          email: _email.text,
          password: _password.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              // Keeps the form readable on a desktop browser instead of
              // stretching a single column across 1600px.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Shelf Monitor',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRegistering
                          ? 'Create an account to get started'
                          : 'Sign in to record and review shelf data',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_isRegistering) ...[
                      TextFormField(
                        controller: _fullName,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter your email';
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'That does not look like an email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitEmail(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword ? 'Show' : 'Hide',
                        ),
                      ),
                      validator: (v) {
                        if ((v ?? '').isEmpty) return 'Enter your password';
                        // Supabase enforces 6 as well; saying so up front beats
                        // a round trip to be told.
                        if (_isRegistering && (v?.length ?? 0) < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      _Banner(
                        icon: Icons.error_outline,
                        text: _error!,
                        color: theme.colorScheme.error,
                      ),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 16),
                      _Banner(
                        icon: Icons.check_circle_outline,
                        text: _notice!,
                        color: theme.colorScheme.primary,
                      ),
                    ],

                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _isBusy ? null : _submitEmail,
                      child: _isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : Text(_isRegistering ? 'Create account' : 'Sign in'),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed: _isBusy
                          ? null
                          : () => _run(widget.authService.signInWithGoogle),
                      icon: const Icon(Icons.g_mobiledata, size: 26),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () => setState(() {
                              _isRegistering = !_isRegistering;
                              _error = null;
                              _notice = null;
                            }),
                      child: Text(
                        _isRegistering
                            ? 'Already have an account? Sign in'
                            : "Don't have an account? Create one",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Banner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
