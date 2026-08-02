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

  /// Minimum height for a primary action, which is also the accessible tap
  /// target. Deliberately a *height*: see [_buttonMinimumSize].
  static const double controlHeight = 48;

  /// Floor for button size.
  ///
  /// The width must stay finite. `Size.fromHeight` looks like the obvious way
  /// to say "48 tall, natural width", but it expands to `Size(infinity, 48)`,
  /// which is a minimum *width* of infinity. A button in a [Column] survives
  /// that because the column bounds it; a button in a [Row] is laid out with an
  /// unbounded main axis and inherits the infinity, so it fails layout and is
  /// never painted. That is not hypothetical -- it silently removed the Approve
  /// button from the access-request list while leaving Decline beside it.
  ///
  /// 64 is Material's own minimum button width. Anything that wants to fill its
  /// row says so at the call site, which is where the intent belongs.
  static const Size _buttonMinimumSize = Size(64, controlHeight);

  /// The dark elevation ramp.
  ///
  /// Set explicitly rather than left to the generated neutral palette, which is
  /// tuned for a lighter base than [surfaceDark] and leaves cards nearly
  /// indistinguishable from the background.
  static const Color _darkContainerLowest = Color(0xFF0B0D10);
  static const Color _darkContainerLow = Color(0xFF14171B);
  static const Color _darkContainer = Color(0xFF181B20);
  static const Color _darkContainerHigh = Color(0xFF1F232A);
  static const Color _darkContainerHighest = Color(0xFF262B33);

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: seed,
            brightness: brightness,
            surface: surfaceDark,
            surfaceContainerLowest: _darkContainerLowest,
            surfaceContainerLow: _darkContainerLow,
            surfaceContainer: _darkContainer,
            surfaceContainerHigh: _darkContainerHigh,
            surfaceContainerHighest: _darkContainerHighest,
          )
        : ColorScheme.fromSeed(seedColor: seed, brightness: brightness);

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
    );

    final smallShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSmall),
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
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
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
          minimumSize: _buttonMinimumSize,
          shape: smallShape,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _buttonMinimumSize,
          shape: smallShape,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: smallShape,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(smallShape)),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      chipTheme: ChipThemeData(
        // Solid fills rather than the translucent ones this used to carry. A
        // low-alpha tint over a near-black surface lands within a few points of
        // the background, so an unselected chip read as unlabelled space and a
        // selected one was barely distinguishable from it.
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        checkmarkColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide.none,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          // A WidgetStateColor is still a Color, and chips resolve the label
          // colour against their own states -- which is the only way to give
          // selected and unselected chips different foregrounds from a theme.
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? surfaceDarkElevated : scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? surfaceDarkElevated : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? surfaceDarkElevated : scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? _darkContainerHighest : null,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: smallShape,
      ),
      textTheme: base.textTheme.apply(
        // Tighter tracking on headings reads as more considered at these sizes.
        displayColor: scheme.onSurface,
        bodyColor: scheme.onSurface,
      ),
    );
  }
}
