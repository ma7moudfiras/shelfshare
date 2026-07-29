import 'package:flutter/material.dart';

import '../models/detection_result.dart';
import 'share_of_shelf_panel.dart';

/// The lower half of the capture screen: whatever we currently know about the
/// most recent capture.
///
/// Renders one of four states -- idle placeholder, in-flight, failed, or a
/// finished [DetectionResult] -- so the screen itself stays free of layout
/// branching.
class ResultsPanel extends StatelessWidget {
  /// Finished detection result, when there is one.
  final DetectionResult? result;

  /// True while inference is in flight.
  final bool isLoading;

  /// Message from the last failure, if the last attempt failed.
  final String? errorMessage;

  /// Invoked when the user taps Retry on the error state.
  final VoidCallback? onRetry;

  /// Model that produced [result], e.g. `aystro-project/11`.
  final String? modelId;

  /// Confidence threshold the result was produced at, 0.0 - 1.0.
  final double? confidence;

  /// Scroll controller supplied by an enclosing draggable sheet, so dragging
  /// the content also drags the sheet.
  final ScrollController? scrollController;

  const ResultsPanel({
    super.key,
    this.result,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.modelId,
    this.confidence,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading) return const _AnalyzingState();
    if (errorMessage != null) {
      return _ErrorState(message: errorMessage!, onRetry: onRetry);
    }

    final result = this.result;
    if (result == null) return const _IdleState();
    if (result.isEmpty) return const _NoDetectionsState();

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShareOfShelfPanel(shareOfShelf: result.shareOfShelf),
          const SizedBox(height: 14),
          _RunCaption(
            modelId: modelId,
            confidence: confidence,
            detectionCount: result.count,
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown before the first capture.
class _IdleState extends StatelessWidget {
  const _IdleState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.insights_outlined,
      title: 'No analysis yet',
      subtitle: 'Capture a shelf photo to see detected products and their '
          'Share of Shelf breakdown.',
    );
  }
}

/// Shown while the inference request is in flight.
class _AnalyzingState extends StatelessWidget {
  const _AnalyzingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text('Analyzing shelf…', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Shown when the workflow ran but found nothing.
class _NoDetectionsState extends StatelessWidget {
  const _NoDetectionsState();

  @override
  Widget build(BuildContext context) {
    return const _CenteredMessage(
      icon: Icons.search_off_outlined,
      title: 'No products detected',
      subtitle: 'Try moving closer to the shelf or improving the lighting.',
    );
  }
}

/// Shown when detection failed, with an optional retry affordance.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 34,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// States what produced the numbers above.
///
/// Makes the model and threshold visible, which is the difference between
/// "the app is broken" and "this threshold hid the weaker detections".
class _RunCaption extends StatelessWidget {
  final String? modelId;
  final double? confidence;
  final int detectionCount;

  const _RunCaption({
    this.modelId,
    this.confidence,
    required this.detectionCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final parts = <String>[
      ?modelId,
      if (confidence != null) '≥${(confidence! * 100).round()}% confidence',
      '$detectionCount detected',
    ];

    return Text(
      parts.join('  ·  '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Shared icon + title + subtitle layout used by the empty states.
class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
