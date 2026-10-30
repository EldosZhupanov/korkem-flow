import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';

/// Semantic intent behind a piece of status.
///
/// Colour is never the only signal: every use pairs an intent's colour with
/// its icon (see [StatusColors.iconFor]) and a text label.
enum StatusIntent { success, warning, danger, info, neutral }

/// Semantic status colours, delivered through the theme.
///
/// This exists so widgets resolve status colours from `Theme.of(context)`
/// instead of importing [AppColors] and branching on brightness themselves —
/// which is how light/dark drift creeps in.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
  });

  factory StatusColors.of(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return StatusColors(
      success: dark ? AppColors.successDark : AppColors.successLight,
      warning: dark ? AppColors.warningDark : AppColors.warningLight,
      danger: dark ? AppColors.dangerDark : AppColors.dangerLight,
      info: dark ? AppColors.infoDark : AppColors.infoLight,
      neutral: dark ? AppColors.neutralDark : AppColors.neutralLight,
    );
  }

  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color neutral;

  Color resolve(StatusIntent intent) => switch (intent) {
    StatusIntent.success => success,
    StatusIntent.warning => warning,
    StatusIntent.danger => danger,
    StatusIntent.info => info,
    StatusIntent.neutral => neutral,
  };

  static IconData iconFor(StatusIntent intent) => switch (intent) {
    StatusIntent.success => AppIcons.success,
    StatusIntent.warning => AppIcons.warning,
    StatusIntent.danger => AppIcons.danger,
    StatusIntent.info => AppIcons.info,
    StatusIntent.neutral => AppIcons.neutral,
  };

  @override
  StatusColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? neutral,
  }) {
    return StatusColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

/// Convenience accessor so widgets read `context.statusColors.success`.
extension StatusColorsX on BuildContext {
  StatusColors get statusColors =>
      Theme.of(this).extension<StatusColors>() ??
      StatusColors.of(Theme.of(this).brightness);
}
