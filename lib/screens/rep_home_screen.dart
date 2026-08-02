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

/// Where a sales rep starts: which market are you standing in?
///
/// This screen used to not exist -- reps were dropped straight onto the camera.
/// That made the shutter one tap away, which sounds right until you notice the
/// photo had nowhere to go: no market, no fridge, no visit, so nothing could be
/// stored and no dashboard could ever be built on it. Choosing the market first
/// is what turns a photo into a measurement.
class RepHomeScreen extends StatefulWidget {
  final UserProfile profile;
  final AuthService authService;
  final VisitService visitService;
  final DetectionService? detectionService;

  const RepHomeScreen({
    super.key,
    required this.profile,
    required this.authService,
    required this.visitService,
    this.detectionService,
  });

  @override
  State<RepHomeScreen> createState() => _RepHomeScreenState();
}

class _RepHomeScreenState extends State<RepHomeScreen> {
  List<PointOfSale>? _markets;
  String? _error;

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
    final companyId = widget.profile.companyId;
    if (companyId == null) return;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelf Monitor'),
        actions: [
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
                'Where are you today?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    // An empty list here almost always means nobody has assigned this rep to a
    // market yet, so say that rather than leaving a blank screen that reads as
    // a broken app.
    if (_markets != null && _markets!.isEmpty) {
      return const ContentShell(
        maxWidth: Breakpoints.readableWidth,
        child: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'No markets assigned to you',
          message:
              'Your administrator decides which markets you cover. Ask them to '
              'assign you, then pull down to refresh.',
        ),
      );
    }

    return MarketList(markets: _markets, onOpen: _openMarket);
  }
}
