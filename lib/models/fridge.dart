/// A cooler or shelf bay inside a market, and the unit a capture is recorded
/// against.
///
/// The real-world dimensions are optional and exist so a facing count can
/// eventually be turned into occupied centimetres. Nothing depends on them yet.
class Fridge {
  final String id;
  final String companyId;
  final String pointOfSaleId;
  final String name;

  /// Printed on a label and scanned to identify this fridge without typing.
  final String qrToken;

  final double? widthCm;
  final double? heightCm;
  final bool isActive;

  /// Shelves or bays this fridge is divided into.
  ///
  /// Empty when the query did not ask for them. Every fridge has at least one
  /// section, created by a database trigger at insert.
  final List<FridgeSection> sections;

  const Fridge({
    required this.id,
    required this.companyId,
    required this.pointOfSaleId,
    required this.name,
    required this.qrToken,
    this.widthCm,
    this.heightCm,
    this.isActive = true,
    this.sections = const [],
  });

  factory Fridge.fromJson(Map<String, dynamic> json) {
    final sections = json['fridge_sections'];
    return Fridge(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      pointOfSaleId: json['point_of_sale_id'] as String,
      name: json['name'] as String? ?? 'Unnamed fridge',
      qrToken: json['qr_token'] as String? ?? '',
      widthCm: (json['width_cm'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      sections: sections is List
          ? (sections
                .map((s) => FridgeSection.fromJson(s as Map<String, dynamic>))
                .toList()
              ..sort((a, b) => a.position.compareTo(b.position)))
          : const [],
    );
  }

  /// Whether this fridge is split into parts a rep has to choose between.
  ///
  /// A single-section fridge shows no section UI at all: asking someone to pick
  /// "Shelf 1 of 1" is a step that teaches them to tap without reading.
  bool get hasMultipleSections => sections.length > 1;

  /// Size rendered for display, or null when it was never measured.
  String? get sizeLabel {
    if (widthCm == null && heightCm == null) return null;
    String fmt(double? v) => v == null ? '?' : v.toStringAsFixed(0);
    return '${fmt(widthCm)} × ${fmt(heightCm)} cm';
  }
}

/// One shelf or bay of a fridge.
///
/// Fixed at setup rather than chosen per visit. A fridge split three ways one
/// week and two the next produces a trend line that means nothing.
class FridgeSection {
  final String id;
  final String fridgeId;
  final String label;

  /// Order within the fridge, top to bottom.
  final int position;

  const FridgeSection({
    required this.id,
    required this.fridgeId,
    required this.label,
    required this.position,
  });

  factory FridgeSection.fromJson(Map<String, dynamic> json) => FridgeSection(
    id: json['id'] as String,
    fridgeId: json['fridge_id'] as String? ?? '',
    label: json['label'] as String? ?? 'Section',
    position: json['position'] as int? ?? 0,
  );
}
