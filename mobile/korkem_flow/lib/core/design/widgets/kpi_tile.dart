import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';

/// A single dashboard metric.
///
/// The value uses `displaySmall`, which carries tabular figures — so a row of
/// tiles keeps its numbers optically aligned instead of drifting.
class KpiTile extends StatelessWidget {
  const KpiTile({
    required this.label,
    required this.value,
    this.icon,
    this.intent,
    this.onTap,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final StatusIntent? intent;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = intent == null
        ? theme.colorScheme.primary
        : context.statusColors.resolve(intent!);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: AppIconSize.small, color: accent),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isLoading)
            // Placeholder matches the final text height so the tile does not
            // resize when the real number lands.
            Container(
              height: AppPlaceholder.metricHeight,
              width: AppPlaceholder.metricWidth,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
            )
          else
            Text(
              value,
              style: theme.textTheme.displaySmall?.copyWith(color: accent),
              maxLines: 1,
            ),
        ],
      ),
    );
  }
}
