import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/capture_draft.dart';
import '../theme/layout.dart';
import '../widgets/detection_overlay.dart' show DetectionPalette;
import '../widgets/editable_detection_overlay.dart';
import '../widgets/share_of_shelf_panel.dart';

/// Check the count, fix it, then save.
///
/// The model is not always right and the person holding the phone is standing
/// in front of the shelf: they can see the bottle it missed and the reflection
/// it counted twice. A number they know to be wrong is a number they stop
/// trusting, and a rep who stops trusting the number stops using the app.
///
/// Nothing here destroys the original. Rejecting a box flags it, adding one
/// appends an entry marked as manual, and both are written alongside the raw
/// prediction -- which is what stops an editable number from being a gameable
/// one, and turns every correction into a training label.
class CaptureReviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final CaptureDraft initialDraft;

  /// Where this capture is being recorded, e.g. "Entrance cooler · Shelf 2".
  final String targetLabel;

  /// Every class the model knows, so a product can be added even when none was
  /// detected in this photo.
  final List<String> availableClasses;

  /// Writes the corrected capture. Completes when it is stored.
  ///
  /// Returning a future rather than firing and forgetting is what lets this
  /// screen hold the rep on it until the write lands. Popping straight back to
  /// the fridge list on tap would show a success the database has not agreed to
  /// yet, and a rep in a shop with poor signal would walk away from a visit
  /// that never saved.
  final Future<void> Function(CaptureDraft draft) onSave;

  const CaptureReviewScreen({
    super.key,
    required this.imageBytes,
    required this.initialDraft,
    required this.targetLabel,
    required this.availableClasses,
    required this.onSave,
  });

  @override
  State<CaptureReviewScreen> createState() => _CaptureReviewScreenState();
}

class _CaptureReviewScreenState extends State<CaptureReviewScreen> {
  late CaptureDraft _draft = widget.initialDraft;
  bool _isSaving = false;

  void _update(CaptureDraft next) => setState(() => _draft = next);

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await widget.onSave(_draft);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Classes offered in the "add a product" sheet.
  ///
  /// The project's full list where available, so a product can be recorded even
  /// when the model found none of it -- which is the case that matters most,
  /// because a competitor's shelf takeover looks exactly like a detection
  /// failure until someone says otherwise.
  List<String> get _addableClasses {
    final classes = {...widget.availableClasses, ..._draft.knownClasses};
    return classes.toList()..sort();
  }

  Future<void> _addProduct() async {
    final classes = _addableClasses;
    if (classes.isEmpty) return;

    final chosen = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => _ProductPickerSheet(classes: classes),
    );
    if (chosen != null) _update(_draft.addManual(chosen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = context.layoutSize.isWide;

    final photo = ColoredBox(
      color: Colors.black,
      child: EditableDetectionOverlay(
        imageBytes: widget.imageBytes,
        draft: _draft,
        onToggle: (index) => _update(_draft.toggleRemoved(index)),
      ),
    );

    final panel = _EditorPanel(
      draft: _draft,
      onAdd: (className) => _update(_draft.addManual(className)),
      onRemove: (className) => _update(_draft.removeOneOf(className)),
      onAddProduct: _addableClasses.isEmpty ? null : _addProduct,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check the count'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.targetLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      // On a laptop the photo and the numbers sit side by side, so a correction
      // and its effect on Share of Shelf are visible at the same time. On a
      // phone they stack, photo first.
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 3, child: photo),
                const VerticalDivider(width: 1),
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: panel,
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 4, child: photo),
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: panel,
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _SaveBar(
        draft: _draft,
        isSaving: _isSaving,
        onSave: _save,
      ),
    );
  }
}

/// Per-class counts with the controls to correct them.
class _EditorPanel extends StatelessWidget {
  final CaptureDraft draft;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final VoidCallback? onAddProduct;

  const _EditorPanel({
    required this.draft,
    required this.onAdd,
    required this.onRemove,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = draft.countsByClass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShareOfShelfPanel(shareOfShelf: draft.corrected.shareOfShelf),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Facings',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onAddProduct != null)
              TextButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add product'),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Tap a box on the photo to reject it, or use − and + here.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),

        if (counts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nothing counted in this photo. Add a product if there is stock '
              'on the shelf the model did not pick up.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          )
        else
          for (final row in counts)
            _ClassRow(
              className: row.className,
              count: row.count,
              onAdd: () => onAdd(row.className),
              onRemove: () => onRemove(row.className),
            ),

        if (draft.isEdited) ...[
          const SizedBox(height: 16),
          _EditSummary(draft: draft),
        ],
      ],
    );
  }
}

class _ClassRow extends StatelessWidget {
  final String className;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ClassRow({
    required this.className,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: DetectionPalette.forClass(className),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              className,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            key: ValueKey('remove-$className'),
            onPressed: count > 0 ? onRemove : null,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'One fewer $className',
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            key: ValueKey('add-$className'),
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'One more $className',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// States what was changed, so the rep can see it before committing.
class _EditSummary extends StatelessWidget {
  final CaptureDraft draft;

  const _EditSummary({required this.draft});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final parts = <String>[
      if (draft.removedCount > 0) '${draft.removedCount} rejected',
      if (draft.addedCount > 0) '${draft.addedCount} added by hand',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${parts.join(' · ')}. The model\'s original answer is kept too.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final CaptureDraft draft;
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveBar({
    required this.draft,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: ContentShell(
          maxWidth: Breakpoints.readableWidth,
          shrinkWrapHeight: true,
          // Stacked rather than side by side. A count and a labelled button on
          // one row overflows a narrow phone once the count reaches two digits,
          // and the button is the thing that must never be pushed off screen.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                draft.keptCount == 1
                    ? '1 facing will be recorded'
                    : '${draft.keptCount} facings will be recorded',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(isSaving ? 'Saving…' : 'Save capture'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pick a product to add.
class _ProductPickerSheet extends StatefulWidget {
  final List<String> classes;

  const _ProductPickerSheet({required this.classes});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = [
      for (final className in widget.classes)
        if (className.toLowerCase().contains(_query.toLowerCase())) className,
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                labelText: 'Which product?',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: matches.length,
              itemBuilder: (context, i) => ListTile(
                leading: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: DetectionPalette.forClass(matches[i]),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(matches[i]),
                onTap: () => Navigator.of(context).pop(matches[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
