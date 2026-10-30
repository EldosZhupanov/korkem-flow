import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/design/motion/hero_title.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/readable_width.dart';
import 'package:korkem_flow/core/design/widgets/section_label.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/core/design/widgets/status_chip.dart';

/// The shell every entity detail screen wears.
///
/// Owns the async states so no detail screen re-invents them, and so a record
/// that fails to load looks the same everywhere.
class DetailScaffold<T> extends StatelessWidget {
  const DetailScaffold({
    required this.state,
    required this.onRefresh,
    required this.builder,
    this.title,
    this.actions = const [],
    super.key,
  });

  final AsyncValue<T> state;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext context, T value) builder;
  final String? title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        actions: actions,
      ),
      body: ReadableWidth(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: switch (state) {
            AsyncLoading() => const ListSkeleton(rows: 4),
            AsyncError(:final error) => ErrorView(
              error: error,
              onRetry: onRefresh,
            ),
            AsyncData(:final value) => ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [builder(context, value)],
            ),
          },
        ),
      ),
    );
  }
}

/// The identity block at the top of a detail screen: what this is, and what
/// state it is in.
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.statusIntent,
    this.heroTag,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? statusLabel;
  final StatusIntent? statusIntent;

  /// Matches the tag on the row this screen was opened from, when it was
  /// opened from one. Null is correct and harmless: a hero with no counterpart
  /// simply does not fly.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heroTag case final tag?)
          HeroTitle(
            tag: tag,
            text: title,
            style: theme.textTheme.headlineMedium,
          )
        else
          Text(title, style: theme.textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (statusLabel != null && statusIntent != null) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusChip(label: statusLabel!, intent: statusIntent!),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// A titled group of fields. Renders nothing when every field is empty, so a
/// sparsely-filled record does not show a page of blank headings.
class DetailSection extends StatelessWidget {
  const DetailSection({required this.label, required this.fields, super.key});

  final String label;
  final List<DetailField> fields;

  @override
  Widget build(BuildContext context) {
    final present = fields.where((f) => f.value != null).toList();
    if (present.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        AppCard(
          child: Column(
            children: [
              for (final (index, field) in present.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpacing.md),
                field,
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// One label/value row, optionally actionable.
///
/// A [value] of `null` means the record does not carry it, and the row is
/// dropped by [DetailSection] rather than rendered as an empty line.
class DetailField extends StatelessWidget {
  const DetailField({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = InfoRow(icon: icon, label: label, value: value ?? '');
    if (onTap == null) return row;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: row),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              AppIcons.forward,
              size: AppIconSize.small,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of primary actions under the header: call, email, open in the Desk.
class DetailActions extends StatelessWidget {
  const DetailActions({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        children: children,
      ),
    );
  }
}

/// A tappable contact action that disables itself when there is nothing to
/// act on, rather than disappearing — a missing phone number is information.
class ContactAction extends StatelessWidget {
  const ContactAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppIconSize.small),
      label: Text(label),
    );
  }
}

/// The empty-state message for a detail screen with no related records.
class DetailEmpty extends StatelessWidget {
  const DetailEmpty({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
