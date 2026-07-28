import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/typography.dart';

/// Light and dark themes.
///
/// The brand green is applied as a *tuned* accent rather than the raw seed:
/// Material 3's tonal generation from a near-fluorescent seed produces muddy
/// containers. See `docs/design_system.md` §2.
abstract final class AppTheme {
  static ThemeData light() => _shared(
    FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: AppColors.brandOnLight,
        primaryContainer: AppColors.brandContainerLight,
        secondary: AppColors.infoLight,
        secondaryContainer: AppColors.secondaryContainerLight,
        tertiary: AppColors.neutralLight,
        tertiaryContainer: AppColors.tertiaryContainerLight,
        appBarColor: AppColors.surfaceLight,
        error: AppColors.dangerLight,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 4,
    ),
    Brightness.light,
  );

  static ThemeData dark() => _shared(
    FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: AppColors.brand,
        primaryContainer: AppColors.brandContainerDark,
        secondary: AppColors.infoDark,
        secondaryContainer: AppColors.secondaryContainerDark,
        tertiary: AppColors.neutralDark,
        tertiaryContainer: AppColors.tertiaryContainerDark,
        appBarColor: AppColors.surfaceDark,
        error: AppColors.dangerDark,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 8,
    ),
    Brightness.dark,
  );

  static ThemeData _shared(ThemeData base, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final textTheme = AppTypography.textTheme(brightness);

    return base.copyWith(
      textTheme: textTheme,
      // Overridden too, not just `textTheme`. Several Material widgets — the
      // tab bar among them — resolve their label style from `primaryTextTheme`,
      // which otherwise stays on Flutter's default family. That is how tab
      // labels ended up rendered in a font the design system never chose.
      primaryTextTheme: textTheme,
      extensions: [StatusColors.of(brightness)],

      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
        dividerColor: Colors.transparent,
      ),

      // Cards carry no shadow in dark mode — shadows are invisible against a
      // dark surface and only cost a raster pass. A hairline outline does the
      // separation instead.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark
            ? AppColors.surfaceContainerDark
            : AppColors.surfaceContainerLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: isDark
              ? const BorderSide(color: AppColors.outlineDark)
              : BorderSide.none,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppTouchTarget.min),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppTouchTarget.min),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppTouchTarget.min),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}
