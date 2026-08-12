import 'package:flutter/material.dart';

import '../models/brand_share_of_shelf.dart';
import '../models/fridge.dart';
import '../models/market_visit_summary.dart';
import '../models/point_of_sale.dart';
import '../models/user_profile.dart';
import '../services/market_service.dart';
import '../theme/layout.dart';
import '../widgets/error_state.dart';
import '../widgets/market_form_dialog.dart';

/// One market: its details, the fridges inside it, and who covers it.
///
/// The coverage section is not an optional extra. A rep's access to a market is
/// decided entirely by `rep_assignments` -- it backs the read policy on markets
/// and fridges *and* the insert policy on visits -- so a market nobody is
/// assigned to is a market nobody can record against.
class MarketDetailScreen extends StatefulWidget {
  final PointOfSale market;
  final MarketService marketService;

  /// Everyone in the company who could be assigned here.
  final List<UserProfile> reps;

  const MarketDetailScreen({
    super.key,
    required this.market,
    required this.marketService,
    required this.reps,
  });

  @override
  State<MarketDetailScreen> createState() => _MarketDetailScreenState();
}

class _MarketDetailScreenState extends State<MarketDetailScreen> {
  late PointOfSale _market = widget.market;

  List<Fridge>? _fridges;
  Set<String>? _assignedRepIds;
  List<MarketVisitSummary>? _visits;
  BrandShareOfShelf? _shareOfShelf;
  String? _error;
  bool _isBusy = false;

  /// Set when anything changed, so the list behind this screen knows to reload
  /// rather than showing a stale fridge count.
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final fridges = await widget.marketService.fridges(_market.id);
      final assigned = await widget.marketService.assignedRepIds(_market.id);
      if (!mounted) return;
      setState(() {
        _fridges = fridges;
        _assignedRepIds = assigned;
      });
    } on MarketFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }

    // Loaded separately from the block above: a rep with nothing submitted
    // yet, or a share-of-shelf query hiccup, should not blank out the fridge
    // and coverage sections that already loaded fine.
    try {
      final visits = await widget.marketService.recentVisits(_market.id);
      final share = await widget.marketService.shareOfShelf(_market.id);
      if (!mounted) return;
      setState(() {
        _visits = visits;
        _shareOfShelf = share;
      });
    } on MarketFailure {
      if (!mounted) return;
      setState(() {
        _visits = const [];
        _shareOfShelf = const BrandShareOfShelf.empty();
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isBusy = true);
    try {
      await action();
      _didChange = true;
      await _load();
      if (mounted) _say(success);
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

  Future<void> _editMarket() async {
    final details = await showDialog<MarketDetails>(
      context: context,
      builder: (_) => MarketFormDialog(existing: _market),
    );
    if (details == null) return;

    await _run(
      () => widget.marketService.updateMarket(
        id: _market.id,
        name: details.name,
        city: details.city,
        area: details.area,
        address: details.address,
      ),
      'Market saved.',
    );

    if (!mounted) return;
    // Reflect the edit locally: this screen owns the header, and reloading the
    // whole market list from here to refresh one title would be wasteful.
    setState(() {
      _market = PointOfSale(
        id: _market.id,
        companyId: _market.companyId,
        name: details.name,
        city: details.city,
        area: details.area,
        address: details.address,
        isActive: _market.isActive,
        fridgeCount: _fridges?.length,
      );
    });
  }

  Future<void> _addFridge() async {
    final details = await showDialog<FridgeDetails>(
      context: context,
      builder: (_) => const FridgeFormDialog(),
    );
    if (details == null) return;

    await _run(
      () => widget.marketService.createFridge(
        companyId: _market.companyId,
        pointOfSaleId: _market.id,
        name: details.name,
        widthCm: details.widthCm,
        heightCm: details.heightCm,
        sectionCount: details.sectionCount,
      ),
      '${details.name} added.',
    );
  }

  Future<void> _toggleAssignment(UserProfile rep, bool assigned) {
    return _run(
      () => widget.marketService.setRepAssignment(
        profileId: rep.id,
        pointOfSaleId: _market.id,
        assigned: assigned,
      ),
      assigned
          ? '${rep.displayName} now covers ${_market.name}.'
          : '${rep.displayName} no longer covers ${_market.name}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_didChange);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_market.name),
          actions: [
            IconButton(
              onPressed: _isBusy ? null : _editMarket,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit market',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: _error != null && _fridges == null
              ? ErrorState(message: _error!, onRetry: _load)
              : ContentShell(
                  maxWidth: Breakpoints.readableWidth,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: ListView(
                    children: [
                      _LocationCard(market: _market),
                      const SizedBox(height: 24),
                      _SectionHeader(
                        title: 'Fridges',
                        subtitle:
                            'What a rep photographs. Each fridge is measured '
                            'separately over time.',
                        action: FilledButton.tonalIcon(
                          onPressed: _isBusy ? null : _addFridge,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _FridgeSection(fridges: _fridges),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Share of shelf',
                        subtitle:
                            'Across every submitted capture at this market, '
                            'brand by brand.',
                      ),
                      const SizedBox(height: 8),
                      _ShareOfShelfSection(share: _shareOfShelf),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Submissions',
                        subtitle:
                            'What reps have captured and submitted here.',
                      ),
                      const SizedBox(height: 8),
                      _SubmissionsSection(visits: _visits, reps: widget.reps),
                      const SizedBox(height: 28),
                      _SectionHeader(
                        title: 'Who covers this market',
                        subtitle:
                            'A rep sees a market only when assigned to it, and '
                            'cannot record a visit anywhere else.',
                      ),
                      const SizedBox(height: 8),
                      _CoverageSection(
                        reps: widget.reps,
                        assignedIds: _assignedRepIds,
                        isBusy: _isBusy,
                        onChanged: _toggleAssignment,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final PointOfSale market;

  const _LocationCard({required this.market});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.place_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    market.locationLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (market.address != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      market.address!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FridgeSection extends StatelessWidget {
  final List<Fridge>? fridges;

  const _FridgeSection({required this.fridges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = fridges;

    if (items == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No fridges here yet. Until one is added, a rep assigned to '
                  'this market has nothing to photograph.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final fridge in items) ...[
          _FridgeTile(fridge: fridge),
          if (fridge != items.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _FridgeTile extends StatelessWidget {
  final Fridge fridge;

  const _FridgeTile({required this.fridge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final facts = <String>[
      if (fridge.sizeLabel != null) fridge.sizeLabel!,
      fridge.sections.length == 1
          ? '1 shelf'
          : '${fridge.sections.length} shelves',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.kitchen_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fridge.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    facts.join('  ·  '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // The scan code, shown so it can be printed onto a label. Kept
            // monospace-ish and selectable rather than hidden behind a menu.
            SelectableText(
              fridge.qrToken,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverageSection extends StatelessWidget {
  final List<UserProfile> reps;
  final Set<String>? assignedIds;
  final bool isBusy;
  final void Function(UserProfile rep, bool assigned) onChanged;

  const _CoverageSection({
    required this.reps,
    required this.assignedIds,
    required this.isBusy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assigned = assignedIds;

    if (assigned == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (reps.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No sales reps on the team yet. Approve someone as a sales '
            'representative and they can be assigned here.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          for (final rep in reps)
            CheckboxListTile(
              value: assigned.contains(rep.id),
              onChanged: isBusy
                  ? null
                  : (value) => onChanged(rep, value ?? false),
              title: Text(rep.displayName),
              subtitle: rep.email == null ? null : Text(rep.email!),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }
}

/// A brand-by-brand percentage breakdown of every submitted capture at this
/// market, each brand expandable into whatever finer-grained classes the
/// pipeline currently distinguishes for it.
class _ShareOfShelfSection extends StatelessWidget {
  final BrandShareOfShelf? share;

  const _ShareOfShelfSection({required this.share});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = share;

    if (data == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (data.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Nothing submitted here yet. Once a rep submits a visit, its '
            'share of shelf shows up here.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final brand in data.brands)
            ExpansionTile(
              title: Text(
                _titleCase(brand.brand),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Text(
                '${brand.percentage.round()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              children: [
                for (final variant in brand.variants)
                  ListTile(
                    dense: true,
                    title: Text(variant.className),
                    trailing: Text('${variant.percentage.round()}%'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _titleCase(String value) => value
      .replaceAll('_', ' ')
      .split('-')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Recent submitted visits at this market: who, when, and how much.
class _SubmissionsSection extends StatelessWidget {
  final List<MarketVisitSummary>? visits;
  final List<UserProfile> reps;

  const _SubmissionsSection({required this.visits, required this.reps});

  String _repName(String repId) {
    for (final rep in reps) {
      if (rep.id == repId) return rep.displayName;
    }
    return 'Unknown rep';
  }

  static String _formatDate(DateTime? utc) {
    if (utc == null) return 'Unknown date';
    final local = utc.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour24 = local.hour;
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 < 12 ? 'AM' : 'PM';
    return '${months[local.month - 1]} ${local.day}, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = visits;

    if (items == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (items.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No submissions yet. A rep assigned here who submits a visit '
            'will show up in this list.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final visit in items)
            ListTile(
              leading: CircleAvatar(
                radius: 16,
                child: Icon(Icons.person_outline, size: 18),
              ),
              title: Text(_repName(visit.repId)),
              subtitle: Text(
                '${_formatDate(visit.submittedAt)}  ·  '
                '${visit.captureCount} '
                '${visit.captureCount == 1 ? 'capture' : 'captures'}',
              ),
              trailing: Text(
                '${visit.detectionCount}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ],
    );
  }
}
