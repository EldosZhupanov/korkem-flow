import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:korkem_flow/core/api/api_providers.dart';
import 'package:korkem_flow/core/api/mutation_outbox.dart';
import 'package:korkem_flow/core/design/theme/status_colors.dart';
import 'package:korkem_flow/core/design/tokens/dimensions.dart';
import 'package:korkem_flow/core/design/tokens/icons.dart';
import 'package:korkem_flow/core/design/widgets/app_card.dart';
import 'package:korkem_flow/core/design/widgets/state_views.dart';
import 'package:korkem_flow/features/outbox/presentation/outbox_command_formatter.dart';
import 'package:korkem_flow/l10n/app_localizations.dart';

/// Screen displaying the ordered queue of pending mutations and rejections.
class OutboxScreen extends ConsumerWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final outbox = ref.watch(mutationOutboxProvider);
    final snapshot =
        ref.watch(mutationOutboxSnapshotProvider).value ?? outbox.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.outboxTitle),
        actions: [
          if (snapshot.pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: FilledButton.icon(
                onPressed: () => unawaited(
                  outbox.retryPending(ref.read(frappeClientProvider)),
                ),
                icon: const Icon(AppIcons.refresh, size: AppIconSize.small),
                label: Text(l10n.outboxRetry),
              ),
            ),
        ],
      ),
      body: snapshot.pending.isEmpty && snapshot.rejection == null
          ? EmptyView(
              icon: AppIcons.check,
              title: l10n.outboxEmptyTitle,
              message: l10n.outboxEmptyBody,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (snapshot.rejection != null) ...[
                  _RejectionBanner(
                    rejection: snapshot.rejection!,
                    onClose: outbox.clearRejection,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                for (var i = 0; i < snapshot.pending.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.md),
                  _PendingMutationCard(
                    index: i + 1,
                    mutation: snapshot.pending[i],
                  ),
                ],
              ],
            ),
    );
  }
}

class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({
    required this.rejection,
    required this.onClose,
  });

  final OutboxRejection rejection;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = context.statusColors.danger;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.danger, size: AppIconSize.small, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.outboxRejected(rejection.reason ?? l10n.errorGeneric),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onClose,
            tooltip: l10n.actionClose,
            icon: const Icon(AppIcons.close, size: AppIconSize.small),
          ),
        ],
      ),
    );
  }
}

class _PendingMutationCard extends StatelessWidget {
  const _PendingMutationCard({
    required this.index,
    required this.mutation,
  });

  final int index;
  final PendingMutation mutation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final info = describePendingMutation(mutation, l10n);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xxl,
            height: AppSpacing.xxl,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        info.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      info.icon,
                      size: AppIconSize.small,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
                if (info.details.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final detail in info.details)
                        Text(
                          detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      AppIcons.offline,
                      size: AppIconSize.dense,
                      color: context.statusColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      l10n.outboxQueued,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.statusColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
