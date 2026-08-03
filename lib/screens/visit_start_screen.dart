import 'package:flutter/material.dart';

import '../models/point_of_sale.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/detection_service.dart';
import '../services/visit_service.dart';
import '../theme/layout.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/market_list.dart';
import 'rep_visit_screen.dart';

/// Where recording a shelf begins: which market are you standing in?
///
/// Used by both roles, which is why it is not named after one. Reps get it as
/// their home; an administrator reaches it from the dashboard. The database
/// backs that up -- `visits_admin_manage` and `captures_admin_manage` grant a
/// company admin full write on their own company's rows, so an admin recording
/// a visit is a case the schema already allows and the client was the only
/// thing refusing.
///
/// It exists at all because a photo with no market, fridge and visit attached
/// cannot be stored. Reps used to land straight on the camera: one tap from the
/// shutter, and nowhere to put the result.
class VisitStartScreen extends StatefulWidget {
  final UserProfile profile;
  final VisitService visitService;
  final DetectionService? detectionService;

  /// Offered only at the root. Pushed onto a dashboard the app bar carries a
  /// back arrow instead, and signing out from a pushed route is a trap.
  final AuthService? authService;

  const VisitStartScreen({
    super.key,
    required this.profile,
    required this.visitService,
    this.detectionService,
    this.authService,
  });

  @override
  State<VisitStartScreen> createState() => _VisitStartScreenState();
}

class _VisitStartScreenState extends State<VisitStartScreen> {
  List<PointOfSale>? _markets;
  String? _error;

  bool get _isRep => widget.profile.role == UserRole.salesRep;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final markets = await widget.visitService.assignedMarkets();
      if (!mounted) return;
      setState(() => _markets = markets);
    } on VisitFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _openMarket(PointOfSale market) async {
    // A platform admin has no company of their own, so the market's company is
    // the only correct answer -- and it is the one the row will be written
    // against either way.
    final companyId = widget.profile.companyId ?? market.companyId;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepVisitScreen(
          market: market,
          companyId: companyId,
          visitService: widget.visitService,
          detectionService: widget.detectionService,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = widget.authService;

    return Scaffold(
      appBar: AppBar(
        title: Text(auth != null ? 'Shelf Monitor' : 'Record a visit'),
        actions: [
          if (auth != null)
            IconButton(
              onPressed: auth.signOut,
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
                'Where are you today?',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null && _markets == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    if (_markets != null && _markets!.isEmpty) {
      return ContentShell(
        maxWidth: Breakpoints.readableWidth,
        // The two roles reach an empty list for different reasons. Telling a
        // rep to add a market they have no permission to add would send them
        // somewhere they cannot act.
        child: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'No markets to visit yet',
          message: _isRep
              ? 'Your administrator decides which markets you cover. Ask them '
                    'to assign you, then pull down to refresh.'
              : 'Add a market with at least one fridge under Markets, then '
                    'come back here to record a visit.',
        ),
      );
    }

    return MarketList(markets: _markets, onOpen: _openMarket);
  }
}
