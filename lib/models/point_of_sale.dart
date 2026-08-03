/// A supermarket or shop a company sells into.
///
/// Called a "market" throughout the UI because that is what the people using
/// this call it; `points_of_sale` is the database's name for the same thing.
///
/// These are labels for data, never users -- nobody signs in as a market. They
/// are also per-company by design: if two tenants sell into the same
/// supermarket that is two rows, because tenant isolation is far easier to get
/// right up front than to repair later.
class PointOfSale {
  final String id;
  final String companyId;
  final String name;

  /// City is required by the schema: a market list without it stops being
  /// searchable the moment a chain has branches in more than one place.
  final String city;

  /// Neighbourhood or district. Optional.
  final String? area;
  final String? address;

  final double? latitude;
  final double? longitude;

  final bool isActive;

  /// How many fridges are recorded here, when the query asked for the count.
  ///
  /// Null means "not loaded" rather than zero -- the difference matters,
  /// because zero is worth showing a warning for and unknown is not.
  final int? fridgeCount;

  const PointOfSale({
    required this.id,
    required this.companyId,
    required this.name,
    required this.city,
    this.area,
    this.address,
    this.latitude,
    this.longitude,
    this.isActive = true,
    this.fridgeCount,
  });

  factory PointOfSale.fromJson(Map<String, dynamic> json) {
    // PostgREST returns an aggregate join as a list holding one row.
    final fridges = json['fridges'];
    final count = fridges is List && fridges.isNotEmpty
        ? (fridges.first as Map)['count'] as int?
        : null;

    return PointOfSale(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String? ?? 'Unnamed market',
      city: json['city'] as String? ?? '',
      area: json['area'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      fridgeCount: count,
    );
  }

  /// City and area on one line, for the subtitle of a list row.
  String get locationLabel {
    final district = area?.trim();
    if (district == null || district.isEmpty) return city;
    return '$city · $district';
  }

  /// A market with no fridges cannot be captured against, so it is worth
  /// calling out rather than letting a rep discover it at the shelf.
  bool get hasNoFridges => fridgeCount == 0;
}
