import 'package:flutter/material.dart';

import '../models/company_option.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Asks a newly signed-in user which company they work for.
///
/// Choosing does not grant anything. It routes the request to that company's
/// administrator instead of leaving every new person in one global queue that
/// only Aystro could clear -- which is what makes onboarding scale as
/// customers are added.
class CompanyRequestScreen extends StatefulWidget {
  final UserProfile profile;
  final AuthService authService;

  const CompanyRequestScreen({
    super.key,
    required this.profile,
    required this.authService,
  });

  @override
  State<CompanyRequestScreen> createState() => _CompanyRequestScreenState();
}

class _CompanyRequestScreenState extends State<CompanyRequestScreen> {
  List<CompanyOption>? _companies;
  String? _selectedId;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companies = await widget.authService.availableCompanies();
    if (!mounted) return;
    setState(() => _companies = companies);
  }

  Future<void> _submit() async {
    final id = _selectedId;
    if (id == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await widget.authService.requestAccess(id);
      // No navigation here: the profile stream now reports a pending user with
      // a request, and the gate moves to the waiting screen on its own.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companies = _companies;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(
                    Icons.apartment_outlined,
                    size: 42,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Which company do you work for?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your request goes to that company\'s administrator, who '
                    'will approve it and set what you can do.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 26),

                  if (companies == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    )
                  else if (companies.isEmpty)
                    Text(
                      'No companies are set up yet. Ask your administrator to '
                      'add one before you request access.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Flexible(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: companies.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final company = companies[i];
                            final selected = company.id == _selectedId;
                            return Material(
                              color: selected
                                  ? theme.colorScheme.primary.withValues(
                                      alpha: 0.14,
                                    )
                                  : theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                              child: ListTile(
                                title: Text(
                                  company.name,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : null,
                                  ),
                                ),
                                trailing: Icon(
                                  selected
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 21,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                ),
                                onTap: () =>
                                    setState(() => _selectedId = company.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _selectedId == null || _isSubmitting
                        ? null
                        : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Text('Request access'),
                  ),
                  TextButton.icon(
                    onPressed: widget.authService.signOut,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign out'),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
