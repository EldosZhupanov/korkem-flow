import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Compact status indicator.
///
/// Always icon **plus** text, never a bare colour swatch: colour alone is not
/// an accessible signal, and a status is the single most-scanned element in
/// every list in this app.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.intent,
    this.compact = false,
    super.key,
  });

  final String label;
  final StatusIntent intent;

  /// Drops the icon when horizontal space is tight (dense list rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = context.statusColors.resolve(intent);
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.semanticStatus(label),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppTint.surface),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(
                StatusColors.iconFor(intent),
                size: AppIconSize.dense,
                color: color,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
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
}
