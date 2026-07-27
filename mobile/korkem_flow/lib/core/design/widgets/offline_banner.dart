import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/tokens/motion.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Persistent banner shown while the device has no connectivity.
///
/// Persistent, not a snackbar: being offline is a *state*, not an event, and
/// the user needs to know why the data they are reading might be stale.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.visible, super.key});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.statusColors.warning;

    return AnimatedSize(
      duration: motionOf(context, AppDuration.quick),
      curve: AppCurves.standard,
      child: visible
          ? Container(
              width: double.infinity,
              color: color.withValues(alpha: 0.14),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(AppIcons.offline, size: AppIconSize.small, color: color),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).offlineBanner,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
