import 'package:flutter/material.dart';

import '../models/company_option.dart';
import '../models/user_profile.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../widgets/access_request_list.dart';
import '../widgets/company_list.dart';
import '../widgets/team_list.dart';
import 'capture_screen.dart';

/// Home for both administrator roles.
///
/// One screen rather than two, because a platform admin and a company admin do
/// the same things to the same objects -- the difference is only how much they
/// can see, and Row Level Security already decides that. Duplicating the screen
/// would mean duplicating every future change to it.
///
/// The one genuine difference is that companies are a platform admin's to
/// create, so that tab is theirs alone.
class AdminDashboardScreen extends StatefulWidget {
  final UserProfile profile;
  final AuthService authService;
  final AdminService adminService;
  final DetectionService? detectionService;

  const AdminDashboardScreen({
    super.key,
    required this.profile,
    required this.authService,
    required this.adminService,
    this.detectionService,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  List<UserProfile>? _requests;
  List<UserProfile>? _members;
  List<CompanyOption>? _companies;
  String? _error;
  bool _isBusy = false;

  bool get _isPlatformAdmin => widget.profile.role == UserRole.platformAdmin;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final requests = await widget.adminService.pendingRequests();
      final members = await widget.adminService.members();
      final companies = _isPlatformAdmin
          ? await widget.adminService.companies()
          : const <CompanyOption>[];
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _members = members;
        _companies = companies;
      });
    } on AdminFailure catch (e) {
      if (!mounted) return;
      // The lists are deliberately left as they are. On a first load they are
      // still null, so the whole screen becomes an error with a retry. On a
      // later refresh they still hold the last good data, and replacing that
      // with an error page would throw away something usable to report a
      // problem the user can see for themselves in the snackbar.
      final hadData = _requests != null;
      setState(() => _error = e.message);
      if (hadData) _say(e.message, isError: true);
    }
  }

  /// Runs an action, then reloads so the lists reflect what actually happened
  /// rather than what the UI assumed would happen.
  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isBusy = true);
    try {
      await action();
      await _load();
      if (mounted) _say(success);
    } on AdminFailure catch (e) {
      if (mounted) _say(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _say(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  Future<void> _addCompany() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCompanyDialog(),
    );
    if (name == null || name.isEmpty) return;
    await _run(
      () => widget.adminService.createCompany(name),
      '$name added.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _requests?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Monitor'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    CaptureScreen(detectionService: widget.detectionService),
              ),
            ),
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: 'Open capture',
          ),
          IconButton(
            onPressed: widget.authService.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  widget.profile.role.label,
                  if (widget.profile.companyName != null)
                    widget.profile.companyName!,
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _isPlatformAdmin && _tab == 2
          ? FloatingActionButton.extended(
              onPressed: _isBusy ? null : _addCompany,
              icon: const Icon(Icons.add),
              label: const Text('Add company'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              // Requests are the only thing here that goes stale if ignored:
              // somebody is waiting on the other end of each one.
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.how_to_reg_outlined),
            ),
            selectedIcon: const Icon(Icons.how_to_reg),
            label: 'Requests',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Team',
          ),
          if (_isPlatformAdmin)
            const NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment),
              label: 'Companies',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildTab(),
      ),
    );
  }

  Widget _buildTab() {
    if (_error != null && _requests == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }

    return switch (_tab) {
      0 => AccessRequestList(
        requests: _requests,
        isBusy: _isBusy,
        showCompany: _isPlatformAdmin,
        onApprove: (user, role) => _run(
          () => widget.adminService.approve(user.id, role),
          '${user.displayName} approved as ${role.label.toLowerCase()}.',
        ),
        onDecline: (user) => _run(
          () => widget.adminService.decline(user.id),
          'Request from ${user.displayName} declined.',
        ),
      ),
      1 => TeamList(
        members: _members,
        isBusy: _isBusy,
        showCompany: _isPlatformAdmin,
        currentUserId: widget.profile.id,
        onSetActive: (user, active) => _run(
          () => widget.adminService.setActive(user.id, active),
          active
              ? '${user.displayName} reactivated.'
              : '${user.displayName} deactivated.',
        ),
      ),
      _ => CompanyList(companies: _companies, members: _members),
    };
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCompanyDialog extends StatefulWidget {
  const _AddCompanyDialog();

  @override
  State<_AddCompanyDialog> createState() => _AddCompanyDialogState();
}

class _AddCompanyDialogState extends State<_AddCompanyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add company'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Company name',
          hintText: 'UniPal',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty ? null : _submit,
            child: const Text('Add'),
          ),
        ),
      ],
    );
  }
}
