import 'package:flutter/material.dart';

import '../models/capture_aspect_ratio.dart';

/// Framing selector shown over the viewfinder.
///
/// Sits on the camera rather than behind a menu: framing is decided while
/// looking through the lens, and a control you have to leave the viewfinder to
/// reach is one nobody uses.
class AspectRatioSelector extends StatelessWidget {
  final CaptureAspectRatio selected;
  final ValueChanged<CaptureAspectRatio> onSelected;

  const AspectRatioSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        // Translucent so the scene stays visible behind the control.
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in CaptureAspectRatio.values)
            _RatioChip(
              option: option,
              isSelected: option == selected,
              onTap: () => onSelected(option),
            ),
        ],
      ),
    );
  }
}

class _RatioChip extends StatelessWidget {
  final CaptureAspectRatio option;
  final bool isSelected;
  final VoidCallback onTap;

  const _RatioChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Frame ${option.label}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            option.label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
