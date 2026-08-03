import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Sign in with email or Google.
///
/// There is deliberately no registration form: accounts are granted by an
/// administrator, never self-created. Signing in with Google is still allowed
/// for anyone, but a new account lands with no company and no access until an
/// admin assigns it -- authentication is not authorisation.
///
/// Note the enforcement is in the database, not here. Hiding a button would
/// not stop anyone calling the signup endpoint directly; the profiles trigger
/// is what guarantees a new account is powerless.
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

  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Runs [action] with the busy state and error handling every path needs.
  Future<void> _run(
    Future<void> Function() action, {
    String? successNotice,
  }) async {
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
    await _run(
      () => widget.authService.signInWithEmail(
        email: _email.text,
        password: _password.text,
      ),
    );

    // Tells the platform the credentials were accepted, which is what makes
    // Safari and iOS offer to remember them. Without it nothing is ever
    // saved, so every sign-in is another round of typing into fields that are
    // awkward to type into. Only on success: offering to save a password that
    // was just rejected would be worse than not offering at all.
    if (mounted && _error == null) TextInput.finishAutofillContext();
  }

  /// Also the first-time path for an account an admin created: the person sets
  /// their own password from the emailed link, so no one has to hand a
  /// credential over.
  Future<void> _resetPassword() async {
    if ((_email.text).trim().isEmpty) {
      setState(() => _error = 'Enter your email first, then tap this again.');
      return;
    }
    await _run(
      () => widget.authService.sendPasswordReset(_email.text),
      successNotice:
          'If that account exists, a link to set a password is on its way.',
    );
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
              // Without an AutofillGroup the hints on the fields below do
              // nothing: iOS and Safari only offer to fill a set of fields
              // they have been told belong together. That matters more here
              // than it looks -- Flutter draws text fields on a canvas with a
              // hidden input behind them, so Safari's own paste and selection
              // menus are unreliable inside them. AutoFill is the one route
              // into these fields that does not depend on that working.
              child: AutofillGroup(
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
                        'Sign in to record and review shelf data',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),

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
                        validator: (v) =>
                            (v ?? '').isEmpty ? 'Enter your password' : null,
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isBusy ? null : _resetPassword,
                          child: const Text('Set or reset password'),
                        ),
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
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Accounts are created by your administrator. If you '
                        'cannot sign in, ask them to add you.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
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
