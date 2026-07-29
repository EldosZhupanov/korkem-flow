import 'package:flutter/material.dart';
import 'package:korkem_flow/core/design/motion/app_pressable.dart';
import 'package:korkem_flow/core/design/motion/hero_title.dart';
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

    return AppPressable(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

/// Where an entity's status chip sits on the card.
enum StatusPlacement {
  /// Top-right, opposite the title. Scannable down the edge of a list — right
  /// for short titles like organisation names.
  header,

  /// Inline with the other facts. Right when the title needs the full width:
  /// a chip in the header row steals that width from *every* line of the
  /// title, not just the first, because both live inside one [Row].
  metadata,
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
    this.statusPlacement = StatusPlacement.header,
    this.metadata = const [],
    this.leading,
    this.onTap,
    this.heroTag,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? statusLabel;
  final StatusIntent? statusIntent;
  final StatusPlacement statusPlacement;

  /// Small facts shown on the bottom row: date, quantity, assignee.
  final List<EntityMeta> metadata;

  final Widget? leading;
  final VoidCallback? onTap;

  /// Set only where the card opens a detail screen that carries the same tag.
  /// A tag must be unique among everything mounted at once, so this is left
  /// null on any list whose rows the user reaches another way.
  final String? heroTag;

  Widget? _statusChip() {
    if (statusLabel == null || statusIntent == null) return null;
    return StatusChip(label: statusLabel!, intent: statusIntent!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = _statusChip();

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
                child: _Title(
                  text: title,
                  style: theme.textTheme.titleMedium,
                  heroTag: heroTag,
                ),
              ),
              if (chip != null &&
                  statusPlacement == StatusPlacement.header) ...[
                const SizedBox(width: AppSpacing.sm),
                chip,
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
          if (metadata.isNotEmpty ||
              (chip != null &&
                  statusPlacement == StatusPlacement.metadata)) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (chip != null && statusPlacement == StatusPlacement.metadata)
                  chip,
                for (final meta in metadata) _MetaChip(meta: meta),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The entity's name, flying to its detail screen when there is one to fly to.
///
/// Two lines, not one: Russian and Kazakh entity names run far longer than
/// their English equivalents, and a single line truncated to "Кромление фаса…"
/// tells a worker nothing.
class _Title extends StatelessWidget {
  const _Title({
    required this.text,
    required this.style,
    required this.heroTag,
  });

  final String text;
  final TextStyle? style;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tag = heroTag;
    if (tag == null) {
      return Text(
        text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return HeroTitle(tag: tag, text: text, style: style, maxLines: 2);
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
