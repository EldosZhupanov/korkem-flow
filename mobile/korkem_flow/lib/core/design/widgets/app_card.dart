import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';

/// The base surface for every entity in the app.
///
/// Whole-card tap target with an ink response; inline actions must sit in their
/// own hit areas at least 8dp apart to prevent mis-taps.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// One entity, one card.
///
/// Deal, Work Order, Task and Item all share this shape — the same widget with
/// different content, rather than four near-identical copies that drift apart.
class EntityCard extends StatelessWidget {
  const EntityCard({
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.statusIntent,
    this.metadata = const [],
    this.leading,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? statusLabel;
  final StatusIntent? statusIntent;

  /// Small facts shown on the bottom row: date, quantity, assignee.
  final List<EntityMeta> metadata;

  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (statusLabel != null && statusIntent != null) ...[
                const SizedBox(width: AppSpacing.sm),
                StatusChip(label: statusLabel!, intent: statusIntent!),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              children: [
                for (final meta in metadata) _MetaChip(meta: meta),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A single fact on a card's metadata row.
@immutable
class EntityMeta {
  const EntityMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.meta});

  final EntityMeta meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          meta.icon,
          size: AppIconSize.inline - 2,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(meta.label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
