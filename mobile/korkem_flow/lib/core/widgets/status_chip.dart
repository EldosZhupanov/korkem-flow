import 'package:flutter/material.dart';
import 'package:korkem_flow/core/theme/tokens.dart';

/// Semantic intent behind a status. Colour alone is never the signal —
/// every chip carries an icon and a label (docs/design_system.md §11).
enum StatusIntent { success, warning, danger, info, neutral }

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.intent,
    super.key,
  });

  final String label;
  final StatusIntent intent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _color(isDark);

    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _color(bool isDark) => switch (intent) {
    StatusIntent.success =>
      isDark ? AppColors.successDark : AppColors.successLight,
    StatusIntent.warning =>
      isDark ? AppColors.warningDark : AppColors.warningLight,
    StatusIntent.danger =>
      isDark ? AppColors.dangerDark : AppColors.dangerLight,
    StatusIntent.info => isDark ? AppColors.infoDark : AppColors.infoLight,
    StatusIntent.neutral =>
      isDark ? AppColors.neutralDark : AppColors.neutralLight,
  };

  IconData get _icon => switch (intent) {
    StatusIntent.success => Icons.check_circle_outline,
    StatusIntent.warning => Icons.schedule,
    StatusIntent.danger => Icons.error_outline,
    StatusIntent.info => Icons.info_outline,
    StatusIntent.neutral => Icons.inventory_2_outlined,
  };
}
