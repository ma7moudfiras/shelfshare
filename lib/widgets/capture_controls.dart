import 'package:flutter/material.dart';

/// The control strip between the viewfinder and the results panel.
///
/// Swaps between "take a photo" and "retake" depending on whether a capture is
/// currently held, so the primary action is always the obvious one.
class CaptureControls extends StatelessWidget {
  /// Whether the shutter can fire right now.
  final bool canCapture;

  /// Whether a photo is currently held on screen.
  final bool hasCapture;

  /// Whether analysis is in flight; disables the actions while true.
  final bool isBusy;

  final VoidCallback onCapture;
  final VoidCallback onPickFromGallery;
  final VoidCallback onRetake;

  const CaptureControls({
    super.key,
    required this.canCapture,
    required this.hasCapture,
    required this.isBusy,
    required this.onCapture,
    required this.onPickFromGallery,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: isBusy ? null : onPickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Choose from gallery',
          ),
          const SizedBox(width: 20),
          if (hasCapture)
            FilledButton.icon(
              onPressed: isBusy ? null : onRetake,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Retake'),
            )
          else
            _ShutterButton(onPressed: canCapture ? onCapture : null),
          const SizedBox(width: 20),
          // Balances the gallery button so the shutter stays centred.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Round shutter control, styled to read as the screen's primary action.
class _ShutterButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _ShutterButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      label: 'Capture shelf photo',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: enabled ? theme.colorScheme.primary : theme.disabledColor,
              width: 3,
            ),
          ),
          child: Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
