import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/typography.dart';

/// Light and dark themes, both derived from the logo.
///
/// The brand is two colours in a *surface* relationship — a forest field and a
/// cream mark — which is why the two themes are the same artwork either way up.
/// Light is forest ink on cream paper; dark is the logo itself. Neither invents
/// a colour the brand does not own. See `docs/design_system.md` §2.
///
/// Surfaces are pinned rather than blended. FlexColorScheme's surface modes
/// tint every surface toward the primary, and with a primary this dark that
/// muddied the cream into a grey-green; the palette already has exact values
/// measured against WCAG, and there is nothing for a blend to improve.
abstract final class AppTheme {
  static ThemeData light() => _shared(
    FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: AppColors.forest,
        primaryContainer: AppColors.brandContainerLight,
        secondary: AppColors.infoLight,
        secondaryContainer: AppColors.secondaryContainerLight,
        tertiary: AppColors.neutralLight,
        tertiaryContainer: AppColors.tertiaryContainerLight,
        appBarColor: AppColors.surfaceLight,
        error: AppColors.dangerLight,
      ),
      surface: AppColors.surfaceLight,
      scaffoldBackground: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
    ),
    Brightness.light,
  );

  static ThemeData dark() => _shared(
    FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: AppColors.cream,
        primaryContainer: AppColors.brandContainerDark,
        secondary: AppColors.infoDark,
        secondaryContainer: AppColors.secondaryContainerDark,
        tertiary: AppColors.neutralDark,
        tertiaryContainer: AppColors.tertiaryContainerDark,
        appBarColor: AppColors.surfaceDark,
        error: AppColors.dangerDark,
      ),
      surface: AppColors.surfaceDark,
      scaffoldBackground: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
    ),
    Brightness.dark,
  );

  static OutlineInputBorder _fieldBorder(bool isDark) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(
      color: isDark
          ? AppColors.outlineStrongDark
          : AppColors.outlineStrongLight,
    ),
  );

  static ThemeData _shared(ThemeData base, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final textTheme = AppTypography.textTheme(brightness);

    return base.copyWith(
      textTheme: textTheme,
      // One transition on every platform, chosen rather than inherited.
      // Material's default varies by host OS, so the same push looked
      // different on the phone and on the Linux desktop build — the shell is
      // identical, so the motion should be too. Fade-through matches a tabbed
      // app where a push is a change of subject, not a step deeper into a
      // hierarchy.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: const FadeForwardsPageTransitionsBuilder(),
        },
      ),
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

      // A field is now bounded by a line, not only by a fill.
      //
      // The fill sits about 1.1:1 above the page — a difference many people
      // cannot see at all, and one that disappears entirely under glare on a
      // workshop floor. The border carries the job instead, at a measured 3:1,
      // which is what WCAG 1.4.11 asks of anything that identifies a component.
      // It also happens to be what makes the form look considered rather than
      // like text floating on a slightly different grey.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceContainerDark
            : AppColors.surfaceContainerLight,
        border: _fieldBorder(isDark),
        enabledBorder: _fieldBorder(isDark),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(
            color: base.colorScheme.primary,
            width: AppStroke.focus,
          ),
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

      // The bar is the page, not a separate slab. Material's default gives it
      // its own elevated surface, which under this palette came out near-black
      // against a forest page — a black band across the bottom of the brand.
      // The selected indicator was worse: it defaults to `secondaryContainer`,
      // which is the blue anchor, so the one persistently-visible piece of
      // chrome in the app was the only thing on screen that was not KORKEM.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        indicatorColor: isDark
            ? AppColors.brandContainerDark
            : AppColors.brandContainerLight,
        elevation: 0,
        height: AppNavigation.barHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),

      // The navigation panel is the page it sits beside, not a slab of its own.
      // Material's default gives a Drawer its own elevated surface, which under
      // this palette came out near-black against a forest app — a black column
      // where the brand should be.
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),

      // The rail is the same decision on a wider screen.
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        indicatorColor: isDark
            ? AppColors.brandContainerDark
            : AppColors.brandContainerLight,
        elevation: 0,
      ),

      dividerTheme: DividerThemeData(
        space: AppStroke.hairline,
        thickness: AppStroke.hairline,
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
