import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:korkem_flow/core/theme/tokens.dart';

/// Builds the light and dark themes from [AppColors].
///
/// The brand green is applied as a tuned accent rather than the raw seed:
/// Material 3 tonal generation from a near-fluorescent seed produces muddy
/// containers. See docs/design_system.md §2.
abstract final class AppTheme {
  static ThemeData light() {
    final base = FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: AppColors.brandOnLight,
        primaryContainer: AppColors.brandLightContainer,
        secondary: AppColors.infoLight,
        secondaryContainer: Color(0xFFD3E7F5),
        tertiary: AppColors.neutralLight,
        tertiaryContainer: Color(0xFFE3E5E1),
        appBarColor: AppColors.surfaceLight,
        error: AppColors.dangerLight,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 4,
    );
    return _applyShared(base);
  }

  static ThemeData dark() {
    final base = FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: AppColors.brand,
        primaryContainer: AppColors.brandDarkContainer,
        secondary: AppColors.infoDark,
        secondaryContainer: Color(0xFF12384F),
        tertiary: AppColors.neutralDark,
        tertiaryContainer: Color(0xFF2A2E29),
        appBarColor: AppColors.surfaceDark,
        error: AppColors.dangerDark,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 8,
    );
    return _applyShared(base);
  }

  static ThemeData _applyShared(ThemeData base) {
    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTouchTarget.min),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTouchTarget.min),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        filled: true,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }

  /// Numeric columns use tabular figures so digits align in lists — without it,
  /// quantity and price columns visibly jitter while scrolling.
  static TextTheme _textTheme(TextTheme base) {
    const tabular = [FontFeature.tabularFigures()];
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: tabular,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
