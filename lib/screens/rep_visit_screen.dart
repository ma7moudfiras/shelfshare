import 'package:flutter/material.dart';

import '../models/capture_target.dart';
import '../models/fridge.dart';
import '../models/point_of_sale.dart';
import '../services/detection_service.dart';
import '../services/visit_service.dart';
import '../theme/layout.dart';
import '../widgets/error_state.dart';
import 'capture_screen.dart';

/// One visit to one market: photograph each fridge, then submit.
///
/// The visit is opened as soon as this screen loads rather than on the first
/// photo. An in-progress visit is what the database checks before it will
/// accept a capture, and opening it up front means a rep who takes a photo the
/// moment they walk in is not waiting on a round trip at the shelf.
class RepVisitScreen extends StatefulWidget {
  final PointOfSale market;
  final String companyId;
  final VisitService visitService;
  final DetectionService? detectionService;

  const RepVisitScreen({
    super.key,
    required this.market,
    required this.companyId,
    required this.visitService,
    this.detectionService,
  });

  @override
  State<RepVisitScreen> createState() => _RepVisitScreenState();
}

class _RepVisitScreenState extends State<RepVisitScreen> {
  String? _visitId;
  List<Fridge>? _fridges;
  String? _error;
  bool _isSubmitting = false;

  /// Fridge ids photographed during this session, so the list shows progress.
  ///
  /// Deliberately session-local. It answers "have I done this one yet, right
  /// now", not "was this ever captured", and conflating the two would tell a
  /// rep they had finished a fridge they photographed last week.
  final Set<String> _capturedFridgeIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final visitId = await widget.visitService.startVisit(
        companyId: widget.companyId,
        pointOfSaleId: widget.market.id,
      );
      final fridges = await widget.visitService.fridges(widget.market.id);
      if (!mounted) return;
      setState(() {
        _visitId = visitId;
        _fridges = fridges;
      });
    } on VisitFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
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

  Future<void> _capture(Fridge fridge, FridgeSection? section) async {
    final visitId = _visitId;
    if (visitId == null) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(
          detectionService: widget.detectionService,
          visitService: widget.visitService,
          target: CaptureTarget(
            visitId: visitId,
            companyId: widget.companyId,
            fridge: fridge,
            section: section,
          ),
        ),
      ),
    );

    if ((saved ?? false) && mounted) {
      setState(() => _capturedFridgeIds.add(fridge.id));
      _say('Capture saved.');
    }
  }

  Future<void> _submit() async {
    final visitId = _visitId;
    if (visitId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit this visit?'),
        content: Text(
          _capturedFridgeIds.isEmpty
              ? 'You have not saved any captures yet. Submitting now records a '
                    'visit with nothing in it.'
              : 'Once submitted you can no longer add captures to this visit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.visitService.submitVisit(visitId);
      if (!mounted) return;
      Navigator.of(context).pop();
      _say('Visit at ${widget.market.name} submitted.');
    } on VisitFailure catch (e) {
      if (mounted) _say(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.market.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.market.locationLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
      bottomNavigationBar: _fridges == null || _fridges!.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ContentShell(
                  maxWidth: Breakpoints.readableWidth,
                  shrinkWrapHeight: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all, size: 18),
                      label: Text(
                        _capturedFridgeIds.isEmpty
                            ? 'Submit visit'
                            : 'Submit visit · ${_capturedFridgeIds.length} done',
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _fridges == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final fridges = _fridges;
    if (fridges == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }

    if (fridges.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        children: [
          Icon(
            Icons.kitchen_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No fridges recorded here',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your administrator to add the fridges in this market before '
            'you record a visit.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      );
    }

    return ContentShell(
      maxWidth: Breakpoints.readableWidth,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: ListView.separated(
        itemCount: fridges.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _FridgeCard(
          fridge: fridges[i],
          isDone: _capturedFridgeIds.contains(fridges[i].id),
          onCapture: (section) => _capture(fridges[i], section),
        ),
      ),
    );
  }
}

/// One fridge, with a shutter per shelf when it has more than one.
class _FridgeCard extends StatelessWidget {
  final Fridge fridge;
  final bool isDone;
  final ValueChanged<FridgeSection?> onCapture;

  const _FridgeCard({
    required this.fridge,
    required this.isDone,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : Icons.kitchen_outlined,
                  size: 20,
                  color: isDone ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fridge.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (fridge.sizeLabel != null)
                  Text(
                    fridge.sizeLabel!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // A single-section fridge shows no section UI at all: asking
            // someone to pick "Shelf 1 of 1" teaches them to tap without
            // reading, which is exactly the habit that produces bad data.
            if (!fridge.hasMultipleSections)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => onCapture(null),
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Photograph'),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final section in fridge.sections)
                    FilledButton.tonalIcon(
                      onPressed: () => onCapture(section),
                      icon: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: Text(section.label),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
