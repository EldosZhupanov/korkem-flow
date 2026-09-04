import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/features/events/domain/proactive_event.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Renders a single proactive event noticed by KORKEM.
///
/// Urgency is displayed with a tri-factor signal:
/// 1. Color: from [StatusColors.resolve] via context.statusColors
/// 2. Shape / Glyph: semantic [AppIcons] icon
/// 3. Word: localized severity label (Urgent / Attention / Info)
class EventCard extends StatelessWidget {
  const EventCard({
    required this.event,
    required this.onDismiss,
    this.onAction,
    this.onTap,
    super.key,
  });

  final ProactiveEvent event;
  final VoidCallback onDismiss;
  final void Function(EventAction action)? onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final statusColors = context.statusColors;
    final intentColor = statusColors.resolve(event.severity.intent);

    final subjectRoute = event.subject?.route;
    final effectiveTap =
        onTap ??
        (subjectRoute != null ? () => context.push(subjectRoute) : null);

    return AppCard(
      onTap: effectiveTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Severity badge with color, shape/glyph, and word:
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: intentColor.withValues(alpha: AppTint.surface),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      event.severity.icon,
                      size: AppIconSize.dense,
                      color: intentColor,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      event.severity.label(l10n).toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: intentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.outline,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                ),
                child: Text(l10n.eventsActionDismiss),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            event.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (event.detail != null && event.detail!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              event.detail!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (event.subject != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.forward,
                  size: AppIconSize.dense,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    '${event.subject!.doctype}: ${event.subject!.name}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (event.actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final action in event.actions)
                  FilledButton(
                    onPressed: () => onAction?.call(action),
                    child: Text(action.label),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
