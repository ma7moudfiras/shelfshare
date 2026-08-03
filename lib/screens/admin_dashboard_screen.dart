import 'package:flutter/material.dart';

import '../models/company_option.dart';
import '../models/point_of_sale.dart';
import '../models/user_profile.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../services/market_service.dart';
import '../services/visit_service.dart';
import '../theme/layout.dart';
import '../widgets/access_request_list.dart';
import '../widgets/adaptive_scaffold.dart';
import '../widgets/company_list.dart';
import '../widgets/error_state.dart';
import '../widgets/market_form_dialog.dart';
import '../widgets/market_list.dart';
import '../widgets/team_list.dart';
import 'market_detail_screen.dart';
import 'visit_start_screen.dart';

/// What an administrator manages, in the order they need it.
enum _Tab {
  requests,
  team,
  markets,

  /// Platform admins only: companies are Aystro's to create.
  companies,
}

/// Home for both administrator roles.
///
/// One screen rather than two, because a platform admin and a company admin do
/// the same things to the same objects -- the difference is only how much they
/// can see, and Row Level Security already decides that. Duplicating the screen
/// would mean duplicating every future change to it.
class AdminDashboardScreen extends StatefulWidget {
  final UserProfile profile;
  final AuthService authService;
  final AdminService adminService;
  final MarketService marketService;
  final VisitService visitService;
  final DetectionService? detectionService;

  const AdminDashboardScreen({
    super.key,
    required this.profile,
    required this.authService,
    required this.adminService,
    required this.marketService,
    required this.visitService,
    this.detectionService,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tabIndex = 0;

  List<UserProfile>? _requests;
  List<UserProfile>? _members;
  List<CompanyOption>? _companies;
  List<PointOfSale>? _markets;
  String? _error;
  bool _isBusy = false;

  bool get _isPlatformAdmin => widget.profile.role == UserRole.platformAdmin;

  List<_Tab> get _tabs => [
    _Tab.requests,
    _Tab.team,
    _Tab.markets,
    if (_isPlatformAdmin) _Tab.companies,
  ];

  _Tab get _tab => _tabs[_tabIndex.clamp(0, _tabs.length - 1)];

  /// Team members who can be assigned to a market.
  List<UserProfile> get _reps => [
    for (final member in _members ?? const <UserProfile>[])
      if (member.role == UserRole.salesRep) member,
  ];

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
      final markets = await widget.marketService.markets();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _members = members;
        _companies = companies;
        _markets = markets;
      });
    } on AdminFailure catch (e) {
      _reportLoadFailure(e.message);
    } on MarketFailure catch (e) {
      _reportLoadFailure(e.message);
    }
  }

  /// The lists are deliberately left as they are.
  ///
  /// On a first load they are still null, so the whole screen becomes an error
  /// with a retry. On a later refresh they still hold the last good data, and
  /// replacing that with an error page would throw away something usable to
  /// report a problem the user can already see in the snackbar.
  void _reportLoadFailure(String message) {
    if (!mounted) return;
    final hadData = _requests != null;
    setState(() => _error = message);
    if (hadData) _say(message, isError: true);
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
    } on MarketFailure catch (e) {
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
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  Future<void> _addCompany() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddCompanyDialog(),
    );
    if (name == null || name.isEmpty) return;
    await _run(() => widget.adminService.createCompany(name), '$name added.');
  }

  Future<void> _addMarket() async {
    final companyId = await _companyForNewMarket();
    if (companyId == null || !mounted) return;

    final details = await showDialog<MarketDetails>(
      context: context,
      builder: (_) => const MarketFormDialog(),
    );
    if (details == null) return;

    await _run(
      () => widget.marketService.createMarket(
        companyId: companyId,
        name: details.name,
        city: details.city,
        area: details.area,
        address: details.address,
      ),
      '${details.name} added.',
    );
  }

  /// Which company a new market belongs to.
  ///
  /// A company admin has exactly one and is never asked. A platform admin is
  /// not scoped to any, so the question has to be put to them -- guessing would
  /// file a market under the wrong tenant, which RLS then makes invisible to
  /// the people who need it.
  Future<String?> _companyForNewMarket() async {
    final own = widget.profile.companyId;
    if (own != null) return own;

    final companies = _companies ?? const <CompanyOption>[];
    if (companies.isEmpty) {
      _say(
        'Add a company first — a market has to belong to one.',
        isError: true,
      );
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Which company?'),
        children: [
          for (final company in companies)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(company.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(company.name),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openMarket(PointOfSale market) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MarketDetailScreen(
          market: market,
          marketService: widget.marketService,
          reps: _reps,
        ),
      ),
    );
    // Fridge counts and assignments are shown on the card behind, so a change
    // in there has to be reflected out here.
    if ((changed ?? false) && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: 'Shelf Monitor',
      subtitle: [
        widget.profile.role.label,
        if (widget.profile.companyName != null) widget.profile.companyName!,
      ].join(' · '),
      selectedIndex: _tabIndex,
      onDestinationSelected: (i) => setState(() => _tabIndex = i),
      destinations: [
        for (final tab in _tabs)
          switch (tab) {
            _Tab.requests => AdaptiveDestination(
              icon: Icons.how_to_reg_outlined,
              selectedIcon: Icons.how_to_reg,
              label: 'Requests',
              // Requests are the only thing here that goes stale if ignored:
              // somebody is waiting on the other end of each one.
              badgeCount: _requests?.length ?? 0,
            ),
            _Tab.team => const AdaptiveDestination(
              icon: Icons.people_outline,
              selectedIcon: Icons.people,
              label: 'Team',
            ),
            _Tab.markets => const AdaptiveDestination(
              icon: Icons.storefront_outlined,
              selectedIcon: Icons.storefront,
              label: 'Markets',
            ),
            _Tab.companies => const AdaptiveDestination(
              icon: Icons.apartment_outlined,
              selectedIcon: Icons.apartment,
              label: 'Companies',
            ),
          },
      ],
      actions: [
        // Goes through a market rather than straight to the camera. An
        // admin who photographed a shelf from here used to get a number and
        // no way to submit it -- the capture had no fridge to belong to, so
        // there was nothing to save it into.
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VisitStartScreen(
                profile: widget.profile,
                visitService: widget.visitService,
                detectionService: widget.detectionService,
              ),
            ),
          ),
          icon: const Icon(Icons.photo_camera_outlined),
          tooltip: 'Record a visit',
        ),
        IconButton(
          onPressed: widget.authService.signOut,
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
        ),
      ],
      floatingActionButton: switch (_tab) {
        _Tab.markets => FloatingActionButton.extended(
          onPressed: _isBusy ? null : _addMarket,
          icon: const Icon(Icons.add),
          label: const Text('Add market'),
        ),
        _Tab.companies => FloatingActionButton.extended(
          onPressed: _isBusy ? null : _addCompany,
          icon: const Icon(Icons.add),
          label: const Text('Add company'),
        ),
        _ => null,
      },
      body: RefreshIndicator(onRefresh: _load, child: _buildTab()),
    );
  }

  Widget _buildTab() {
    if (_error != null && _requests == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    return switch (_tab) {
      _Tab.requests => ContentShell(
        maxWidth: Breakpoints.readableWidth,
        child: AccessRequestList(
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
      ),
      _Tab.team => ContentShell(
        maxWidth: Breakpoints.readableWidth,
        child: TeamList(
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
      ),
      _Tab.markets => MarketList(markets: _markets, onOpen: _openMarket),
      _Tab.companies => ContentShell(
        maxWidth: Breakpoints.readableWidth,
        child: CompanyList(companies: _companies, members: _members),
      ),
    };
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
