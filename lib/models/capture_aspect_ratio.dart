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

  /// Classic photo framing, portrait-oriented for tall shelf bays.
  fourThree(label: '4:3', ratio: 3 / 4),

  /// Wide, for capturing a long run of shelving in one shot.
  sixteenNine(label: '16:9', ratio: 9 / 16);

  const CaptureAspectRatio({required this.label, required this.ratio});

  /// Short label shown on the selector chip.
  final String label;

  /// Width divided by height, or null to leave the frame uncropped.
  ///
  /// Values are expressed portrait-first because the capture screen is
  /// portrait: `4:3` here means 3 wide by 4 tall.
  final double? ratio;

  bool get cropsFrame => ratio != null;

  /// Ratio to use for layout, falling back to [fallback] for [full].
  double effectiveRatio(double fallback) => ratio ?? fallback;
}
