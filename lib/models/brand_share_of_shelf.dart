/// Brand roots the classifier pipeline predicts today, longest/most specific
/// first so a finer-grained label (`coca-cola-slim`, `fanta-orange`) is
/// matched back to the right parent brand rather than a shorter false-positive
/// prefix.
///
/// Mirrors the same brand vocabulary [CanShapeRule.dualFormatBrands] and the
/// Fanta flavour classifier use -- there is no single shared enum for it
/// because each of those exists for a different reason, but the *names* have
/// to agree for a report grouped by brand to make sense.
const knownBrandRoots = [
  'coca-cola',
  'xl_energy',
  'sprite',
  'fanta',
  'pepsi',
  'cappy',
];

/// Maps a raw class label to its parent brand root, e.g. `coca-cola-slim` and
/// `fanta-orange` both fold to `coca-cola` and `fanta`. An unrecognised label
/// (a fallback `unclassified`, or a variant classifier's own vocabulary that
/// hasn't been added to [knownBrandRoots] yet) is its own one-item brand
/// rather than silently disappearing into another one.
String brandRootOf(String className) {
  for (final root in knownBrandRoots) {
    if (className == root || className.startsWith('$root-')) return root;
  }
  return className;
}

/// One finer-grained class's slice of a market's detections, within its
/// parent brand.
class SkuShare {
  /// The raw class label, e.g. `coca-cola-slim` or `fanta-orange`.
  ///
  /// Named for what it will become once packaging and size are classified
  /// too -- today it is only ever brand, or brand plus flavour/shape.
  final String className;

  final int count;

  /// This class's share of the *grand total* across every brand, in the
  /// range 0.0 - 1.0 -- so a brand's variant rows sum back to that brand's
  /// own share rather than to 100% each.
  final double fraction;

  const SkuShare({
    required this.className,
    required this.count,
    required this.fraction,
  });

  double get percentage => fraction * 100;
}

/// One brand's total share of a market's detections, broken into whatever
/// finer-grained classes the pipeline currently distinguishes for it.
class BrandShare {
  final String brand;
  final int count;

  /// Share of the grand total, 0.0 - 1.0.
  final double fraction;

  /// Always non-empty; a brand with only one class still gets a single
  /// variant row, so the UI never has to special-case "no breakdown yet".
  final List<SkuShare> variants;

  const BrandShare({
    required this.brand,
    required this.count,
    required this.fraction,
    required this.variants,
  });

  double get percentage => fraction * 100;
}

/// A two-level share-of-shelf: brand totals, each broken into its variants.
///
/// Built from raw stored class labels rather than a single photo's
/// [Detection]s -- this aggregates *counts already recorded* across every
/// submitted capture at a market, where the pixel-area measure
/// [ShareOfShelf] uses would not be comparable from one photo to the next.
///
/// Deliberately only as granular as the pipeline actually is today: a class
/// with no flavour/shape distinction yet (`sprite`, `pepsi`, `cappy`,
/// `xl_energy`) still shows up as its brand's sole variant, so this report
/// stays honest about what the model currently knows rather than inventing
/// detail. Extending it to packaging material or container size later is a
/// matter of the classifier producing a finer label -- this grouping logic
/// does not need to change.
class BrandShareOfShelf {
  final List<BrandShare> brands;
  final int totalCount;

  const BrandShareOfShelf({required this.brands, required this.totalCount});

  const BrandShareOfShelf.empty() : brands = const [], totalCount = 0;

  bool get isEmpty => brands.isEmpty;
  bool get isNotEmpty => brands.isNotEmpty;

  /// Builds the breakdown from every kept detection's class label.
  factory BrandShareOfShelf.fromClassNames(Iterable<String> classNames) {
    final counts = <String, int>{};
    for (final name in classNames) {
      if (name.trim().isEmpty) continue;
      counts.update(name, (existing) => existing + 1, ifAbsent: () => 1);
    }

    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const BrandShareOfShelf.empty();

    final byBrand = <String, Map<String, int>>{};
    for (final entry in counts.entries) {
      final brand = brandRootOf(entry.key);
      byBrand.putIfAbsent(brand, () => {})[entry.key] = entry.value;
    }

    final brands =
        byBrand.entries.map((brandEntry) {
            final brandTotal = brandEntry.value.values.fold(0, (a, b) => a + b);
            final variants =
                brandEntry.value.entries
                    .map(
                      (variantEntry) => SkuShare(
                        className: variantEntry.key,
                        count: variantEntry.value,
                        fraction: variantEntry.value / total,
                      ),
                    )
                    .toList()
                  ..sort((a, b) {
                    final byCount = b.count.compareTo(a.count);
                    return byCount != 0
                        ? byCount
                        : a.className.compareTo(b.className);
                  });

            return BrandShare(
              brand: brandEntry.key,
              count: brandTotal,
              fraction: brandTotal / total,
              variants: variants,
            );
          }).toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            return byCount != 0 ? byCount : a.brand.compareTo(b.brand);
          });

    return BrandShareOfShelf(brands: brands, totalCount: total);
  }
}
