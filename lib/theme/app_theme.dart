import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Visual language for the app.
///
/// Built dark-first: this is a camera tool used in shops, and a dark shell
/// keeps the viewfinder the brightest thing on screen rather than competing
/// with it. The light theme exists so the app still looks deliberate if the
/// system asks for it.
class AppTheme {
  const AppTheme._();

  /// Accent used for primary actions and the active state of controls.
  static const Color seed = Color(0xFF3B82F6);

  /// Chrome behind the viewfinder and sheets.
  static const Color surfaceDark = Color(0xFF101215);
  static const Color surfaceDarkElevated = Color(0xFF181B20);

  /// Scrim over the camera preview, so controls stay legible on any scene.
  static const Color scrim = Color(0xCC000000);

  /// Corner radius shared by sheets, cards and chips.
  static const double radius = 16;
  static const double radiusSmall = 10;

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: isDark ? surfaceDark : null,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? surfaceDark : scheme.surface,
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: isDark ? Colors.white : scheme.onSurface,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : scheme.onSurface,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? surfaceDarkElevated : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: isDark ? Colors.white24 : Colors.black26,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSmall),
            ),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
        thumbColor: scheme.primary,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white10 : Colors.black12,
        thickness: 1,
        space: 1,
      ),
      textTheme: base.textTheme.apply(
        // Tighter tracking on headings reads as more considered at these sizes.
        displayColor: isDark ? Colors.white : scheme.onSurface,
        bodyColor: isDark ? Colors.white : scheme.onSurface,
      ),
    );
  }
}
