import 'fridge.dart';

/// Where a capture is being recorded.
///
/// A photo with no subject is not data. Before this existed the camera produced
/// a number and dropped it: nothing said which fridge, which shelf, which
/// visit, so nothing downstream could plot it. Carrying the target with the
/// capture is what makes the difference between a demo and a measurement.
class CaptureTarget {
  /// The open visit this capture belongs to.
  final String visitId;
  final String companyId;

  final Fridge fridge;

  /// Null when the fridge has a single section, which needs no choosing.
  final FridgeSection? section;

  const CaptureTarget({
    required this.visitId,
    required this.companyId,
    required this.fridge,
    this.section,
  });

  /// Id to store on the capture row.
  ///
  /// Falls back to the fridge's only section, so a single-section fridge still
  /// records *which* section it was -- the column is what coverage reporting
  /// counts, and leaving it null would make those visits look incomplete.
  String? get sectionId =>
      section?.id ??
      (fridge.sections.length == 1 ? fridge.sections.first.id : null);

  /// Human-readable subject, e.g. `Entrance cooler · Shelf 2`.
  String get label =>
      section == null ? fridge.name : '${fridge.name} · ${section!.label}';
}
