/// Framing options offered in the viewfinder.
///
/// The selected ratio is a genuine crop, not just a guide: the captured image
/// is cut to it before being sent for inference. A guide that changed only the
/// preview would be actively misleading, since detections would come back for
/// parts of the shelf the operator thought they had excluded.
enum CaptureAspectRatio {
  /// Whatever the sensor produces. No cropping.
  full(label: 'Full', ratio: null),

  /// Square. Useful for a single shelf section.
  square(label: '1:1', ratio: 1.0),

  /// Classic photo framing, kept portrait for tall shelf bays and fridges.
  fourThree(label: '4:3', ratio: 3 / 4),

  /// Wide, for capturing a long run of shelving in one shot.
  sixteenNine(label: '16:9', ratio: 16 / 9);

  const CaptureAspectRatio({required this.label, required this.ratio});

  /// Short label shown on the selector chip.
  final String label;

  /// Width divided by height, or null to leave the frame uncropped.
  ///
  /// Orientation follows what the shelf looks like, not one blanket rule.
  /// `4:3` is 3 wide by 4 tall, because the things it frames -- a fridge, a
  /// single bay -- are taller than they are wide. `16:9` is 16 wide by 9 tall,
  /// because it exists for a long horizontal run of shelving. It was
  /// previously 9 by 16, which contradicted its own purpose: the widest
  /// option produced the narrowest crop.
  final double? ratio;

  bool get cropsFrame => ratio != null;

  /// Ratio to use for layout, falling back to [fallback] for [full].
  double effectiveRatio(double fallback) => ratio ?? fallback;
}
